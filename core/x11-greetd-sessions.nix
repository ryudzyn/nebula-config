{ config, lib, pkgs, ... }:

# greetd (на відміну від sddm, який ми звідси прибрали) сам не запускає Xorg —
# автозгенеровані `services.xserver.windowManager.*` xsession-записи це просто
# ігнорують і одразу конектяться до неіснуючого DISPLAY. Тому для кожного
# увімкненого X11 WM додаємо власний сесійний запис, що сам піднімає приватний
# Xorg. (Раніше це робилось через `xinit` — прибрано у Follow-up #7 round 5,
# бо власна вбудована в xinit перевірка готовності сервера не працювала; назви
# на кшталт `mkXinitSession`/`-xinit-wrapper` лишились історичними, не
# перейменовував, щоб не роздувати diff.)
let
  # halley (наша wayland-сесія) вже тримає display :0 через свій Xwayland-compat,
  # тож ці ігрові X11-сесії піднімають свій приватний Xorg на :1, щоб не битися
  # за той самий сокет. Прибираємо ":0"/"-terminate" зі стандартних xserverArgs
  # (вони розраховані на "класичний" DM, який сам керує :0) і підставляємо своє.
  # "-logfile /dev/null" теж прибираємо — інакше Xorg не лишає жодного логу для
  # діагностики, коли сесія падає.
  xserverArgs = lib.remove "-logfile /dev/null"
    (lib.remove ":0" (lib.remove "-terminate" config.services.xserver.displayManager.xserverArgs));

  # Desktop Entry Exec= виконується напряму (execvp), без шела — greetd/tuigreet
  # НЕ підставляють значення змінних оточення на кшталт $XDG_VTNR. Тож весь запуск
  # ховаємо в один реальний shell-скрипт (writeShellScript має шебанг), а Exec=
  # лише вказує на нього — тоді $XDG_VTNR підставляється по-справжньому, під час
  # виконання, справжнім /bin/sh.
  mkXinitSession = wm: let
    # wm.start (з services.xserver.windowManager.<wm>) запускає сам WM у фоні й
    # лишає "wait \"$waitPID\"" на відповідальність викликача — у звичайному
    # display-managers/default.nix його дописує generic xsession-скрипт, якого
    # ми тут не використовуємо. Без нього клієнтський скрипт завершується
    # одразу після `wm & waitPID=$!`.
    #
    # Історія фіксів нижче (усі підтверджені живими тестами) -- один
    # повторюваний клас бага: різні споживачі (WM, Electron, sxhkd,
    # D-Bus-активовані user-сервіси) або бачать чуже оточення (DISPLAY=:0 від
    # halley/Xwayland-compat, протеклий XDG_SESSION_TYPE=wayland від
    # greetd/pam_systemd), або не бачать потрібного (XDG_DATA_DIRS з
    # home-manager, DISPLAY у systemd --user), бо ця xinit-сесія — не
    # login-шел і не звичайний generic-xsession-скрипт:
    # - DISPLAY форсується явно (був :0, мав бути :1)
    # - XDG_SESSION_TYPE форсується в x11 (Electron/VSCodium бачив протеклий
    #   "wayland", ловив "Connection refused" і не показував вікно)
    # - xinit замінено на прямий запуск Xorg + пулінг /tmp/.X11-unix/X1:
    #   вбудована перевірка готовності xinit ніколи не спрацьовувала (~240с
    #   таймаут і вбивство сервера, хоча він приймав з'єднання), а неявний
    #   "-keeptty" від xinit тепер треба ставити вручну (без нього — "Cannot
    #   open virtual console: Permission denied")
    clientScript = ''
      export DISPLAY=:1
      export XDG_SESSION_TYPE=x11

      # hm-session-vars.sh (XDG_DATA_DIRS з gsettings-desktop-schemas тощо) —
      # джерелять тільки login-шели, ця сесія такою не є.
      . /etc/profiles/per-user/ryudzyn/etc/profile.d/hm-session-vars.sh

      # D-Bus-активовані user-сервіси (напр. xdg-desktop-portal-gtk.service —
      # звідти GTK4/libadwaita типу pavucontrol бере color-scheme) стартують
      # через systemd --user manager, який успадковує СВОЄ оточення, а не
      # export DISPLAY вище — без import-environment падає з "cannot open
      # display" і лишається failed до кінця сесії.
      systemctl --user import-environment DISPLAY XDG_SESSION_TYPE
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY XDG_SESSION_TYPE

      ${pkgs.xorg-server}/bin/X -keeptty ${toString xserverArgs} :1 vt$XDG_VTNR &
      xpid=$!
      trap 'kill "$xpid" 2>/dev/null; wait "$xpid" 2>/dev/null' EXIT

      for i in $(seq 1 100); do
        [ -e /tmp/.X11-unix/X1 ] && break
        sleep 0.2
      done
      [ -e /tmp/.X11-unix/X1 ] || exit 1
    '' + wm.start + ''

      test -n "$waitPID" && wait "$waitPID"
    '';
    wrapper = pkgs.writeShellScript "${wm.name}-xinit-wrapper" ''
      exec ${pkgs.writeShellScript "${wm.name}-start" clientScript}
    '';
  in pkgs.writeTextFile {
    name = "${wm.name}-xsession-xinit";
    destination = "/share/xsessions/${wm.name}.desktop";
    text = ''
      [Desktop Entry]
      Type=XSession
      Name=${wm.name} (xinit)
      Exec=${wrapper}
      DesktopNames=${wm.name}
    '';
  } // {
    providedSessions = [ wm.name ];
  };
in
{
  services.displayManager.sessionPackages =
    map mkXinitSession (lib.filter (wm: wm.start != "") config.services.xserver.windowManager.session);
}
