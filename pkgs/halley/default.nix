{ lib, fetchFromGitHub, rustPlatform, pkg-config, udev, libinput, seatd, libGL, libxkbcommon, wayland, pipewire, llvmPackages, glibc, mesa, cairo, pixman, libgbm, autoAddDriverRunpath }:

rustPlatform.buildRustPackage rec {
  pname = "halley";
  version = "main";

  src = fetchFromGitHub {
    owner = "saltnpepper97";
    repo = "halley";
    rev = "main";
    sha256 = "sha256-6r6lmH/GQpygmIrJ6m57iJWdyE5zYnGPt4238UrqdP0=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "smithay-0.7.0" = "sha256-TV/GTfSvgfVwIFUGoASU7xm38opIBLjLMf1HeNTW07U=";
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
  ];

  postInstall = ''
   install -Dm755 packaging/wayland-sessions/halley-session $out/bin/halley-session
   install -Dm644 packaging/wayland-sessions/halley.desktop $out/share/wayland-sessions/halley.desktop
   install -Dm644 packaging/xdg-desktop-portal/portals/halley.portal $out/share/xdg-desktop-portal/portals/halley.portal
   install -Dm644 packaging/systemd-user/halley.service $out/lib/systemd/user/halley.service
   install -Dm644 packaging/systemd-user/halley-shutdown.target $out/lib/systemd/user/halley-shutdown.target
   
   substituteInPlace $out/lib/systemd/user/halley.service \
    --replace-fail "/usr/bin/halley" "$out/bin/halley"

    substituteInPlace $out/share/wayland-sessions/halley.desktop \
      --replace-fail "/usr/bin/halley-session" "$out/bin/halley-session"

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
