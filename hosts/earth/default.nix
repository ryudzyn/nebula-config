{ config, pkgs, inputs, ... }:

{
  imports = [
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
    ../../core/x11-greetd-sessions.nix
  ];

  networking.hostName = "earth";

  # НЕ підвищувати "просто так" при апдейті nixpkgs -- це версія формату
  # stateful-даних (бази даних тощо), не версія NixOS, яку ми фактично
  # використовуємо; змінювати лише за прямою вказівкою release notes.
  system.stateVersion = "23.11";
}