{ config, pkgs, ... }:
{
  # SSH дозволяє вхід по паролю навмисно (обслуговує всю LAN) — тому прикриваємо
  # брутфорс fail2ban'ом.
  services.fail2ban.enable = true;

  boot.kernel.sysctl = {
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.log_martians" = 1;
  };
}
