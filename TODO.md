# Nebula OS: cleanup, hardening, workflow, gaming WM

## Status: core fix done and committed; new black-screen regression under investigation (Follow-up #7)

All four original work streams below are implemented and committed
(`77a4bd6`..`bfa9247`). X11 sessions (`i3`, `bspwm`) initially never launched
under the new `greetd` setup — root-caused across Follow-ups #1–#6 (missing
`wait "$waitPID"`, then a `DISPLAY=:0` leak from inherited session
environment instead of the intended `:1`) and fixed (committed `3ad8397`);
both `i3 (xinit)` and `bspwm (xinit)` held at tuigreet, and PoE1 confirmed
launching under `bspwm (xinit)`. Since then, a **new, separate** issue
surfaced: see Follow-up #7 — `bspwm (xinit)` black-screens unless a sway
session is already active on another VT. Undiagnosed, diagnostics staged,
not yet root-caused.

## Context

While writing `CLAUDE.md` for this repo, several loose ends turned up: orphaned empty files not
wired into any import list, an accidentally-committed `dmesg` dump, no `.gitignore` or formatter,
and an empty `core/security.nix` stub that was clearly staked out for hardening but never filled
in. Separately, Path of Exile 1 has problems on *both* existing sessions (sway and i3), so the plan
is to add a genuinely different, minimal X11 WM just for gaming rather than tune i3/sway further.

Decisions locked in:
- Delete `gravity-drive.nix`/`propulsion.nix` outright (no placeholder purpose, can recreate later).
- SSH `PasswordAuthentication = true` and AdGuard/DNS bound to `0.0.0.0` are **intentional**
  (serves the whole LAN) — do not touch.
- Commit as several logical commits, not one giant one.
- Add a new WM (bspwm) for gaming rather than tuning i3/sway.

Technical details below were verified against the actual pinned `nixpkgs`/`home-manager` source
(not just docs knowledge) — notably: the `xsession.windowManager` conflict is real, and
`nixfmt-tree` (not bare `nixfmt`) is the correct `formatter` output.

## Work streams (separate commits)

### 1. Cleanup — done (`77a4bd6`)
- `git rm --cached log/log.txt` (a `sudo dmesg -w` capture, not real log content) and delete it;
  add root `.gitignore` with `result`, `result-*`, `.direnv/`.
- `git rm constellations/gravity-drive.nix constellations/propulsion.nix` (0 bytes, unimported,
  confirmed dead).
- `git add core/packages.nix` — the existing unstaged `gimpss` → `gimp` typo fix, no further
  changes needed there.
- Leave `crew/terminal/kitty.nix` / `starship.nix` untouched — deliberately deferred per the
  comment in `crew/default.nix`.

### 2. Security hardening (`core/security.nix`) — done (`ce23eec`)
Populate the currently-empty `core/security.nix` and add it to the `imports` list in
`hosts/earth/default.nix` (next to the other `core/*.nix` entries):
- `services.fail2ban.enable = true;` — mitigates brute-force given SSH password auth is
  intentionally kept on.
- `boot.kernel.sysctl` additions not already covered by NixOS defaults or `constellations/comms.nix`:
  `"kernel.yama.ptrace_scope" = 1;` and `"net.ipv4.conf.all.log_martians" = 1;` (verified: neither
  is set anywhere today). Skip `kptr_restrict` (already a NixOS-wide `mkDefault 1`) and
  `fs.protected_hardlinks`/`protected_symlinks` (upstream kernel default since 3.6) — adding them
  would be no-op noise.

In `core/system.nix`, delete the `nixpkgs.config.permittedInsecurePackages = [
"python3.14-youtube-dl-2021.12.17" ];` line — nothing else in the repo references youtube-dl or
yt-dlp, so this looks like a stale allowance. Verify with `dry-build`; if something surfaces as
actually needing it, decide then whether to swap to `yt-dlp` or restore the line with a comment
explaining why.

### 3. Workflow: `.gitignore` + `nix fmt` — done (`27f5a77`)
- Add the `.gitignore` from stream 1.
- Add to `flake.nix` outputs: `formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;`
  — `nixfmt-tree` is nixpkgs's own treefmt wrapper meant specifically for the `formatter` flake
  output (recursively formats a directory tree); bare `nixfmt` (already used as an installed
  package in `core/packages.nix` for editor/CLI use) is single-file/stdin only and isn't the right
  fit here. Not running `nix fmt` across the whole repo in this pass — that's its own follow-up
  given the diff size it'd produce.

### 4. New minimal gaming WM: bspwm — done (`69bfd71`)
System-level, in `core/games.nix` next to the existing `services.xserver.windowManager.i3.enable`
line (same file already mixes WM/session toggles, no new imports needed):
```nix
services.xserver.windowManager.bspwm.enable = true;
```

