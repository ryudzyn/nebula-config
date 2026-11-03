{ ... }:
{
  # Стрімінг робочого столу на телефон (Moonlight + DualShock 4 по Bluetooth), щоб
  # грати й тестувати мод на відстані: гра лишається на Arc, телефон -- лише екран.
  # openFirewall=false навмисно: tailscale0 уже в trustedInterfaces (comms.nix), тож
  # Sunshine доступний лише через tailnet, а не з LAN чи інтернету.
  # capSysAdmin не потрібен: на Hyprland захоплення йде через wlr-screencopy, а не KMS.
  # Пара з телефоном -- одноразово вручну: PIN у веб-панелі https://<earth>:47990.
  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = false;
    capSysAdmin = false;
    settings = {
      capture = "wlr";
    };
  };
}
