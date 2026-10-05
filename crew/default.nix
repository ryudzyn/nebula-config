{ config, pkgs, ... }:

{
  imports = [
    ./terminal/zsh.nix
    ./cli-tools.nix
    ./media.nix
    ./vscodium.nix
    ./theming.nix
    ./modes.nix
    ./poe-price-check.nix
    ./keybind-help.nix
    ./remote-control.nix
    ./stream-relay.nix
    ./hyprland
    ./noctalia
    ./wezterm.nix
    ./kando.nix
    ./gzml.nix
    ./terminal/starship.nix

    # kitty як термінал сам уже підключений напряму через hyprland-
    # біндинги (hyprland.lua) без окремого home-manager-
    # модуля/конфіга -- цей файл під майбутнє кастомне налаштування (тема,
    # шрифт, курсор), поки не написано.
    # ./terminal/kitty.nix
  ];

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = config.gtk.theme;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # Декларативно фіксує темну тему: пише gtk-application-prefer-dark-theme
    # у gtk-3.0/gtk-4.0 settings.ini і color-scheme=prefer-dark у
    # dconf.settings (org/gnome/desktop/interface) — саме те значення, яке
    # читає портал (xdg-desktop-portal-gtk), підтверджено робочим у
    # Follow-up #14. На відміну від runtime-скрипта toggle-theme, це
    # застосовується самим HM при кожному switch, без залежності від
    # ручного натискання super+n.
    colorScheme = "dark";
    gtk4.extraConfig = {
      # Follow-up #15: home-manager's mkGtkSettings (modules/misc/gtk/lib.nix)
      # пише gtk-interface-color-scheme як ціле число (2 = dark за офіційним
      # GTK4 enum'ом Gtk.InterfaceColorScheme), але парсер settings.ini у цій
      # збірці gtk4 (4.22.4, nixpkgs-unstable) очікує рядок-нікнейм ("dark"),
      # не число, і мовчки провалюється з
      # "Gtk-WARNING: ... value that cannot be interpreted" — підтверджено
      # живим strace/screenshot-тестом pavucontrol. Без цього
      # @media (prefers-color-scheme: dark) у CSS теми (adw-gtk3-dark/
      # libadwaita) ніколи не активується: GTK3-застосунки лишаються темними
      # (там немає цього ключа), а GTK4 — білими з сірими кнопками. `//` у
      # gtk4.nix об'єднує extraConfig з авто-згенерованими ключами так, що
      # extraConfig перемагає, тож цей рядок коректно перекриває зламане
      # число з colorScheme вище.
      "gtk-interface-color-scheme" = "dark";
    };
  };

  # Дані головного пілота
  home.username = "ryudzyn";
  home.homeDirectory = "/home/ryudzyn";
  home.packages = with pkgs; [
    fuzzel # Wayland-нативний app-launcher (Hyprland)
    nerd-fonts.jetbrains-mono # іконки-гліфи для nebula-keybind-help-hypr/panels
    fzf # fuzzy-пошук у терміналі (Ctrl+R в zsh, yazi тощо)
    fd # швидша заміна `find`
    ripgrep # швидша заміна `grep -r`
    jq # парсинг JSON (hyprctl -j у скриптах crew/hyprland/default.nix)
    gh # GitHub CLI
    tldr # короткі приклади замість повних man-сторінок
    duf # наочний `df` (використання дисків)
    astroterm # планетарій у терміналі -- зорі/планети/сузір'я в реальному часі
    starfetch # ASCII-рендер сузір'їв у терміналі
  ];

  # Дозволяємо Home Manager самому керувати своїми оновленнями
  programs.home-manager.enable = true;

  home.pointerCursor = {
  enable = true;
  gtk.enable = true;
  package = pkgs.bibata-cursors;
  name = "Bibata-Modern-Classic";
  size = 24;
};  

  # Версія стану (не змінюй її після встановлення, це потрібно для внутрішніх баз даних)
  home.stateVersion = "23.11"; 
}