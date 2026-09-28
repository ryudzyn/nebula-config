{ lib, fetchFromGitHub, fetchFromGitLab, rustPlatform, pkg-config, udev, libinput, seatd, libGL, libxkbcommon, wayland, pipewire, llvmPackages, glibc, mesa, cairo, pixman, libgbm, libdisplay-info, autoAddDriverRunpath }:
let
  # nixpkgs (28.09.2026-пін цього флейка) уже на libdisplay-info 0.4.0, але
  # Rust-байндінг у Cargo.lock (libdisplay-info-sys-0.3.0) жорстко вимагає
  # `< 0.4.0` -- build падає з "PKG_CONFIG... version mismatch" на новішому.
  # Оверрайджуємо саме тут (не чіпаючи системний libdisplay-info для решти
  # пакетів), джерело/хеш -- той самий 0.3.0-реліз, що був у nixpkgs до
  # бампу на 0.4.0.
  libdisplay-info-0_3 = libdisplay-info.overrideAttrs (_: {
    version = "0.3.0";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "emersion";
      repo = "libdisplay-info";
      rev = "0.3.0";
      sha256 = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
    };
  });
in
rustPlatform.buildRustPackage rec {
  pname = "halley";
  version = "main";

  src = fetchFromGitHub {
    owner = "saltnpepper97";
    repo = "halley";
    # Запінений конкретний commit, не "main" -- той floating-рев рано чи пізно
    # розходиться з хардкодженим sha256 нижче (апстрім рухає гілку), і build
    # падає з hash mismatch (живцем зловлено 2026-09-28: rev був "main",
    # реальний `nix build` уперся в розбіжність хешів). Апдейт halley тепер
    # означає: бампнути rev/sha256 тут І синхронно замінити ./Cargo.lock на
    # версію апстріму з того самого commit (інакше cargoHash-перевірка нижче
    # впаде окремо, бо граф залежностей у Cargo.toml міг змінитись).
    rev = "d3cbefde7d767366294d637a3cc108f6a143f51a";
    sha256 = "sha256-I65ClJjmEAntQDzvGOW2bbhdIy9NV9wrbbTwkLTpt6g=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    # smithay-drm-extras тягнеться з git (не crates.io) -- cargoLock сам не
    # може захешувати git-залежності, тож хеш вказано окремо тут. smithay
    # сам (той самий репо/rev) відтепер запатчений апстрімом на локальний
    # vendor/smithay всередині halley (Cargo.toml: [patch."...smithay.git"]),
    # тому для нього самого outputHash більше не потрібен -- лишився тільки
    # для сателітної smithay-drm-extras, яка й далі тягнеться напряму з git.
    outputHashes = {
      "smithay-drm-extras-0.1.0" = "sha256-TV/GTfSvgfVwIFUGoASU7xm38opIBLjLMf1HeNTW07U=";
    };
  };

  nativeBuildInputs = [ pkg-config llvmPackages.libclang autoAddDriverRunpath ];

  doCheck = false;

  env = {
    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${glibc.dev}/include";
  };

  buildInputs = [
    udev
    libinput
    seatd
    libGL
    libxkbcommon
    wayland
    pipewire
    mesa
    cairo
    pixman
    libgbm
    libdisplay-info-0_3 # EDID/DisplayID -- потрібен з появою multi-GPU output-коду вище за pin
  ];

  # Апстрімний build.rs не встановлює нічого сам (немає make install) -- усі
  # сесійні/сервісні файли з packaging/ треба розкласти по FHS-шляхах вручну,
  # і кожен з них хардкодить /usr/bin/... замість реального /nix/store-шляху.
  postInstall = ''
   install -Dm755 packaging/wayland-sessions/halley-session $out/bin/halley-session
   install -Dm644 packaging/wayland-sessions/halley.desktop $out/share/wayland-sessions/halley.desktop
   install -Dm644 packaging/xdg-desktop-portal/portals/halley.portal $out/share/xdg-desktop-portal/portals/halley.portal
   install -Dm644 packaging/systemd-user/halley.service $out/lib/systemd/user/halley.service
   install -Dm644 packaging/systemd-user/halley-shutdown.target $out/lib/systemd/user/halley-shutdown.target
   
   substituteInPlace $out/lib/systemd/user/halley.service \
    --replace-fail "/usr/bin/halley" "$out/bin/halley"

    # 2026-09-28 pin-бамп: апстрім спростив Exec/TryExec з абсолютного
    # /usr/bin/halley-session до голого відносного імені (розраховує на
    # PATH) -- substituteInPlace-патерн тут підганяти під конкретний
    # апстрімний формат щоразу, коли бампаєш rev/hash вище.
    # Один --replace-fail: "TryExec=halley-session" містить "Exec=halley-
    # session" як підрядок, тож глобальна заміна підхоплює обидва ключі
    # (Exec=/TryExec=) за раз -- другий окремий replace-fail на TryExec=
    # більше нічого не знаходить (уже замінено) і падає "pattern doesn't
    # match anything".
    substituteInPlace $out/share/wayland-sessions/halley.desktop \
      --replace-fail "Exec=halley-session" "Exec=$out/bin/halley-session"

    # На відміну від файлів вище цього немає в апстрімному packaging/ --
    # без нього D-Bus не знає, який бінарник підняти для
    # org.freedesktop.impl.portal.desktop.halley (портал ScreenCast/Screenshot,
    # core/desktop.nix), пишемо вручну.
    mkdir -p $out/share/dbus-1/services
    cat > $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.halley.service <<EOF
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.halley
Exec=$out/bin/xdg-desktop-portal-halley
EOF
  '';

  postFixup = ''
    patchelf --add-rpath "${lib.makeLibraryPath [ libGL wayland ]}" $out/bin/halley '';

  passthru.providedSessions = [ "halley" ];

  meta = with lib; {
    description = "A Wayland compositor";
    homepage = "https://saltnpepper97.github.io/halley-site/";
    license = licenses.gpl3Only;
  };
}
