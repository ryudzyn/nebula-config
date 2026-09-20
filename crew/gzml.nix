{ pkgs, lib, ... }:
let
  # GZML Visual Tools — трей-застосунок для перемикання presets анімацій/
  # блюру/wallpaper-ефектів Hyprland. Апстрімний installer/install.sh
  # Arch-only (перевіряє pacman), але сам застосунок — один Python-скрипт
  # (gzml-tray.py) поруч з presets/assets, без окремої збірки, тож пакується
  # напряму: копіюємо дерево репо і обгортаємо скрипт через python3+pygobject3,
  # updater зі скрипта (git clone поверх $HOME) не використовується — оновлення
  # відбувається через бамп rev/hash тут.
  gzml-visual-tools = pkgs.stdenv.mkDerivation {
    pname = "gzml-visual-tools";
    version = "unstable-2026-09-20";

    src = pkgs.fetchFromGitHub {
      owner = "zero-j89";
      repo = "Hyprland-Visual-Gzml";
      rev = "e84d4cc1056e305f584c80a62432e1a0c688e06a";
      hash = "sha256-Vj6QATkjchMyVJXqwAvk4ld8G4RsKhfnZ/4vWx8OjmA=";
    };

    nativeBuildInputs = [
      pkgs.wrapGAppsHook3
      pkgs.gobject-introspection
    ];
    buildInputs = [
      pkgs.gtk3
      # НЕ libayatana-appindicator -- той форк перейменував GI-namespace на
      # AyatanaAppIndicator3, а gzml-tray.py явно шукає старий
      # `gi.require_version("AppIndicator3", "0.1")". Живо перевірено: з
      # ayatana-варіантом typelib не знаходиться, застосунок мовчки
      # відкочується на легасі Gtk.StatusIcon (XEmbed), який Noctalia не
      # підтримує -- іконка технічно жива, але ніде не рендериться.
      pkgs.libappindicator-gtk3
    ];

    dontBuild = true;
    dontConfigure = true;

    # APP_DIR у /nix/store лишається read-only, а апстрім хардкодить і
    # STATE_DIR (прогрес/активні presets), і PRESETS_DIR (сам список presets,
    # апстрім сам домальовує туди нові підпапки типу "themes", якої навіть
    # нема в репо) як шляхи поруч зі скриптом. Живо перевірено: без цих двох
    # патчів застосунок падає з OSError при першому ж mkdir у /nix/store.
    postPatch = ''
      substituteInPlace gzml-tray.py \
        --replace-fail 'STATE_DIR = APP_DIR / ".state"' \
                        'STATE_DIR = Path.home() / ".local/state/gzml-visual-tools"' \
        --replace-fail 'PRESETS_DIR = APP_DIR / "presets"' \
                        'PRESETS_DIR = Path.home() / ".local/share/gzml-visual-tools/presets"'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/gzml-visual-tools" "$out/bin"
      cp -r assets presets gzml-tray.py "$out/share/gzml-visual-tools/"
      find "$out/share/gzml-visual-tools/presets" -type f -name "*.sh" -exec chmod +x {} \;

      # Ручний launcher замість makeWrapper --run: ця версія makeWrapper —
      # C-обгортка (makeBinaryWrapper) без підтримки --run, тож логіку
      # "скопіювати presets в writable путь, якщо ще нема" пишемо прямим
      # bash-скриптом; wrapGAppsHook3 сам довгорне його нижче для GI-typelib.
      cat > "$out/bin/gzml-visual-tools" <<WRAPPER
#!/usr/bin/env bash
mkdir -p "\$HOME/.local/share/gzml-visual-tools"
if [ ! -d "\$HOME/.local/share/gzml-visual-tools/presets" ]; then
  cp -r "$out/share/gzml-visual-tools/presets" "\$HOME/.local/share/gzml-visual-tools/"
  chmod -R u+w "\$HOME/.local/share/gzml-visual-tools/presets"
fi
export PATH="${
  lib.makeBinPath [
    pkgs.imagemagick
    pkgs.jq
    pkgs.wallust
    pkgs.libnotify
  ]
}:\$PATH"
exec "${pkgs.python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3" "$out/share/gzml-visual-tools/gzml-tray.py" "\$@"
WRAPPER
      chmod +x "$out/bin/gzml-visual-tools"

      runHook postInstall
    '';

    meta = {
      description = "Tray GUI for switching Hyprland animation/blur/wallpaper-effect presets";
      homepage = "https://github.com/zero-j89/Hyprland-Visual-Gzml";
      platforms = lib.platforms.linux;
    };
  };
in
{
  home.packages = [ gzml-visual-tools ];
}
