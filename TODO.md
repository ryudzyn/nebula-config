# Nebula OS: cleanup, hardening, workflow, gaming WM

## Status: all known X11-session bugs fixed (Follow-ups #1–#9)

All four original work streams below are implemented and committed
(`77a4bd6`..`bfa9247`). X11 sessions (`i3`, `bspwm`) initially never launched
under the new `greetd` setup — root-caused across Follow-ups #1–#6 (missing
`wait "$waitPID"`, then a `DISPLAY=:0` leak from inherited session
environment instead of the intended `:1`) and fixed (committed `3ad8397`);
both `i3 (xinit)` and `bspwm (xinit)` held at tuigreet, and PoE1 confirmed
launching under `bspwm (xinit)`. A **new, separate** black-screen regression
then surfaced (Follow-up #7): `bspwm (xinit)` only rendered when a sway
session was already active on another VT. Root-caused and fixed (committed):
two compounding bugs in `core/x11-greetd-sessions.nix`'s use of `xinit`,
fixed by dropping `xinit` entirely in favor of starting Xorg directly and
polling for its socket. A third leaked-env bug (Follow-up #9, `greetd`
leaking `XDG_SESSION_TYPE=wayland` into these X11 sessions, breaking any
app — VSCodium, `discord-canary`, see Follow-up #8's correction note — that
reads that variable directly for Ozone backend selection) has also been
root-caused and fixed, **confirmed working 2026-08-12** across a real reboot:
zen, Steam, PoE1, Minecraft, VSCodium, and `discord-canary` (including screen
share) all launch and render correctly under `bspwm (xinit)` with no sway
session active. Follow-up #9's fix is staged, not yet committed.

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

### Round 3: full-process live monitoring — bspwm/sxhkd never actually start when alone

The "logind device-handoff race" theory from Round 2 was never confirmed or denied directly —
instead, live monitoring (a background script polling `ps -eo pid,ppid,comm,args` every second,
diffing against the previous second) was run *during* a live re-test, rather than reconstructing
after the fact from journalctl. Across two full "alone" test sessions (~4 min each — this round is
where the suspiciously exact **~240s session duration** first got noticed, consistent across every
subsequent "alone" attempt too), `bspwm`/`sxhkd` **never appeared as processes at all**, under any
name, in either run — only `xinit` and `X` ever showed up as running. This ruled out a "silent
input-grab failure" (Round 2's theory) in favor of something preventing the WM from ever launching in
the first place.

### Round 4: `xinit` itself never forks the client

Live-polled `/proc/<xinit_pid>/status`+`wchan` every second during a third "alone" test. Found: after
an initial one-second `sigsuspend` (the normal "wait for X ready" signal wait, which returns quickly
as expected), `xinit` drops into a **repeating `hrtimer_nanosleep` loop for the full ~240s**, the
entire time with exactly one child (the X server) and no second child ever appearing — confirming
directly (not inferred) that `xinit` never forks the client script at all.

Added a redirect capturing `xinit`'s own stdout/stderr (previously only the client script's output
was captured — `xinit`'s own was going nowhere visible). This immediately surfaced the real message:
```
waiting for X server to begin accepting connections
xinit: giving up
xinit: unable to connect to X server: Connection refused
```
So `xinit` really is doing exactly what it looks like: polling `XOpenDisplay` for ~240s and getting
ECONNREFUSED every time, despite Xorg's own log showing a complete, clean startup (full device
enumeration finishes in under 1 second by Xorg's own internal clock, then total silence in the log
until teardown — Xorg believes itself ready and just sits there).

A `LISTEN_FDS`/`LISTEN_PID` leak (systemd socket-activation env vars fooling Xorg into not creating
its normal socket) was checked and ruled out — both were confirmed empty in the actual environment.

### Round 5: proved the server was fine all along, replaced `xinit` outright

