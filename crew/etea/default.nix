{ pkgs, ... }:
let
  # ETEA (github:SDcold/etea-shell, GPL-3.0) -- оболонка на Quickshell: бар, сповіщення,
  # лончер, буфер обміну, захоплення екрана, "планети" як теми. Замінила Noctalia.
  # Закріплена на коміті: вбудоване оновлення через git у незмінному сховищі не працює,
  # новий код приходить лише зміною rev/hash тут.
  # nebula.patch: Super+Space (Kando), Super+L (фокус) і Super+Escape (блокування) лишаються нашими; жести тачпада не знімаються, якщо їх не
  # було (на десктопі це давало помилку Lua); оголошена крива emphasizedDecel (без неї
  # помилка при кожному новому вікні); без зірок на рамках вікон; виклик quiet для режимів.
  # Налаштування -- не тут, а в ~/.config/etea/settings.json (GUI, Super+,).
  etea = pkgs.stdenvNoCC.mkDerivation {
    pname = "etea-shell";
    version = "0-unstable-2026-11-03";
    src = pkgs.fetchFromGitHub {
      owner = "SDcold";
      repo = "etea-shell";
      rev = "d9e1c38a3ac465fe4d9f6a087971b9025338368a";
      hash = "sha256-+CXxe+oA8yxwaqhyV8MIIa2KKDo9xHZCij12sPsXUh8=";
    };
    patches = [ ./nebula.patch ];
    # На NixOS немає /usr/share: без цього порожній список мов у Settings
    postPatch = ''
      substituteInPlace services/Keyboard.qml \
        --replace-fail /usr/share/X11/xkb/rules/evdev.lst \
        ${pkgs.xkeyboard_config}/share/X11/xkb/rules/evdev.lst
    '';
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      cp -r . $out
    '';
  };

  # Для біндів і скриптів: `etea-ipc <target> <function> [args]`
  etea-ipc = pkgs.writeShellScriptBin "etea-ipc" ''
    exec ${pkgs.quickshell}/bin/qs ipc -p ${etea} call "$@"
  '';
in
{
  home.packages = with pkgs; [
    etea-ipc
    quickshell
    # Те, що ETEA викликає на ходу (README, Requirements)
    cava
    cliphist
    wl-clipboard
    grim
    slurp
    wf-recorder
    hyprpicker
    hyprsunset
    brightnessctl
    jq
    curl
    libnotify
    xdg-user-dirs
    zenity
    pulseaudio # pactl
  ];

  # Стартує з hyprland.lua, а не через WantedBy: graphical-session.target під Hyprland
  # на NixOS сам не активується. PATH сервіс бере з імпорту оточення сесії там же.
  systemd.user.services.etea = {
    Unit = {
      Description = "ETEA shell";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -p ${etea}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
