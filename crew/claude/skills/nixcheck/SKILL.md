---
name: nixcheck
description: Verify a change to the nebula-config NixOS flake before handing it back — format touched .nix files, dry-build earth, and summarize what would change. Use after editing any .nix file in ~/nebula-config, or when the user asks "чи збирається", "перевір конфіг", "dry-build".
---

# nixcheck — перевірка змін у nebula-config

Run from `~/nebula-config`. Never run `nh os switch` / `nixos-rebuild switch` / sudo — the user applies changes themselves.

1. **Format only touched files.** `git diff --name-only HEAD -- '*.nix'` plus untracked `.nix` files (`git ls-files --others --exclude-standard -- '*.nix'`). Run `nixfmt` on those only — never the whole repo (it would reflow unrelated files and pollute the diff). Skip `hosts/earth/hardware.nix`.
2. **New module wired in?** For every untracked `.nix` under `core/`, `constellations/`, `crew/`, confirm it is listed in the right imports (`hosts/earth/default.nix`, `constellations/default.nix`, `crew/default.nix`; a directory module counts via its parent). Unwired modules silently do nothing.
3. **Dry-build.** Delegate to the `nix-builder` subagent so the long build log stays out of the main context: ask it to run `nixos-rebuild dry-build --flake .#earth` and return only pass/fail, the first real error with file:line, and the count of derivations to build/fetch.
4. **If it fails**, fix and repeat from step 3. Evaluation errors with a trace: the relevant frame is usually the last one inside `/home/ryudzyn/nebula-config` or a `«github:nixos/nixpkgs»` option path.
5. **Report** in Ukrainian: what was checked, pass/fail, notable rebuilds (kernel, mesa, hyprland → long switch), and whether the change needs more than `sysup` (greetd/session changes need `sudo systemctl restart greetd`; live-linked Lua/TOML needs only `hyprctl reload`).
