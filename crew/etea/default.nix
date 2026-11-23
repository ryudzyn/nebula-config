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
    version = "0-unstable-2026-11-23";
    src = pkgs.fetchFromGitHub {
      owner = "ryudzyn";
      repo = "etea-shell";
      rev = "b074d1e2f898e76550d8351b8ad98175d5eff172";
      hash = "sha256-k+I/jHsK3q8okg39KE75QlEb5oytjPEiMhiS92x+oNw=";
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

  # Жива Земля на шпалерах: супутникові хмари поверх Blue Marble, оновлюються кожні 3 год
  # (github.com/matteason/live-cloud-maps, CC0; «Contains modified EUMETSAT data»). Щогодини
  # питаємо з ETag -- без змін нічого не качається. ETEA підхоплює файл сама (World.qml).
  systemd.user.services.etea-live-earth = {
    Unit.Description = "Live Earth texture with today's clouds for ETEA";
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "etea-live-earth" ''
          set -eu
          dir="$HOME/.cache/etea"
          mkdir -p "$dir"
          ${pkgs.curl}/bin/curl -fsS --max-time 60 \
            --etag-compare "$dir/earth-live.etag" --etag-save "$dir/earth-live.etag.new" \
            -o "$dir/.earth-live.tmp" https://clouds.matteason.co.uk/images/2048x1024/earth.jpg
          # 304 (не змінилось) -- curl нічого не пише; заміна атомарна, щоб ETEA не впіймала півфайлу
          if [ -s "$dir/.earth-live.tmp" ]; then
            mv "$dir/.earth-live.tmp" "$dir/earth-live.jpg"
            mv "$dir/earth-live.etag.new" "$dir/earth-live.etag"
          fi
          rm -f "$dir/.earth-live.tmp" "$dir/earth-live.etag.new"
        ''
      );
    };
  };
  systemd.user.timers.etea-live-earth = {
    Unit.Description = "Refresh the live Earth texture hourly";
    Timer = {
      OnBootSec = "2min";
      OnCalendar = "hourly";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
