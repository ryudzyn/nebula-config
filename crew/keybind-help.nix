{ pkgs, lib, ... }:
let
  # nebula-keys -- візуальна довідка комбінацій Hyprland (SUPER+SHIFT+/, бінд і JSON з
  # даними -- у crew/hyprland/hyprland.lua): клавіатура з підсвіченими клавішами, картки
  # груп із «ковпачками», пошук. Замість fuzzel-списку (2026-10-05: вузький, обрізав описи).
  # Пакування -- той самий підхід, що й poe-price-check (GTK3 + gtk-layer-shell через PyGObject).
  nebula-keys-unwrapped = pkgs.writers.writePython3Bin "nebula-keys"
    {
      libraries = [ pkgs.python3Packages.pygobject3 ];
      flakeIgnore = [ "E501" "W503" ];
    }
    (builtins.readFile ./keybind-help/keys.py);

  # Ті самі пояснення, що в crew/poe-price-check.nix: typelib-и через GI_TYPELIB_PATH,
  # LD_PRELOAD для gtk-layer-shell (мусить завантажитись раніше за libwayland-client),
  # pango.out -- там і PangoCairo-1.0, яким малюється клавіатура.
  giPackages = with pkgs; [ gtk3 gtk-layer-shell pango.out gdk-pixbuf atk harfbuzz glib.out gobject-introspection ];
  nebula-keys = pkgs.symlinkJoin {
    name = "nebula-keys";
    paths = [ nebula-keys-unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nebula-keys \
        --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" giPackages}" \
        --prefix LD_PRELOAD : "${pkgs.gtk-layer-shell}/lib/libgtk-layer-shell.so" \
        --set GDK_BACKEND wayland
    '';
  };
in
{
  home.packages = [ nebula-keys ];
}
