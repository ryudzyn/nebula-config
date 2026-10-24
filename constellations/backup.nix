{ pkgs, ... }:

# Бекап earth у Hetzner Storage Box (2026-10-24, BX11 earth-backup, Falkenstein).
# restic шифрує все на earth -- Hetzner бачить лише зашифровані блоки.
#
# Поза репо (секрети):
#   ~/.config/restic/password     -- ключ шифрування репозиторію restic. Без нього
#                                    бекап НЕ відновити: копія має бути в KeePassXC.
#   ~/.ssh/storagebox_ed25519     -- SSH-ключ лише для Storage Box
#   ~/.ssh/known_hosts            -- ключ хоста звірено з docs.hetzner.com
#                                    (SHA256:XqONwb1S0zuj5A1CDxpOSuD2hnAArV1A3wKY7Z3sdgM)
#
# Ігри, кеші, Downloads, Android SDK свідомо не бекапляться -- їх можна завантажити знову.
# Відновлення: `restic-hetzner snapshots`, `restic-hetzner restore latest --target /tmp/r --include ~/Projects`
# (обгортку restic-hetzner модуль ставить сам, бо задано user).
let
  home = "/home/ryudzyn";
  host = "u700117.your-storagebox.de";
in
{
  services.restic.backups.hetzner = {
    # Від імені користувача: читає ~ без root і бере його SSH-ключ / known_hosts
    user = "ryudzyn";
    initialize = true;
    repository = "sftp:u700117@${host}:earth";
    passwordFile = "${home}/.config/restic/password";
    extraOptions = [
      "sftp.command='ssh u700117@${host} -p 23 -i ${home}/.ssh/storagebox_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -s sftp'"
    ];
    paths = [
      "${home}/Projects"
      "${home}/nebula-config"
      "${home}/Documents"
      "${home}/Pictures"
      "${home}/Screenshots"
      "${home}/dotfiles"
      "${home}/Паролі.kdbx"
      "${home}/.ssh"
      "${home}/.gnupg"
      "${home}/.thunderbird"
      "${home}/.config/restic"
      "${home}/.local/share/Steam/userdata"
    ];
    # Світи Minecraft з усіх інстансів PrismLauncher (самі збірки -- 15 ГБ -- ні)
    dynamicFilesFrom = ''
      find ${home}/.local/share/PrismLauncher/instances -mindepth 3 -maxdepth 3 -type d -name saves
    '';
    exclude = [
      "**/build"
      "**/.gradle"
      "**/node_modules"
      "**/target"
      "**/.direnv"
      "**/result"
      "**/run/logs"
      "**/.cache"
      "${home}/Projects/*/.claude/worktrees"
    ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    # Після кожного бекапу перечитує випадкові 5% даних -- ловить биті блоки на сервері
    # (Hetzner за трафік Storage Box не бере)
    checkOpts = [ "--read-data-subset=5%" ];
  };

  # Збій бекапу -> пуш на телефон (той самий локальний ntfy, що й notify-phone)
  systemd.services.restic-backups-hetzner.onFailure = [ "restic-backup-failed.service" ];
  systemd.services.restic-backup-failed = {
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.curl}/bin/curl -fsS --max-time 10 \
        -H "Title: earth: бекап НЕ вдався" -H "Priority: high" -H "Tags: warning" \
        --data-binary "restic-backups-hetzner впав. journalctl -u restic-backups-hetzner" \
        http://127.0.0.1:2586/claude
    '';
  };
}
