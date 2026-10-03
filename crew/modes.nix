{ pkgs, ... }:
# Workspace-лончери, прив'язані на super+F1/F2/F3 (crew/hyprland/hyprland.lua)
# -- один натиск розкладає потрібний набір застосунків по конкретних
# workspace замість ручного відкриття кожного окремо. hl.exec_cmd з
# правилом `workspace = "N silent"` кладе вікно одразу на свій workspace, не
# смикаючи фокус (живо перевірено 2026-10-03 через hyprctl eval) -- тож не
# треба ні перемикатись перед кожним запуском (як робила bspwm-версія через
# `bspc desktop -f`), ні sleep між ними. Наприкінці -- фокус на workspace 2.
# Сповіщення -- через Noctalia DND (dunst жив лише в bspwm-сесії).
let
  # $1 -- workspace, решта -- команда. Одинарні лапки в команді не
  # підтримуються (вона вставляється в Lua-рядок у подвійних лапках).
  launch = ''
    launch() { ws=$1; shift; hyprctl eval "hl.exec_cmd(\"$*\", { workspace = \"$ws silent\" })" >/dev/null; }
    focus() { hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $1 }))" >/dev/null; }
  '';

  mode-work = pkgs.writeShellScriptBin "mode-work" ''
    ${launch}
    noctalia msg notification-dnd-set true
    launch 2 codium
    launch 3 ${pkgs.kitty}/bin/kitty
    launch 4 zen
    focus 2
  '';

  mode-study = pkgs.writeShellScriptBin "mode-study" ''
    ${launch}
    noctalia msg notification-dnd-set true
    launch 2 anki
    launch 2 goldendict
    launch 3 zen
    focus 2
  '';

  mode-play = pkgs.writeShellScriptBin "mode-play" ''
    ${launch}
    noctalia msg notification-dnd-set false
    launch 2 steam
    launch 3 discord
    focus 2
  '';
in
{
  home.packages = [ mode-work mode-study mode-play ];
}
