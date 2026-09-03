{ config, pkgs, ... }:
{
  # SSH дозволяє вхід по паролю навмисно (обслуговує всю LAN) — тому прикриваємо
  # брутфорс fail2ban'ом.
  services.fail2ban.enable = true;

  # Без явного PAM-сервісу NixOS не генерує /etc/pam.d/i3lock(-color) — тоді
  # PAM-розмова взагалі не має проти чого перевіряти пароль, і i3lock-color
  # відхиляє БУДЬ-ЯКИЙ пароль, навіть правильний (мовчки, без пояснення —
  # виглядає так, ніби екран просто "не розблоковується"). `{}` тут
  # НЕДОСТАТНЬО — nixos/modules/security/pam.nix вмикає ці сервіси лише через
  # `mkDefault config.programs.i3lock.enable`, якого ми ніде не ставимо
  # (перевірено: без цього /etc/pam.d/i3lock-color на диску не з'являвся
  # навіть з `security.pam.services.i3lock-color = {}` в конфізі). Свідомо не
  # чіпаємо programs.i3lock.enable — той тягне за собою окремий пакет i3lock
  # (не -color) через environment.systemPackages, а i3lock-color вже стоїть
  # через home-manager (crew/bspwm.nix).
  security.pam.services.i3lock.enable = true;
  security.pam.services.i3lock-color.enable = true;

  boot.kernel.sysctl = {
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv4.conf.all.log_martians" = 1;
  };
}
