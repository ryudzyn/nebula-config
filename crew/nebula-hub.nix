{ pkgs, config, ... }:
let
  python = pkgs.python3.withPackages (p: [
    p.fastapi
    p.uvicorn
    p.websockets
  ]);
in
{
  # Nebula Hub -- пульт earth з ПК і телефону (~/Projects/nebula-hub, план у PLAN.md):
  # стан машини, сервіси, згодом дев-сервер моду, моделі й Claude Code. Код живий у
  # чекауті (як hyprland.lua), тож правки -- `systemctl --user restart nebula-hub`, без switch.
  #
  # Слухає лише 127.0.0.1:8095; назовні -- `tailscale serve` (HTTPS на
  # https://earth.<тейлнет>.ts.net), який додає Tailscale-User-Login, а хаб пускає тільки
  # власника вузла (nebula_hub/auth.py). Для serve без sudo ryudzyn -- оператор tailscaled
  # (constellations/comms.nix). Передумова поза Nix: HTTPS-сертифікати увімкнені в адмінці
  # Tailscale (зроблено 2026-11-10).
  systemd.user.services.nebula-hub = {
    Unit.Description = "Nebula Hub (earth control panel)";
    Service = {
      WorkingDirectory = "${config.home.homeDirectory}/Projects/nebula-hub";
      ExecStart = "${python}/bin/python -m nebula_hub";
      # Ідемпотентно; serve-конфіг tailscaled і так пам'ятає між перезавантаженнями.
      # `-` -- якщо tailscaled ще не готовий, хаб однаково працює локально.
      ExecStartPost = "-${pkgs.coreutils}/bin/timeout 20 ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:8095";
      # PATH user-юнітів на NixOS порожній: хабу потрібні systemctl/journalctl/tailscale
      Environment = "PATH=${
        pkgs.lib.makeBinPath [
          pkgs.systemd
          pkgs.tailscale
          pkgs.coreutils
        ]
      }";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
