{ pkgs, ... }:
{
  # X11-сесія для гри (PoE1 глючить і на sway, і на i3) — без композитора
  # (заради продуктивності), але з повноцінним polybar (паритет з waybar
  # в crew/sway.nix), бо крок за кроком добудовується до заміни sway/i3.
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

    # mako (сповіщення) в sway реально стартує лише тому, що sway явно
    # запускає sway-session.target/graphical-session.target; наша xinit-сесія
    # (core/x11-greetd-sessions.nix) цього не робить, тож без явного запуску
    # тут makoctl (в т.ч. з crew/modes.nix) стукав би в порожнечу.
    ${pkgs.mako}/bin/mako &

    # Нічний фільтр — X11-еквівалент wlsunset з crew/sway.nix (той самий
    # розклад/температури), налаштування розкладу в ~/.config/redshift.conf.
    ${pkgs.redshift}/bin/redshift &
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
    modules-left = bspwm
    modules-center = date
    modules-right = pulseaudio network cpu memory
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
      "super + shift + e" = "bspc quit";

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
  ];
}
