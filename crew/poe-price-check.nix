{ pkgs, ... }:
let
  # Альтернатива awakened-poe-trade (видалений з crew/bspwm.nix): той самий
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
  home.packages = [
    poe-price-check
    pkgs.xdotool # симулює ctrl+c над наведеним предметом перед читанням буфера
    # xclip для читання буфера вже тягнеться crew/bspwm.nix
  ];

  # super+p -- вільний біндинг (не перетинається з ctrl+d/іншими стандартними
  # хоткеями Awakened PoE Trade, який глобально перехоплював би ctrl+d і зламав
  # би EOF у терміналах). Вікно результату -- override_redirect (дивись
  # show_overlay у price_check.py), bspwm його взагалі не бачить і не тайлить,
  # тому на відміну від Awakened тут не потрібне окреме floating-правило в
  # crew/bspwm.nix.
  services.sxhkd.keybindings."super + p" = "poe-price-check";
}
