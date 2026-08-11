{ config, lib, pkgs, ... }:

# greetd (на відміну від sddm, який ми звідси прибрали) сам не запускає Xorg —
# автозгенеровані `services.xserver.windowManager.*` xsession-записи це просто
# ігнорують і одразу конектяться до неіснуючого DISPLAY. Тому для кожного
# увімкненого X11 WM додаємо власний сесійний запис, обгорнутий у xinit, який
# сам піднімає приватний Xorg.
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
    # ми тут не використовуємо. Без нього клієнтський скрипт xinit завершується
    # одразу після `wm & waitPID=$!`, xinit бачить "клієнт вийшов" і миттєво
    # вбиває щойно піднятий Xorg.
    # Follow-up #6: X стартує чисто, але одразу після `wait "$waitPID"` WM
    # репортував "Another window manager is already running" — виявилось,
    # `$DISPLAY` у клієнтському скрипті був :0 (де реально живе
    # halley/Xwayland-compat), а не :1. `xinit` не завжди перезаписує вже
    # встановлений $DISPLAY зі свого запуску сервера — :0 протікав з
    # успадкованого середовища сесії. Форсуємо $DISPLAY явно, перед wm.start.
    clientScript = ''
      export DISPLAY=:1
    '' + wm.start + ''

      test -n "$waitPID" && wait "$waitPID"
    '';
    wrapper = pkgs.writeShellScript "${wm.name}-xinit-wrapper" ''
      exec ${pkgs.xinit}/bin/xinit ${pkgs.writeShellScript "${wm.name}-start" clientScript} -- ${pkgs.xorg-server}/bin/X ${toString xserverArgs} :1 vt$XDG_VTNR
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
