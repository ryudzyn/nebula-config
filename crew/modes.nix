{ pkgs, ... }:
let
  # bspwm кладе нові вікна на поточний фокусний десктоп, тож перемикаємось на
  # потрібний десктоп *перед* запуском кожного застосунку замість матчити
  # app_id/WM_CLASS постфактум (як робив sway-варіант до видалення sway/i3).
  mode-work = pkgs.writeShellScriptBin "mode-work" ''
    ${pkgs.dunst}/bin/dunstctl set-paused true
    bspc desktop -f '^2'; vscodium &
    sleep 0.3
    bspc desktop -f '^3'; ${pkgs.kitty}/bin/kitty &
    sleep 0.3
    bspc desktop -f '^4'; zen-browser &
    sleep 1
    bspc desktop -f '^2'
  '';

  mode-study = pkgs.writeShellScriptBin "mode-study" ''
    ${pkgs.dunst}/bin/dunstctl set-paused true
    bspc desktop -f '^2'; anki &
    sleep 0.3
    bspc desktop -f '^2'; goldendict-ng &
    sleep 0.3
    bspc desktop -f '^3'; zen-browser &
    sleep 1
    bspc desktop -f '^2'
  '';

  mode-play = pkgs.writeShellScriptBin "mode-play" ''
    ${pkgs.dunst}/bin/dunstctl set-paused false
    bspc desktop -f '^2'; steam &
    sleep 0.3
    bspc desktop -f '^3'; discord-canary &
    sleep 1
    bspc desktop -f '^2'
  '';
in
{
  home.packages = [ mode-work mode-study mode-play ];
}