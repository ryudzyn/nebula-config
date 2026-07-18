{ config, pkgs, self, ... }:
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = [ pkgs.sddm-astronaut ]; # <- це і є пункт 4, заодно
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      self.packages.${pkgs.system}.halley
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "halley" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "halley" ];
    };
  };
}