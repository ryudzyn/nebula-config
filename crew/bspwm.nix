{ pkgs, ... }:
{
  # Мінімальна X11-сесія для гри (PoE1 глючить і на sway, і на i3) — без
  # композитора, з мінімальним polybar (лише workspace-індикатор + годинник).
  xdg.configFile."bspwm/bspwmrc".source = pkgs.writeShellScript "bspwmrc" ''
    bspc monitor -d 1 2 3 4 5

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
  '';

  xdg.configFile."polybar/config.ini".text = ''
    [bar/mybar]
    width = 100%
    height = 24
    background = #1a1a2e
    foreground = #e0e0f0
    font-0 = monospace:size=10
    modules-left = bspwm
    modules-right = date

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
    };
  };

  home.packages = with pkgs; [ rofi polybar ];
}
