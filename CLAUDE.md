# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Мова спілкування

Спілкування з користувачем у цьому репозиторії ведеться українською мовою.

## What this is

"Nebula OS" — a personal NixOS flake config (single host: `earth`, an Intel i5-9400 + Arc A770
desktop as of 2026-09-29, previously AMD/RX590) plus a
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
- Boot-test a generation on a disposable VM instead of the real `earth` host: `scripts/test-vm.sh`.
  Builds `earth`'s own `config.system.build.vm` (no separate host config needed — every
  `nixosSystem` already has this target) and boots it headless with SSH access. Reliable for a
  cold-boot check (services starting cleanly, generated session files, etc.) and for a one-shot
  `switch-to-configuration dry-activate`/`test` to preview what a switch would touch. A live
  `nixos-rebuild switch` *inside* the guest is unreliable — see the script's header comment for
  why (it tears down its own 9p store/share mounts mid-switch). `--fresh` wipes the guest disk.

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
- `crew/` — everything that runs as the `ryudzyn` Home Manager profile: `hyprland/` (the sole
  compositor/session — Lua config, live-linked via `mkOutOfStoreSymlink`, see below), `noctalia/`
  (the shell: bar, launcher, notifications, lock screen), terminal/shell, CLI tools, theming, the
  VSCodium profile, Spotify (spicetify, inside `media.nix`), and `modes.nix` (workspace-launcher
  scripts bound to `SUPER+F1/F2/F3` in `hyprland.lua`: work / study / play). Aggregated through
  `crew/default.nix` — same rule, a new crew module must be added there.
- `pkgs/halley/` — a `buildRustPackage` derivation for `halley`, a Wayland compositor built from
  source (github:saltnpepper97/halley) with a checked-in `Cargo.lock`. Still exposed as a flake
  package (`nix build .#halley`), but since 2026-10-03 it is **not wired into the system** — no
  greetd session, no portal, not in `systemPackages`.
- `assets/` — wallpapers, Plymouth theme and a static `roulette.html`, referenced by absolute Nix
  path (e.g. `${../assets/wallpaper/wallpaper.jpg}`) from `core/desktop.nix` and `crew/hyprland/`.

### Things to know before adding a module

- Adding a file under `core/`, `constellations/`, or `crew/` does nothing until it's added to the
  relevant `imports` list (`hosts/earth/default.nix`, `constellations/default.nix`,
  `crew/default.nix` respectively) — there's no auto-discovery.
- `crew/terminal/kitty.nix` is written but deliberately left commented out in
  `crew/default.nix` pending later work.
- Hyprland (`crew/hyprland/`) + Noctalia (`crew/noctalia/`) is the sole desktop session; the only
  other greetd entry is Steam's own gamescope session (`core/games.nix`). The history: sway/i3 were
  retired for bspwm (2026-08-13), then bspwm (plus `core/x11-greetd-sessions.nix`, polybar, sxhkd,
  dunst, picom, i3lock) was deleted once the Hyprland port was complete (2026-10-03). There is no
  X server (`services.xserver.enable` is off) — X11 apps run through XWayland. Don't reintroduce a
  second X11/Wayland session without checking whether that decision still holds.
- `hyprland.lua`, `tweaks.lua`, `alttab.lua` and Noctalia's `config.toml` are live symlinks into
  this checkout — edits apply on `hyprctl reload` without a switch. Hyprland here uses the native
  Lua config: legacy `hyprctl keyword` is rejected ("Use eval."), so use
  `hyprctl eval '<lua>'` (e.g. `hl.exec_cmd(...)`, `hl.dispatch(hl.dsp.focus({workspace=2}))`).
- `self` and `inputs` are threaded through via `specialArgs` in `flake.nix` — modules that need flake
  inputs (e.g. `zen-browser`, `spicetify-nix`, `noctalia`) take `self`/`inputs` as module arguments rather than importing them another way.
