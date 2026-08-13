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
    # Follow-up #6: X стартує чисто, але одразу після `wait "$waitPID"` WM
    # репортував "Another window manager is already running" — виявилось,
    # `$DISPLAY` у клієнтському скрипті був :0 (де реально живе
    # halley/Xwayland-compat), а не :1. Форсуємо $DISPLAY явно, перед wm.start.
    #
    # Follow-up #7: спершу піднімали Xorg через `xinit`, але його вбудована
    # перевірка готовності сервера ("waiting for X server to begin accepting
    # connections") ніколи не спрацьовувала — приблизно за 240с здавалась і
    # вбивала сервер, хоча він сам увесь цей час був повністю робочий і
    # приймав з'єднання (перевірено підключенням ззовні, 81/81 успіхів).
    # Замінили на власний запуск Xorg у фоні + пулінг сокета
    # /tmp/.X11-unix/X1, замість вбудованої в xinit перевірки. Це, своєю
    # чергою, забрало неявний "-keeptty", який xinit завжди сам додає до
    # команди сервера — без нього Xorg не міг отримати VT через
    # systemd-logind ("Cannot open virtual console: Permission denied").
    #
    # Follow-up #9: VSCodium не запускався в цій сесії — з'ясувалось,
    # greetd/pam_systemd протікає `XDG_SESSION_TYPE=wayland` навіть у цю
    # приватну X11-сесію (той самий клас багу, що й DISPLAY=:0 у Follow-up
    # #6, лише інша змінна). Electron/Chromium (принаймні VSCodium) читає
    # XDG_SESSION_TYPE напряму для вибору ozone-бекенду, незалежно від
    # прапорців у власній обгортці пакета — бачить "wayland", намагається
    # підключитись, отримує "Connection refused" (жодного wayland-компоцитора
    # тут нема) і виходить, вікно так і не з'являється. Підтверджено
    # порівняльним тестом: з протеклим XDG_SESSION_TYPE=wayland — та сама
    # помилка; з форсованим XDG_SESSION_TYPE=x11 — запускається нормально.
    clientScript = ''
      export DISPLAY=:1
      export XDG_SESSION_TYPE=x11

      # Follow-up #12: home.sessionVariables (напр. crew/theming.nix'ів
      # XDG_DATA_DIRS для gsettings-desktop-schemas) експортуються лише в
      # /etc/profiles/per-user/ryudzyn/etc/profile.d/hm-session-vars.sh,
      # який джерелять login-шели — ця xinit-сесія такою не є, тож sxhkd/WM
      # їх ніколи не бачили (підтверджено читанням /proc/<sxhkd>/environ:
      # XDG_DATA_DIRS без gsettings-schemas). Джерелимо той самий файл тут,
      # той самий клас фіксу, що й DISPLAY/XDG_SESSION_TYPE вище.
      . /etc/profiles/per-user/ryudzyn/etc/profile.d/hm-session-vars.sh

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
