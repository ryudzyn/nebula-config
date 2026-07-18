{ config, pkgs, ... }:

{
  imports = [
    # Підключаємо наш супер-швидкий термінал (цей файл ми вже написали!)
    ./terminal/zsh.nix
    
    # Ці файли ми напишемо трохи згодом, тому поки вони закоментовані (#)
    # ./terminal/kitty.nix
    # ./terminal/starship.nix
  ];

  # Дані головного пілота
  home.username = "ryudzyn";
  home.homeDirectory = "/home/ryudzyn";
  home.packages = with pkgs; [ kando fuzzel ];

  # Дозволяємо Home Manager самому керувати своїми оновленнями
  programs.home-manager.enable = true;

  # Версія стану (не змінюй її після встановлення, це потрібно для внутрішніх баз даних)
  home.stateVersion = "23.11"; 
}