{ pkgs, config, ... }:
let
  python = pkgs.python3.withPackages (p: [
    p.fastapi
    p.uvicorn
    p.websockets
    p.pyte # екран терміналу фонових задач: відповіді на питання клавішами (attach.py)
  ]);

  # Хаб окремим вікном на ПК (desktop/nebula_desktop.py у тому ж чекауті): GTK4 + WebKitGTK,
  # без браузерного інтерфейсу. wrapGAppsHook4 підставляє typelib-и й GIO-модулі
  # (glib-networking -- без нього WebKit не відкриє HTTPS).
  nebula-hub-desktop = pkgs.stdenv.mkDerivation {
    name = "nebula-hub-desktop";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];
    buildInputs = [
      pkgs.gtk4
      pkgs.webkitgtk_6_0
      pkgs.glib-networking
    ];
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/nebula-hub-desktop <<'EOF'
      #!${pkgs.bash}/bin/bash
      export PATH="${pkgs.tailscale}/bin:$PATH"
      exec ${
        pkgs.python3.withPackages (p: [ p.pygobject3 ])
      }/bin/python "$HOME/Projects/nebula-hub/desktop/nebula_desktop.py" "$@"
      EOF
      chmod +x $out/bin/nebula-hub-desktop
    '';
  };
in
{
  home.packages = [ nebula-hub-desktop ];

  xdg.desktopEntries.nebula-hub = {
    name = "Nebula Hub";
    comment = "Пульт earth: стан машини, дев-сервер моду, моделі, Claude";
    exec = "nebula-hub-desktop";
    icon = "${config.home.homeDirectory}/Projects/nebula-hub/static/icon-512.png";
    terminal = false;
    categories = [
      "System"
      "Utility"
    ];
    settings.StartupWMClass = "io.github.ryudzyn.NebulaHub";
  };

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
