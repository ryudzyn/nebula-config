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
    # SSH-ключі для входу без пароля. Pixel 11 (Termux) -- через Tailscale,
    # `ssh earth` / `mosh earth` (constellations/comms.nix). Пароль у sshd
    # лишається ввімкненим як запасний шлях.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEapV73v63w+hv7xtvO0WV39eu4J4qZqoTYPg+/t0jEn pixel-11-termux"
    ];
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