Instead of guessing further, ran a live connectivity probe from the tty2 vantage point: poll for
`/tmp/.X11-unix/X1`, and the moment it exists, try `DISPLAY=:1 xset q` directly. Result: **81/81
successful connections**, zero failures, for the entire lifetime of the socket — while `xinit`, the
process that started this exact server, insisted the whole time that the connection was refused. This
conclusively proved the server itself was never the problem; something specific to `xinit`'s own
internal readiness-check implementation was broken, and static analysis of the binary (`grep -a` for
strings, since `strings` itself isn't installed here) didn't turn up anything more specific without a
disassembler — not worth pursuing further.

**Fix**: dropped `xinit` from `core/x11-greetd-sessions.nix` entirely. `clientScript` now starts Xorg
directly in the background itself, polls for `/tmp/.X11-unix/X1` to appear (the exact method just
proven reliable), and only then proceeds to `wm.start`; a `trap ... EXIT` kills the X server when the
WM exits, replacing `xinit`'s teardown role.

This surfaced one immediate regression: dropping `xinit` also silently dropped `-keeptty`, which
`xinit` always adds to the server command line itself. Without it, Xorg logged `systemd-logind
integration requires -keeptty ... disabling logind integration` followed by a fatal `xf86OpenConsole:
Cannot open virtual console 1 (Permission denied)` — without `-keeptty`, Xorg tries to take the VT via
direct ioctls instead of through the logind session, which an unprivileged user can't do. Added
`-keeptty` explicitly to the `X` invocation and this resolved cleanly.

**Confirmed working 2026-08-12** by the user testing real applications (not just "session doesn't
bounce"): zen browser, Steam, Path of Exile 1, and Minecraft all launch and render correctly under
`bspwm (xinit)` with no sway session active anywhere — the original Follow-up #7 symptom is gone.
Also tested `i3 (xinit)` this round (previously **never** actually verified end-to-end in any prior
Follow-up despite being assumed to share the same code path) — also confirmed working.

All temporary trace-file diagnostics (`exec >>`/`echo` scaffolding accumulated across rounds 3–5) were
removed from `core/x11-greetd-sessions.nix` once the fix was confirmed; only the permanent fix
(no-`xinit` client script + explicit `-keeptty`) and a condensed explanatory comment remain.
**Staged, not yet committed** — `dry-build` clean, switched and tested live during this session, but
per this repo's usual workflow the actual `git commit` is left for the user to do (or ask for)
separately.

## Follow-up #8: `discord-canary` never opens a window at all — CORRECTION: actually fixed by Follow-up #9, not a separate bug

**Update**: after the Follow-up #9 fix (`export XDG_SESSION_TYPE=x11`) was switched, the user
re-tested `discord-canary` from scratch (post-reboot) — it now launches, logs in, and screen share
works too. So the investigation below, while technically accurate about *what* was observed (a real
Mojo/network-service IPC timeout, confirmed via `strace`), drew the wrong conclusion about *why*: this
was almost certainly the **same** `XDG_SESSION_TYPE=wayland` leak as Follow-up #9, not an independent
upstream Electron/canary-channel bug. Electron's network-service/GPU-process bootstrap probably
diverges or gets confused when `XDG_SESSION_TYPE` says `wayland` while the process is actually
connected over X11 `DISPLAY`, producing a Mojo handshake timeout rather than VSCodium's cleaner
"failed to connect to Wayland display" — different failure mode, plausibly the same root cause.
**The "switch to stable `discord`" recommendation below is retracted** — no package change needed.
Left the original investigation notes below for the record (the `strace`/ruled-out-causes work was
real and might be useful context if a *genuinely* different Discord issue shows up later), but treat
the "conclusion" and "recommendation" sections as superseded by this update.

---

2026-08-12, surfaced during the same testing pass that confirmed Follow-up #7 fixed: zen, Steam,
PoE1, and Minecraft all work fine under `bspwm (xinit)`, but Discord specifically "doesn't launch at
all" (user's words) — no window ever appears.

Reproduced directly from a shell (not through bspwm/sxhkd) via `DISPLAY=:1 discordcanary`, which made
it possible to inspect live rather than guess from outside:

- The process tree comes up looking healthy — main process, 2–3 zygotes, `chrome_crashpad_handler`,
  a `gpu-process` — but **no `--type=renderer` process ever appears**, and `bspc query -N` /
  `xlsclients` confirm no real UI window ever gets created (only a tiny 10x10 IPC "leader" window
  shows up in some runs).
- The `--type=utility --utility-sub-type=network.mojom.NetworkService` child process reliably becomes
  a zombie (`<defunct>`) roughly 15s after launch, every single time, regardless of any of the
  variables tried below.
- `strace -f` on the whole tree nailed this precisely: the network-service process does one
  `socketpair()` call to set up its Mojo bootstrap channel, then goes **completely silent** (no
  further syscalls in the traced set) for **exactly ~15.0s**, then exits with status 0 — a clean,
  voluntary exit, not a crash. This matches Chromium's own internal message, also present in the
  regular (non-strace) log: `Terminating current process after 15 seconds with no connection`
  (`content/child/child_thread_impl.cc:903`) — a real Chromium watchdog for "my Mojo bootstrap
  handshake never completed." The main browser process's own IPC-related syscalls (per the same
  filtered trace) also go quiet around the same time, though this wasn't traced broadly enough to
  say for certain whether it's genuinely stuck vs. just busy elsewhere.
- `coredumpctl list` additionally shows the **main** Discord process (not the network service)
  SIGSEGV-crashing outright in several past sessions across multiple days (most recently today,
  16:58) — a second, likely related but distinct symptom. No usable stack trace (stripped binary, no
  `strings`/`gdb` on this system to go further).

**Ruled out, each independently verified, none of them the cause:**
- `programs.mangohud.enableSessionWide = true` (`core/games.nix`) — Discord's log does show a MangoHud
  warning (`Could not find cpu temp sensor location`, confirming MangoHud does inject into Discord's
  GPU process), but `MANGOHUD=0 discordcanary` reproduces the exact same 15s-zombie-then-nothing
  pattern. Not the cause of the "no window" symptom (may still be a contributing factor to the
  separate SIGSEGV crashes — not tested in isolation).
- Chromium sandbox / setuid helper: `chrome-sandbox` inside the package is *not* setuid
  (`-r-xr-xr-x`, no `s` bit), but unprivileged user namespaces are confirmed available and working on
  this kernel (`unshare --user --pid` succeeds, `max_user_namespaces=63618`) — this is the normal
  nixpkgs Electron-sandboxing setup and not the issue. `--no-sandbox` was tried explicitly too, same
  result.
- DNS/network: `getent hosts discord.com` and `curl -sI https://discord.com` both work instantly from
  the same shell/session.
- `/dev/shm`: healthy (7.8G tmpfs, plenty free, normal perms) — and Chromium's own `u1000-Shm_*`
  shared-memory files from earlier runs are present, proving shared-memory allocation itself works
  fine.
- OpenASAR (a common culprit for `discord-canary` + NixOS "stuck at installing update" reports —
  see nixpkgs issue #515106): checked directly, `grep -a -c openasar` on both `app.asar` and
  `core.asar` inside the package returns 0 — this build is **not** patched with OpenASAR, so that
  well-known bug class doesn't apply here. `core/packages.nix` just references plain `discord-canary`
  with no override.
- `--disable-features=NetworkService` (forces networking in-process instead of a separate Mojo
  service, a common workaround for exactly this class of Electron bug): tried, same zombie-after-15s
  pattern — either the flag isn't being honored by this Electron build, or it's not actually the
  cause.
- kernel LSM stack (`lsm=landlock,yama,bpf` on the kernel command line, `kernel.yama.ptrace_scope = 1`
  from our own `core/security.nix`): no seccomp/Landlock denials found in `journalctl -k` /
  `dmesg` for the relevant time windows, so no direct evidence implicating either.

**Conclusion**: this looks like a genuine upstream Electron/Chromium Mojo-IPC-bootstrap bug specific
to this exact `discord-canary` build (1.0.1398, an explicitly unstable/nightly channel by design),
not something caused by anything in this repo's config — every plausible NixOS/WM-side lever
(mangohud, sandboxing, DNS, shared memory, OpenASAR, network-service feature flag) was pulled and
none of them changed the outcome. Going deeper would need actual Chromium debug symbols or the
upstream issue tracker, which is past the point of reasonable return here.

### Recommendation (not yet applied)
Swap `discord-canary` for the stable `discord` package in `core/packages.nix`. Canary is Discord's
nightly/beta channel and is far more likely to carry exactly this kind of fresh Electron-version
regression; the stable channel is a much better bet for actually working, and is the standard
day-to-day client anyway (canary is normally opted into for testing upcoming features, not as a
daily driver). Not applied automatically since it's a product/workflow choice (losing whatever
canary-only features prompted using it in the first place), not a pure bug fix — left for the user to
decide.

## Follow-up #9: VSCodium didn't launch under `bspwm (xinit)` (root-caused and fixed, confirmed)

2026-08-12, reported by the user with their own correct hunch: "maybe it's because it's somehow tied
to Wayland?" — exactly right.

Root cause: `greetd`/`pam_systemd` leaks `XDG_SESSION_TYPE=wayland` into this private X11 session's
environment, confirmed by reading `/proc/<bspwm-start-pid>/environ` directly on the live session —
same *class* of bug as Follow-up #6's `DISPLAY=:0` leak (greetd mislabels/leaks session metadata into
these xinit-less X11 sessions), just a different variable this time. `NIXOS_OZONE_WL=1` is also
present (a normal global session variable, harmless on its own), but `WAYLAND_DISPLAY` is correctly
*unset* — so VSCodium's own wrapper script (`${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform...}}}`)
wouldn't add Wayland flags by that logic alone. The actual break is one level deeper: Electron/Chromium
itself reads `XDG_SESSION_TYPE` directly to auto-select its Ozone backend, independent of the
wrapper's own flag construction — sees `wayland`, tries to connect, and since no Wayland compositor is
listening on this X11-only session, fails outright:
```
Failed to connect to Wayland display: Connection refused (111)
Failed to initialize Wayland platform
The platform failed to initialize.  Exiting.
```
No window ever appears — process exits almost immediately.

