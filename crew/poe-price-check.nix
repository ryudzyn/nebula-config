{ pkgs, ... }:
let
  # Альтернатива awakened-poe-trade: той самий
  # офіційний pathofexile.com/api/trade (перевірено вручну проти реального
  # API -- /data/leagues, /data/static, /exchange, /search+/fetch, усі
  # працюють анонімно, без POESESSID), але без Electron -- лише stdlib
  # python (urllib+tkinter) та xclip/xdotool як зовнішні бінарники. Мета:
  # прибрати саме Electron-оверлей як джерело нестабільності, не сам API.
  poe-price-check = pkgs.writers.writePython3Bin "poe-price-check"
    {
      libraries = [ pkgs.python3Packages.tkinter ];
      # довгі рядки (URL, query-словники) -- нема сенсу ламати заради E501;
      # W503 (перенос перед `and`/`or`) суперечить самому PEP8, який радить
      # саме такий стиль.
      flakeIgnore = [ "E501" "W503" ];
    }
    (builtins.readFile ./poe-price-check/price_check.py);
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
