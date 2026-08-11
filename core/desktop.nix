{ config, pkgs, self, ... }:
{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions:${config.services.displayManager.sessionData.desktops}/share/xsessions";
      };
    };
  };

  services.displayManager.sessionPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.halley ];
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable = true;
    extraPortals = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.halley
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "halley" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "halley" ];
    };
  };
}