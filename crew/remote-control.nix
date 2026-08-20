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
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      WorkingDirectory = "%h/nebula-config";
      ExecStart = "${pkgs.claude-code}/bin/claude remote-control --name earth";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