Home Manager side — **not** via `xsession.windowManager.bspwm.enable`. Confirmed by tracing the
actual HM source: both the i3 module (already enabled in `crew/i3.nix`) and the bspwm module
unconditionally assign the single string option `xsession.windowManager.command`, so enabling both
at once in the same profile throws a hard eval conflict on every switch — not just a runtime
misconfiguration. (This doesn't matter for session *selection* anyway, since greetd/tuigreet execs
each system-level WM session directly and never touches `~/.xsession`/
`xsession.windowManager.command` at all — that indirection is only used by lightdm/sddm/gdm-style
display managers.)

New `crew/bspwm.nix`, added to `imports` in `crew/default.nix` next to `./i3.nix`:
- `xdg.configFile."bspwm/bspwmrc"` generated via `pkgs.writeShellScript` (so it's executable —
  plain `.text` isn't) with minimal config: `bspc config border_width 0`, `bspc config window_gap
  0`, `bspc config borderless_monocle true`, `bspc config gapless_monocle true`, plus a
  `feh --bg-fill` wallpaper line reusing `../assets/wallpaper/wallpaper.jpg` for consistency with
  `crew/i3.nix`/`crew/sway.nix`. Deliberately no compositor and no bar.
- `services.sxhkd.enable = true;` with a small `keybindings` set: terminal (`kitty`), kill window,
  `rofi -show drun` launcher, quit session. Note: the system-level bspwm module already spawns its
  own `sxhkd` process as part of session start — HM's `services.sxhkd` here is purely for
  declaratively generating `~/.config/sxhkd/sxhkdrc` at the path the system module reads from, not
  for starting the daemon itself.

## Follow-up: X11 sessions didn't actually launch under greetd (staged, not committed)

Discovered right after switching: picking `bspwm` at tuigreet bounced straight back to the login
screen (~0–1s). Root cause, confirmed via `journalctl -b 0`: `greetd` (which replaced `sddm` in
this same work session) never starts an Xorg server for X11 sessions — the auto-generated
`none+i3`/`none+bspwm` xsession entries assume X is already running, which was true under `sddm`
but isn't under `greetd`. **This affected `i3` identically**, not just the new `bspwm` session —
i3 likely hadn't actually worked since the greetd migration either.

Fix: new `core/x11-greetd-sessions.nix`, imported in `hosts/earth/default.nix`. For every enabled
X11 window manager it generates an extra `xsessions/<name>.desktop` entry that wraps the WM's
start script with `xinit`, so the session brings up its own private Xorg on `:1` (kept off `:0` to
avoid colliding with halley's Xwayland-compat). The old `none+i3`/`none+bspwm` entries are still
generated too (nixpkgs does this unconditionally) but are non-functional — pick the plain `i3` /
`bspwm` cards at the greeter, not the `none+`-prefixed ones.

`dry-build` and a full `system.build.toplevel` build both succeed; the generated `.desktop` `Exec=`
lines were inspected by hand. **Not yet verified with a real login** — that's the next step.

## Follow-up #2: the xinit fix above still didn't work — root cause + second fix (staged)

Confirmed the fix from above *was* actually switched (running generation 209, built 2026-08-11
20:59, matches the committed-but-unswitched work in this session — several generations 207–209
were built today). `journalctl -b 0` across several greetd login attempts today shows zero trace of
an `Xorg`/`xinit` process ever running — no `Fatal server error`, no coredump, nothing — meaning the
X server was never actually reached, not that it started and crashed.

Root cause: **`Exec=` in a `.desktop` file is executed directly (`execvp`), not through a shell** —
greetd/tuigreet do not do `$VAR` expansion on it (this is per the Desktop Entry spec, confirmed by
inspecting the generated file, not assumed). The old `mkXinitSession` put
`... :1 vt$XDG_VTNR` directly in `Exec=`, so the X server received the *literal, unexpanded* string
`vt$XDG_VTNR` as an argument instead of a real VT number (e.g. `vt1`) — garbage input to the X
server's VT argument, whatever the actual failure mode. Same bug for both `i3` and `bspwm` since
both go through the same `mkXinitSession` function, matching the fact both fail identically.

Compounding this: the default `xserverArgs` bakes in `-logfile /dev/null`, so even if X had started
and hit a fatal error, its own log would've been discarded — nothing to grep for in `journalctl`
either, since X's fatal-error output goes to its logfile, not stdout/stderr in all cases.

Fix (staged, in `core/x11-greetd-sessions.nix`, not yet committed/switched):
- `mkXinitSession` now wraps the whole `xinit ... X ...` invocation in its own
  `pkgs.writeShellScript` (real shebang, real shell), and `Exec=` just points at that one wrapper
  script path. Verified via `nix eval` + reading the built store paths: the generated `.desktop`
  now has `Exec=/nix/store/...-i3-xinit-wrapper` (single token, no inline args), and that wrapper
  script's body still contains the literal `vt$XDG_VTNR` — but now inside a real `#!.../bash`
  script, so it gets properly expanded at run time.
- Also drop `-logfile /dev/null` from the `xserverArgs` used for these sessions (on top of the
  existing `:0`/`-terminate` removal), so a real Xorg log lands at the default `/var/log/Xorg.1.log`
  if this still isn't the whole story.

`dry-build` and a full `toplevel` build both succeed; the generated `i3-xinit-wrapper` /
`bspwm-xinit-wrapper` scripts and the `.desktop` files pointing at them were inspected by hand in
the nix store. **Switched** — `nh os switch ~/nebula-config` run 2026-08-11 (confirmed:
`/run/current-system` -> `/nix/store/i32i2dwsbxdi8ampw8pph02zyw8kmnn1-nixos-system-earth-...`, the
store path built with this fix). A reboot is in progress to test a real login.

### Next steps
- After reboot: log out (or straight from tuigreet after boot), pick plain `i3` (not `none+i3`),
  see if it holds. Same for `bspwm`.
- If it still bounces: check `/var/log/Xorg.1.log` first (should now actually have content) before
  going back to `journalctl` — that's the more direct signal now that logging isn't discarded.
- Open question, not yet confirmed either way: whether `XDG_VTNR` is actually present/correct in
  the environment greetd hands to the session command at all (it's supposed to come from
  `pam_systemd` opening the session) — the wrapper-script fix only solves the "never expanded"
  half of the problem; if `XDG_VTNR` itself is unset or wrong in that environment, `vt$XDG_VTNR`
  would expand to just `vt` (empty) or the wrong number and this may need a different value
  entirely (e.g. drop the explicit `vt` arg and let Xorg auto-pick, or shell out to `fgconsole`).

## Follow-up #3: reboot happened, but the i3/bspwm entries still weren't actually tested

Checked `journalctl -b 0` and `/var/log/Xorg.1.log` after the reboot mentioned above. Findings:

- `/var/log/Xorg.1.log` doesn't exist at all — no X server has been started on `:1` this boot.
- Every `ryudzyn` login this boot (`journalctl -b0 | grep "New session.*ryudzyn"`) came back
  `type 'wayland'`, never `type 'x11'`. So the plain `i3`/`bspwm` xinit cards were never actually
  selected at tuigreet since the reboot — the wrapper-script fix from Follow-up #2 is still
  **unverified**, not confirmed broken.
- The `i3-xinit-wrapper`/`bspwm-xinit-wrapper` derivations and the generated
  `xsessions/i3.desktop` (pointing at the wrapper, in `i3-xsession-xinit`) do exist in the store,
  so the build side of the fix is in place — just not exercised.
- Separately (unrelated to the X11 fix, don't conflate): three of the wayland-session login
  attempts in this same window bounced back in ~1s each, with pipewire logging
  `mod.x11-bell: X11 display (:0) has encountered a fatal I/O error` — that's halley's
  Xwayland-compat on `:0` dying, not the `:1` xinit path. Also noticed `picom` XDG-autostart
  failing under the wayland session (`Backend not specified`) — a pre-existing cosmetic bug,
  autostart isn't conditioned on session/WM type. Neither of these blocks testing the X11 fix, but
  worth separate tickets if they recur.

**Actual next step, unchanged**: at tuigreet, explicitly arrow over to the plain `i3` card (not
`none+i3`, not the default highlighted wayland session) and log in, then re-check
`/var/log/Xorg.1.log` and `journalctl -b 0` for `Xorg`/`xinit`/`i3-xinit-wrapper`. Same for
`bspwm`.

## Follow-up #4: root cause of "picking the wrong session" — duplicate `Name=` in tuigreet's list (fixed, staged)

User-reported: the tuigreet session list shows two entries labeled identically `i3` (and two
labeled `bspwm`), impossible to tell apart, which explains why every login this boot resolved to
`type 'wayland'` instead of `type 'x11'` — the intended `i3`/`bspwm` card was likely never actually
reached, and `--remember` in the tuigreet invocation (`core/desktop.nix`) kept re-selecting the
last-used session on ambiguous input.

Confirmed by inspecting the live session-data store path (`ps aux | grep tuigreet` →
`--sessions .../desktops/share/...`):
- `none+i3.desktop` (nixpkgs-generated, non-functional under greetd) has `Name=i3`.
- our `i3.desktop` (from `mkXinitSession` in `core/x11-greetd-sessions.nix`) also had `Name=i3`.
- Same collision for `bspwm`/`none+bspwm`.

This is nixpkgs's own upstream behavior for the `none+<wm>` entries (`Name=` is just the WM name;
`DesktopNames=none+<wm>` carries the distinguishing info internally, but tuigreet only displays
`Name=`) — not something we generate, so it can't be changed from our side.

Fix (staged, not yet built/switched): `core/x11-greetd-sessions.nix` now sets
`Name=${wm.name} (xinit)` on our generated entries, so the working session shows as `i3 (xinit)` /
`bspwm (xinit)` in tuigreet, distinct from the broken `i3` / `bspwm` (`none+`) ones.
`dry-build` confirms this only rebuilds the expected small set of derivations (the two
`*-xsession-xinit` derivations, `desktops`, and the top-level system closure) — no other errors,
no missing packages found while auditing `core/x11-greetd-sessions.nix`, `crew/i3.nix`,
`crew/bspwm.nix`, `core/games.nix` (`xset`, `bspc`, `sxhkd` all confirmed present on `$PATH` via
`command -v`).

**Next step**: `nh os switch`, then at tuigreet pick `i3 (xinit)` (not the plain `i3` /
`none+i3` card) — that's now the unambiguous way to reach the working session — and re-run the
Follow-up #3 log check.

## Follow-up #5: real root cause found — missing `wait "$waitPID"` (fixed, switched)

The `Name=` fix from Follow-up #4 got built (gen 211) and switched (gen 212), but repeated login
attempts afterward (`sudo systemctl restart greetd.service` + several fast relogins between
22:54–22:58) still showed every `New session … ryudzyn` as `type 'wayland'` in `journalctl -b 0` —
looked like the `i3 (xinit)`/`bspwm (xinit)` card still wasn't being reached. That read on the
evidence was wrong: greetd apparently reports `type 'wayland'` for *any* session it launches,
including our xinit ones, so `journalctl` session-type alone can't distinguish the two paths.

The actual signal came from the temporary per-WM stdout/stderr capture already in
`mkXinitSession` (`exec >>"$HOME/.local/state/${wm.name}-xinit.log" 2>&1`, added in an earlier
pass specifically so this log could be read directly instead of relying on `journalctl`/manual
reporting). Reading `~/.local/state/i3-xinit.log` and `bspwm-xinit.log` directly showed **two full
Xorg startup sequences each**, timestamps matching the 22:28–22:29 and 22:54 login attempts —
i.e. the `i3 (xinit)`/`bspwm (xinit)` cards *were* being reached and Xorg *was* starting cleanly
(full device probing, keyboard/mouse setup, no `(EE) Fatal` anywhere) — then, with zero i3/bspwm
output in between, immediately `xinit: connection to X server lost` → server shutdown. So the
bounce was happening *after* a clean X start, not before.

Root cause, confirmed by reading the actual built `i3-start`/`bspwm-start` scripts in the store
(`nix-store --realise` on the `.drv`s, no switch needed) and cross-checking against the pinned
`nixpkgs` source (`nixos/modules/services/x11/window-managers/i3.nix` /
`display-managers/default.nix`): `services.xserver.windowManager.i3`'s `wm.start` is just
```sh
i3 &
waitPID=$!
```
— nixpkgs expects the *caller* to append `test -n "$waitPID" && wait "$waitPID"` afterward, which
normally happens inside nixpkgs's own generic `xsession` wrapper script
(`display-managers/default.nix:284`, used to build the `none+i3`/`none+bspwm` entries). Our
`mkXinitSession` never used that wrapper — it fed `wm.start` straight into
`pkgs.writeShellScript`, so the client script backgrounds the WM and then immediately reaches EOF
with nothing waiting on it. From `xinit`'s point of view the client process exited right away, so
it tore down the just-started X server — a correctly-functioning instant self-destruct, not a
config or timing bug. Same root cause for both `i3` and `bspwm` since both upstream modules use
the identical `& waitPID=$!` pattern.

Fix (`core/x11-greetd-sessions.nix`): `mkXinitSession` now appends
`test -n "$waitPID" && wait "$waitPID"` to `wm.start` before wrapping it in
`pkgs.writeShellScript`, mirroring exactly what nixpkgs's own `xsession` script does. Verified by
building just the changed derivations (`nix-store --realise` on the `i3-start.drv`/`bspwm-start.drv`,
no full switch needed to check) and reading the output — both now end with the `wait` line.
`dry-build` shows only the expected small rebuild (the two `*-start`/`*-xinit-wrapper`/
`*-xsession-xinit` derivations, `desktops`, and the top-level closure).

**Switched.** `nh os switch ~/nebula-config` run 2026-08-11, confirmed via
`/nix/var/nix/profiles/system` symlink.

### Next steps
- At tuigreet, pick `i3 (xinit)`, confirm the session actually holds this time (not an instant
  bounce) — check `~/.local/state/i3-xinit.log` for a fresh run that does *not* end in
  `connection to X server lost` right after startup. Same for `bspwm (xinit)`.
- Once confirmed working: remove the temporary `exec >>"$HOME/.local/state/${wm.name}-xinit.log"
  2>&1` diagnostic redirect from `mkXinitSession` — it was only for tracking this bug down.
- Then resume the original verification checklist below (sxhkd keybindings, PoE1 launch check).

## Follow-up #6: new failure mode after the #5 fix — "Another window manager is already running" (diagnostic added, not yet fixed)

The `wait "$waitPID"` fix from Follow-up #5 was switched and the user tested real logins into
`i3 (xinit)` and `bspwm (xinit)` at tuigreet. Both still bounce back to the login screen — but
reading `~/.local/state/i3-xinit.log` / `bspwm-xinit.log` directly (all read-only investigation,
cross-checked against `journalctl -b0`) shows this is a **new, different failure mode**, not a
recurrence of #5:

- Xorg starts cleanly every time — full device probing, no `(EE) Fatal` anywhere.
- The client script is reached (confirmed by reading the actual built `i3-start`/`bspwm-start`
  scripts from the store) and does invoke the WM.
- The WM itself immediately reports the display already has a window manager:
  - i3: `11.08.26 23:16:08 - ERROR: Another window manager is already running (WM_Sn is owned)`
  - bspwm: `Another window manager is already running.`
- Right after, `xinit: connection to X server lost` — the WM exits on its own conflict check,
  `wait "$waitPID"` correctly returns, and xinit tears the (otherwise healthy) X server back
  down. This is the actual bounce being observed.

Ruled out via `journalctl -b0` / `ps aux` / `/tmp/.X11-unix/` at the time of investigation:
- No overlapping greetd sessions — each greeter → ryudzyn → greeter cycle is fully sequential,
  confirmed session-by-session in the journal.
- No stale Xorg/i3/bspwm process or leftover `:1` socket sitting around between attempts.
- No system-wide compositor/WM/display-manager duplication in the repo (`core/games.nix`,
  `crew/i3.nix`, `crew/bspwm.nix`, `crew/default.nix` all checked) that would explain a second
  client grabbing `WM_Sn` before i3/bspwm gets there.

One confirmed-but-unexplained anomaly, noted for later: `systemctl --user list-units` shows
`graphical-session.target` and `sway-session.target` still marked `active`, left over from an
earlier, already-logged-out halley/sway session in the same boot — the systemd `--user` manager
persists across sequential greetd logins for the same UID and apparently isn't fully reset between
them. Nothing currently active in that leftover state is itself an X11 window manager, so it
doesn't explain `WM_Sn` ownership directly, but it's the only confirmed stale state found.

Log archaeology narrows this to "some client claims `WM_Sn` on `:1` before/instead of i3/bspwm
successfully doing so," but doesn't identify *what*. Rather than guess again (the #1→#2→#3→#4→#5
chain shows guessing without measuring first tends to be wrong or incomplete), added a targeted
diagnostic instead:

