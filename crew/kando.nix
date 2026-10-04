{ pkgs, lib, config, ... }:
{
  # Kando -- круговий лончер для десктопа (той самий принцип, що й Orbit на
  # телефоні). Виклик SUPER+Space (у hyprland.lua через `global`-диспетчер:
  # на Hyprland Kando сам глобальні клавіші не реєструє), автозапуск і
  # window-rule для оверлея -- теж там.
  home.packages = [ pkgs.kando ];

  # Меню -- crew/kando-menus.json (Папки, Режими, Game mode, Рулетка, Оновити
  # систему, Заблокувати, Живлення). Kando редагує ~/.config/kando/menus.json
  # через власний GUI-редактор, тож це НЕ home.file (той зробив би файл
  # read-only symlink-ом у /nix/store): шаблон лише копіюється, коли там ще
  # нема меню "Nebula" (перший запуск або чистий дефолтний приклад Kando).
  # Після цього меню належить редактору Kando, repo його не перезаписує.
  home.activation.kandoMenus = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    menus="${config.xdg.configHome}/kando/menus.json"
    if [ ! -f "$menus" ] || ! ${pkgs.gnugrep}/bin/grep -q '"shortcutID": *"nebula-menu"' "$menus"; then
      run mkdir -p "$(dirname "$menus")"
      [ -f "$menus" ] && run cp "$menus" "$menus.before-nebula"
      run install -m 644 ${./kando-menus.json} "$menus"
    fi
  '';
}
