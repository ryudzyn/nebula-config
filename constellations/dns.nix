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
  systemd.services.adguardhome.serviceConfig = {
    After = [ "network.target" "unbound.service" ];
    Requires = [ "unbound.service" ];
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
        # Tailnet-зона нижче не підписана DNSSEC -- без цього валідатор unbound
        # відкидав би відповіді MagicDNS як bogus.
        domain-insecure = [ "taild85963.ts.net" ];
        harden-glue = true;
        harden-dnssec-stripped = true;
        prefetch = true;
        edns-buffer-size = 1232;
        hide-identity = true;
        hide-version = true;
      };
      forward-zone = [
        # MagicDNS Tailscale: імена з tailnet (pixel-11.taild85963.ts.net тощо)
        # через резолвер самого tailscaled. Без цього earth не міг резолвити
        # імена власного tailnet (TODO.md #47). Специфічніша зона має пріоритет
        # над ".".
        {
          name = "taild85963.ts.net.";
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
    host = "0.0.0.0";
    port = 3005;
    mutableSettings = true;
    openFirewall = true;
    settings = {
      http.address = "127.0.0.1:3005";
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
      filters = map (url: { enabled = true; inherit url; }) [
        "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
        "https://easylist.to/easylist/easylist.txt"
        "https://easylist.to/easylist/easyprivacy.txt"
      ];
    };
  };
}