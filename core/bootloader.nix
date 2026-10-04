  { config, pkgs, ... }:

{
  boot.loader = {
    systemd-boot.enable = true;
    # Без ліміту в меню завантаження потрапляли ВСІ покоління (76 на
    # 2026-10-04 -- nix.gc чистить лише старші 30 днів, а sysup буває по
    # кілька разів на день). 20 останніх вистачає для відкату, і /boot (1 ГіБ)
    # не переповниться, якщо зміниться ядро кілька разів поспіль.
    systemd-boot.configurationLimit = 20;
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot";
    timeout = 5;
  };

}