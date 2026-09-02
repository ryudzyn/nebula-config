{ pkgs, ... }:
let
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
    # тут X11-еквівалент через setxkbmap.
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
    [module/xkeyboard]
    type = internal/xkeyboard
    blacklist-0 = num lock
    blacklist-1 = caps lock
    label-layout = %{T2}%{T-} %layout%
    label-layout-background = #242444
    label-layout-padding = 1
    label-layout-foreground = #c9b8ff

    ; Решта модулів — паритет з waybar-набором в crew/sway.nix
    ; (pulseaudio/network/cpu/memory/tray), X11-native через polybar internal-модулі.
    ; Іконки — nerd-fonts.jetbrains-mono (crew/default.nix), pill-фони
    ; (#242444, трохи світліше за фон бару) — щоб модулі читались окремими
    ; чипами, а не суцільним рядком тексту.
    ; %percentage:3% ліворуч доповнює число пробілами до 3 символів — без
    ; цього пілюля стрибала б по ширині щоразу, коли відсоток переходив
    ; між 1/2/3-значним числом (напр. 9% -> 10%), зсуваючи все праворуч.
    [module/cpu]
    type = internal/cpu
    interval = 2
    label = %{T2}%{T-} %percentage:3%%
    label-background = #242444
    label-padding = 1
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
    label = %{T2}%{T-} %gb_used:9%
    label-background = #242444
    label-padding = 1
    label-foreground = #c9b8ff

    ; Стаціонарна машина на дроті — інтерфейс enp5s0 (перевірено `ip link`),
    ; на відміну від waybar тут немає wifi/essid-гілки, лише ethernet.
    [module/network]
    type = internal/network
    interface = enp5s0
    interval = 3
    label-connected = %{T2}%{T-} Ethernet
    label-connected-background = #242444
    label-connected-padding = 1
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
    exec = wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{pct=int($2*100+0.5); if ($0 ~ /MUTED/) print "Muted"; else printf "%3d%%\n", pct}'
    interval = 1
    label = %{T2}%{T-} %output%
    label-background = #242444
    label-padding = 1
    label-foreground = #c9b8ff
  '';

  # Системний модуль bspwm сам запускає sxhkd при старті сесії — тут ми лише
  # декларативно генеруємо ~/.config/sxhkd/sxhkdrc, який він читає.
  services.sxhkd = {
    enable = true;
    keybindings = {
      "super + Return" = "kitty";
      "super + shift + q" = "bspc node -c";
      "super + d" = "${pkgs.rofi}/bin/rofi -show drun";
      "super + shift + e" = "power-menu";

      # Блокування/екран/тема — перенесено з crew/i3.nix (той самий колір і
      # той самий xset), theme toggle — з crew/sway.nix (portable-скрипт).
      "super + Escape" = "${pkgs.i3lock-color}/bin/i3lock-color -c 1a1a2e";
      "super + shift + Escape" = "xset dpms force off";
      "super + n" = "toggle-theme";

      # Косметика з crew/sway.nix: waypaper (wayland-only picker) →
      # nitrogen (X11-native); nwg-look і roulette самі по собі portable
      # (gsettings/xdg-open), тому запускаються без заміни.
      "super + w" = "${pkgs.nitrogen}/bin/nitrogen";
      "super + shift + t" = "nwg-look";
      "super + shift + r" = "xdg-open file://${../assets/cprogram/roulette.html}";

      # Панель керування мишею Swiftpoint X1 — в sway.nix запускається
      # автостартом, тут — за біндом (той самий позасистемний бінарник).
      "super + shift + m" = ''sh -c 'cd ~/Applications/SwiftpointX1 && ./"Swiftpoint X1 Control Panel"' '';

      # Швидкий запуск дев-клієнта Ascension-мода (~/Projects/ascension-limitless-progression)
      # у kitty, щоб бачити build/runtime лог; той самий `nix develop --command ./gradlew
      # runClient`, що й уручну в терміналі. Гучність — pavucontrol, вже системний пакет
      # (core/packages.nix), тут просто бінд для швидкого виклику GUI.
      "super + shift + c" =
        ''kitty --title "Ascension runClient" -e sh -c "cd ~/Projects/ascension-limitless-progression && nix develop --command ./gradlew runClient"'';
      "super + shift + v" = "${pkgs.pavucontrol}/bin/pavucontrol";

      # Історія буфера обміну (clipmenud автостартує в bspwmrc) — сам пікер
      # викликається лише по біндy, CM_LAUNCHER=rofi замість дефолтного dmenu.
      "super + v" = "CM_LAUNCHER=rofi ${pkgs.clipmenu}/bin/clipmenu";

      # Список відкритих вікон (усі десктопи) — bspwm сам виставляє EWMH-хінти,
      # якими користується вбудований rofi-модуль "window".
      "super + Tab" = "${pkgs.rofi}/bin/rofi -show window";

      # Режими роботи/навчання/гри — ті самі скрипти, що й у sway.nix
      # (crew/modes.nix), скрипти самі визначають bspwm vs sway в рантаймі.
      "super + F1" = "mode-work";
      "super + F2" = "mode-study";
      "super + F3" = "mode-play";

      # floating toggle — bspc-еквівалент "floating toggle" з sway/i3.
      "super + shift + space" = "bspc node -t ~floating";

      # фокус між вікнами (vim-стиль і стрілки — обидва варіанти)
      "super + {h,j,k,l}" = "bspc node -f {west,south,north,east}";
      "super + {Left,Down,Up,Right}" = "bspc node -f {west,south,north,east}";

      # робочі простори: перемкнутись / перекинути туди вікно
      "super + {1-5}" = "bspc desktop -f '^{1-5}'";
      "super + shift + {1-5}" = "bspc node -d '^{1-5}' --follow";

      # layout: перемикання tiled/monocle, фулскрін, обмін місцями, resize
      "super + m" = "bspc desktop -l next";
      "super + f" = "bspc node -t ~fullscreen";
      "super + shift + {h,j,k,l}" = "bspc node -s {west,south,north,east}";
      "super + ctrl + {h,j,k,l}" =
        "bspc node -z {left -20 0,bottom 0 20,top 0 -20,right 20 0}";

      # Гучність/яскравість — перенесено з crew/sway.nix, ці команди самі по
      # собі не wayland-specific (wpctl керує pipewire, brightnessctl — sysfs).
      "XF86AudioRaiseVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
      "XF86AudioLowerVolume" = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      "XF86AudioMute" = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      "XF86MonBrightnessUp" = "brightnessctl set 5%+";
      "XF86MonBrightnessDown" = "brightnessctl set 5%-";

      # Скріншоти — перенесено з crew/sway.nix, там grim/slurp/wl-copy
      # (wayland-only); тут X11-еквівалент maim/xclip.
      "Print" =
        "mkdir -p ~/Pictures/Screenshots && ${pkgs.maim}/bin/maim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png";
      "super + shift + s" =
        "${pkgs.maim}/bin/maim -s | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png";
    };
  };

  home.packages = with pkgs; [
    rofi
    polybar
    maim
    xclip
    brightnessctl
    i3lock-color
    nitrogen
    redshift
    power-menu
    clipmenu
    xkb-switch
    dunst

    # Price-checker для PoE1 — awakened-poe-trade (Electron) видалено,
    # непрацював стабільно (Follow-up #18, TODO.md); замінено власним
    # crew/poe-price-check.nix (той самий офіційний trade API, без Electron).
  ];
}
