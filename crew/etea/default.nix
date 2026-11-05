{ pkgs, ... }:
let
  # ETEA -- оболонка на Quickshell: бар, сповіщення, лончер, буфер обміну, захоплення екрана.
  # Наш форк github:ryudzyn/etea-shell, гілка nebula (оригінал SDcold/etea-shell, GPL-3.0):
  # стіл -- планета зі своїм кольором, Super+Tab -- Сонячна система, стиль обсерваторії,
  # тема "Глибокий космос", українська мова. Закріплена на коміті: новий код приходить лише
  # зміною rev/hash тут. Правити так: ~/Projects/etea-shell, гілка nebula, коміт і push туди.
  # Скомпільовані .qsb не потрібні, збірка нижче робить їх сама.
  # Текстури -- assets/planets, CC BY 4.0, авторство там же в CREDITS.md.
  # Налаштування -- не тут, а в ~/.config/etea/settings.json (GUI, Super+,).
  etea = pkgs.stdenvNoCC.mkDerivation {
    pname = "etea-shell";
    version = "0-unstable-2026-11-04";
    src = pkgs.fetchFromGitHub {
      owner = "ryudzyn";
      repo = "etea-shell";
      rev = "3c5025a41f57fc1e14f6f7f8d920310966d23c40";
      hash = "sha256-0NB8kRqBf9jEK3Un7fE5MV8BGEO8zPC+q1Hr5b5h1LU=";
    };
    # На NixOS немає /usr/share: без цього порожній список мов у Settings
    postPatch = ''
      substituteInPlace services/Keyboard.qml \
        --replace-fail /usr/share/X11/xkb/rules/evdev.lst \
        ${pkgs.xkeyboard_config}/share/X11/xkb/rules/evdev.lst
    '';
    nativeBuildInputs = [ pkgs.qt6.qtshadertools ];
    dontWrapQtApps = true;
    buildPhase = ''
      cp -r ${../../assets/planets} assets/planets
      # Тема "Глибокий космос": шейдери шпалер, перекладені під Qt
      for wallpaper in ${../../assets/shaders}/*.frag; do
        sh ${../../assets/shaders/port-qt.sh} "$wallpaper" "shaders/deep-$(basename "$wallpaper")"
      done
      for shader in shaders/*.frag; do
        qsb --glsl "320 es,330" -o "$shader.qsb" "$shader"
      done
    '';
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
      # Без цього Quickshell не знає теми значків і лончер показує заглушки
      Environment = [ "QS_ICON_THEME=Papirus-Dark" ];
    };
  };
}
