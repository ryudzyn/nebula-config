---
name: flake-bump
description: Update the nebula-config flake inputs (nixpkgs, home-manager, zen-browser, spicetify-nix) safely — build the new system without switching, and summarize what changes (nvd diff: kernel, mesa, hyprland, claude-code…). Use when the user says "онови флейк", "flake update", "оновити систему/пакети", "bump nixpkgs", "нові версії".
---

# flake-bump — оновлення інпутів nebula-config

Run from `~/nebula-config`. Never switch or sudo — the user runs `sysup`, then `/post-switch`.

1. **Clean start.** `git status --short` — if `flake.lock` is already modified, stop and ask. Unrelated dirty files are fine; this skill only ever stages `flake.lock`.
2. **Record "before".** `cp flake.lock "$CLAUDE_JOB_DIR/tmp/flake.lock.before"` (or another scratch dir if `$CLAUDE_JOB_DIR` is unset).
3. **Update.** Default: everything — `nix flake update`. If the user named inputs, `nix flake update <input>...`.
4. **Build, don't switch.** Delegate to the `nix-builder` agent: `nix build .#nixosConfigurations.earth.config.system.build.toplevel --no-link --print-out-paths` → pass/fail, first real error with file:line, the out path. (Real build, not dry-build: the diff in step 6 needs the closure. It may download a few GB.) On eval errors from renamed/removed options, fix the module, rerun, and list each fix in the report.
5. **What changes.** `nix run nixpkgs#nvd -- diff /run/current-system <out-path>` — feed long output to `log-digger`. Summarize: kernel, mesa / intel drivers (Arc A770), hyprland, pipewire, steam/gamescope, claude-code, plus counts of added/removed/changed packages and closure size delta.
6. **Report** (Ukrainian): per input old → new date (from `flake.lock.before` vs `flake.lock`), lockstep verdict, build result, notable version jumps and risks (kernel/mesa → reboot advised; hyprland major → Lua API may have changed, check `hyprctl configerrors` after switch).
8. **Commit only when the user agrees** — stage `flake.lock` (plus any module fixes) and commit `flake.lock: bump <inputs> (nixpkgs <short rev>)`. Then hand back: `sysup`, then `/post-switch`.

Mod dev shells (`~/Projects/ascension-*`) have their own flake.lock with the same glibc trap — if the user plays/dev-tests the mod after this bump, mention: `nix flake lock --override-input nixpkgs github:nixos/nixpkgs/<new system rev>` in that repo.
