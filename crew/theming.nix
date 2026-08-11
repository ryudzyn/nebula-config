{ pkgs, ... }:
let
  toggle-theme = pkgs.writeShellScriptBin "toggle-theme" ''
    CURRENT=$(${pkgs.glib}/bin/gsettings get org.gnome.desktop.interface color-scheme)
    if [ "$CURRENT" = "'prefer-dark'" ]; then
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    else
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    fi
  '';
in
{
  dconf.enable = true;

  home.sessionVariables = {
    GTK_THEME = "adw-gtk3-dark";
  };

  home.packages = with pkgs; [
    nwg-look
    waypaper
    swaybg
    wlsunset
    dconf
    glib
    gsettings-desktop-schemas
    toggle-theme
  ];
}