{ config, pkgs, ... }:

{
  users.users.ryudzyn = {
    isNormalUser = true;
    description = "Oleksandr";
    extraGroups = [ 
      "networkmanager" 
      "wheel" # Надає права sudo
      "video" 
      "audio" 
      "input" 
    ];
    # Одразу ставимо Zsh як оболонку за замовчуванням
    shell = pkgs.zsh; 
  };

  # Оскільки ми вказали Zsh вище, систему треба попередити, що він увімкнений
  programs.zsh.enable = true; 
}