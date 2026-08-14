{ pkgs, ... }:
let
  # Follow-up #14/подальше розслідування: write_gtk4_ini (переписування
  # ~/.config/gtk-4.0/settings.ini звичайним файлом поверх HM-символлінку)
  # прибрано звідси — воно ламало switch: HM бекапить конфліктний файл у
  # settings.ini.backup один раз, а вдруге відмовляється активуватись
  # цілком ("would be clobbered"), силою завалюючи весь
  # home-manager-ryudzyn.service. Темна тема тепер декларативна
  # (gtk.colorScheme + gtk4.extraConfig у crew/default.nix, див. Follow-up
  # #15), toggle-theme лише перемикає gsettings/dconf. Виправлення в
  # crew/theming.nix: попередня версія цього коментаря стверджувала, що ця
  # збірка GTK4 узагалі не читає settings.ini — Follow-up #15 спростував це
  # прямим strace: settings.ini читається, просто один ключ
  # (gtk-interface-color-scheme) у ній мовчки не парсився через
  # int-vs-string багу home-manager/gtk4.
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
    # Емпірично перевірено (live-запуск pavucontrol + скріншот): жоден з
    # "декларативних" шляхів (gtk-4.0/settings.ini, dconf, портал) реально
    # не фарбує цю збірку GTK4 у темне — при GTK_THEME=adw-gtk3-dark (без
    # variant-суфіксу) вона лишається білою, бо "adw-gtk3-dark" узагалі не
    # існує як GTK4 CSS-тема (adw-gtk3 — суто GTK3-сумісний реплікант).
    # Єдине, що реально спрацювало: вбудована "Adwaita" з явним :dark
    # варіантом — GTK_THEME читають і GTK3, і GTK4 напряму, в обхід
    # settings.ini/dconf/порталу. Ціна: GTK3-застосунки тепер бачать
    # ванільну Adwaita замість "гарнішої" adw-gtk3-dark — свідомий вибір на
    # користь гарантовано робочого темного вигляду скрізь.
    GTK_THEME = "Adwaita:dark";
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