First diagnostic pass (built, switched, tested): `core/x11-greetd-sessions.nix`'s `mkXinitSession`
ran a single `xlsclients -display :1` right before the WM starts.

**Gotcha hit along the way**: the first test after `nh os switch` showed *zero* diagnostic output —
turned out `greetd.service` has `X-RestartIfChanged=false` (confirmed by reading the resolved unit
file), so NixOS deliberately never restarts the live greetd process on switch (to avoid killing an
active graphical session). The running `greetd` (PID 1657) was still serving the pre-diagnostic
generation's session list a full switch-cycle later — `nh os switch` alone does not make a
greetd-level change live. Fixed for this round via `sudo systemctl restart greetd`; worth
remembering for every future greetd-session-list change: **switch alone is not enough, greetd needs
an explicit restart (or a reboot) to pick it up.**

With that resolved, the diagnostic actually ran: **`xlsclients -display :1` came back completely
empty** right before i3/bspwm start — no client connected to the display at that point. This rules
out a persistent second X11 client. The conflict must be arising in the narrow window *between* that
check and the WM's own connection — inside `wm.start` itself, which runs (nixpkgs-generated, not
ours) `systemctl --user import-environment DISPLAY ...` and
`dbus-update-activation-environment --systemd --all` immediately before launching i3/bspwm. That's
the first moment `DISPLAY=:1` is published into the systemd `--user` manager / D-Bus activation
environment — and per Follow-up #6's still-unexplained anomaly, that manager already has a stale
`graphical-session.target`/`sway-session.target` marked active from an earlier, already-logged-out
sway session in the same boot. Leading suspicion: something bus-activates or reacts to the freshly
published `DISPLAY` and briefly touches `:1`.

