{ config, pkgs, ... }:
let
  # Той самий звужений (укр/eng) tesseract, що й crew/bspwm.nix -- окрема
  # копія тут навмисно, кожен crew-модуль лишається самодостатнім (див.
  # CLAUDE.md), а override -- це два рядки, не варте крос-модульного імпорту.
  tesseract-ocr = pkgs.tesseract.override { enableLanguages = [ "eng" "ukr" ]; };

  # Wayland-порт nebula-ocr з crew/bspwm.nix: maim -s -> grim+slurp,
  # xclip -> wl-copy. Та сама логіка/notify-send-патерн.
  nebula-ocr-wl = pkgs.writeShellScriptBin "nebula-ocr-wl" ''
    tmp=$(${pkgs.coreutils}/bin/mktemp --suffix=.png)
    trap 'rm -f "$tmp"' EXIT
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$tmp" || exit 1
    text=$(${tesseract-ocr}/bin/tesseract "$tmp" - -l ukr+eng 2>/dev/null)
    if [ -z "$text" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "OCR" "Текст не розпізнано"
      exit 0
    fi
    printf '%s' "$text" | ${pkgs.wl-clipboard}/bin/wl-copy
    preview=$(printf '%s' "$text" | head -c 120)
    ${pkgs.libnotify}/bin/notify-send -t 3000 "OCR → буфер" "$preview"
  '';

  # Wayland-порт nebula-color-picker: xcolor (X11-лише) -> hyprpicker,
  # яке саме копіює hex у буфер через -a.
  nebula-color-picker-wl = pkgs.writeShellScriptBin "nebula-color-picker-wl" ''
    color=$(${pkgs.hyprpicker}/bin/hyprpicker -a)
    if [ -n "$color" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "Color picker → буфер" "$color"
    fi
  '';

  # Ctrl+D (і всі інші глобальні хоткеї Awakened) не працюють на XWayland:
  # уся детекція клавіш іде через вбудований uiohook-napi 1.5.4, чий
  # load_input_helper() (libuiohook/src/x11/input_helper.c) намагається
  # визначити evdev-vs-xfree86 нумерацію кодів клавіш через XkbGetKeyboard() —
  # цей виклик на XWayland ЗАВЖДИ повертає NULL (підтверджено issues
  # SnosMe/awakened-poe-trade#1643 і #956 на цьому самому Arch+Hyprland
  # сетапі), тому is_evdev лишається false назавжди, і клавіші читаються по
  # НЕПРАВИЛЬНІЙ (xfree86) таблиці замість evdev, яку завжди використовує
  # XWayland. Живо перевірено (build/config.gypi підтверджує, що USE_EVDEV
  # дефайниться на Linux) -- мінімальний патч: захардкодити is_evdev=true
  # замість зламаної автодетекції, і перезібрати саме цей N-API аддон (ABI-
  # стабільний, не залежить від точної версії Node/Electron).
  uiohook-napi-x11-fix = pkgs.stdenv.mkDerivation {
    pname = "uiohook-napi-x11-fix";
    version = "1.5.4";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/uiohook-napi/-/uiohook-napi-1.5.4.tgz";
      hash = "sha256-qsCLLc1KKDsvr7/aOLsXcBlJPeOUwnIIJs2WBzgkcp8=";
    };

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.node-gyp
      pkgs.python3
      pkgs.pkg-config
      pkgs.gnumake
    ];
    buildInputs = [
      pkgs.libx11
      pkgs.libxrandr
      pkgs.libxtst
      pkgs.libxt
    ];

    postPatch = ''
      substituteInPlace libuiohook/src/x11/input_helper.c \
        --replace-fail 'static bool is_evdev = false;' 'static bool is_evdev = true;'
    '';

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      node-gyp rebuild
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp build/Release/uiohook_napi.node "$out/node.napi.node"
      runHook postInstall
    '';
  };

  # Exiled Exchange 2 (PoE2 price-checker) -- неофіційний наступник Awakened
  # PoE Trade, той самий package.json: electron-overlay-window@4.0.2,
  # uiohook-napi@1.5.4 (перевірено -- точно та сама версія, той самий
  # node.napi.node з uiohook-napi-x11-fix вище підходить без перезбірки).
  # Живий тест на "чистій" версії (2026-09-27) підтвердив той самий
  # is_evdev/XkbGetKeyboard баг у логах -- тому тут одразу з обома фіксами
  # (той самий рецепт, що й awakened-poe-trade-x11 нижче):
  # --ozone-platform=x11 + патчений uiohook.
  exiled-exchange-2 = pkgs.stdenv.mkDerivation rec {
    pname = "exiled-exchange-2";
    version = "0.16.3";

    src = pkgs.fetchurl {
      url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v${version}/Exiled-Exchange-2-${version}.AppImage";
      hash = "sha256-aAHFELdlL7cccpzAW9ROHF1hZDAnQGTLLtDonS0CT2Q=";
    };

    appImageContents = pkgs.appimageTools.extractType2 { inherit pname src version; };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/exiled-exchange-2"
      cp -a "${appImageContents}"/{locales,resources} "$out/share/exiled-exchange-2"
      chmod -R u+w "$out/share/exiled-exchange-2"

      cp ${uiohook-napi-x11-fix}/node.napi.node \
        "$out/share/exiled-exchange-2/resources/app.asar.unpacked/node_modules/uiohook-napi/prebuilds/linux-x64/node.napi.node"

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper ${pkgs.lib.getExe pkgs.electron} "$out/bin/exiled-exchange-2" \
        --add-flags "$out/share/exiled-exchange-2/resources/app.asar --ozone-platform=x11" \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libxtst pkgs.libxt ]}
    '';
  };

  # Нативний Wayland-режим Electron ламає click-through оверлею — вікно
  # ловить весь інпут і блокує кнопки гри під собою. Форсуємо XWayland
  # через --ozone-platform=x11 (живо перевірено на Hyprland: з цим флагом
  # кнопки PoE знову клікабельні).
  #
  # symlinkJoin тут не годиться -- треба підмінити один файл усередині вже
  # готового пакета (app.asar.unpacked лишається звичайною директорією на
  # диску, не всередині asar-архіву, тож підміна безпечна й не чіпає решту
  # Electron-застосунку), тому копіюємо все дерево пакета і патчимо на місці.
  # Nixpkgs-овий bin/awakened-poe-trade -- це вже сам по собі wrapper
  # (makeWrapper), і всередині нього ЖОРСТКО закодований абсолютний шлях на
  # app.asar в ОРИГІНАЛЬНОМУ /nix/store/...-awakened-poe-trade-3.28.103 --
  # навіть після copy-і-патчу цей текстовий рядок лишається старим, тому
  # electron продовжував би вантажити непатчений app.asar.unpacked (жива
  # перевірка: hyprctl/ps показував старий шлях, попри те, що ми запускали
  # бінарник з нового шляху). Тому останній `exec`-рядок відкидаємо і пишемо
  # свій, з коректним шляхом на copies у $out; решту скрипта (LD_LIBRARY_PATH
  # тощо, налаштовані апстрімом) лишаємо як є -- це стійкіше до майбутніх
  # змін залежностей electron у nixpkgs, ніж передруковувати їх вручну.
  awakened-poe-trade-x11 = pkgs.runCommand "awakened-poe-trade-x11" { } ''
    mkdir -p "$out"
    cp -rL ${pkgs.awakened-poe-trade}/. "$out/"
    chmod -R u+w "$out"

    cp ${uiohook-napi-x11-fix}/node.napi.node \
      "$out/share/awakened-poe-trade/resources/app.asar.unpacked/node_modules/uiohook-napi/prebuilds/linux-x64/node.napi.node"

    electron_path=$(grep -m1 '^exec "' "$out/bin/awakened-poe-trade" | sed -E 's/^exec "([^"]+)".*/\1/')
    head -n -1 "$out/bin/awakened-poe-trade" > "$out/bin/awakened-poe-trade.new"
    echo "exec \"$electron_path\" \"$out/share/awakened-poe-trade/resources/app.asar\" --ozone-platform=x11 \"\$@\"" \
      >> "$out/bin/awakened-poe-trade.new"
    mv "$out/bin/awakened-poe-trade.new" "$out/bin/awakened-poe-trade"
    chmod +x "$out/bin/awakened-poe-trade"
  '';
