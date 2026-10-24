---
name: disk-cleanup
description: Free disk space on earth (NixOS) safely — report what takes space (Nix generations/store, Steam leftovers of uninstalled games, caches, Android SDK images, journal), propose concrete deletions with sizes, delete only what the user confirms. Never touches ~/Downloads. Use when the user says "закінчилось місце", "почисти диск", "звільни місце", "disk full", or when builds/tools fail with ENOSPC / "No space left on device".
---

# disk-cleanup — звільнити місце на earth

Nothing is deleted without the user's explicit OK for that category. **`~/Downloads` is never touched** — show its size, the user cleans it personally.

## 0. Disk already full?

If commands fail with ENOSPC, nothing works (not even tool output). First, with no confirmation needed because it's lossless:
- delete your own scratch files (`$CLAUDE_JOB_DIR/tmp/*`, build logs you wrote);
- stop running background builds (they keep filling `/tmp` and the store);
- `nix-store --gc --max-freed 30G` — removes only store paths nothing references (half-finished build downloads); current system and all generations stay. Redirect output to `/dev/null` while the disk is full.

## 1. Report

Run `disk-report` (read-only) and show the user a short table: category · size · what deleting it means. Add `du -sh` for anything unusual it surfaces.

## 2. Propose, by category (ask once per category, AskUserQuestion multi-select works well)

| Category | Command | Risk |
|---|---|---|
| Old NixOS generations | `nh clean all --keep 10 --keep-since 3d` (no sudo needed for the user's profiles; system profiles need sudo — give the user the command) | Can't roll back past the kept ones. Never touch the current/booted generation |
| Nix store garbage | `nix-store --gc` after the above | none |
| Steam leftovers | `disk-report --steam-orphans` lists compatdata/shadercache of uninstalled games and `common/` dirs no manifest owns | **compatdata holds saves of games without Steam Cloud** — show the list with sizes and let the user pick; never bulk-delete. `common/` leftovers and shadercache are safe |
| Big installed games | only list (`disk-report` shows top ones) | user uninstalls via Steam, not `rm` |
| Gradle / uv / appimage-run / mesa cache | `rm -rf ~/.gradle/caches ~/.cache/uv ~/.cache/appimage-run ~/.cache/mesa_shader_cache` | rebuild on next use (Gradle re-downloads deps: next mod/Orbit build is slower). Don't remove `~/.cache/watch` (WhisperX) or `~/.cache/huggingface` unless asked |
| Trash | `gio trash --empty` | gone for good — confirm |
| Android SDK images / AVDs | list `~/Android/Sdk/system-images/*`, `~/.android/avd/*` | Orbit builds via `~/Projects/orbit/shell.nix` (androidenv in the Nix store), so `~/Android/Sdk` is likely an old Android Studio SDK — still ask; AVDs may be in use |
| Journal | `journalctl --vacuum-size=500M` needs sudo → give the user the command | none |

## 3. After

`df -h /` before vs after, one line per category: freed size. Send `notify-phone` only if the user isn't in the chat (long cleanup). If auto-cleanup isn't configured in `core/system.nix` (`nix.settings.min-free`, `programs.nh.clean`, `SystemMaxUse`), mention it.
