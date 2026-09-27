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