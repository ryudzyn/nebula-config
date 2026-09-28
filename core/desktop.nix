{ config, pkgs, self, ... }:
let
  # Plymouth-тема "hud_space" (adi1090x/plymouth-themes, pack_3, GPLv3) —
  # анімація відчинення дверей космічного корабля на завантаженні, щоб і
  # boot виглядав частиною "Nebula OS", а не дефолтним екраном. Файли
  # (122 PNG-кадри + .script + .plymouth-дескриптор) закомічені напряму в
  # assets/plymouth/hud_space/ (той самий підхід, що й wallpaper.jpg/
  # roulette.html) — увесь апстрімний репозиторій тем важить ~290 МіБ
  # (80+ тем разом), фетчити його цілим заради однієї теми через Nix
  # безглуздо; large_icons/ (альтернативний набір кадрів для іншого
  # розширення) не закомічений — hud_space.script його не використовує.
  # ImageDir/ScriptFile в апстрімному .plymouth хардкоджені на
  # /usr/share/... — підміняємо на реальний $out, як і з halley/
  # gzml-visual-tools (той самий клас "апстрім розрахований на FHS" фіксу).
  plymouth-hud-space = pkgs.runCommand "plymouth-theme-hud-space" { } ''
    mkdir -p $out/share/plymouth/themes/hud_space
    cp ${../assets/plymouth/hud_space}/* $out/share/plymouth/themes/hud_space/
    substituteInPlace $out/share/plymouth/themes/hud_space/hud_space.plymouth \
      --replace-fail "/usr/share/plymouth/themes/hud_space" "$out/share/plymouth/themes/hud_space"
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = "hud_space";
    themePackages = [ plymouth-hud-space ];
  };

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
  services.displayManager.regreet.enable = true;

  # Космічна тема для ReGreet — та сама adw-gtk3-dark/Papirus-Dark/
  # Bibata-Modern-Classic і та сама nebula-шпалера, що й у crew/default.nix і
  # crew/bspwm.nix, щоб грітер виглядав продовженням десктопу, а не дефолтним
  # Adwaita-екраном. background.fit = "Cover" (а не sample-івський "Contain")
  # -- заповнює весь екран без чорних смуг, image ширший за екран (3840x2160).
  services.displayManager.regreet.theme = {
    name = "adw-gtk3-dark";
    package = pkgs.adw-gtk3;
  };
  services.displayManager.regreet.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };
  services.displayManager.regreet.cursorTheme = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
  };
  services.displayManager.regreet.settings = {
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