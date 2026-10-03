{ pkgs, lib, ... }:
let
  # Альтернатива awakened-poe-trade: той самий
  # офіційний pathofexile.com/api/trade (перевірено вручну проти реального
  # API -- /data/leagues, /data/static, /exchange, /search+/fetch, усі
  # працюють анонімно, без POESESSID), але без Electron -- python (urllib) +
  # GTK3/gtk-layer-shell для оверлею та xclip/xdotool як зовнішні бінарники.
  # Мета: прибрати саме Electron-оверлей як джерело нестабільності, не сам API.
  poe-price-check-unwrapped = pkgs.writers.writePython3Bin "poe-price-check"
    {
      libraries = [ pkgs.python3Packages.pygobject3 ];
      # довгі рядки (URL, query-словники) -- нема сенсу ламати заради E501;
      # W503 (перенос перед `and`/`or`) суперечить самому PEP8, який радить
      # саме такий стиль.
      flakeIgnore = [ "E501" "W503" ];
    }
    (builtins.readFile ./poe-price-check/price_check.py);

  # Оверлей -- GTK3 через GObject Introspection, тож typelib-и треба явно
  # показати через GI_TYPELIB_PATH. LD_PRELOAD: gtk-layer-shell з 0.9 мусить
  # завантажитись раніше за libwayland-client (підміняє частину його API), а з
  # Python це можливо лише так -- інакше init_for_window мовчки не спрацює і
  # вікно стане звичайним тайленим. GDK_BACKEND=wayland -- layer-shell існує
  # лише у Wayland; X-сесії на earth більше нема (TODO.md #44).
  # gobject-introspection -- там typelib cairo-1.0, без якого GTK не імпортується;
  # pango.out явно -- makeSearchPath інакше бере вихід pango-bin без typelib-ів.
  giPackages = with pkgs; [ gtk3 gtk-layer-shell pango.out gdk-pixbuf atk harfbuzz glib.out gobject-introspection ];
  poe-price-check = pkgs.symlinkJoin {
    name = "poe-price-check";
    paths = [ poe-price-check-unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/poe-price-check \
        --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" giPackages}" \
        --prefix LD_PRELOAD : "${pkgs.gtk-layer-shell}/lib/libgtk-layer-shell.so" \
        --set GDK_BACKEND wayland
    '';
  };
in
{
  # Бінд super+p -- у crew/hyprland/hyprland.lua (нативний hl.bind).
  home.packages = [
    poe-price-check
    pkgs.xdotool # симулює ctrl+c над наведеним предметом перед читанням буфера
    # xclip -- читання/запис буфера; PoE іде через XWayland, тож це той самий
    # X11-буфер, у який гра копіює предмет. Раніше тягнувся crew/bspwm.nix.
    pkgs.xclip
  ];
}
