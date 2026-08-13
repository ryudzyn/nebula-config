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
    # nixpkgs навмисно виносить схеми gsettings-desktop-schemas з
    # share/glib-2.0/schemas у share/gsettings-schemas/<name>/glib-2.0/schemas
    # (щоб уникнути колізій при об'єднанні пакетів у профіль) — там уже
    # лежить готовий gschemas.compiled, просто glib його сам не шукає.
    # Ні NixOS, ні home-manager не збирають такі схеми назад у звичайний
    # профіль, тож без цього gsettings/dconf/toggle-theme бачать "Схем не
    # встановлено" незалежно від dconf.enable — той лише про сховище
    # значень, не про самі схеми.
    XDG_DATA_DIRS = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}\${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}";
  };

  home.packages = with pkgs; [
    nwg-look
    dconf
    glib
    gsettings-desktop-schemas
    toggle-theme
  ];
}