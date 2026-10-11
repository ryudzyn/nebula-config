---
name: mod-port
description: Port the Ascension Minecraft mod to Minecraft 1.21.1 NeoForge for the user's modpack — set up the port worktree, then carry code and features over one batch at a time with build, tests and a live check. Use when the user says "порт", "портуй мод", "1.21.1", "перенеси фічу з forge-1.20.1", or asks to continue the modpack port.
argument-hint: "[setup | next | <feature or commit>]"
---

# mod-port — Ascension → 1.21.1 NeoForge

What the user typed: `$ARGUMENTS` (empty = continue with the next unported item).

## Where things are

| | path / branch | MC / loader / Java |
|---|---|---|
| source of truth for the port | `~/Projects/ascension-night`, `master` | 26.2 / NeoForge 26.2.0.59 / Java 25 |
| night features to carry over | `~/Projects/ascension-1201`, `forge-1.20.1` (frozen) | 1.20.1 / Forge 47 / Java 17 |
| **port target** | `~/Projects/ascension-1211`, `neoforge-1.21.1` | 1.21.1 / NeoForge 21.1.x / Java 21 |

All three are worktrees of the same repo (`git -C ~/Projects/ascension-night worktree list`). The original `~/Projects/ascension-limitless-progression` is never touched. Plan and decisions: `~/Projects/ascension-1201/docs/MODPACK_PLAN.md`. Lessons from the first port: `PORT_1.20.1.md` and `tools/port/*.py` on `forge-1.20.1`.

Each repo's own `CLAUDE.md` has the commands and environment notes. Read the target's (or, before setup, ascension-night's) before working.

## setup (once — skip if `~/Projects/ascension-1211` exists)

1. Confirm with the user before creating the worktree (new branch in their repo):
   `git -C ~/Projects/ascension-night worktree add ~/Projects/ascension-1211 -b neoforge-1.21.1 master`.
2. **Versions from live sources, not memory.** Latest NeoForge 21.1.x: `curl -s https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml | grep -o '<version>21\.1\.[0-9]*</version>' | tail -1`. Check the MDK template (`github.com/NeoForgeMDKs/MDK-1.21.1-ModDevGradle`) for the matching ModDevGradle version and `gradle.properties` keys. Set `minecraft_version=1.21.1`, `minecraft_version_range=[1.21.1]`, `neo_version`, Java toolchain 21; switch the `flake.nix` devShell JDK to 21 (keep the openal-soft override).
3. Park the 26.2 sources the way the 1.20.1 port did (move `src/` aside into `port/`), bring back the pure model first (`progression/`, `graph/`, their unit tests) — it has no MC dependency and proves the toolchain. Commit.
4. Create `PORT_1.21.1.md`: a mapping table (26.2 → 1.21.1) that grows as you go, plus a checklist of every `forge-1.20.1` feature commit (`git log --reverse --oneline master..forge-1.20.1`, skipping the first port-mechanics commits) with a status column.

## The batch loop (every other invocation)

1. **Pick** the next unchecked item in `PORT_1.21.1.md` (or what the user named). Batch size: one subsystem or one feature — something that compiles and can be tested on its own.
2. **Port the 26.2 code first, then the 1.20.1 feature delta.** For a night feature, read its forge-1.20.1 commit (`git show <hash>`) for *what* changed, but port the logic onto the NeoForge structure — don't drag Forge idioms (capabilities, SimpleChannel, IGuiOverlay) in.
3. **API differences — verify, don't assume.** Starting hypotheses for 26.2 → 1.21.1, to confirm against decompiled sources (`find ~/.gradle -iname "*.jar" | xargs grep -l <Class>` per ascension-night's CLAUDE.md) or context7 NeoForge docs before relying on them:
   - `Identifier` → `ResourceLocation` (`ResourceLocation.fromNamespaceAndPath`).
   - Render pipelines (`RenderPipeline`, 1.21.5+) don't exist → `RenderType` / `ShaderInstance` / `BufferBuilder` paths.
   - `GuiGraphicsExtractor` and newer GUI APIs → 1.21.1 `GuiGraphics`; GUI layers via `RegisterGuiLayersEvent`.
   - Still present in 1.21.1 (keep the 26.2 approach): AttachmentType player data, `StreamCodec` payloads, data components, Breeze sounds/particles.
   - Java 25 features (newer pattern/switch forms) → Java 21.
   Every confirmed difference goes into the `PORT_1.21.1.md` table, every disproved hypothesis gets removed there.
   For repetitive renames, adapt `tools/port/rewrite.py` from `forge-1.20.1` rather than editing hundreds of call sites by hand.
4. **Build & test:** `nix develop --command ./gradlew build` then `nix develop --command ./gradlew runGameTestServer`. On failure, give the log path to the `log-digger` subagent and ask for the first compile error / failing test with file:line — don't read the whole gradle log in the main context. Unit and GameTest counts must not drop vs. the source branch for ported subsystems.
5. **Live check** for anything visible or interactive: focus an empty workspace (workspace 2) *before* `tools/hyprland-test/run-client`, verify the focused window before any synthetic input (helpers enforce it — exit code 3 means stop), screenshot with grim, then `stop-client` (SIGKILL a client holding corrupted state, never SIGTERM — it saves).
6. **Commit** in the target worktree: `1.21.1: <feature> (from <forge-1.20.1 hash>)`, tick the checklist row in `PORT_1.21.1.md` in the same commit. No push (local-only repo anyway).
7. **Report** in Ukrainian: what was ported, test counts, what was seen live, and what's next on the checklist. One batch per invocation unless the user asked for more.

## After the core port

Per `MODPACK_PLAN.md`: Create compat moves from 6.0.8/1.20.1 to Create 6.0.10/1.21.1 (keep it optional, `-PnoCreate`), then Aeronautics/Cosmonautics. Check each mod's current 1.21.1 version on Modrinth/CurseForge live before pinning it.
