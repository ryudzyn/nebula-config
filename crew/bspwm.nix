{ pkgs, ... }:
{
  # Мінімальна X11-сесія для гри (PoE1 глючить і на sway, і на i3) — без
  # композитора й бару, лише bspwm + sxhkd.
  xdg.configFile."bspwm/bspwmrc".source = pkgs.writeShellScript "bspwmrc" ''
    bspc config border_width 0
    bspc config window_gap 0
    bspc config borderless_monocle true
    bspc config gapless_monocle true

    ${pkgs.feh}/bin/feh --bg-fill ${../assets/wallpaper/wallpaper.jpg}
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
    };
  };
}
