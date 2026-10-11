---
name: orbit-ship
description: Build, install and visually verify a change to the Orbit Launcher Android app (~/Projects/orbit) on the USB-connected phone or emulator — bumps the version, assembles the debug APK, installs via adb, screenshots the result. Use when an Orbit change is ready to try on a device, or the user says "збери орбіт", "постав на телефон", "ship orbit".
---

# orbit-ship — збірка й перевірка Orbit на пристрої

Repo: `~/Projects/orbit` (package `com.ykatchou.orbit`). Toolchain comes from its `shell.nix` — run gradle as `nix-shell ~/Projects/orbit/shell.nix --run './gradlew …'` from the repo root.

1. **Version bump (mandatory for any behavior change).** In `app/build.gradle.kts`: `versionCode` +1, `versionName` patch +1 (minor for a bigger feature). The user reads the on-screen `vX.Y.Z` to know which build runs — a stale number defeats that. Skip only for docs/comment-only changes.
2. **Build.** `./gradlew assembleDebug`. On failure, hand the log to the `log-digger` subagent and ask for the first compiler error with file:line instead of reading the whole log.
3. **Device.** `adb devices` — if nothing is listed, stop and tell the user (USB/emulator not connected); don't guess.
4. **Install & launch.** `adb install -r app/build/outputs/apk/debug/app-debug.apk`, then `adb shell monkey -p com.ykatchou.orbit -c android.intent.category.HOME 1` (or press HOME — Orbit is the launcher).
5. **Verify visually.** `adb exec-out screencap -p > <scratchpad>/orbit.png` and Read the image. Confirm the new version string in the bottom-right corner and the changed behavior. UI driving: `adb shell input motionevent DOWN x y` / `MOVE` / `UP`; settings = long-press the clock (DOWN, ~1.2 s, UP); in the pie, move back to the center before UP so nothing launches.
6. **Commit** in the orbit repo with the version in the subject, e.g. `Widgets: clock glance (v0.13.3)`. Push only if the user asked.
