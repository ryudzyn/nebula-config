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
    # SSH-ключі для входу без пароля (телефон тощо) свідомо НЕ тут, а в
    # ~/.ssh/authorized_keys на самому earth: репо публічне, а sshd читає й цей
    # файл (AuthorizedKeysFile %h/.ssh/authorized_keys). Пароль -- лише з LAN і
    # tailnet (constellations/comms.nix).
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