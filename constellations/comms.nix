{ config, pkgs, ... }:
{
  networking.networkmanager.enable = true;

  # Wake-on-LAN (магічний пакет). Прошите через systemd-udevd .link-файл — діє на рівні
  # мережевої карти незалежно від NetworkManager, тому вмикається без конфліктів.
  # Передумова в BIOS: "Resume By PCI-E Device" має бути увімкнено.
  # ВАЖЛИВО: вбудована мережева карта earth (alx/Killer E220x) не має mainline WoL
  # у драйвері, тож цей прапорець зараз, найімовірніше, no-op на реальному залізі.
  # Тому окремо замовлено фізичне USB-реле як обхідний шлях (див. пам'ять
  # project_earth_wol_relay) — цей рядок лишається на майбутнє, якщо
  # драйвер коли-небудь отримає підтримку, або як безкоштовна спроба про всяк
  # випадок.
  networking.interfaces.enp5s0.wakeOnLan.enable = true;

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