Second diagnostic pass (built, switched, tested — but had its own bug): `clientScript` backgrounds a
tight `xlsclients -display :1` poll (every 20ms) that's meant to run *concurrently* with `wm.start`,
to catch even a connect-then-immediately-disconnect client that a single before/after check would
miss.

**Bug in this diagnostic itself, found from the log**: `kill "$watchPID"` was placed immediately
after `wm.start` in the script, but `wm.start` only backgrounds the WM and captures `$waitPID` — it
returns control almost instantly, long before the WM has actually connected/failed. The real wait
happens in `test -n "$waitPID" && wait "$waitPID"` a few lines later. So the poll loop was being
killed essentially immediately (confirmed in the logs: the `=== watching ===` / `=== end ===` marker
lines landed on directly adjacent log lines for both i3 and bspwm — the loop never got a chance to
run). Fixed by moving `kill "$watchPID"` to *after* the `wait "$waitPID"` line, and bumped the poll
count from 100 to 150 iterations (3s ceiling) so it comfortably outlasts the WM's lifetime either
way.

With the timing bug fixed, the poll ran for real this time (confirmed: dozens of interleaved Xorg
log lines between the watch markers, `already running` landing *inside* the window, not adjacent to
it) — and **still zero `xlsclients poll` hits, for either WM, across the whole failure window**. By
ICCCM, a selection's ownership is cleared by the X server the moment the owning client disconnects,
so a "stuck" `WM_Sn` with no live owner shouldn't be possible under normal X server behavior. Three
independent checks now agree (single check, first poll attempt, and this correctly-timed poll) — the
"a real second X11 client is holding `:1`" theory is essentially dead.

