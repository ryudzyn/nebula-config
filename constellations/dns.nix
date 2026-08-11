{ config, pkgs, ... }:
{
  networking.firewall = {
    allowedTCPPorts = [ 53 5335 ];
    allowedUDPPorts = [ 53 5335 ];
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
        access-control = [ "127.0.0.1 allow" "192.168.0.0/24 allow" ];
        harden-glue = true;
        harden-dnssec-stripped = true;
        prefetch = true;
        edns-buffer-size = 1232;
        hide-identity = true;
        hide-version = true;
      };
      forward-zone = [{
        name = ".";
        forward-tls-upstream = "yes";
        forward-addr = [
          "1.1.1.1@853#cloudflare-dns.com"
          "1.0.0.1@853#cloudflare-dns.com"
        ];
      }];
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