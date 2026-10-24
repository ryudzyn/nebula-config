---
name: screen-watch
description: Record a few seconds of the live Hyprland screen on earth (monitor, active window, region) and watch it frame by frame with /watch — for motion bugs a single screenshot can't show (animations, flicker, stutter, popups that vanish, in-game behaviour of the Minecraft mod). Use when the user says "подивись що в мене на екрані", "запиши екран", "глянь анімацію/мерехтіння", or after a visual change where timing matters. For a still image use /hypr-verify's screenshot instead.
---

# screen-watch — запис екрана → /watch

Only record when the user asked for it or agreed: the screen may show private windows. Recording is passive (no input is sent), but if you're about to trigger something on screen first, follow /hypr-verify's focus rule.

1. **Record.** `screen-rec -s <secs> [-w | -o <monitor> | -g "x,y WxH" | -r] [-a] "$CLAUDE_JOB_DIR/tmp/rec.mp4"` (outside a job use the scratchpad). Default 10 s of the focused monitor at 30 fps, no audio.
   - `-w` the active window (what's focused right now — check with `hyprctl activewindow -j` that it's the right one); `-r` lets the user drag a region with the mouse (they must be at the PC); `-a` adds system audio (needed only if sound matters).
   - Keep it short: 3–10 s. Long recordings cost many frames/tokens.
   - To capture something you start yourself (reload, a keybind via `hyprctl eval`), run `screen-rec` in the background (`&`), wait ~1 s, trigger, then `wait`.
2. **Watch.** `python3 ~/.claude/skills/watch/scripts/watch.py <file> --no-whisper --detail <d> --out-dir "$CLAUDE_JOB_DIR/tmp"` (add `--whisper whisperx` instead of `--no-whisper` only with `-a` and speech).
   - Static UI → `efficient`. Motion/animation → `balanced`. Flicker or a one-frame glitch → `token-burner --no-dedup` on a ≤3 s clip (dedup otherwise drops near-identical frames — exactly the ones that differ by a flash).
   - `--timestamps 0:01.5,0:02` grabs exact moments if the user says when it happens.
3. **Read the frames** listed in the report and answer with timestamps ("на 00:02 панель на мить зникає").
4. **Clean up**: delete the mp4 and the `watch-*` work dir — recordings of the user's screen don't stay around.
