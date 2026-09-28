{ config, pkgs, ... }:

{
  users.users.ryudzyn = {
    isNormalUser = true;
    description = "ryudzyn";
    extraGroups = [
      "networkmanager"
      "wheel" # sudo
      "video"
      "audio"
      "input"
    ];
    shell = pkgs.zsh;
  };

  # Lingering: юзер-інстанс systemd (і, відповідно, наш сервіс
  # claude-remote-control з crew/remote-control.nix) стартує разом з ОС,
  # а не лише після логіну в greetd. Дозволяє розбудити earth по WoL і
  # одразу мати живий Remote Control сеанс, не логінячись фізично.
  users.users.ryudzyn.linger = true;

  # programs.zsh.enable реєструє /etc/shells -- без цього users.users.*.shell
  # вище формально вказував би на неавторизовану оболонку.
  programs.zsh.enable = true;
}