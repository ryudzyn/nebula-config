{ config, pkgs, ... }:
{
  # Постійний Claude Code Remote Control сервер: тримає сесію живою
  # незалежно від того, чи залогінений хтось у greetd (linger в
  # core/users.nix), щоб з телефону (claude.ai/code або застосунок) можна
  # було одразу під'єднатись після WoL-пробудження earth.
  #
  # Робоча директорія — ~/nebula-config, а не $HOME: за документацією
  # Remote Control діалог довіри воркспейсу НІКОЛИ не зберігається для
  # домашньої директорії, тож сервіс у $HOME щоразу впирався б у
  # інтерактивний prompt, якого немає в systemd-юніті без TTY.
  #
  # Передумови, які Nix не покриває (одноразово вручну):
  #   1. `claude auth login` під ryudzyn — потрібен саме claude.ai логін
  #      (Pro/Max), API-ключ Remote Control не підтримує.
  #   2. Хоч раз інтерактивно запустити `claude` у ~/nebula-config і
  #      підтвердити workspace trust dialog.
  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control (earth)";
      # Без ліміту перезапусків: після WoL-пробудження сервіс мусить піднятись
      # будь-що, навіть якщо мережа/DNS готові із запізненням.
      StartLimitIntervalSec = 0;
    };
    Service = {
      WorkingDirectory = "%h/nebula-config";
      # Чекаємо DNS перед стартом (до 2 хв). Раніше тут стояло
      # After/Wants=network-online.target, але в user-юніті цей target не
      # існує (він лише в системному менеджері) -- тож після кожного
      # завантаження сервіс стартував раніше за AdGuard/unbound, падав з
      # "getaddrinfo ENOTFOUND api.anthropic.com" і піднімався лише з 5-ї
      # спроби (живо видно в журналі 2026-10-04).
      # Без `$` у команді (systemd сам розкриває $-змінні) і з повними шляхами
      # (PATH user-юнітів на NixOS не містить coreutils).
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in {1..120}; do ${pkgs.getent}/bin/getent hosts api.anthropic.com >/dev/null && exit 0; ${pkgs.coreutils}/bin/sleep 1; done; exit 0'";
      ExecStart = "${pkgs.claude-code}/bin/claude remote-control --name earth";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
