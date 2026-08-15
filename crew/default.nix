{ config, pkgs, ... }:

{
  imports = [
    # Підключаємо наш супер-швидкий термінал (цей файл ми вже написали!)
    ./terminal/zsh.nix
    ./cli-tools.nix
    ./media.nix
    ./vscodium.nix
    ./theming.nix
    ./modes.nix
    ./bspwm.nix

    # Ці файли ми напишемо трохи згодом, тому поки вони закоментовані (#)
    # ./terminal/kitty.nix
    # ./terminal/starship.nix
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
    # Follow-up #16: `super+w` (nitrogen, crew/bspwm.nix) лишався білим після
    # #14/#15 — виявилось, nitrogen лінкується проти GTK2 (libgtk-x11-2.0),
    # не GTK3/4 (підтверджено `ldd`). adw-gtk3 — реплікант виключно для
    # GTK3/GTK4 (пакет узагалі не має директорії gtk-2.0), тож
    # gtk.gtk2.theme, який без цього успадкував би той самий "adw-gtk3-dark"
    # від gtk.theme, не знаходив тему і GTK2 тихо відкочувався на дефолтну
    # світлу. arc-theme реально несе gtk-2.0/gtk-3.0/gtk-4.0 в одному пакеті
    # (перевірено на диску), тож "Arc-Dark" узято лише для gtk2 — GTK3/4
    # лишаються на adw-gtk3-dark, який виглядає ближче до системної теми.
    gtk2.theme = {
      name = "Arc-Dark";
      package = pkgs.arc-theme;
    };
  };

  # Дані головного пілота
  home.username = "ryudzyn";
  home.homeDirectory = "/home/ryudzyn";
  home.packages = with pkgs; [
    # Arc-Dark (gtk.gtk2.theme вище) рендериться через рушій "murrine"
    # (посилання за назвою в кожному .rc теми, не абсолютний шлях) — без
    # цього пакета в профілі GTK2 сипле "Unable to locate theme engine in
    # module_path: murrine" і мовчки лишається без стилю. Підтверджено живим
    # тестом nitrogen (GTK_PATH з libmurrine.so → фон реально потемнів,
    # #404552 замість білого). gtk.gtk2.theme.package (arc-theme) на
    # відміну від цього автоматично потрапляє в home.packages через
    # home-manager's collectGtkPackages, тому окремо не додається тут.
    gtk-engine-murrine
    kando 
    fuzzel
    nerd-fonts.jetbrains-mono
    fzf
    fd
    ripgrep
    jq
    gh
    tldr
    duf
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