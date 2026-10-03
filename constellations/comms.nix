{ config, pkgs, ... }:
{
  networking.networkmanager.enable = true;

  # Мешева VPN -- прямий SSH/remote-control доступ до earth ззовні без
  # port-forwarding, доповнює WoL-relay+A50-проєкт (пам'ять
  # project_orbit_a50_remote_wake_vision): розбудити по WoL і одразу
  # підключитись через tailnet, а не чекати відкритий порт на роутері.
  # trustedInterfaces -- щоб nftables/networking.firewall не різав трафік
  # усередині tailnet (SSH тощо) так само, як зовнішній інтернет.
  # openFirewall відкриває UDP для NAT-traversal (direct-з'єднання без
  # relay-серверів Tailscale, де це можливо).
  #
  # Передумова, яку Nix не покриває (одноразово вручну): `sudo tailscale up`
  # -- інтерактивна авторизація через tailscale.com акаунт.
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  services.tailscale.openFirewall = true;

  # Wake-on-LAN (магічний пакет). Після заміни плати (2026-09-29) вбудована
  # карта -- Realtek RTL8111 на r8169 (enp6s0), драйвер WoL підтримує, на
  # відміну від старої Atheros/Killer на alx (через яку замовлялось фізичне
  # реле, пам'ять project_earth_wol_relay).
  # Через NetworkManager, а НЕ через networking.interfaces.<if>.wakeOnLan:
  # той генерує .link з `OriginalName=<if>`, а OriginalName -- це ім'я від
  # ядра (eth0) ДО перейменування udev, тож правило не матчилось ніколи (так
  # і було зі старим enp5s0). Тут -- глобальний дефолт для всіх ethernet-
  # підключень NM, незалежно від назви інтерфейсу: 64 = 0x40 = "magic"
  # (nm-settings-nmcli, 802-3-ethernet.wake-on-lan). Без нього підключення
  # має "default", а глобального значення не було -- WoL лишався вимкненим.
  # Передумова в BIOS (ASUS): Advanced > APM -- "Power On By PCI-E" увімкнено,
  # ErP вимкнено (інакше живлення мережевої карти в S5 зникає).
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = 64;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.syncthing = {
    enable = true;
    user = "ryudzyn";
    dataDir = "/home/ryudzyn";
    configDir = "/home/ryudzyn/.config/syncthing";
  };

  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.core.default_qdisc" = "fq";
    "net.core.somaxconn" = 2048;
  };

  environment.systemPackages = [ pkgs.networkmanagerapplet ];
}