Confirmed via a clean A/B test (`codium` launched twice, once with the leaked env reproduced exactly,
once with `XDG_SESSION_TYPE=x11` forced): the leaked-env run hit the error above every time; the
forced-x11 run opened a normal window (`window#validateWindowState` logged the correct real display
geometry, 2560x1440).

**Fix** (staged, `core/x11-greetd-sessions.nix`): added `export XDG_SESSION_TYPE=x11` to
`clientScript`, right next to the existing `export DISPLAY=:1` from Follow-up #6 — same pattern,
same root cause category (greetd-leaked session metadata), same fix shape (force the correct value
explicitly rather than trusting what's inherited). `dry-build` clean.

**Confirmed working.** Switched, greetd restarted, user rebooted and re-tested from a clean boot:
VSCodium opens normally. As a bonus, this same fix also resolved Follow-up #8's `discord-canary`
issue — see the correction note at the top of that section.

Worth keeping in mind for any *future* app that mysteriously "doesn't launch" under these xinit-less
sessions: check `/proc/<pid>/environ` for the actual process first, rather than guessing — this is now
the second confirmed case (after `DISPLAY`) of greetd leaking session-type metadata into these
sessions, and it's plausible other `XDG_SESSION_*`/`WAYLAND_*` variables could cause similar
toolkit-specific breakage for apps that check them directly.

## Follow-up #10: bspwm keybinding parity with sway (committed `f77c916`, live-confirmed)

2026-08-12. With `bspwm (xinit)` confirmed fully working (Follow-up #7), `crew/bspwm.nix` was
missing several bindings that `crew/sway.nix` already has, ported over with X11-native
equivalents where the sway originals are Wayland-only:
- Keyboard layout: `setxkbmap -layout us,ua,de -option grp:alt_shift_toggle` in `bspwmrc`,
  X11 equivalent of sway's `input.xkb_layout`/`xkb_options`.
- Volume/brightness (`XF86Audio*`/`XF86MonBrightness*`): identical `wpctl`/`brightnessctl`
  commands added to `services.sxhkd.keybindings` — these tools aren't Wayland-specific, so no
  substitution needed, just copied over.
- Screenshots: sway's `grim`/`slurp`/`wl-copy` (Wayland-only) replaced with `maim`/`xclip` under
  the same `Print` / `super+shift+s` bindings; `home.packages` gained `maim`, `xclip`,
  `brightnessctl`.

`dry-build` clean (only `bspwmrc`, `sxhkdrc`, and the usual home-manager derivations rebuild).
**Update**: this content was in fact committed as part of `f77c916` (whose message only names the
lock/dpms/floating/theme-toggle bindings from Follow-up #11 item 1, but whose diff bundles this
section's `setxkbmap`/volume/brightness/screenshot bindings too) — this section's "not yet
committed" note was stale. Confirmed live in the current running session (2026-08-13):
`crew/bspwm.nix` on disk has `setxkbmap`, `wpctl`/`brightnessctl`, and `maim`/`xclip` bindings, and
`git status` is clean.

## Follow-up #11: build bspwm up to sway parity, as prep for eventually retiring sway+i3

2026-08-12. Decision: since bspwm (xinit) is now fully confirmed working (Follow-up #7) and is a
genuinely different, working WM, the user wants to eventually delete `crew/sway.nix` and
`crew/i3.nix` outright and make bspwm the only session — but only *after* bspwm has real parity,
since sway is currently the de facto daily-driver session (not just a gaming WM). Strategy agreed:
build bspwm up first, verify live, delete sway/i3 as a separate later step — not done in this pass.

Gap analysis (compared `crew/sway.nix` against `crew/i3.nix`/`crew/bspwm.nix`) found: halley (the
other Wayland session, wired in `core/desktop.nix`) has **zero** home-manager config anywhere in
this repo — no bar, keybindings, lock, notifications — so it isn't a usable fallback either; sway
really is the only fully-fleshed-out session today besides what's being built into bspwm here.

Six commits landed this round, each `dry-build`-clean, none switched/live-tested yet:
1. Trivial keybindings ported 1:1 from `crew/i3.nix`/`crew/sway.nix`: `super+Escape` → lock
   (`i3lock-color`, same color as i3/sway), `super+shift+Escape` → `xset dpms force off`,
   `super+n` → `toggle-theme` (already-portable script from `crew/theming.nix`),
   `super+shift+space` → floating toggle (`bspc node -t ~floating`).
2. `polybar` expanded from workspace+clock-only to parity with sway's waybar module set: cpu,
   memory (`%gb_used%G`), network (hardcoded `enp5s0` — this machine is wired, confirmed via
   `ip link`, no wifi/essid branch needed unlike waybar's), pulseaudio, tray. Deliberately no icon
   glyphs (plain "Vol"/"CPU"/"RAM" text labels) since polybar's `font-0` here isn't a Nerd Font,
   unlike waybar's CSS which explicitly sets one — avoids tofu-box rendering.
3. Cosmetics ported: `wlsunset` (wayland-only) → `redshift` with a `~/.config/redshift.conf` using
   `dawn-time=07:00`/`dusk-time=20:00` (redshift's fixed-clock-time override, independent of
   geo-location — same effect as wlsunset's `-S`/`-s`), matching temps (day 6500K/night 4000K).
   `waypaper` (wayland-only) → `nitrogen`. `nwg-look` and the roulette.html launcher are portable
   as-is (gsettings/xdg-open) and were just copied over unchanged.
4. `super+shift+m` bound to launch the Swiftpoint X1 Control Panel (the same out-of-tree
   `~/Applications/SwiftpointX1` binary sway autostarts) — on-demand keybind here instead of
   autostart, per explicit user request.
5. `mako &` added directly to `bspwmrc`. Root cause it fixes: mako's bundled systemd user unit only
   starts because sway explicitly reaches `sway-session.target`/`graphical-session.target`; the
   xinit-based X11 session from `core/x11-greetd-sessions.nix` never does that, so notifications
   (including `crew/modes.nix`'s `makoctl` calls) were silently dead under bspwm until now — same
   *shape* of bug as Follow-up #6 (`DISPLAY`) and #9 (`XDG_SESSION_TYPE`): greetd's xinit sessions
   don't get session-manager integration nixpkgs assumes is present, so anything relying on it
   needs an explicit workaround here.
6. `crew/modes.nix`'s `mode-work`/`mode-study`/`mode-play` were 100% `swaymsg`/`app_id`-coupled, so
   F1/F2/F3 only ever worked under sway (i3 never bound them either). Each script now branches on
   `$SWAYSOCK`: sway branch unchanged, new bspwm branch focuses the target desktop
   (`bspc desktop -f '^N'`) *before* spawning each app (bspwm places new windows on the currently
   focused desktop) instead of trying to match `WM_CLASS` after the fact — avoids having to guess
   exact class names for vscodium/zen/anki/goldendict/steam/discord-canary without live `xprop`
   access. Bound `super+F1/F2/F3` in `crew/bspwm.nix` to match.

### Not done yet / explicitly deferred
- **Nothing above has been switched or live-tested this round** — only `dry-build` per commit.
  Needs a real `nh os switch` + `sudo systemctl restart greetd` (per the Follow-up #6 gotcha) and
  then exercising every new bind under `bspwm (xinit)`: lock, dpms, floating toggle, theme toggle,
  nitrogen, nwg-look, roulette, redshift's actual dawn/dusk transition, the mouse-app bind, mako
  notifications actually popping (e.g. `notify-send test`), and all three F1/F2/F3 modes — the
  `bspc desktop -f` timing (`sleep 0.3` between spawns) in particular is an untested guess and may
  need tuning once watched live.
- redshift's `dawn-time`/`dusk-time` config-file syntax was written from memory, not verified
  against a running instance — check `redshift.conf`'s man-page-documented format actually parses
  (redshift may log a config error rather than silently ignore it) once live.
- The screen-share/screenshot portal question flagged during gap analysis (whether `bspwm`/`i3`'s
  fallback to `core/desktop.nix`'s `config.common` halley portal actually works for an X11 session,
  vs. needing its own scoped `xdg.portal.config` like sway's `config.sway` block in `core/games.nix`)
  is **still unverified** — not touched this round. Likely lower-risk than it looks: X11 apps
  (Discord, browsers) traditionally capture the display directly (XSHM/GLX) without going through a
  portal at all, unlike Wayland where portals are mandatory — but this is an assumption, not
  confirmed for this specific setup.
- Not ported (explicitly out of scope this round, no i3 precedent existed either):
  `dbus-update-activation-environment` call from sway's startup, and richer per-app `bspc rule`
  window-placement (currently only `Steam:Popup`).

### Next steps
- Switch + restart greetd, then work through the "not live-tested" checklist above under
  `bspwm (xinit)`.
- Once everything above is confirmed working live: revisit deleting `crew/sway.nix` +
  `crew/i3.nix` (+ the `programs.sway`/`services.xserver.windowManager.i3` system-level toggles in
  `core/games.nix`) — user has confirmed this is the end goal, but explicitly wants it sequenced
  *after* live verification here, not bundled into this round.

## Follow-up #12: `toggle-theme` broken under both sessions — real root cause was `XDG_DATA_DIRS`, not `dconf` (committed `e3a7db2` + `70c5a95`; confirmed live with a real `super+n` keypress 2026-08-14 — closed, see Follow-up #14's update)

2026-08-13. `toggle-theme` (`crew/theming.nix`, bound `super+n` in both `crew/sway.nix` and the new
`crew/bspwm.nix` per Follow-up #11) failed with `gsettings` reporting no schema installed
("Схем не встановлено") — happened identically under sway and bspwm (confirmed live, from a real
tty2 shell post-switch), so unrelated to the xinit-session-leak bug class from Follow-ups #6/#9/#11.

**First attempted fix was wrong, reverted before committing.** Initial hypothesis: NixOS's
`programs.dconf.enable` (system-level) was needed for `gschemas.compiled` compilation, since
`crew/theming.nix` only sets HM's own (differently-namespaced) `dconf.enable`. This was staged in
`core/desktop.nix`, dry-build clean — but after the actual switch+reboot the user confirmed live
that `toggle-theme`/`gsettings` still failed identically. Investigation (reading nixpkgs source
directly, not guessing) found `programs.dconf` (`nixos/modules/programs/dconf.nix`) only wires up
the dconf *storage* backend (dbus service, `environment.systemPackages = [ pkgs.dconf ]`) — it does
**not** compile or gather any GSettings schemas. Reverted this change entirely (net-zero diff on
`core/desktop.nix`).

**Actual root cause**, confirmed by reading `pkgs/by-name/gs/gsettings-desktop-schemas/package.nix`
and glib's `setup-hook.sh`: nixpkgs deliberately does *not* install `gsettings-desktop-schemas`'s
XML files at the standard `share/glib-2.0/schemas/` path. Glib's own setup hook moves them at build
time to a package-specific `share/gsettings-schemas/gsettings-desktop-schemas-<ver>/glib-2.0/schemas/`
(to avoid collisions when many schema-providing packages are merged into one profile) — and a
`gschemas.compiled` is already pre-built there. Neither NixOS's `system-path.nix` (which only
compiles schemas already sitting at `$out/share/glib-2.0/schemas`, and only for
`environment.systemPackages`) nor home-manager (grepped its entire source — no glib-schema handling
at all) ever gathers these relocated per-package schema dirs back onto `XDG_DATA_DIRS` for a normal
profile. So `gsettings`/`toggle-theme` had no way to find `org.gnome.desktop.interface` regardless
of any `dconf.enable` flag, HM or NixOS — `dconf.enable` is about value storage, not schema
*existence*, a different concern entirely.

Fix (staged, `crew/theming.nix`, `home.sessionVariables`): prepend the package's own precompiled
schema dir to `XDG_DATA_DIRS`:
```nix
XDG_DATA_DIRS = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}\${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}";
```
Verified two ways before proposing this as done, not just dry-build: (1) built the actual
`hm-session-vars.sh` derivation standalone (`nix build ...home.activationPackage`, no switch) and
read the generated `/etc/profile.d/hm-session-vars.sh` — the `export XDG_DATA_DIRS=...` line renders
exactly as intended, correctly preserving any pre-existing `XDG_DATA_DIRS` via
`${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}`; (2) ran `gsettings get org.gnome.desktop.interface color-scheme`
directly with only that one schema dir on `XDG_DATA_DIRS` (no other exports) — returned `'prefer-dark'`
correctly, confirming the compiled schema there is valid and sufficient on its own.

`dry-build` clean. **Update**: committed as `e3a7db2` and switched — current running system
(`/run/current-system` = generation 230) has this fix active. Partially confirmed live
(2026-08-13): a login shell (zsh in kitty, launched from inside the live bspwm session) has the
`gsettings-desktop-schemas` path on `XDG_DATA_DIRS` and `gsettings get
org.gnome.desktop.interface color-scheme` succeeds there.

**But the specific open question this section raised was answered, and the answer is "it doesn't
reach it"**: reading `/proc/<sxhkd_pid>/environ` directly (`sxhkd` is genuinely running, confirmed
via `ps`) shows sxhkd's own `XDG_DATA_DIRS` does **not** include the `gsettings-desktop-schemas`
path — it only has the standard set (`desktops` share dir, nix-profile, `/run/current-system/sw/share`,
etc.), the same as before this fix. Since `home.sessionVariables` is exported via
`/etc/profile.d/hm-session-vars.sh` (login-shell-only), and sxhkd is started from `bspwmrc`/the
xinit `clientScript` rather than through a login shell, it never sources that file — so `super+n`
→ `toggle-theme`, triggered *through the actual keybind*, almost certainly still fails with the
original "no schema installed" error even though a plain login shell now works. **Not yet verified
by literally pressing `super+n`** — this is inferred from the environment diff, not a live keypress
test — but the mechanism is the same one already documented in Follow-ups #6/#9/#11 item 5 (things
that assume login-shell or session-manager env propagation silently don't get it under these xinit
sessions).

**Fix applied (staged, not yet switched/live-tested):** rather than duplicating the
`gsettings-desktop-schemas` path expression a second time in `crew/bspwm.nix`/`bspwmrc`, sourced
the real generated file directly — `core/x11-greetd-sessions.nix`'s `clientScript` now runs
`. /etc/profiles/per-user/ryudzyn/etc/profile.d/hm-session-vars.sh` right after the existing
`DISPLAY`/`XDG_SESSION_TYPE` exports, before `wm.start`. This picks up *all* of
`home.sessionVariables` (not just `XDG_DATA_DIRS`), the same general fix shape as those two prior
leaks. Verified by building the derivation directly (`nix-store --realise` on
`bspwm-xinit-wrapper.drv`, no switch needed) and reading the resulting `bspwm-start` script from the
store: the `.`-source line runs before `sxhkd`/`bspwm` are launched, so both inherit the corrected
`XDG_DATA_DIRS`. `dry-build` and a full `system.build.toplevel` build both succeed (only the
expected small set of derivations rebuild: `bspwm-start`, `-xinit-wrapper`, `-xsession-xinit`,
`desktops`, and the top-level closure).

**Mechanism confirmed live (2026-08-14), independent of the graphical session**: ran the exact
`export DISPLAY=:1; export XDG_SESSION_TYPE=x11; . /etc/profiles/per-user/ryudzyn/etc/profile.d/hm-session-vars.sh`
sequence in a throwaway shell, backgrounded a child process at that point (standing in for
`sxhkd`/`bspwm`, which is what `wm.start` does next in the real `clientScript`), and read
`/proc/<child>/environ` directly — `XDG_DATA_DIRS` there has the `gsettings-desktop-schemas` path
prepended, matching exactly what a login shell already had. Since environment inheritance at fork
time doesn't care whether the parent script is running under a real xinit session or a plain
shell, this is conclusive for the propagation mechanism itself.

**Still not switched or tested with a real `super+n` keypress** — that's the one remaining step
(`nh os switch` + the Follow-up #6-established `sudo systemctl restart greetd` gotcha, since this
touches the session-list-affecting `core/x11-greetd-sessions.nix`), left for the user per usual
workflow.

## Follow-up #13: sway/i3 deleted, bspwm made sole session (committed `192697a`, switched and confirmed live)

2026-08-13. Per the Follow-up #11 end goal (bspwm at parity → retire sway/i3), and since the
user confirmed the Follow-up #11 checklist already works live, jumped straight to deletion —
deferring Follow-up #12's `XDG_DATA_DIRS`-through-sxhkd open question to later, since it doesn't
block this.

Removed:
- `crew/sway.nix`, `crew/i3.nix` deleted outright.
- `crew/default.nix`: dropped their imports; also dropped the standalone
  `programs.waybar.enable = true;` — nothing uses waybar now that sway (its only consumer) is
  gone (bspwm uses polybar instead, per Follow-up #11 #2).
- `core/games.nix`: dropped `services.xserver.windowManager.i3.enable`, the whole
  `programs.sway = { ... }` block, and the `xdg.portal { extraPortals = [ xdg-desktop-portal-wlr
  ]; config.sway = { ... }; }` block — all sway/i3-only, nothing else in the repo referenced
  `xdg-desktop-portal-wlr` (grepped to confirm). halley's own portal config
  (`core/desktop.nix`'s `config.common`) is untouched and unaffected.
- `crew/modes.nix`: `mode-work`/`mode-study`/`mode-play` had a `$SWAYSOCK`-branching `if/else`
  (Follow-up #11 #6) to support both sessions at once — collapsed to bspwm-only unconditional
  logic now that sway can't run these binds anymore.
- `crew/theming.nix`: dropped `waypaper`, `swaybg`, `wlsunset` from `home.packages` — grepped
  first to confirm all three were sway-only (bspwm already uses nitrogen/redshift instead, per
  Follow-up #11 #3); `nwg-look` stayed since bspwm still binds it.
- `core/x11-greetd-sessions.nix` needed **no changes**: `mkXinitSession` is driven by
  `config.services.xserver.windowManager.session` (filtered to enabled WMs with a non-empty
  `.start`), so dropping i3's system-level `.enable` automatically stops generating its xinit
  session — confirmed via `dry-build`'s derivation list, which now only shows
  `none+bspwm-xsession`/the bspwm xinit session, no i3/sway entries at all.

`dry-build` clean (exit 0), 34 derivations, none of them i3/sway-related. **Update**: committed as
`192697a` and switched. Confirmed live (2026-08-13): the current running system
(`/run/current-system`, generation 230) has no `sway` binary at all, and `bspwm`/`sxhkd` are
running as the live session (`SWAYSOCK` unset). Note the switch actually happened *before* the
commit in wall-clock terms (generation 230 was built ~22:32, the commit landed ~23:29) — consistent
with this repo's usual workflow of switching staged changes live first, then committing once
confirmed, not a sign anything is out of sync.

### Next steps
- Confirmed at the process level: only `bspwm`/`sxhkd` are running, no `sway`/`i3`. Still worth an
  explicit look at tuigreet's session list itself (not yet checked) to confirm `none+bspwm` is the
  only other entry and no stale `i3`/`sway`/`none+i3`/`none+sway` cards remain.
- Re-run the full Follow-up #11 live checklist once more post-deletion (lock, dpms, floating
  toggle, theme toggle, nitrogen, nwg-look, roulette, redshift, mouse-app bind, mako, F1/F2/F3)
  to make sure removing the sway/i3 code paths didn't regress anything that was working. Not done
  as part of this doc-status pass.
- Follow-up #12 (`XDG_DATA_DIRS` reaching `super+n` through sxhkd, not just a login shell): fix
  staged in `core/x11-greetd-sessions.nix` (source `hm-session-vars.sh` in `clientScript`), verified
  by reading the built script, but not yet switched or confirmed with a real `super+n` keypress —
  do that together with the switch for this section.

## Follow-up #14: `toggle-theme`/`super+n` still didn't apply to GTK4 apps (root-caused, fixed, confirmed live with a real keypress — closed)

2026-08-14. User report: theme toggling still doesn't work for GTK4 apps (e.g. `pavucontrol`,
which nixpkgs updated to link against `libgtk-4`) even after Follow-up #12's `XDG_DATA_DIRS` fix
was switched and confirmed. This is a **new, separate** bug from #12 — that fix was about
`gsettings`/`dconf` working at all (GTK3-era mechanism); this one is about GTK4 apps specifically.

Root cause, confirmed live in the running session (not guessed):
- GTK3 apps read `org.gnome.desktop.interface` via a built-in `GSettings` binding baked into
  `GtkSettings` itself — this is why `gsettings set ... gtk-theme 'adw-gtk3-dark'` alone already
  worked for GTK3 apps once #12 fixed schema visibility.
- **GTK4 dropped that built-in binding.** GTK4 apps get light/dark preference from
  `org.freedesktop.portal.Settings` (namespace `org.freedesktop.appearance`, key `color-scheme`)
  instead, and — confirmed by `strace -f` on a live `pavucontrol` process, zero occurrences of
  `settings.ini` anywhere in the trace — this particular GTK4 build (4.22.4) does **not** fall
  back to reading `~/.config/gtk-4.0/settings.ini` at all in this setup, despite that file having
  the correct `gtk-application-prefer-dark-theme=1` written to it. So the uncommitted
  `write_gtk4_ini`/`GTK4_INI` logic already sitting in `crew/theming.nix` (not part of this
  follow-up — pre-existing local changes) is confirmed dead code for at least this app: harmless,
  but not what actually needs fixing.
- `core/desktop.nix` already pairs halley's portal impl with `xdg-desktop-portal-gtk` for exactly
  this class of interface (`config.common.default = [ "gtk" ]`), and `xdg-desktop-portal-gtk` does
  implement `org.freedesktop.impl.portal.Settings`, reading from the same `org.gnome.desktop.interface`
  gsettings/dconf keys `toggle-theme` already sets — so the wiring is conceptually right. But
  `systemctl --user list-units` showed `xdg-desktop-portal-gtk.service` in a **permanently failed**
  state, `journalctl --user` showing every start attempt (five, from 01:13 through 01:20) dying with
  `cannot open display: ` and eventually `start-limit-hit`.
- Traced further: `systemctl --user show-environment` had **no `DISPLAY` at all**, even deep into a
  live, working bspwm session where `DISPLAY=:1` works fine in every interactive shell/child
  process. `xdg-desktop-portal-gtk.service` is D-Bus-activated by the systemd `--user` manager, not
  spawned as a direct child of `mkXinitSession`'s `clientScript` — and unlike direct children (which
  inherit `export DISPLAY=:1` from the script's own environment), the systemd `--user` manager has
  its *own* separate environment block that only picks up new variables via an explicit
  `systemctl --user import-environment` (for future unit starts) or `dbus-update-activation-environment
  --systemd` (for D-Bus-activated ones specifically). `clientScript` was never doing either — it does
  `export DISPLAY=:1`/`export XDG_SESSION_TYPE=x11` for its own direct children only. Same *bug
  class* as Follow-ups #6/#9/#12 (xinit-less session skips integration steps nixpkgs's generic
  xsession wrapper would otherwise have done), but a **different consumer** (a D-Bus-activated user
  unit, not a directly-launched child process) — so none of the three prior fixes touched it.

Confirmed as the actual, complete root cause by reproducing and reversing it live, in-session:
ran `systemctl --user import-environment DISPLAY XDG_SESSION_TYPE` +
`dbus-update-activation-environment --systemd DISPLAY XDG_SESSION_TYPE` by hand, then
`systemctl --user reset-failed xdg-desktop-portal-gtk.service && systemctl --user restart
xdg-desktop-portal-gtk.service` — it came up `active (running)` on the first try (previously failed
every time). Immediately after, `gdbus call ... org.freedesktop.portal.Settings.Read
org.freedesktop.appearance color-scheme` returned `uint32 1` (prefer-dark), matching what
`toggle-theme`'s `gsettings set ... color-scheme 'prefer-dark'` had already set — confirming the
portal path itself is correct end-to-end once the service can actually start.

Fix (staged, `core/x11-greetd-sessions.nix`, not yet switched): `clientScript` now runs
`systemctl --user import-environment DISPLAY XDG_SESSION_TYPE` and
`dbus-update-activation-environment --systemd DISPLAY XDG_SESSION_TYPE` right after sourcing
`hm-session-vars.sh` (Follow-up #12's fix) and before starting Xorg — same general spot as the
other environment-fixup lines. Verified by building the derivation directly
(`nix-store --realise` on `bspwm-start.drv`, no switch) and reading the resulting script: both
lines are present, in order, with `dbus-update-activation-environment` resolving to a real
`pkgs.dbus` store path. `dry-build` and a full `system.build.toplevel` build both succeed — only
the expected small set of derivations rebuild (`bspwm-start`, `-xinit-wrapper`, `-xsession-xinit`,
`desktops`, top-level closure).

**Switched and confirmed live 2026-08-14.** Post-switch read-only verification (no code changes,
just inspection of the live session): `sxhkd`'s `/proc/<pid>/environ` had the correct `DISPLAY`,
`XDG_SESSION_TYPE`, and `XDG_DATA_DIRS` (schemas path included); `xdg-desktop-portal-gtk.service`
was `active (running)`, no longer `failed`; `gdbus call ... Settings.Read ... color-scheme`
returned the correct live value. A simulated `xdotool key super+n` toggled `gsettings` correctly
first — then the user pressed the **real physical** `super+n` twice from the actual keyboard and
`gsettings get org.gnome.desktop.interface color-scheme` changed each time
(`prefer-dark` → `prefer-light` → back), confirmed directly in a terminal. The whole chain
(sxhkd → `toggle-theme` → `gsettings`/dconf → portal) is fully live-verified end to end, not just
inferred from environment inspection.

**Known limitation hit in practice, then superseded by a declarative fix (2026-08-14):**
already-running GTK4 apps didn't repaint live when the theme toggled — not every GTK4 app
subscribes to the portal's `SettingChanged` D-Bus signal, some only read `color-scheme` once at
startup. Given the runtime toggle route (`toggle-theme` + manual per-app restarts) still felt
unreliable in practice, the user asked to just fix the app color in code and stop iterating on
live-toggle. `crew/default.nix`'s `gtk` block was declaring the **light** variant
(`theme.name = "adw-gtk3"`, no `colorScheme` set at all) — the actual root cause of "GTK4 apps
default to light" independent of anything `toggle-theme`/#12/#14 fixed. Changed to
`theme.name = "adw-gtk3-dark"` and added `gtk.colorScheme = "dark";`. Home-manager's `gtk` module
(`modules/misc/gtk/lib.nix`'s `mkGtkSettings`) turns that into `gtk-application-prefer-dark-theme
= true` and (GTK4-only) `gtk-interface-color-scheme = 2` in both `gtk-3.0` and `gtk-4.0`
`settings.ini`, **and** `dconf.settings."org/gnome/desktop/interface".color-scheme =
"prefer-dark"` — the exact same dconf key the portal reads (confirmed working end-to-end in this
same follow-up). Verified by building the two derivations directly (`nix-store --realise` on
`hm_gtk4.0settings.ini.drv` and `hm-dconf.ini.drv`, no switch): generated `gtk-4.0/settings.ini`
has `gtk-application-prefer-dark-theme=true`, `gtk-interface-color-scheme=2`,
`gtk-theme-name=adw-gtk3-dark`; generated `dconf.ini` has `color-scheme='prefer-dark'`,
`gtk-theme='adw-gtk3-dark'`. `dry-build` clean (exit 0), only the expected `gtk3.0`/`gtk4.0`
`settings.ini`, `dconf`, and home-manager-generation derivations rebuild.

This makes dark the HM-managed default applied on every `switch`, independent of `toggle-theme`/
`super+n` — **closing this follow-up here** per explicit user decision, no further live-reload
work planned. `toggle-theme` and its `super+n` bind are left in place untouched (not asked to
remove); note for later: toggling away from dark at runtime will just get reasserted back to dark
on the next `home-manager switch`, since the declarative default now wins.

### Not done yet
- The uncommitted `write_gtk4_ini`/GTK4 `settings.ini`-writing fallback still sitting in
  `crew/theming.nix` remains confirmed dead code for `pavucontrol` (this GTK4 build doesn't read
  `settings.ini` here) — still left in place untouched, still the user's own pre-existing local
  change and still their call whether to keep it (harmless) or drop it later.

## Follow-up #15: `pavucontrol` (and any non-libadwaita GTK4 app) stayed white/light despite every prior dark-theme fix (root-caused, fixed, confirmed live — closed)

2026-08-14. User report: `pavucontrol` still white background with gray checkboxes, hurts the eyes,
despite Follow-up #14 being closed as fully confirmed live. Re-investigated live rather than trusting
the closed status.

Findings, each confirmed directly on the running session, not guessed:
- The actual *runtime* toggle state (`gsettings get org.gnome.desktop.interface color-scheme`) was
  `'prefer-light'` — someone had pressed `super+n` since the last switch, and per Follow-up #14's own
  documented "known limitation," a runtime toggle away from dark doesn't get reasserted until the next
  `home-manager switch`. Reset live via `gsettings set ... 'prefer-dark'` — this alone did **not** fix
  `pavucontrol` (confirmed both on the already-running window and a freshly relaunched one), so this
  was a real, distinct, second bug, not just a stale toggle.
- **Correction to Follow-up #14**: that section concluded "this GTK4 build does not read
  `settings.ini`" from a `strace` that showed zero `settings.ini` occurrences. Re-traced live this
  round (`strace -f -e trace=open,openat` on a real `pavucontrol` launch) and it clearly **does** open
  `~/.config/gtk-4.0/settings.ini` *and* `~/.config/gtk-4.0/gtk.css` *and* the imported
  `adw-gtk3-dark/gtk-4.0/{gtk,libadwaita,libadwaita-tweaks}.css` — likely a genuine behavior change
  between whatever gtk4 version Follow-up #14 tested against and the current `4.22.4`
  (nixpkgs-unstable), not a mistake in that trace at the time.
- Root cause, confirmed via a live A/B screenshot test (`maim`) using an isolated `XDG_CONFIG_HOME`
  sandbox to control exactly one variable at a time: home-manager's own generated
  `~/.config/gtk-4.0/settings.ini` (from `modules/misc/gtk/lib.nix`'s `mkGtkSettings`) writes
  `gtk-interface-color-scheme=2` — `2` being the numerically-correct value per GTK4's own published
  enum (`Gtk.InterfaceColorScheme`: `DEFAULT=1`, `DARK=2`, `LIGHT=3`,
  https://docs.gtk.org/gtk4/enum.InterfaceColorScheme.html) — but this exact gtk4 build's
  `settings.ini` key-file loader rejects it outright:
  ```
  Gtk-WARNING **: Error setting gtk-interface-color-scheme in .../settings.ini: Key file contains key
  "gtk-interface-color-scheme" which has a value that cannot be interpreted.
  ```
  reproduced reliably in the sandbox with *only* that one key set. Since this property is what
  actually drives the `@media (prefers-color-scheme: dark)` blocks inside `adw-gtk3-dark`'s (and
  libadwaita's) GTK4 CSS — confirmed by grepping the real `libgtk-4.so` strings table, which lists
  `notify::gtk-interface-color-scheme` right next to the CSS engine's media-query machinery — a failed
  parse means those blocks never activate: the app falls back to light colors even though
  `gtk-application-prefer-dark-theme=true` is *also* set correctly right above it in the same file (that
  older boolean key still parses fine, but no longer appears to independently drive the CSS in this
  GTK version — `gtk-interface-color-scheme` is the one that matters now). Swapping the value to the
  **string nickname** `"dark"` (same sandbox, same app, nothing else changed) parsed with zero warning
  and rendered `pavucontrol` fully dark on the very next launch — conclusive, not inferred. This is a
  real home-manager/gtk4-version mismatch (home-manager assumes the settings.ini loader accepts the
  enum's raw integer; this gtk4 build's loader wants the nickname string instead), not anything wrong
  in this repo's config, and not fixable by changing `gtk.colorScheme` (which only controls whether the
  key is emitted at all, not its format — the integer-vs-string choice is hardcoded in home-manager's
  `lib.nix`).
- The GTK_THEME=Adwaita:dark env var (home.sessionVariables, `crew/theming.nix`) and the portal path
  (`org.freedesktop.portal.Settings.Read` → confirmed returning the correct dark value throughout this
  investigation) were both re-verified live and are fine — neither was the problem this round; the
  broken `settings.ini` key was blocking the CSS media query regardless of what those two reported.

Fix (staged, `crew/default.nix`): added
```nix
gtk4.extraConfig."gtk-interface-color-scheme" = "dark";
```
next to the existing `colorScheme = "dark";`. Home-manager's `gtk4.nix` builds `settings.ini` as
`mkGtkSettings { ... } // cfg4.extraConfig` — a right-biased merge — so this cleanly overrides just
the one broken key without touching `gtk.colorScheme` (still needed for the `gtk-application-prefer-dark-theme`
key, GTK3's `settings.ini`, and the `dconf.settings`/portal value) or forking home-manager's module.
Verified by building the `hm_gtk4.0settings.ini` derivation directly (`nix-store --realise`, no switch)
and reading the output: `gtk-interface-color-scheme=dark` (string), rest of the file unchanged.
`dry-build` clean — only the expected small set of derivations rebuild (`hm_gtk4.0settings.ini`,
`home-manager-files`, `home-manager-generation`, the HM systemd unit, `etc`, `activate`, the top-level
system closure).

**Switched and confirmed live by the user 2026-08-14** — `pavucontrol` renders fully dark now. Closing
this follow-up here. Still worth a spot-check on any other plain-GTK4 (non-libadwaita) app if a similar
white/light-with-dark-accents symptom ever turns up — this bug would have affected all of them
identically, not just `pavucontrol`.

## Critical files
- `core/security.nix`, `hosts/earth/default.nix` — hardening module + wiring
- `core/system.nix` — drop insecure-package allowance
- `flake.nix` — formatter output
- `core/games.nix`, `crew/default.nix`, `crew/bspwm.nix` — bspwm session
- `core/x11-greetd-sessions.nix` — xinit wrapper for i3/bspwm under greetd (follow-up fix)
- `crew/theming.nix` — `toggle-theme`, `XDG_DATA_DIRS` gsettings-schemas fix (Follow-up #12)
- `crew/sway.nix`, `crew/i3.nix` (deleted), `crew/modes.nix` (sway branch dropped) — sway/i3
  retirement (Follow-up #13)
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
