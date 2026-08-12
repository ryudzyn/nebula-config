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
    # Follow-up #7, round 5: раніше тут був `xinit`, який сам піднімав Xorg і
    # чекав, поки сервер стане готовим, перш ніж форкати клієнта. Живе
    # трасування показало: Xorg стартує й повністю готовий (усі пристрої
    # проліковано) менше ніж за секунду, і залишається абсолютно робочим —
    # підключення (`DISPLAY=:1 xset q`) з іншого терміналу спрацьовувало 81/81
    # разів поспіль, поки Xorg просто "висів" — але сам `xinit` весь цей час
    # (рівно ~240с щоразу) друкував "waiting for X server to begin accepting
    # connections", жодного разу не форкаючи клієнта, і зрештою здавався з
    # "unable to connect to X server: Connection refused" та вбивав щойно
    # робочий сервер. Причина в самому бінарнику `xinit` (nixpkgs, версія
    # 1.4.4) не встановлена — без дизасемблера далі копати нема сенсу, а
    # обхідний шлях (не покладатись на вбудовану в xinit перевірку готовності)
    # і дешевший, і вже емпірично перевірений. Тому піднімаємо Xorg самі, у
    # фоні, і чекаємо появи сокета `/tmp/.X11-unix/X<N>` власним пулінгом —
    # саме той метод, яким я підключався 81 раз без жодного провалу.
    clientScript = ''
      export DISPLAY=:1
      TRACE=/tmp/${wm.name}-xinit-trace.log
      echo "[$(date -Is)] clientScript start (no xinit, round 5)" >> "$TRACE"
      exec >>"$TRACE" 2>&1

      # Round 5 continued: без xinit зник неявний "-keeptty", який xinit завжди
      # сам додає до команди X-сервера. Без нього X друкує "systemd-logind
      # integration requires -keeptty ... disabling logind integration" і одразу
      # "xf86OpenConsole: Cannot open virtual console 1 (Permission denied)" —
      # без -keeptty X намагається відкрити VT напряму (ioctl), а не через
      # logind-сесію, і в непривілейованого користувача на це нема прав.
      ${pkgs.xorg-server}/bin/X -keeptty ${toString xserverArgs} :1 vt$XDG_VTNR &
      xpid=$!
      trap 'kill "$xpid" 2>/dev/null; wait "$xpid" 2>/dev/null' EXIT

      echo "[$(date -Is)] X forked as $xpid, polling for /tmp/.X11-unix/X1"
      ready=0
      for i in $(seq 1 100); do
        if [ -e /tmp/.X11-unix/X1 ]; then
          ready=1
          break
        fi
        sleep 0.2
      done
      echo "[$(date -Is)] socket poll done, ready=$ready after $i tries"
      if [ "$ready" != 1 ]; then
        echo "[$(date -Is)] X never became ready, bailing out"
        exit 1
      fi
    '' + wm.start + ''

      echo "[$(date -Is)] after wm.start block, waitPID=$waitPID"
      test -n "$waitPID" && wait "$waitPID"
      echo "[$(date -Is)] wait returned (exit=$?), clientScript exiting"
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
