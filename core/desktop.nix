{ config, pkgs, self, ... }:
{
  # Hyprland — кінцева мета міграції (не тимчасовий тест поруч з bspwm).
  # Сам собою реєструє свою wayland-сесію (services.displayManager.sessionPackages)
  # і власний xdg-desktop-portal-hyprland (xdg.portal.extraPortals +
  # configPackages, для ScreenCast/Screenshot з Noctalia) — нічого з цього не
  # треба дублювати вручну нижче.
  programs.hyprland.enable = true;

  # ReGreet замість tuigreet: показує список сесій (bspwm + Hyprland, зручно
  # поки Hyprland не стабілізується) і сам пам'ятає останній вибір
  # (~/.local/state або /var/lib/regreet — на відміну від tuigreet, без
  # --remember-прапорця). enable=true сам вмикає services.greetd і прописує
  # default_session.command (cage + regreet) — окремо його більше не задаємо.
  programs.regreet.enable = true;

  # Космічна тема для ReGreet — та сама adw-gtk3-dark/Papirus-Dark/
  # Bibata-Modern-Classic і та сама nebula-шпалера, що й у crew/default.nix і
  # crew/bspwm.nix, щоб грітер виглядав продовженням десктопу, а не дефолтним
  # Adwaita-екраном. background.fit = "Cover" (а не sample-івський "Contain")
  # -- заповнює весь екран без чорних смуг, image ширший за екран (3840x2160).
  programs.regreet.theme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  programs.regreet.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  programs.regreet.cursorTheme = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
  programs.regreet.settings = {
    background = {
      path = ../assets/wallpaper/wallpaper.jpg;
      fit = "Cover";
    };
    GTK.application_prefer_dark_theme = true;
    appearance.greeting_msg = "Nebula OS — ласкаво просимо";
  };

  services.displayManager.sessionPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.halley ];
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable = true;
    extraPortals = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.halley
      pkgs.xdg-desktop-portal-gtk
    ];
    # ScreenCast/Screenshot тут раніше форсились на "halley" у config.common
    # -- тобто для ВСІХ сесій, не тільки halley. Halley сам оголошує
    # `UseIn=Halley` у власному .portal-файлі (перевірено:
    # /nix/store/.../share/xdg-desktop-portal/portals/halley.portal), тож
    # цей глобальний override був не просто зайвим, а шкідливим у Hyprland-
    # сесії: halley там не запущений, портал-запит впирався в нікуди --
    # звідси і скріншот у Noctalia, і screen-share в Discord мовчки не
    # працювали. Прибрано; кожна сесія сама бере свій портал за UseIn=.
    config.common.default = [ "gtk" ];
  };
}