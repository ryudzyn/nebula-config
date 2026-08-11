{ config, pkgs, inputs, ... }:

{
  imports = [
    # Тут ми будемо підключати наші системні модулі (ядро, звук, ігри)
    ./hardware.nix
    ../../core/bootloader.nix
    ../../core/system.nix
    ../../core/users.nix
    ../../core/packages.nix
    ../../core/desktop.nix
    ../../core/games.nix
    ../../core/virtualisation.nix
    ../../constellations/default.nix
    ../../core/peripherals.nix
    ../../core/security.nix
  ];

  # Встановлюємо ім'я нашого корабля в мережі
  networking.hostName = "earth";
  
  # Версія стану системи
  system.stateVersion = "23.11"; 
}