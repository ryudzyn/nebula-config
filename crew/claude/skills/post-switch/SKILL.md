---
name: post-switch
description: Health check of earth right after the user ran `sysup` / `nh os switch` — failed system and user units, errors logged since the switch, Home Manager activation, Noctalia, whether greetd still runs the old config, dangling Claude skill links. Read-only. Use when the user says "зробив sysup", "свічнув", "перевір після світча", "все ок після оновлення?", or before pushing commits that were just switched.
---

# post-switch — перевірка earth після switch

Read-only: never restart services, never sudo, never switch. Report findings; the user fixes or approves.

Run these (one Bash call is fine), then report:

1. **Generation & switch time.**
   `stat -c '%y %N' /nix/var/nix/profiles/system` → switch time `T` (first 19 chars) and generation number.
   `readlink /run/current-system` vs `readlink /run/booted-system` — different means a reboot would boot something newer than what's running; only matters if the change touched kernel/initrd/bootloader (mention reboot then).
2. **Failed units.** `systemctl --failed --no-legend` and `systemctl --user --failed --no-legend`. For each failed unit: `journalctl [-u|--user-unit] <unit> -b -n 30 --no-pager` and give the cause in one line.
3. **New errors since the switch.** `journalctl -b -p err --since "$T" --no-pager -q` and the same with `--user`. If longer than ~40 lines, hand it to the `log-digger` agent. Ignore known noise only if it also appears before `T` (check with `--until "$T"`, same filter).
4. **Home Manager.** `systemctl show home-manager-ryudzyn -p Result,ExecMainExitTimestamp` — `Result=success` and a timestamp ≈ `T`. On failure: `journalctl -u home-manager-ryudzyn -b -n 40 --no-pager` (usually a file clobber: "would be clobbered").
5. **Noctalia** (glibc lockstep trap after nixpkgs bumps): `systemctl --user is-active noctalia`. Not active → `journalctl --user-unit noctalia -b -n 30`; `eglGetDisplay failed` means the `noctalia` input lags nixpkgs — fix is `nix flake update noctalia` (see the `/flake-bump` skill).
6. **greetd still on old config?** greetd has `X-RestartIfChanged=false`, so switch never restarts it. Compare the running cmdline with the unit:
   ```sh
   a=$(tr '\0' ' ' < /proc/$(systemctl show -p MainPID --value greetd)/cmdline | sed 's/ $//')
   b=$(grep ^ExecStart /etc/systemd/system/greetd.service | sed 's/^ExecStart=//')
   [ "$a" = "$b" ] && echo same || printf '%s\n%s\n' "$a" "$b"
   ```
   Compare as strings — `diff <(…) <(…)` false-alarms on the missing trailing newline of `/proc/*/cmdline`.
   Different `--config` path → tell the user `sudo systemctl restart greetd` is needed (it ends the graphical session, so they choose when — or just reboot).
7. **Claude links.** `find ~/.claude/skills ~/.claude/agents -maxdepth 1 -xtype l` must be empty; every name in the `skills`/`agents` lists of `~/nebula-config/crew/claude/default.nix` must exist under `~/.claude/`.
8. **Live-linked config** (only if this switch touched `crew/hyprland/` or `crew/noctalia/`): `hyprctl configerrors` (needs `HYPRLAND_INSTANCE_SIGNATURE`; take it from `ls /run/user/1000/hypr/`). For anything visual, offer `/hypr-verify`.

## Report (Ukrainian, short)

One line per check: ✅ / ⚠️ / ❌ + the fact. Then a "що зробити" list with exact commands for the user (restart greetd, reboot, flake update, etc.). If everything is green, say so in one line — and if the user asked to push afterwards, proceed.
