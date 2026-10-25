{ config, pkgs, ... }:
# Два шари: unbound -- локальний рекурсивний резолвер з DNS-over-TLS до
# Cloudflare (приватність/швидкість), AdGuard Home -- мережевий
# рекламо/трекер-блокер (веб-UI на :3005) поверх нього, форвардить у unbound
# на 127.0.0.1:5335. Обидва слухають :53 на різних інтерфейсах/адресах --
# AdGuard на 0.0.0.0 (доступний з усього LAN), unbound лише на localhost.
{
  # Лише 53 (AdGuard для LAN). 5335 тут раніше теж відкривався, але unbound
  # слухає тільки 127.0.0.1 -- порт у файрволі був зайвий (прибрано 2026-10-04).
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  services.resolved.enable = false;

  systemd.services.unbound.stopIfChanged = false;
  # AdGuard пересилає запити в unbound -- стартує після нього. (До 2026-10-25 це
  # стояло в serviceConfig, тобто в секції [Service], де systemd After/Requires
  # ігнорує: "Unknown key 'After' in section [Service]" -- порядку не було.)
  systemd.services.adguardhome = {
    after = [
      "network.target"
      "unbound.service"
    ];
    requires = [ "unbound.service" ];
  };

  services.unbound = {
    enable = true;
    settings = {
      remote-control.control-enable = true;
      server = {
        interface = [ "127.0.0.1" ];
        port = 5335;
        # Тільки localhost: unbound слухає лише 127.0.0.1, клієнтів LAN обслуговує
        # AdGuard. (Тут була 192.168.0.0/24 -- стара підмережа до роутера Starlink.)
        access-control = [ "127.0.0.1 allow" ];
        # Відповіді MagicDNS (зона ts.net нижче) не підписані DNSSEC -- без цього
        # валідатор unbound відкидав би їх як bogus.
        domain-insecure = [ "ts.net" ];
        harden-glue = true;
        harden-dnssec-stripped = true;
        prefetch = true;
        edns-buffer-size = 1232;
        hide-identity = true;
        hide-version = true;
      };
      forward-zone = [
        # MagicDNS Tailscale: імена з tailnet (<пристрій>.<tailnet>.ts.net) через
        # резолвер самого tailscaled. Без цього earth не міг резолвити імена
        # власного tailnet (TODO.md #47). Уся зона ts.net, а не конкретна назва
        # tailnet -- репо публічне, назву tailnet сюди не пишемо; 100.100.100.100
        # сам відповідає за свій tailnet і пересилає решту ts.net назовні.
        # Специфічніша зона має пріоритет над ".".
        {
          name = "ts.net.";
          forward-addr = [ "100.100.100.100" ];
        }
        {
          name = ".";
          forward-tls-upstream = "yes";
          forward-addr = [
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
          ];
        }
      ];
    };
  };

  services.adguardhome = {
    enable = true;
    # Панель керування (:3005) -- лише з самого earth і з tailnet (2026-10-04):
    # слухає на всіх інтерфейсах (AdGuard уміє лише одну адресу), але файрвол
    # порт 3005 для LAN більше не відкриває -- через tailscale0 (trustedInterfaces,
    # comms.nix) і localhost доступ лишається. "Білий список" = членство в
    # tailnet. DNS-фільтрація (порт 53) для всієї мережі не змінюється.
    # Адреса панелі -- settings.http.address (2026-10-25: модуль оголосив
    # host/port застарілими; раніше саме вони перебивали http.address).
    mutableSettings = true;
    openFirewall = false;
    settings = {
      http.address = "0.0.0.0:3005";
      dns = {
        bind_host = "0.0.0.0";
        bind_port = 53;
        upstream_dns = [ "127.0.0.1:5335" ];
        bootstrap_dns = [ "127.0.0.1:5335" ];
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
      };
      filters =
        map
          (url: {
            enabled = true;
            inherit url;
          })
          [
            "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
            "https://easylist.to/easylist/easylist.txt"
            "https://easylist.to/easylist/easyprivacy.txt"
          ];
    };
  };
}
