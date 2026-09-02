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

    # mako (сповіщення) в sway реально стартує лише тому, що sway явно
    # запускає sway-session.target/graphical-session.target; наша xinit-сесія
    # (core/x11-greetd-sessions.nix) цього не робить, тож без явного запуску
    # тут makoctl (в т.ч. з crew/modes.nix) стукав би в порожнечу.
    ${pkgs.mako}/bin/mako &

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
    modules-left = bspwm xwindow
    modules-center = date
    modules-right = xkeyboard pulseaudio network cpu memory
    separator = "  "
    tray-position = right
    tray-padding = 4
    tray-background = #1a1a2e

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

    [module/date]
    type = internal/date
    date = %H:%M
    label = %date%

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
    label-layout = Розкладка: %layout%
    label-layout-foreground = #c9b8ff

    ; Решта модулів — паритет з waybar-набором в crew/sway.nix
    ; (pulseaudio/network/cpu/memory/tray), X11-native через polybar internal-модулі.
    [module/cpu]
    type = internal/cpu
    interval = 2
    label = CPU %percentage%%
    label-foreground = #c9b8ff

    [module/memory]
    type = internal/memory
    interval = 2
    label = RAM %gb_used%G
    label-foreground = #c9b8ff

    ; Стаціонарна машина на дроті — інтерфейс enp5s0 (перевірено `ip link`),
    ; на відміну від waybar тут немає wifi/essid-гілки, лише ethernet.
    [module/network]
    type = internal/network
    interface = enp5s0
    interval = 3
    label-connected = Ethernet
    label-connected-foreground = #c9b8ff
    label-disconnected = Немає мережі
    label-disconnected-foreground = #888888

    [module/pulseaudio]
    type = internal/pulseaudio
    format-volume = <label-volume>
    format-muted = <label-muted>
    label-volume = Vol %percentage%%
    label-volume-foreground = #c9b8ff
    label-muted = Vol Muted
    label-muted-foreground = #888888
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

    # Price-checker для PoE1 — awakened-poe-trade (Electron) видалено,
    # непрацював стабільно (Follow-up #18, TODO.md); замінено власним
    # crew/poe-price-check.nix (той самий офіційний trade API, без Electron).
  ];
}
