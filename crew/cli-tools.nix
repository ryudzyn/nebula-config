{ pkgs, config, ... }:
{
  # SSH-підпис комітів замість GPG -- перевикористовує вже наявний
  # ~/.ssh/id_ed25519.pub (той самий, що й для push на GitHub), без окремої
  # церемонії генерації GPG-ключа. allowedSignersFile -- лише для локальної
  # перевірки (`git log --show-signature`); "Verified" на GitHub залежить
  # від того, чи цей самий публічний ключ доданий там окремо як Signing Key
  # (Settings → SSH and GPG keys) -- це вже поза Nix, робиться руками один раз.
  programs.git = {
    enable = true;
    signing = {
      key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
      signByDefault = true;
    };
    settings = {
      user.name = "ryudzyn";
      user.email = "ryudzyn@gmail.com";
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
    };
  };

  home.file.".config/git/allowed_signers".text =
    "ryudzyn@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKXGpFTxZVgZenOr+8DcDjJomdc4VL4goRLbMOfIin/J\n";

  programs.btop = {
    enable = true;
    # rocmSupport (AMD) прибрано разом із заміною заліза AMD RX590 -> Intel
    # i5-9400 + Arc A770 (2026-09-29) -- btop підтримує лише
    # cudaSupport/rocmSupport як build-флаги (перевірено джерело пакета),
    # окремого Intel-флага нема, тож дефолтна збірка без override.
  };
  programs.cava.enable = true; # аудіо-візуалізатор у терміналі (спектр-аналізатор)
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fastfetch.enable = true;
  programs.lazygit.enable = true;
  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
  };
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
  };
  programs.thunderbird.enable = true;
}