---
name: hypr-verify
description: Apply and visually verify a change to the live Hyprland/Noctalia desktop on earth — reload, check for config errors, screenshot. Use after editing hyprland.lua, tweaks.lua, alttab.lua, Noctalia config.toml, or anything whose result is visible on screen.
---

# hypr-verify — перевірка змін на живому десктопі

`hyprland.lua`, `tweaks.lua`, `alttab.lua` and Noctalia's `config.toml` are live symlinks into `~/nebula-config` — no switch needed. Other files under `crew/` need a `sysup` by the user first; say so and stop.

1. **Reload.** `hyprctl reload`. Legacy `hyprctl keyword` is rejected here — runtime changes go through `hyprctl eval '<lua>'` (e.g. `hl.dispatch(hl.dsp.focus({workspace=2}))`).
2. **Errors.** `hyprctl configerrors` must be empty. Lua errors also appear in Hyprland's red error bar — the screenshot catches those too.
3. **Before any synthetic input** (`hyprctl eval` dispatches, `wlrctl`, `dotool`): `hyprctl activewindow -j` / `hyprctl activeworkspace -j`. If the user's own windows are focused, they may be at the PC — don't send keys/clicks into them; ask or use an empty workspace.
4. **Screenshot.** `grim <scratchpad>/shot.png` (or `grim -o <monitor>`; `hyprctl monitors -j` for names) and Read it. Coordinates in grim shots of a scaled output are half-scale — double them for clicks.
5. **Report** what changed on screen, with the screenshot as evidence. A change that wasn't seen rendered is not verified — say "не перевірено візуально" rather than assuming.
