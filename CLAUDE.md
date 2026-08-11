# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Мова спілкування

Спілкування з користувачем у цьому репозиторії ведеться українською мовою.

## What this is

"Nebula OS" — a personal NixOS flake config (single host: `earth`, an AMD/RX590 desktop) plus a
Home Manager user profile (`ryudzyn`), managed together as one flake. All prose comments in the
`.nix` files are in Ukrainian.

## Commands

- Check the whole config builds without applying it:
  `nixos-rebuild dry-build --flake .#earth`
- Apply changes to the running system (the `sysup` shell alias defined in `crew/terminal/zsh.nix`
  does exactly this, via `nh`):
  `nh os switch ~/nebula-config`
- Build just the custom compositor package standalone:
  `nix build .#halley`
- Format a `.nix` file: `nixfmt <file>` (installed as a regular package in `core/packages.nix`;
  there is no `nix fmt` / flake-level formatter wired up).
- There is no test suite; correctness is checked via `dry-build` and, for real changes, a switch
  + manual verification of the affected service/session.

## Architecture

Everything is wired from `flake.nix`, which defines two outputs:
- `packages.x86_64-linux.halley` — a custom-built package (see below).
- `nixosConfigurations.earth` — the system, built from `hosts/earth/default.nix` with the
  `home-manager` NixOS module folded in (`home-manager.users.ryudzyn = import ./crew/default.nix`).

The module tree is split by *level*, not by feature, and each level has its own aggregator file
that a new module must be added to or it silently has no effect:

- `hosts/earth/default.nix` — the entrypoint. Imports `hardware.nix` (machine-generated, don't
  hand-edit) plus each `core/*.nix` module individually, plus `constellations/default.nix`.
- `core/` — base system modules (bootloader, users, system-wide locale/kernel settings, desktop
  session/greeter, package list, games, virtualisation, peripherals/udev). Each file is imported
  by name directly in `hosts/earth/default.nix` (no aggregator).
- `constellations/` — system-level *services* (bluetooth, network/ssh/syncthing, DNS via
  unbound+AdGuard Home, sound via pipewire, docker/podman, printing/scanning/misc udisks
  services). Aggregated through `constellations/default.nix` — a new constellation module must be
  added to that import list.
- `crew/` — everything that runs as the `ryudzyn` Home Manager profile: window managers (sway is
  the primary WM; i3 is a secondary/gaming-session WM), terminal/shell, CLI tools, theming, the
  VSCodium profile, Spotify (spicetify), and `modes.nix` (workspace-launcher scripts bound to
  `Mod4+F1/F2/F3` in sway: work / study / play). Aggregated through `crew/default.nix` — same
  rule, a new crew module must be added there.
- `pkgs/halley/` — a `buildRustPackage` derivation for `halley`, a Wayland compositor built from
  source (github:saltnpepper97/halley) with a checked-in `Cargo.lock`. It's exposed as a flake
  package and consumed two ways: as the greetd session (`core/desktop.nix`) and as the
  `xdg-desktop-portal` implementation for screenshot/screencast (also `core/desktop.nix`), always
  referenced as `self.packages.${pkgs.stdenv.hostPlatform.system}.halley`.
- `assets/` — wallpapers and a static `roulette.html`, referenced by absolute Nix path from
  `crew/i3.nix` / `crew/sway.nix` (e.g. `${../assets/wallpaper/wallpaper.jpg}`).

### Things to know before adding a module

- Adding a file under `core/`, `constellations/`, or `crew/` does nothing until it's added to the
  relevant `imports` list (`hosts/earth/default.nix`, `constellations/default.nix`,
  `crew/default.nix` respectively) — there's no auto-discovery.
- Several files currently exist as empty, unimported placeholders staked out for future work:
  `core/security.nix`, `constellations/gravity-drive.nix`, `constellations/propulsion.nix`. Two
  more are written but deliberately left commented out in `crew/default.nix` pending later work:
  `crew/terminal/kitty.nix`, `crew/terminal/starship.nix`.
- Sway is the primary compositor/session; i3 (`crew/i3.nix`) is kept for the Steam/gamescope
  gaming session (`core/games.nix` enables `services.xserver.windowManager.i3` for that path).
  Don't assume one replaces the other.
- `self` and `inputs` are threaded through via `specialArgs` in `flake.nix` — modules that need the
  `halley` package or flake inputs (e.g. `zen-browser`, `spicetify-nix`) take `self`/`inputs` as
  module arguments rather than importing them another way.
