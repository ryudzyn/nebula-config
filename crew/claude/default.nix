{ config, pkgs, ... }:

# Інструменти для Claude Code (сам claude-code -- системно, core/packages.nix).
#
# Скіли й агенти живуть у цьому репо і лінкуються живими симлінками
# (mkOutOfStoreSymlink, як hyprland.lua) -- правки діють одразу, без switch.
# Лінкуємо поштучно, а не весь ~/.claude/skills: там же лежить skills/synced,
# яким керує сам Claude Code (скіли з claude.ai).
#
# Плагіни не декларуються тут -- їх стан (кеш, увімкненість) веде сам
# Claude Code у ~/.claude/plugins. Встановлення:
#   claude plugin marketplace add ~/nebula-config/crew/claude/marketplace
#   claude plugin install <назва>@<маркетплейс>
# Повний список встановленого -- у crew/claude/README.md.
let
  live =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/claude/${path}";
  skills = [
    "nixcheck"
    "orbit-ship"
    "hypr-verify"
    "arena"
    "mod-port"
    "post-switch"
    "flake-bump"
    "screen-watch"
    # Вендорені сторонні скіли (лише SKILL.md + ліцензія, без хуків):
    # ponytail, ponytail-debt -- github:DietrichGebert/ponytail @ 09c434a, MIT
    "ponytail"
    "ponytail-debt"
    # interview-me, debugging..., source-driven... -- github:addyosmani/agent-skills @ aeac41d, MIT
    "interview-me"
    "debugging-and-error-recovery"
    "source-driven-development"
    # graphify -- github:safishamsi/graphify @ 92741d1 (graphifyy 0.9.95), Apache-2.0/MIT
    "graphify"
    # security-audit -- github:cloudflare/security-audit-skill @ c1c8a8c, MIT
    "security-audit"
    # minecraft-testing -- github:jahrome907/minecraft-agent-skills @ 30137f9, MIT
    # (правка: анотаційні GameTests і для 1.21.1, не лише 1.21.3)
    "minecraft-testing"
    # hyprland-lua -- github:janusfil/ai-skills @ 3082711, Apache-2.0
    # (правки: NixOS-шлях до стабів, наш crew/hyprland/, `hyprctl eval`)
    "hyprland-lua"
    # kotlin-* -- github:affaan-m/ECC @ 90606c8, MIT (лише 3 SKILL.md з 311 скілів,
    # без хуків ECC; додано примітку про стек Orbit: JUnit 4, без нових залежностей)
    "kotlin-coroutines-flows"
    "kotlin-patterns"
    "kotlin-testing"
    # watch -- github:bradautomates/claude-video @ 03ceb42, MIT (без SessionStart-хука;
    # налаштування й ключі -- ~/.config/watch/.env, поза репо)
    "watch"
  ];
  agents = [
    "log-digger.md"
    "nix-builder.md"
  ];
in
{
  home.packages = with pkgs; [
    # Мовні сервери для LSP-плагінів (діагностика після кожного Edit,
    # go-to-definition). Плагіни лише кажуть, яку команду запускати --
    # самі бінарники мають бути на PATH.
    nixd # Nix -- власний плагін nixd-lsp у marketplace/
    lua-language-server # Hyprland Lua-конфіг (lua-lsp)
    rust-analyzer # pkgs/halley (rust-analyzer-lsp)
    jdt-language-server # моди Minecraft (jdtls-lsp)
    # Офіційний kotlin-lsp від JetBrains у nixpkgs немає, тому для Orbit --
    # fwcd/kotlin-language-server через власний плагін kotlin-ls у marketplace/
    kotlin-language-server
    # MCP-сервер керування браузером. `npx @playwright/mcp` з офіційного
    # плагіна тягне власний chromium, який на NixOS не стартує -- цей
    # пакет зібраний проти браузерів з nixpkgs
    playwright-mcp
    # skills/arena (вендорено з github:Jakeschincariol/arena-skill @ df07b8e,
    # MIT) веде турнір через bracket.py -- лише stdlib, але потрібен python3
    python3
    # skills/graphify сам ставить і знаходить свій Python через `uv tool`
    # (graphifyy з ~25 tree-sitter-граматиками, у nixpkgs нема). Колеса
    # manylinux запускаються завдяки nix-ld (core/system.nix)
    uv
    # skills/security-audit перевіряє findings.json і coverage-ledger.json
    # власними валідаторами (.cjs, без залежностей) -- потрібен node
    nodejs
    # skills/watch: yt-dlp качає відео (javascriptSupport у nixpkgs тягне deno для
    # YouTube), ffmpeg/ffprobe -- кадри й аудіо. WhisperX скіл ставить сам у
    # ~/.cache/watch/whisperx-venv через uv
    yt-dlp
    ffmpeg
    # adb до телефона через Tailscale (порт бездротового налагодження щоразу інший)
    (writeShellApplication {
      name = "phone-adb";
      runtimeInputs = [
        android-tools
        nmap
      ];
      text = builtins.readFile ./phone-adb.sh;
    })
    # пуш на телефон через ntfy (сервер -- constellations/comms.nix)
    (writeShellApplication {
      name = "notify-phone";
      runtimeInputs = [ curl ];
      text = builtins.readFile ./notify-phone.sh;
    })
    # коротке відео екрана для /watch (skills/screen-watch)
    (writeShellApplication {
      name = "screen-rec";
      runtimeInputs = [
        wf-recorder
        slurp
        jq
      ];
      text = builtins.readFile ./screen-rec.sh;
    })
  ];

  home.file =
    builtins.listToAttrs (
      map (s: {
        name = ".claude/skills/${s}";
        value.source = live "skills/${s}";
      }) skills
    )
    // builtins.listToAttrs (
      map (a: {
        name = ".claude/agents/${a}";
        value.source = live "agents/${a}";
      }) agents
    );
}
