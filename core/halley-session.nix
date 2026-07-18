{ config, pkgs, ... }:

{
  # Створюємо файл сесії для SDDM
  environment.etc."wayland-sessions/halley.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Halley
      Comment=Halley Wayland Compositor
      Exec=halley-session
      Type=Application
    '';
  };
}