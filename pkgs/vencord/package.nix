# Тимчасова копія pkgs/by-name/ve/vencord/package.nix з nixpkgs nixos-unstable
# (коміт 0438bc3, Vencord 1.15.17): у нашому nixpkgs 1.15.13, і Discord від
# 2026-11-12 з ним не стартує ("i.A is not a constructor", порожній #app-mount).
# Прибрати разом із callPackage у core/packages.nix при наступному flake update.
{
  curl,
  fetchFromGitHub,
  git,
  jq,
  lib,
  nix-update,
  nodejs,
  pnpm_12,
  fetchPnpmDeps,
  pnpmConfigHook,
  stdenv,
  writeShellScript,
  discord,
  discord-ptb,
  discord-canary,
  discord-development,
  buildWebExtension ? false,
}:
let
  pnpm = pnpm_12;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vencord";
  version = "1.15.17";

  src = fetchFromGitHub {
    owner = "Vendicated";
    repo = "Vencord";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+dN4wAFNmYVDiEe0QStqrFBRFHBBRkApqbmhuvsLZZM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      src
      ;
    inherit pnpm;
    fetcherVersion = 5;
    hash = "sha256-/cnY+wj2/oHohUwf7zUHsE4aWI8YdhBNO8jSVuvQH+M=";
  };

  nativeBuildInputs = [
    git
    nodejs
    pnpmConfigHook
    pnpm
  ];

  env = {
    VENCORD_REMOTE = "${finalAttrs.src.owner}/${finalAttrs.src.repo}";
    VENCORD_HASH = "${finalAttrs.version}";
  };

  buildPhase = ''
    runHook preBuild

    pnpm run ${if buildWebExtension then "buildWeb" else "build"} \
      -- --standalone --disable-updater

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp -r dist/${lib.optionalString buildWebExtension "chromium-unpacked/"} $out
    cp package.json $out # Presence is checked by Vesktop.

    runHook postInstall
  '';

  passthru = {
    # We need to fetch the latest *tag* ourselves, as nix-update can only fetch the latest *releases* from GitHub
    # Vencord had a single "devbuild" release that we do not care about
    updateScript = writeShellScript "update-vencord" ''
      export PATH="${
        lib.makeBinPath [
          curl
          jq
          nix-update
        ]
      }:$PATH"
      ghTags=$(curl ''${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} "https://api.github.com/repos/Vendicated/Vencord/tags")
      latestTag=$(echo "$ghTags" | jq -r .[0].name)

      echo "Latest tag: $latestTag"

      exec nix-update --version "$latestTag" "$@"
    '';

    tests = lib.genAttrs' [ discord discord-ptb discord-canary discord-development ] (
      p: lib.nameValuePair p.pname p.tests.withVencord
    );
  };

  meta = {
    description = "Cutest Discord client mod";
    homepage = "https://github.com/Vendicated/Vencord";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [
      _4evy
      Gliczy
      NotAShelf
      Scrumplex
      ryand56
    ];
  };
})
