{ pkgs, ... }:
# Січ -- голосовий асистент (план: ~/Brain/notes/асистент-план.md). Мозок, слух і голос живуть у
# Nebula Hub (~/Projects/nebula-hub, nebula_hub/assistant.py + voice.py); тут лише клієнт `sich`,
# який записує мікрофон поки тримаєш SUPER+Z (біндінги -- crew/hyprland/hyprland.lua) і показує
# відповідь сповіщенням та голосом.
let
  sich = pkgs.writeShellApplication {
    name = "sich";
    runtimeInputs = with pkgs; [
      pipewire # pw-record / pw-play
      curl
      jq
      libnotify
      tailscale # логін власника для заголовка, як у tailscale serve (nebula_hub/auth.py)
      zenity
      coreutils
    ];
    text = builtins.readFile ./sich.sh;
  };
in
{
  home.packages = [ sich ];
}
