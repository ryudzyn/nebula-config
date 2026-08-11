{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = false; # вимкнено свідомо — у тебе вже є реальний docker, не треба конфлікту команд
  };

  environment.systemPackages = with pkgs; [
    docker-compose
    podman-compose
  ];

  users.users.ryudzyn.extraGroups = [ "docker" ];
}