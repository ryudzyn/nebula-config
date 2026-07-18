# core/packages.nix
{ config, pkgs, self, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    kitty
    sddm-astronaut
    self.packages.${pkgs.system}.halley  # Nix автоматично візьме його з нашого оверлея
    vscodium
    google-chrome
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    retroarch
  ];

  hardware.graphics = {
  enable = true;
  enable32Bit = true;
};

programs.steam.enable = true;

}