in
{
  # Рішення "Awakened чи poe-price-check" (див. план міграції) прийняте
  # 2026-09-20 після живого тесту на Hyprland: Awakened працює нормально з
  # цими двома фіксами → лишається основним, Windows dual-boot не потрібен.
  home.packages = [
    awakened-poe-trade-x11
    exiled-exchange-2
    # Скріншот-біндинги в hyprland.lua (Print, super+shift+s) -- Wayland-
    # еквівалент bspwm-івського maim+xclip з crew/bspwm.nix: grim знімає,
    # slurp обирає ділянку, wl-clipboard -- буфер обміну для Wayland (xclip
    # там працює тільки з X11-застосунками через XWayland).
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    nebula-ocr-wl
    nebula-color-picker-wl
    # rofi/nwg-look вже стоять через crew/bspwm.nix/theming.nix (спільний
    # home-manager профіль, доступні і в Hyprland-сесії); pavucontrol/
    # hyprpicker там нема -- додаю тут.
    pkgs.pavucontrol
    pkgs.hyprpicker
    # Калькулятор (super+equal) -- rofi-calc замінено на Qalculate (набагато
    # потужніший: одиниці виміру, наукові функції, константи, конвертація
    # валют), окреме GTK-вікно замість rofi-попапу.
    pkgs.qalculate-gtk
    # Рулетка (super+shift+r) -- той самий assets/cprogram/roulette.html, але
    # тепер у власному вікні через surf (suckless, мінімальний WebKitGTK,
    # без вкладок/адресного рядка) замість вкладки в основному браузері.
    pkgs.surf
  ];

  # hyprland.lua/tweaks.lua лишаються звичайними файлами в репо (не в .nix) —
  # mkOutOfStoreSymlink лінкує ~/.config/hypr/* прямо на файл у чекауті
  # nebula-config, а не на копію в /nix/store. Редагування (вручну або через
  # UI-твікалку типу GZML) видно одразу, Hyprland сам перечитує конфіг при
  # зміні файлу — без `nh os switch`.
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/hyprland/hyprland.lua";
  home.file.".config/hypr/tweaks.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/hyprland/tweaks.lua";
}
