---
name: phone-control
description: Look at and operate the user's Pixel from earth without a cable — read the screen as text and tap by label (phone-ui over wireless adb/Tailscale), screenshots, open apps, change settings, install APKs. Use when the user asks to check or set something on the phone ("глянь на телефоні", "налаштуй на телефоні", "постав на телефон", "що в мене в налаштуваннях …"), or a task needs the phone (ntfy, keyboard, Orbit). For Orbit builds use /orbit-ship.
---

# phone-control — телефон через phone-ui / phone-adb

Connection: `phone-adb` (finds the wireless-debugging port over Tailscale; phone must be on Wi-Fi with Wireless debugging on). If it fails, tell the user exactly that — don't guess.

## Before touching anything

`phone-ui dump` first: it prints the focused app. If the user is actively in an app (chat, Termux, a game) and you didn't ask to take over, **ask before tapping** — synthetic input goes into whatever is focused. Reading (dump, screenshot) is fine.

## Read

- `phone-ui dump` — focused app + every element with text / content-desc / resource-id; `*` = clickable, `(x,y)` = centre.
- `phone-ui find TEXT` — just the matches.
- uiautomator needs the screen to go idle; on animations/video/Termux it fails with a clear message → use `phone-adb exec-out screencap -p > "$CLAUDE_JOB_DIR/tmp/phone.png"` and Read it (the image is downscaled; multiply coordinates by the factor the Read result states before tapping).

## Act

- `phone-ui tap "Text" [-n 2]`, `phone-ui long "Text"`, `phone-ui key BACK|HOME|ENTER`, `phone-ui open <package>`.
- `phone-ui type "ascii"` — adb can't type Cyrillic/emoji; for those, ask the user or use the app's own deep links/intents.
- Prefer intents over tapping when an app supports them: `phone-adb shell am start -a android.intent.action.VIEW -d '<uri>' <pkg>` (e.g. `ntfy://…`), `am start -a android.settings.<SECTION>_SETTINGS`.
- Settings that have a `settings`/`cmd`/`pm` equivalent (e.g. `settings put`, `pm grant`, `cmd package`) are more reliable than UI — use them, then verify in the UI.
- After every action, `phone-ui dump` (or a screenshot) to confirm the result before the next step.

## Install apps

Only from F-Droid (`https://f-droid.org/api/v1/packages/<pkg>` → `repo/<pkg>_<versionCode>.apk`) or the project's official releases; check the signer with `nix run nixpkgs#apksigner -- verify --print-certs`; install with `phone-adb install -i org.fdroid.fdroid <apk>` for F-Droid builds so updates flow through F-Droid. Delete the downloaded APK afterwards.
