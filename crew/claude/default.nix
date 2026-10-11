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
