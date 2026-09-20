{ config, pkgs, ... }:
let
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
  home.packages = [ awakened-poe-trade-x11 ];

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
