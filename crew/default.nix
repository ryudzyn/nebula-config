{ config, pkgs, ... }:

{
  imports = [
    # Підключаємо наш супер-швидкий термінал (цей файл ми вже написали!)
    ./terminal/zsh.nix
    ./cli-tools.nix
    ./media.nix
    ./vscodium.nix
    ./sway.nix
    ./theming.nix
    ./modes.nix
    ./i3.nix
    ./bspwm.nix

    # Ці файли ми напишемо трохи згодом, тому поки вони закоментовані (#)
    # ./terminal/kitty.nix
    # ./terminal/starship.nix
  ];

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = config.gtk.theme;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Дані головного пілота
  home.username = "ryudzyn";
  home.homeDirectory = "/home/ryudzyn";
  home.packages = with pkgs; [ 
    kando 
    fuzzel
    nerd-fonts.jetbrains-mono
    fzf
    fd
    ripgrep
    jq
    gh
    tldr
    duf
  ];
  programs.waybar.enable = true;

  # Дозволяємо Home Manager самому керувати своїми оновленнями
  programs.home-manager.enable = true;

  home.pointerCursor = {
  enable = true;
  gtk.enable = true;
  package = pkgs.bibata-cursors;
  name = "Bibata-Modern-Classic";
  size = 24;
};  

  # Версія стану (не змінюй її після встановлення, це потрібно для внутрішніх баз даних)
  home.stateVersion = "23.11"; 
}