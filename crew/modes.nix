{ pkgs, ... }:
let
  # $SWAYSOCK — надійний і вже дешевий спосіб дізнатись, що ми в sway
  # (sway сам його експортує); інакше вважаємо, що це bspwm — наразі це
  # єдині дві сесії, які взагалі біндять mode-work/study/play (i3 — ні).
  # У bspwm-гілці немає app_id-критеріїв swaymsg — замість цього просто
  # перемикаємось на потрібний десктоп *перед* запуском кожного застосунку,
  # бо bspwm кладе нові вікна на поточний фокусний десктоп.
  mode-work = pkgs.writeShellScriptBin "mode-work" ''
    ${pkgs.mako}/bin/makoctl set-mode do-not-disturb
    if [ -n "$SWAYSOCK" ]; then
      ${pkgs.sway}/bin/swaymsg exec vscodium
      ${pkgs.sway}/bin/swaymsg exec "${pkgs.kitty}/bin/kitty"
      ${pkgs.sway}/bin/swaymsg exec zen-browser
      sleep 1
      ${pkgs.sway}/bin/swaymsg '[app_id="codium"] move to workspace 2'
      ${pkgs.sway}/bin/swaymsg '[app_id="kitty"] move to workspace 3'
      ${pkgs.sway}/bin/swaymsg '[app_id="zen"] move to workspace 4'
      ${pkgs.sway}/bin/swaymsg workspace 2
    else
      bspc desktop -f '^2'; vscodium &
      sleep 0.3
      bspc desktop -f '^3'; ${pkgs.kitty}/bin/kitty &
      sleep 0.3
      bspc desktop -f '^4'; zen-browser &
      sleep 1
      bspc desktop -f '^2'
    fi
  '';

  mode-study = pkgs.writeShellScriptBin "mode-study" ''
    ${pkgs.mako}/bin/makoctl set-mode do-not-disturb
    if [ -n "$SWAYSOCK" ]; then
      ${pkgs.sway}/bin/swaymsg exec anki
      ${pkgs.sway}/bin/swaymsg exec goldendict-ng
      ${pkgs.sway}/bin/swaymsg exec zen-browser
      sleep 1
      ${pkgs.sway}/bin/swaymsg '[app_id="anki"] move to workspace 2'
      ${pkgs.sway}/bin/swaymsg '[app_id="goldendict"] move to workspace 2'
      ${pkgs.sway}/bin/swaymsg '[app_id="zen"] move to workspace 3'
      ${pkgs.sway}/bin/swaymsg workspace 2
    else
      bspc desktop -f '^2'; anki &
      sleep 0.3
      bspc desktop -f '^2'; goldendict-ng &
      sleep 0.3
      bspc desktop -f '^3'; zen-browser &
      sleep 1
      bspc desktop -f '^2'
    fi
  '';

  mode-play = pkgs.writeShellScriptBin "mode-play" ''
    ${pkgs.mako}/bin/makoctl set-mode default
    if [ -n "$SWAYSOCK" ]; then
      ${pkgs.sway}/bin/swaymsg exec steam
      ${pkgs.sway}/bin/swaymsg exec discord-canary
      sleep 1
      ${pkgs.sway}/bin/swaymsg '[app_id="steam"] move to workspace 2'
      ${pkgs.sway}/bin/swaymsg '[app_id="discord"] move to workspace 3'
      ${pkgs.sway}/bin/swaymsg workspace 2
    else
      bspc desktop -f '^2'; steam &
      sleep 0.3
      bspc desktop -f '^3'; discord-canary &
      sleep 1
      bspc desktop -f '^2'
    fi
  '';
in
{
  home.packages = [ mode-work mode-study mode-play ];
}