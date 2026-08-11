{ pkgs, ... }:
let
  mode-work = pkgs.writeShellScriptBin "mode-work" ''
    ${pkgs.mako}/bin/makoctl set-mode do-not-disturb
    ${pkgs.sway}/bin/swaymsg exec vscodium
    ${pkgs.sway}/bin/swaymsg exec "${pkgs.kitty}/bin/kitty"
    ${pkgs.sway}/bin/swaymsg exec zen-browser
    sleep 1
    ${pkgs.sway}/bin/swaymsg '[app_id="codium"] move to workspace 2'
    ${pkgs.sway}/bin/swaymsg '[app_id="kitty"] move to workspace 3'
    ${pkgs.sway}/bin/swaymsg '[app_id="zen"] move to workspace 4'
    ${pkgs.sway}/bin/swaymsg workspace 2
  '';

  mode-study = pkgs.writeShellScriptBin "mode-study" ''
    ${pkgs.mako}/bin/makoctl set-mode do-not-disturb
    ${pkgs.sway}/bin/swaymsg exec anki
    ${pkgs.sway}/bin/swaymsg exec goldendict-ng
    ${pkgs.sway}/bin/swaymsg exec zen-browser
    sleep 1
    ${pkgs.sway}/bin/swaymsg '[app_id="anki"] move to workspace 2'
    ${pkgs.sway}/bin/swaymsg '[app_id="goldendict"] move to workspace 2'
    ${pkgs.sway}/bin/swaymsg '[app_id="zen"] move to workspace 3'
    ${pkgs.sway}/bin/swaymsg workspace 2
  '';

  mode-play = pkgs.writeShellScriptBin "mode-play" ''
    ${pkgs.mako}/bin/makoctl set-mode default
    ${pkgs.sway}/bin/swaymsg exec steam
    ${pkgs.sway}/bin/swaymsg exec discord-canary
    sleep 1
    ${pkgs.sway}/bin/swaymsg '[app_id="steam"] move to workspace 2'
    ${pkgs.sway}/bin/swaymsg '[app_id="discord"] move to workspace 3'
    ${pkgs.sway}/bin/swaymsg workspace 2
  '';
in
{
  home.packages = [ mode-work mode-study mode-play ];
}