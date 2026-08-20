{ config, pkgs, ... }:

{
  users.users.ryudzyn = {
    isNormalUser = true;
    description = "ryudzyn";
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

  # Lingering: юзер-інстанс systemd (і, відповідно, наш сервіс
  # claude-remote-control з crew/remote-control.nix) стартує разом з ОС,
  # а не лише після логіну в greetd. Дозволяє розбудити earth по WoL і
  # одразу мати живий Remote Control сеанс, не логінячись фізично.
  users.users.ryudzyn.linger = true;

  # Оскільки ми вказали Zsh вище, систему треба попередити, що він увімкнений
  programs.zsh.enable = true; 
}