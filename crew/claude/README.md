# Claude Code: плагіни, скіли, агенти

Декларативна частина — `default.nix` (бінарники LSP/MCP + живі симлінки на `skills/` і `agents/`).
Плагіни ставляться командами нижче: їх стан веде сам Claude Code у `~/.claude/plugins`,
тож на новій машині ці команди треба виконати один раз вручну.

## Плагіни (user scope)

```sh
claude plugin marketplace add ~/nebula-config/crew/claude/marketplace   # локальний "nebula"
for p in commit-commands claude-md-management hookify claude-code-setup \
         lua-lsp jdtls-lsp rust-analyzer-lsp context7; do
  claude plugin install $p@claude-plugins-official -s user
done
claude plugin install nixd-lsp@nebula -s user
claude plugin install kotlin-ls@nebula -s user
claude mcp add -s user playwright -- playwright-mcp
```

| Плагін | Для чого |
|---|---|
| commit-commands | `/commit`, `/commit-push-pr` |
| claude-md-management | аудит CLAUDE.md, збір уроків із сесії в CLAUDE.md |
| hookify | хуки з опису природною мовою ("не дозволяй X") |
| claude-code-setup | аналізує репо і радить автоматизації |
| lua-lsp / nixd-lsp | діагностика для `hyprland.lua` і `.nix` одразу після правки |
| jdtls-lsp / kotlin-ls / rust-analyzer-lsp | моди (Java), Orbit (Kotlin), halley (Rust) |
| context7 | свіжа документація бібліотек (NeoForge, Android, Hyprland…) |
| playwright (MCP) | керування браузером; бінарник з nixpkgs, не `npx` |

`marketplace/` — власні LSP-обгортки: для Nix в офіційному маркетплейсі нічого немає, а офіційний
`kotlin-lsp` (JetBrains) не запакований у nixpkgs, тож `kotlin-ls` запускає fwcd/kotlin-language-server.

## Скіли (`skills/`)

- `/nixcheck` — nixfmt змінених файлів, перевірка imports, dry-build через `nix-builder`, звіт.
- `/orbit-ship` — bump версії, assembleDebug, adb install, скриншот з телефона.
- `/hypr-verify` — `hyprctl reload`, configerrors, перевірка фокусу, grim-скриншот.
- `/mod-port` — порт Ascension на 1.21.1 NeoForge: setup worktree `~/Projects/ascension-1211` (гілка `neoforge-1.21.1` з `ascension-night` master), далі по одній фічі з `forge-1.20.1` — build, GameTests, живий клієнт, коміт, чекліст у `PORT_1.21.1.md`.
- `/arena` — турнір субагентів за одне завдання (вендорено з [arena-skill](https://github.com/Jakeschincariol/arena-skill) @ `df07b8e`, MIT). **Дорого**: 100 агентів = 595 викликів; для щоденного — `--quick` (16 агентів, 91 виклик) або `--agents 8` (43). Запускати в accept-edits (Shift+Tab), інакше — підтвердження на кожен файл у `.arena/`.

## Statusline

`statusline.sh` — модель │ % контексту │ ліміти підписки 5h/7d (≥80% — з часом скидання ↻) │ $ сесії │ git-гілка.
Підключається в `~/.claude/settings.json` (поза репо):
`"statusLine": {"type": "command", "command": "bash ~/nebula-config/crew/claude/statusline.sh"}`.

## Агенти (`agents/`, модель haiku — економія токенів)

- `nix-builder` — запускає nix-збірки і повертає вердикт замість сирого логу.
- `log-digger` — читає journalctl/логи збірок і повертає лише суттєві рядки.

Аліас `haiku` з claude-code ≥ 2.1.295 указує на Haiku 5.5 (у 10× дешевша за 4.5).
