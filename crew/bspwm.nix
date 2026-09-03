{ pkgs, lib, ... }:
let
  # Дефолтний pkgs.tesseract тягне tessdata "all" (~470 МіБ усіх мов) —
  # звужено до укр/eng, більше нам для OCR тут не треба.
  tesseract-ocr = pkgs.tesseract.override {
    enableLanguages = [
      "eng"
      "ukr"
    ];
  };

  # Повноцінне меню живлення на super+shift+e замість голого "bspc quit" —
  # той самий rofi -dmenu, що й на super+d (drun), лише в текстовому режимі.
  # systemctl reboot/poweroff/suspend без sudo працюють завдяки дефолтним
  # polkit-правилам logind для активної локальної сесії (не потребують
  # окремого налаштування в core/).
  power-menu = pkgs.writeShellScriptBin "power-menu" ''
    choice=$(printf 'Заблокувати\nВийти\nПерезавантажити\nВимкнути\nПризупинити' | ${pkgs.rofi}/bin/rofi -dmenu -p "Живлення")
    case "$choice" in
      "Заблокувати") ${pkgs.i3lock-color}/bin/i3lock-color -c 1a1a2e ;;
      "Вийти") bspc quit ;;
      "Перезавантажити") systemctl reboot ;;
      "Вимкнути") systemctl poweroff ;;
      "Призупинити") systemctl suspend ;;
    esac
  '';

  # PowerToys Awake-еквівалент: тримає системний inhibitor-лок
  # (systemd-inhibit) на idle/sleep/lid, доки не перемкнеш ще раз тим самим
  # біндом. Стан позначається pid-файлом у XDG_RUNTIME_DIR (там і так живе
  # решта рантайм-сокетів користувача) — наявність живого процесу з цим pid
  # і є єдиним джерелом правди, замість окремого прапорця, який міг би
  # розсинхронитись з реальним inhibitor-локом.
  # xset s тут — той самий X11 screensaver-таймер, що й авто-блокування
  # нижче (xss-lock у bspwmrc); вимикається/вертається разом із
  # systemd-inhibit, щоб "awake"-режим блокував і сон, і авто-блокування
  # екрана одночасно, а не лише перше.
  nebula-awake = pkgs.writeShellScriptBin "nebula-awake" ''
    pidfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-awake.pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
      kill "$(cat "$pidfile")"
      rm -f "$pidfile"
      xset s 600 600
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Awake" "Вимкнено — сон/блокування дозволено"
    else
      ${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep:handle-lid-switch \
        --who=nebula-awake --why="Ручний keep-awake" sleep infinity &
      echo $! > "$pidfile"
      xset s off
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Awake" "Увімкнено — сон/блокування заблоковано"
    fi
  '';

  # OCR-скрипт у стилі PowerToys Text Extractor: виділяєш ділянку екрана
  # (той самий maim -s, що й у screenshot-region-біндах нижче), tesseract
  # розпізнає текст, результат одразу в буфер обміну. notify-send з
  # прев'ю — той самий патерн, що для сповіщень про розкладку в bspwmrc,
  # бо на відміну від скріншота результат OCR інакше ніяк не видно.
  nebula-ocr = pkgs.writeShellScriptBin "nebula-ocr" ''
    tmp=$(${pkgs.coreutils}/bin/mktemp --suffix=.png)
    trap 'rm -f "$tmp"' EXIT
    ${pkgs.maim}/bin/maim -s "$tmp" || exit 1
    text=$(${tesseract-ocr}/bin/tesseract "$tmp" - -l ukr+eng 2>/dev/null)
    if [ -z "$text" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "OCR" "Текст не розпізнано"
      exit 0
    fi
    printf '%s' "$text" | ${pkgs.xclip}/bin/xclip -selection clipboard
    preview=$(printf '%s' "$text" | head -c 120)
    ${pkgs.libnotify}/bin/notify-send -t 3000 "OCR → буфер" "$preview"
  '';

  # Always On Top — bspwm сам цього не вміє (немає z-order поверх фокусу),
  # тож напряму через EWMH _NET_WM_STATE_ABOVE. :ACTIVE: у wmctrl резолвиться
  # через _NET_ACTIVE_WINDOW, який bspwm як EWMH-сумісний WM виставляє сам.
  nebula-always-on-top = pkgs.writeShellScriptBin "nebula-always-on-top" ''
    ${pkgs.wmctrl}/bin/wmctrl -r :ACTIVE: -b toggle,above
    win=$(${pkgs.xprop}/bin/xprop -root _NET_ACTIVE_WINDOW | ${pkgs.gawk}/bin/awk '{print $NF}')
    if ${pkgs.xprop}/bin/xprop -id "$win" _NET_WM_STATE 2>/dev/null | grep -q _NET_WM_STATE_ABOVE; then
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Always on top" "Увімкнено"
    else
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Always on top" "Вимкнено"
    fi
  '';

  # PowerToys Color Picker-еквівалент: xcolor сам відкриває піпетку, клік по
  # пікселю — і сам же пише hex у clipboard (`-s clipboard`), без окремого
  # xclip. notify-send лише показує, що саме щойно скопійовано.
  nebula-color-picker = pkgs.writeShellScriptBin "nebula-color-picker" ''
    color=$(${pkgs.xcolor}/bin/xcolor -s clipboard)
    if [ -n "$color" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "Color picker → буфер" "$color"
    fi
  '';

  # Єдине джерело правди для біндингів: список (не attrset — Nix сортує
  # ключі attrset-а алфавітно, це зламало б логічне групування нижче),
  # кожен запис одразу несе короткий опис для nebula-keybind-help. Звідси ж
  # генерується і services.sxhkd.keybindings (мапа key->cmd), щоб опис і
  # реальний бінд ніколи не розійшлись.
  keybinds = [
    {
      key = "super + Return";
      cmd = "kitty";
      desc = "Термінал";
    }
    {
      key = "super + shift + q";
      cmd = "bspc node -c";
      desc = "Закрити вікно";
    }
    {
      key = "super + d";
      cmd = "${pkgs.rofi}/bin/rofi -show drun";
      desc = "Запуск застосунків (rofi)";
    }
    {
      key = "super + shift + e";
      cmd = "power-menu";
      desc = "Меню живлення (блок / вихід / перезавантаження / вимкнення / сон)";
    }
    {
      key = "super + Escape";
      cmd = "${pkgs.i3lock-color}/bin/i3lock-color -c 1a1a2e";
      desc = "Заблокувати екран";
    }
    {
      key = "super + shift + Escape";
      cmd = "xset dpms force off";
      desc = "Вимкнути монітор";
    }
    {
      key = "super + n";
      cmd = "toggle-theme";
      desc = "Перемкнути світлу/темну тему";
    }
    {
      key = "super + w";
      cmd = "${pkgs.nitrogen}/bin/nitrogen";
      desc = "Вибір шпалер (nitrogen)";
    }
    {
      key = "super + shift + t";
      cmd = "nwg-look";
      desc = "Налаштування GTK-теми (nwg-look)";
    }
    {
      key = "super + shift + r";
      cmd = "xdg-open file://${../assets/cprogram/roulette.html}";
      desc = "Рулетка (жарт-застосунок)";
    }
    {
      key = "super + shift + m";
      cmd = ''sh -c 'cd ~/Applications/SwiftpointX1 && ./"Swiftpoint X1 Control Panel"' '';
      desc = "Панель керування мишею Swiftpoint X1";
    }
    {
      key = "super + shift + c";
      cmd = ''kitty --title "Ascension runClient" -e sh -c "cd ~/Projects/ascension-limitless-progression && nix develop --command ./gradlew runClient"'';
      desc = "Запуск Ascension-мода (dev-клієнт у kitty)";
    }
    {
      key = "super + shift + v";
      cmd = "${pkgs.pavucontrol}/bin/pavucontrol";
      desc = "Мікшер гучності (pavucontrol)";
    }
    {
      key = "super + equal";
      cmd = ''${pkgs.rofi}/bin/rofi -modi calc -show calc -plugin-path ${pkgs.rofi-calc}/lib/rofi -no-show-match -no-sort -calc-command "echo -n '{result}' | ${pkgs.xclip}/bin/xclip -selection clipboard"'';
      desc = "Калькулятор (rofi), результат у буфер";
    }
    {
      key = "super + shift + a";
      cmd = "nebula-awake";
      desc = "Keep-awake — тумблер, блокує сон/lid, доки не перемкнеш знову";
    }
    {
      key = "super + shift + o";
      cmd = "nebula-ocr";
      desc = "OCR виділеної ділянки екрана → буфер";
    }
    {
      key = "super + shift + p";
      cmd = "nebula-always-on-top";
      desc = "Always on top для активного вікна";
    }
    {
      key = "super + shift + x";
      cmd = "nebula-color-picker";
      desc = "Піпетка кольору → hex у буфер";
    }
    {
      key = "super + shift + slash";
      cmd = "nebula-keybind-help";
      desc = "Цей список комбінацій";
    }
    {
      key = "super + v";
      cmd = "CM_LAUNCHER=rofi ${pkgs.clipmenu}/bin/clipmenu";
      desc = "Історія буфера обміну";
    }
    {
      key = "super + Tab";
      cmd = "${pkgs.rofi}/bin/rofi -show window";
      desc = "Список відкритих вікон";
    }
    {
      key = "super + F1";
      cmd = "mode-work";
      desc = "Режим \"робота\"";
    }
    {
      key = "super + F2";
      cmd = "mode-study";
      desc = "Режим \"навчання\"";
    }
    {
      key = "super + F3";
      cmd = "mode-play";
      desc = "Режим \"гра\"";
    }
    {
      key = "super + shift + space";
      cmd = "bspc node -t ~floating";
      desc = "Toggle floating для вікна";
    }
    {
      key = "super + {h,j,k,l}";
      cmd = "bspc node -f {west,south,north,east}";
      desc = "Фокус на вікно (vim-стиль)";
    }
    {
      key = "super + {Left,Down,Up,Right}";
      cmd = "bspc node -f {west,south,north,east}";
      desc = "Фокус на вікно (стрілки)";
    }
    {
      key = "super + {1-5}";
      cmd = "bspc desktop -f '^{1-5}'";
      desc = "Перемкнутись на робочий простір 1-5";
    }
    {
      key = "super + shift + {1-5}";
      cmd = "bspc node -d '^{1-5}' --follow";
      desc = "Перекинути вікно на робочий простір 1-5";
    }
    {
      key = "super + m";
      cmd = "bspc desktop -l next";
      desc = "Перемкнути layout (tiled/monocle)";
    }
    {
      key = "super + f";
      cmd = "bspc node -t ~fullscreen";
      desc = "Fullscreen для вікна";
    }
    {
      key = "super + shift + {h,j,k,l}";
      cmd = "bspc node -s {west,south,north,east}";
      desc = "Поміняти вікна місцями (vim-стиль)";
    }
    {
      key = "super + ctrl + {h,j,k,l}";
      cmd = "bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}";
      desc = "Змінити розмір вікна";
    }
    {
      key = "XF86AudioRaiseVolume";
      cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      desc = "Гучність +5%";
    }
    {
      key = "XF86AudioLowerVolume";
      cmd = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      desc = "Гучність -5%";
    }
    {
      key = "XF86AudioMute";
      cmd = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      desc = "Toggle mute";
    }
    {
      key = "XF86MonBrightnessUp";
      cmd = "brightnessctl set 5%+";
      desc = "Яскравість +5%";
    }
    {
      key = "XF86MonBrightnessDown";
      cmd = "brightnessctl set 5%-";
      desc = "Яскравість -5%";
    }
    {
      key = "Print";
      cmd = "mkdir -p ~/Pictures/Screenshots && ${pkgs.maim}/bin/maim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png";
      desc = "Скріншот всього екрана → файл";
    }
    {
      key = "super + shift + s";
      cmd = "${pkgs.maim}/bin/maim -s | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png";
      desc = "Скріншот ділянки → буфер";
    }
  ];

  # nebula-keybind-help: rofi -dmenu лише ПОКАЗУЄ список (нічого не робить із
  # вибору) — читає текст, згенерований з keybinds вище на етапі збірки, тож
  # не може розійтись із реальним sxhkdrc.
  nebula-keybind-help-text = pkgs.writeText "nebula-keybinds.txt" (
    lib.concatMapStringsSep "\n" (b: "${b.key}  →  ${b.desc}") keybinds
  );
  nebula-keybind-help = pkgs.writeShellScriptBin "nebula-keybind-help" ''
    ${pkgs.rofi}/bin/rofi -dmenu -i -p "Комбінації" -no-custom -width 60 -l 20 \
      < ${nebula-keybind-help-text} > /dev/null
  '';
in
{
  # X11-сесія для гри (PoE1 глючив і на sway, і на i3) — без композитора
  # (заради продуктивності), але з повноцінним polybar (паритет з waybar
  # в crew/sway.nix), бо крок за кроком добудовується до заміни sway/i3.
  #
  # 2026-08-15 (TODO.md Follow-up #17): PoE1 знову перестала запускатись,
  # падаючи з `err:vulkan:vkQueueSubmit Exception 0xc0000005` всередині
  # winevulkan.so. Ні компоситор (пробував picom -- не допомогло), ні
  # форсований Steam compat-тул (тимчасово підмінявся на GE-Proton10-29) не
  # були причиною -- обидва відкидались A/B-тестами. Справжня причина:
  # `programs.mangohud.enableSessionWide` (core/games.nix) форсує
  # `vsync`/`gl_vsync` через LD_PRELOAD у кожен процес, включно з PoE1, що й
  # конфліктувало з власним `Present mode = Immediate` гри. Підтверджено
  # чистим A/B в обидва боки того самого вечора. Фікс -- на боці Steam, не
  # тут: у PoE1 Launch Options стоїть `MANGOHUD=0 %command%`, mangohud-конфіг
  # для решти ігор лишається без змін.
  xdg.configFile."bspwm/bspwmrc".source = pkgs.writeShellScript "bspwmrc" ''
    bspc monitor -d 1 2 3 4 5

    # Розкладка клавіатури — перенесено з crew/sway.nix (там input.xkb_layout),
    # тут X11-еквівалент через setxkbmap. Та сама розкладка ще прописана в
    # core/system.nix і core/games.nix (services.xserver.xkb) — тримати всі
    # три копії в синхроні.
    ${pkgs.setxkbmap}/bin/setxkbmap -layout us,ua,de -option grp:alt_shift_toggle

    bspc config border_width 0
    bspc config window_gap 0
    bspc config borderless_monocle true
    bspc config gapless_monocle true
    bspc config single_monocle true
    bspc config pointer_modifier super
    bspc config pointer_action1 move
    bspc config pointer_action2 resize_side
    bspc config pointer_action3 resize_corner

    # Steam любить відкривати дрібні діалоги (friends list, popups), яких
    # тайлинг ламає — примусово floating для них. Додавай сюди інші класи
    # вікон під конкретні ігри за потреби (дивись `xprop WM_CLASS`).
    bspc rule -a Steam:Popup state=floating

    ${pkgs.feh}/bin/feh --bg-fill ${../assets/wallpaper/wallpaper.jpg}
    ${pkgs.polybar}/bin/polybar -c "$HOME/.config/polybar/config.ini" mybar &

    # Авто-блокування за бездіяльністю (раніше блокування було лише ручне,
    # super+Escape/power-menu) — xset заводить X11 screensaver-таймер (10 хв),
    # xss-lock слухає його спрацювання й запускає той самий i3lock-color.
    # nebula-awake (super+shift+a) вимикає/повертає цей таймер разом із
    # systemd-inhibit-локом сну.
    xset s 600 600
    ${pkgs.xss-lock}/bin/xss-lock -- ${pkgs.i3lock-color}/bin/i3lock-color -c 1a1a2e &

    # Композитор — раніше тримався заради Awakened PoE Trade (видалений,
    # Follow-up #18 в TODO.md), тепер потрібен для напівпрозорого
    # оверлей-вікна crew/poe-price-check.nix (tkinter -alpha), яке так само
    # без композитора рендерилось би суцільним непрозорим прямокутником
    # замість "скла" поверх гри. Це не той самий picom, який відкидався в
    # Follow-up #17 (TODO.md) при пошуку причини краху PoE1 — там і сам
    # компоситор не допоміг, і справжньою причиною виявився
    # `mangohud.enableSessionWide` (core/games.nix), вже пофіксений на боці
    # Steam Launch Options. unredirect-fullscreen-windows=false — щоб picom
    # не вимикав композитинг саме тоді, коли гра розгортається в fullscreen
    # (тоді оверлей і потрібен).
    ${pkgs.picom}/bin/picom --config "$HOME/.config/picom.conf" &

    # dunst (сповіщення) — mako сюди не годиться в принципі: це Wayland-only
    # демон (wlr-layer-shell), під X11/bspwm він падає одразу з
    # "failed to create display", і makoctl (в т.ч. з crew/modes.nix) стукав
    # би в порожнечу. dunst — нативний X11, працює без Wayland-компоситора.
    # core/packages.nix лишає mako системним пакетом окремо для halley
    # (Wayland-сесія greetd) — там він реально живий.
    ${pkgs.dunst}/bin/dunst &

    # Нічний фільтр — X11-еквівалент wlsunset з crew/sway.nix (той самий
    # розклад/температури), налаштування розкладу в ~/.config/redshift.conf.
    ${pkgs.redshift}/bin/redshift &

    # Історія буфера обміну — clipmenud лише пасивно пише в SQLite/файловий
    # кеш (~/.cache/clipmenu), сам пікер викликається окремо біндом
    # (super+v, нижче) з CM_LAUNCHER=rofi.
    ${pkgs.clipmenu}/bin/clipmenud &

    # Сповіщення про зміну розкладки — xkb-switch -W блокується і друкує нову
    # розкладку в stdout щоразу, коли setxkbmap-групу перемкнули
    # (super+shift, налаштовано вище через grp:alt_shift_toggle).
    while read -r layout; do
      ${pkgs.libnotify}/bin/notify-send -t 1000 "Розкладка" "$layout"
    done < <(${pkgs.xkb-switch}/bin/xkb-switch -W) &
  '';

  # Мінімальний конфіг picom — лише те, що потрібно для коректного
  # альфа-композитингу оверлей-вікна poe-price-check поверх fullscreen-гри
  # (раніше — заради Awakened PoE Trade, видаленого в Follow-up #18).
  # glx-backend і unredirect-fullscreen-windows=false — та сама комбінація,
  # яку вже пробували в Follow-up #17 (TODO.md) як A/B-тест на причину краху
  # PoE1 (сам компоситор тоді ні до чого не був — див. коментар в bspwmrc).
  xdg.configFile."picom.conf".text = ''
    backend = "glx";
    vsync = false;
    unredirect-fullscreen-windows = false;
  '';

  # Мінімальний dunstrc — та сама палітра, що в polybar/poe-price-check
  # (bg #1a1a2e, accent #9d4edd). origin = bottom-right, а не top-right —
  # єдине, що зараз шле сповіщення через dunst, це розкладка клавіатури
  # (notify-send з bspwmrc), і навмисно окремо від poe-price-check
  # (top-right, tkinter-оверлей, не dunst). Geometry (origin/offset) можна
  # задавати лише в [global] — dunst 1.13 явно відкидає це в rule-секціях
  # ("Setting origin is in the wrong section", перевірено -verbosity debug),
  # тож per-notification позиція тут неможлива, лише глобальна.
  xdg.configFile."dunst/dunstrc".text = ''
    [global]
    origin = bottom-right
    offset = 24x24
    width = (250, 400)
    height = 200
    frame_width = 2
    frame_color = "#9d4edd"
    separator_color = frame
    font = monospace 10

    [urgency_low]
    background = "#1a1a2e"
    foreground = "#e0e0f0"
    frame_color = "#9d4edd"
    timeout = 4

    [urgency_normal]
    background = "#1a1a2e"
    foreground = "#e0e0f0"
    frame_color = "#9d4edd"
    timeout = 5

    [urgency_critical]
    background = "#1a1a2e"
    foreground = "#e05561"
    frame_color = "#e05561"
    timeout = 0
  '';

  # dawn-time/dusk-time дозволяють задати фіксовані години переходу без
  # geo-провайдера — той самий підхід, що wlsunset -S/-s/-t/-T в sway.nix.
  xdg.configFile."redshift.conf".text = ''
    [redshift]
    temp-day=6500
    temp-night=4000
    transition=1
    location-provider=manual
    dawn-time=07:00
    dusk-time=20:00

    [manual]
    lat=0
    lon=0
  '';

  xdg.configFile."polybar/config.ini".text = ''
    [bar/mybar]
    width = 100%
    height = 24
    background = #1a1a2e
    foreground = #e0e0f0
    font-0 = monospace:size=10
    font-1 = JetBrainsMono Nerd Font:size=11;2
    modules-left = bspwm xwindow
    modules-center = date
    modules-right = tray xkeyboard volume network cpu memory
    separator = "  "
    border-bottom-size = 2
    border-bottom-color = #9d4edd

    ; Іконки трею запущених програм (Discord, Steam...) — раніше глобальний
    ; bar-level tray-position="right" (deprecated, попереджав про це сам
    ; polybar у логах) чіплявся до самого краю бару ПІСЛЯ info-пілюль; тепер
    ; окремий internal/tray-модуль, вставлений на початок modules-right, —
    ; тобто перед пілюлями, ближче до центру, як системний трей у Windows
    ; (іконки програм зліва від завжди-видимих індикаторів/годинника).
    ; Поява/зникнення іконки все одно займає/звільняє реальний простір, тож
    ; невеликий зсув при відкритті нової програми лишається — так само
    ; поводиться будь-який живий трей, включно з Windows.
    [module/tray]
    type = internal/tray
    tray-spacing = 4px

    [module/bspwm]
    type = internal/bspwm
    label-focused = %name%
    label-focused-background = #9d4edd
    label-focused-foreground = #1a1a2e
    label-focused-padding = 2
    label-occupied = %name%
    label-occupied-padding = 2
    label-empty = %name%
    label-empty-foreground = #888888
    label-empty-padding = 2

    ; Повна дата (не лише час) — Follow-up на "не вистачає дати". Без %a
    ; (день тижня) навмисно: polybar-3.7 не локалізує strftime %a/%b, навіть
    ; коли LC_TIME=uk_UA.UTF-8 системно вірний (перевірено живим рендером —
    ; видавало "Wed" замість "Ср"), тож день/місяць лишені суто числовими.
    [module/date]
    type = internal/date
    date = %d.%m.%Y  %H:%M
    label = %{T2}%{T-} %date%

    ; Заголовок активного вікна — контекст того, що зараз у фокусі,
    ; чого раніше в panel взагалі не було.
    [module/xwindow]
    type = internal/xwindow
    label = %title:0:60:...%
    label-foreground = #e0e0f0

    ; Персистентний індикатор поточної розкладки (us/ua/de, налаштовані в
    ; bspwmrc через setxkbmap) — доповнює транзиентне notify-send вище:
    ; тут завжди видно, яка розкладка активна, не лише в момент перемикання.
    ; Pill-фон — інлайновий %{B...}...%{B-} (малюється поверх фактично
    ; відрендерених пікселів), а не label-*-background/label-*-padding
    ; (окремо порахований статичний прямокутник). Причина зміни: коли
    ; змінюється склад трею (нова іконка Discord/Steam і т.п.), весь бар
    ; перекомпоновується, і в цей момент box label-*-background міг
    ; порахуватись зі старою/неповною шириною тексту -- будь-яка з pill-
    ; іконок (не конкретна, перевірено на живих скріншотах користувача:
    ; спершу RAM, потім клавіатура) могла зʼявитись обрізаною праворуч чи
    ; ліворуч. Перевірено власним стрес-тестом: 12 скріншотів поспіль під
    ; час навмисного дриґання трею (nm-applet запуск/закриття 6 разів) з
    ; inline %{B} -- жодного разу нічого не обрізалось, на відміну від
    ; попереднього підходу.
    [module/xkeyboard]
    type = internal/xkeyboard
    blacklist-0 = num lock
    blacklist-1 = caps lock
    label-layout = %{B#242444} %{T2}%{T-} %layout% %{B-}
    label-layout-foreground = #c9b8ff

    ; Решта модулів — паритет з waybar-набором в crew/sway.nix
    ; (pulseaudio/network/cpu/memory/tray), X11-native через polybar internal-модулі.
    ; Іконки — nerd-fonts.jetbrains-mono (crew/default.nix).
    ; %percentage:3% ліворуч доповнює число пробілами до 3 символів — без
    ; цього пілюля стрибала б по ширині щоразу, коли відсоток переходив
    ; між 1/2/3-значним числом (напр. 9% -> 10%), зсуваючи все праворуч.
    [module/cpu]
    type = internal/cpu
    interval = 2
    label = %{B#242444} %{T2}%{T-} %percentage:3%%%{B-}
    label-foreground = #c9b8ff

    ; Іконка — база даних (не сервер-стойка, U+F493: та сама, що й тут,
    ; виявилась на такому розмірі гліфа нерозбірливим "прапорцем", не
    ; клпінг-баг, а невдалий вибір гліфа, перевірено на живому рендері).
    ; %gb_used% вже сам повертає "1.70 GiB" (з одиницею) — раніше тут був
    ; ще дописаний "G" вручну, що давало дублікат "GiBG". %gb_used:9%
    ; резервує 9 символів (макс "XX.XX GiB"), той самий анти-стрибковий
    ; прийом, що й у cpu вище.
    [module/memory]
    type = internal/memory
    interval = 2
    label = %{B#242444} %{T2}%{T-} %gb_used:9%%{B-}
    label-foreground = #c9b8ff

    ; Стаціонарна машина на дроті — інтерфейс enp5s0 (перевірено `ip link`),
    ; на відміну від waybar тут немає wifi/essid-гілки, лише ethernet.
    ; Іконка — розетка/plug (U+F1E6), не глобус (U+F0AC, був тут раніше):
    ; глобус періодично рендерився обрізаним (див. коментар вище про
    ; inline %{B} — насправді то був той самий баг статичного боксу, не
    ; проблема конкретно глобуса, але plug лишаю — простіша форма).
    [module/network]
    type = internal/network
    interface = enp5s0
    interval = 3
    label-connected = %{B#242444} %{T2}%{T-} Ethernet %{B-}
    label-connected-foreground = #c9b8ff
    label-disconnected = Немає мережі
    label-disconnected-foreground = #888888

    ; internal/pulseaudio не built-in у цій збірці polybar ("No built-in
    ; support for internal/pulseaudio", перевірено живим запуском) — модуль
    ; мовчки нічого не рендерив, тож "Vol" ніколи не було видно. custom/script
    ; на wpctl (той самий бінарник, що й XF86Audio*-біндинги нижче) працює.
    ; printf "%3d%%" замість голого pct"%" — той самий анти-стрибковий
    ; прийом (awk сам не розуміє polybar-івський %token:N% синтаксис).
    [module/volume]
    type = custom/script
    exec = wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{pct=int($2*100+0.5); if ($0 ~ /MUTED/) print "Muted"; else printf "%3d%%\\n", pct}'
    interval = 1
    label = %{B#242444} %{T2}%{T-} %output%%{B-}
    label-foreground = #c9b8ff
  '';

  # Системний модуль bspwm сам запускає sxhkd при старті сесії — тут ми лише
  # декларативно генеруємо ~/.config/sxhkd/sxhkdrc, який він читає.
  # keybindings генерується з `keybinds` (let-блок вище) — те саме джерело,
  # з якого будується й nebula-keybind-help, щоб опис і реальний бінд не
  # розходились.
  services.sxhkd = {
    enable = true;
    keybindings = builtins.listToAttrs (
      map (b: {
        name = b.key;
        value = b.cmd;
      }) keybinds
    );
  };

  home.packages = with pkgs; [
    rofi
    polybar
    maim
    xclip
    brightnessctl
    i3lock-color
    xss-lock
    nitrogen
    redshift
    power-menu
    clipmenu
    xkb-switch
    dunst
    rofi-calc
    tesseract-ocr
    wmctrl
    xprop
    gawk
    nebula-awake
    nebula-ocr
    nebula-always-on-top
    nebula-color-picker
    xcolor
    nebula-keybind-help

    # Price-checker для PoE1 — awakened-poe-trade (Electron) видалено,
    # непрацював стабільно (Follow-up #18, TODO.md); замінено власним
    # crew/poe-price-check.nix (той самий офіційний trade API, без Electron).
  ];
}
