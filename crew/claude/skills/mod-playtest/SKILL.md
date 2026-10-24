---
name: mod-playtest
description: Play-test the Ascension Minecraft mod in a real client on earth — launch the dev client straight into a test world, run commands / keys / clicks, then check the result with screenshots or a short video (/screen-watch). For anything GameTests can't show — GUIs, particles, HUD, keybinds, feel of a feature. Use when the user says "перевір у грі", "зайди в світ і глянь", "протестуй фічу в грі", or after a mod change whose effect is visual/interactive. Works in ~/Projects/ascension-1211 (1.21.1 port) and ~/Projects/ascension-night.
---

# mod-playtest — фіча мода в живому клієнті

All helpers live in the mod repo: `tools/hyprland-test/` (read each script's header before first use in a session — they encode hard-won rules: US keycodes for typing, why `cmd` waits 0.9 s, why clicks need a nudge). Run them from the repo root.

1. **Build first.** `nix develop --command ./gradlew build` must pass (failing build → stop, report the first error via `log-digger`). If the dev shell complains about GLX/GLXFBConfig, the repo's flake.lock nixpkgs is older than the system's — see memory "Noctalia glibc lockstep" (`nix flake lock --override-input nixpkgs github:nixos/nixpkgs/<system rev>`).
2. **Make room on workspace 2.** The helpers refuse input unless the focused window is the Minecraft client on workspace 2 (exit code 3 = stop, don't work around it). Check `hyprctl activeworkspace -j`: if the user is on workspace 2 with their own windows, ask first.
3. **Launch.** `tools/hyprland-test/relaunch ["World"]` — stops any client, focuses ws 2, starts `runClient` into the world (default: `Ascension Test`, a copy — tests may rewrite its state), clicks through the geckolib warning, waits until in-world. Log: `build/hyprland-test.log` (feed to `log-digger` on crashes). Multiplayer: start `./gradlew runServer` in the background and use `server:localhost`.
4. **Drive.** `cmd "/ascension …"` (chat command; results show as `[CHAT]` in the log), `press KEY [MODS]`, `hold KEY SECS` (for isDown()-polled binds), `click X Y`, `drag X1 Y1 X2 Y2`, `typetext "…"`.
5. **Observe.**
   - Still: `tools/hyprland-test/shot "$CLAUDE_JOB_DIR/tmp/mc.png"` → Read (half scale: double coordinates for `click`).
   - Motion (particles, animations, flicker, HUD transitions): start `screen-rec -s 6 "$CLAUDE_JOB_DIR/tmp/mc.mp4" &`, trigger the action, `wait`, then follow /screen-watch (`balanced`, or `token-burner --no-dedup` on ≤3 s for one-frame glitches).
   - Logic: grep the log for `[CHAT]` / exceptions.
6. **Stop.** `tools/hyprland-test/stop-client` (SIGKILL a client with corrupted state — SIGTERM would save it into the world). Delete screenshots/recordings.
7. **Report** in Ukrainian: what was tested, what was seen (with timestamps/screens as evidence), what's broken. "Not seen" ≠ "works" — say "не перевірено наживо" when you couldn't observe it.