That reframes the question: maybe the problem was never about `:1` at all. `xlsclients -display :1`
in the diagnostic was *hardcoded* to `:1` — if i3/bspwm's actual `$DISPLAY` at connect time were
something else (e.g. `:0`, where halley's Xwayland-compat genuinely does have manager-like state),
our diagnostic would have been checking the wrong display the whole time and would show exactly this
"nothing here" result regardless of what's really happening.

Third diagnostic pass (built, switched, tested) confirmed the hunch: `core/x11-greetd-sessions.nix`
printed `$DISPLAY`/`$XAUTHORITY` at the top of the client script, and the result was
**`DISPLAY=:0 XAUTHORITY=`** — not `:1`. **Root cause found.** i3/bspwm were never talking to the
freshly-started private Xorg on `:1` at all; they were connecting to `:0`, where halley's
Xwayland-compat genuinely does have manager-like state, so "another window manager is already
running" was 100% accurate — just about the wrong display. This also fully explains three rounds of
`xlsclients` on `:1`/`$DISPLAY` coming back empty: the diagnostic itself was checking `:1` (correctly
empty) while the WM connected to `:0` (never checked directly, until this pass printed the actual
value).

Why `:0` leaked in: `xinit` does not unconditionally overwrite an already-set `$DISPLAY` in the
inherited environment with the display it just started the server on — and `:0` was already present,
almost certainly inherited from an earlier halley/sway login in the same boot (ties back to the
`sway-session.target`/`graphical-session.target` leftover-state anomaly noted earlier — the same
underlying systemd `--user` manager persists across greetd session boundaries and evidently the
inherited process environment does too, at least for `DISPLAY`).

**Fix applied and confirmed working.** `mkXinitSession`'s `clientScript` now does `export DISPLAY=:1`
as its very first line, before anything else runs (including `wm.start` and its
`systemctl --user import-environment`/`dbus-update-activation-environment` calls) — so the client is
guaranteed to use the display our own Xorg is actually running on, regardless of whatever leaked in
from the inherited environment. Switched, `sudo systemctl restart greetd`, tested at tuigreet: both
`i3 (xinit)` and `bspwm (xinit)` now hold (no more bounce). PoE1 confirmed launching and working
under `bspwm (xinit)`.

All temporary diagnostic scaffolding from Follow-ups #5/#6 removed post-confirmation: the
`xlsclients` polling, the `echo "=== DISPLAY=..."` line, and the per-WM
`exec >>"$HOME/.local/state/${wm.name}-xinit.log" 2>&1` stdout/stderr capture in the wrapper are all
gone from `core/x11-greetd-sessions.nix` — only the permanent fix (`export DISPLAY=:1`) and its
explanatory comment remain. `dry-build` re-confirmed clean after the cleanup.

### Next steps
- **PoE1 still needs the same check under plain `i3 (xinit)`** — only `bspwm (xinit)` has been
  confirmed with a real game launch so far.
- Confirm sxhkd keybindings on `bspwm (xinit)` (terminal, rofi, kill, quit) — not yet explicitly
  verified, though PoE1 working suggests the session is generally healthy.
- The `sway-session.target`/`graphical-session.target` leftover-state anomaly (systemd `--user`
  manager not resetting between greetd sessions) is still unexplained, but no longer blocking —
  parked as a known oddity unless it causes a future problem.

## Follow-up #7: new bug — `bspwm (xinit)` only renders if sway is already running on another VT (undiagnosed, diagnostics staged)

2026-08-12. After Follow-up #6 was confirmed fully working (including a real PoE1 launch), a new,
different failure surfaced on a later test: picking `bspwm (xinit)` at tuigreet on `tty1` produces a
**black screen** — no bounce back to the greeter this time (unlike #1–#6), Xorg reportedly starts
without a `Fatal` in its log per the same diagnostics as #6, but nothing is ever displayed.

User-observed workaround/clue: `bspwm (xinit)` **does** render correctly when a sway (halley)
session is already logged in and active on `tty2` (`ctrl+alt+f2`) at the same time. Without that,
`tty1` stays black. Not yet confirmed for plain `i3 (xinit)` — only tested with bspwm so far.

Leading theory (unconfirmed): this isn't a repeat of #6's `DISPLAY`/`WM_Sn` bug (Xorg itself starts
clean either way) — more likely an AMD GPU (`amdgpu`) modeset/connector issue, where the monitor
output only gets a real KMS mode set once *some* DRM client (sway, in this case) has successfully
done a modeset since boot; a fresh Xorg started cold (nothing else has touched the GPU yet) may be
silently failing to pick/apply a mode even though it logs no fatal error. Needs actual log evidence
before treating this as confirmed — this is a hypothesis, not yet root-caused the way #1–#6 were.

**Constraint on how this gets diagnosed**: the Claude Code shell session for this work runs *inside*
the sway session on `tty2` (confirmed via `who`/`ps` — the shell's pty is a child of that login). So
live monitoring (`tail -f` / `journalctl -f`) from this session cannot cover the "sway NOT running on
F2" test case — stopping sway on F2 to test that case would kill the very shell doing the watching.
Live monitoring only works for variants where F2/sway stays up throughout.

Plan instead: **post-factum log analysis**, comparing a "black screen" run against a prior working
run, using sources that persist on disk independent of any live session:
- `journalctl -k -b0` (kernel/`amdgpu` messages — persists in the systemd journal regardless of
  session state).
- `/var/log/Xorg.1.log` (already made non-discarded by the Follow-up #2 fix; check for the chosen
  mode/connector lines, not just fatal errors).
- `/sys/class/drm/*/status` (connected/disconnected per output) — only useful if captured live
  during the black-screen state itself (doesn't persist after the fact), so this one specifically
  needs the user to check it manually in the moment, or needs a diagnostic script added to
  `mkXinitSession` the same way Follow-ups #5/#6 did (temporary, removed once root-caused).

**Test procedure (user-run, since it requires killing the sway session this Claude Code shell lives
in)**:
1. Log out of sway on `tty2` (`ctrl+alt+f2`) — this will also kill this Claude Code session's shell;
   expect the conversation to stall until access returns.
2. On `tty1`, at tuigreet, pick `bspwm (xinit)` and observe (should reproduce the black screen per
   the report above).
3. Restore access — log sway back in on `tty2` (or however this session's shell gets a working pty
   again) so the conversation can resume.
4. Once back: re-read `journalctl -k -b0` and `/var/log/Xorg.1.log`, diff against the equivalent
   window from a prior *working* run (the confirmed-good bspwm run from Follow-up #6, 2026-08-11
   night), looking specifically at `amdgpu`/connector/mode lines, not just fatal-error absence.

**Not yet done**: the actual test run (step 1–3 above, blocked on the user doing the VT switch) and
the log diff (step 4). No code changes proposed yet — root cause unknown, so no fix to write.

### Next steps
- User runs the test procedure above (sway off on F2 → bspwm on F1 → confirm black screen with sway
  gone → bring sway back to restore this session).
- Once access returns: pull `journalctl -k -b0` and `/var/log/Xorg.1.log` from that window, compare
  against the last known-good bspwm run, focus on `amdgpu` connector/modeset messages.
- If disk logs aren't conclusive, next escalation is a temporary `mkXinitSession` diagnostic (same
  pattern as #5/#6) that dumps `/sys/class/drm/*/status` and `xrandr --verbose` output from inside
  the client script itself, since that state doesn't survive being read after the fact from outside.
- Confirm whether plain `i3 (xinit)` has the same sway-dependency or if it's bspwm-specific.

### Round 2 (2026-08-12, post-factum log analysis): new symptom found — not just black, also no input

The test above actually happened today, discovered via log archaeology rather than a live report
(correcting the "not yet done" status above). **Important correction to the note about where Xorg
logs**: with `-logfile /dev/null` already dropped (Follow-up #2), Xorg — run unprivileged via
`xinit`, not as root — writes to `~/.local/share/xorg/Xorg.1.log` (+ `.old` for the previous run),
**not** `/var/log/Xorg.1.log`. That path never existed and was the wrong place to look.

Reconstructed from `journalctl -b0` (session/PID kill lists are unusually informative here — every
`session-N.scope: Killing process PID (name)` line effectively enumerates what was running in each
session) plus the two on-disk Xorg logs:

- **15:08–15:21 (session-9, 13 min)**: `bspwm (xinit)` ran concurrently with a manual `login`+`sway`
  session the user had started by hand on tty2 (not through greetd — a plain text-console login that
  happened to reach "sway compositor session"). Confirms the known workaround (bspwm renders fine
  when something has already touched the GPU via another session). Ended when **both** sessions —
  bspwm/xinit *and* the sway one — were killed together in the same instant (session-7 and session-9
  both torn down at 15:21:28, sway's `sxhkd`/`bspwm`/`polybar`/kitty and even a `loginctl` process
  mid-command in the sway session all SIGTERM'd at once) — looks like the user ran something like
  `loginctl terminate-user`/restarted greetd to wipe everything and start a clean test.
- **15:21:36–15:25:37 (session-12, 4 min)**: a **new** X11 session started 8 seconds later, this
  time with nothing else running (confirmed: this is the actual "sway not present" case). User
  report: **sxhkd/bspwm keybindings didn't respond at all** (not just "looked black" — no input got
  through either), so they switched to tty2, logged into a bare TTY (no sway) to keep working here,
  and while that was happening, **bspwm on tty1 exited on its own, without any keypress** — matches
  the journal exactly: `session-12.scope: Deactivated successfully` (a clean self-exit under
  systemd's classification), not an externally-`Killed` teardown like session-9's.
- **Xorg log comparison** (`Xorg.1.log.old` = session-9/sway-present run, `Xorg.1.log` = session-12/
  alone run): byte-for-byte equivalent `modeset(0)` behavior — both detect `DP-2 connected`, read the
  same EDID, and pick `Output DP-2 using initial mode 2560x1440 +0+0`. No `(EE)` lines in either
  besides the pre-existing, unrelated `fbdev` driver load failure (present in both, harmless — an
  unused fallback driver). **This weakens the "cold AMD modeset" theory** — Xorg itself believes it
  configured the display identically both times — though it doesn't rule out a KMS/plane-level issue
  Xorg wouldn't itself detect or log.
- **No libinput/logind/seat/device-grab errors anywhere in `journalctl` for the 15:21:36–15:25:37
  window.** Whatever blocked input isn't visible at the systemd/logind level — if it's real, it's
  happening inside X/sxhkd, below journal visibility.
- The `exec >>"$HOME/.local/state/${wm.name}-xinit.log" 2>&1` diagnostic added this round (staged,
  `core/x11-greetd-sessions.nix`) caught nothing — both log files are 0 bytes. Inconclusive rather
  than clean: i3/bspwm/sxhkd don't print anything on stdout during normal successful operation
  either, so an empty file doesn't distinguish "silently broken" from "silently fine." **This
  diagnostic approach is a dead end and should be dropped rather than iterated on.**

New working theory, not yet confirmed: **a logind device-handoff race**, not a GPU-coldness issue.
Session-12 started only ~8s after sessions 7 *and* 9 were killed together — plausible that
`systemd-logind` hadn't finished releasing the evdev/`/dev/input/event*` file descriptors from the
just-killed sessions before the new session's `sxhkd`/bspwm tried to grab them, leaving the new
session with no working input for its whole (silent) lifetime, ending in whatever caused the
self-exit. This would explain "no combos work" independent of the display/black-screen question, and
is consistent with both the missing libinput errors (the grab may simply silently fail/no-op rather
than error) and the lack of any Xorg-side signal (Xorg's own input handling is separate from
sxhkd/bspwm grabbing global hotkeys).

### Next steps (updated)
- Re-test with a deliberate pause: at tuigreet, wait ~30s+ *before* picking `bspwm (xinit)` again
  (rather than testing immediately after killing a prior session), to separate the "race on
  session teardown" theory from a genuine cold-GPU/modeset issue. If input works fine after a pause,
  that all but confirms the race theory.
- Stop trying to capture WM stdout/stderr (dead end, see above); instead diagnose **input** directly
  — e.g. check whether `sxhkd`/bspwm are even still alive and whether they hold open fds on
  `/dev/input/event*` at the moment of failure (`ls -l /proc/<pid>/fd` from the tty2 vantage point,
  or `fuser /dev/input/event*`), rather than assuming this is purely a display problem.
- The already-planned `/sys/class/drm/*/status` + `xrandr --verbose` dump from inside `clientScript`
  is still worth adding if the pause-retest above doesn't resolve it — but treat this as an input
  problem first, display problem second, given this round's evidence.
- Confirm whether plain `i3 (xinit)` has the same behavior — still untested, all rounds so far used
  bspwm only.

## Critical files
- `core/security.nix`, `hosts/earth/default.nix` — hardening module + wiring
- `core/system.nix` — drop insecure-package allowance
- `flake.nix` — formatter output
- `core/games.nix`, `crew/default.nix`, `crew/bspwm.nix` — bspwm session
- `core/x11-greetd-sessions.nix` — xinit wrapper for i3/bspwm under greetd (follow-up fix)
- `log/log.txt` (deleted), `constellations/gravity-drive.nix` / `propulsion.nix` (deleted), `.gitignore`

## Verification
- After each stream: `nixos-rebuild dry-build --flake .#earth` must succeed. (Done for all
  streams, including the follow-up fix.)
- `nix fmt --help` (or `nix fmt -- --help`) after wiring the formatter, just to confirm it resolves
  and runs without invoking it destructively across the tree.
- **Next**: `nh os switch ~/nebula-config`, log out, pick the plain `bspwm` session (not
  `none+bspwm`) at the tuigreet prompt, confirm sxhkd keybindings work (terminal opens, rofi
  launches) with no bar/compositor running, then launch PoE1 from there to check whether the
  issues seen under sway/i3 persist. Repeat the same check for the plain `i3` entry.
- If a session still bounces back to login: capture `journalctl -b 0 --since <attempt time>`
  immediately after and look for `Xorg`/`xserver-wrapper` output — this time an actual X server
  process should show up in the log; if it doesn't, or it errors, that log points at the next fix.
