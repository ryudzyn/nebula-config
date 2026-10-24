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
- `/post-switch` — перевірка після `sysup`, нічого не змінює: впалі юніти (системні й користувацькі), помилки в журналі з моменту switch,
  Home Manager, Noctalia, чи greetd досі на старому конфігу (тоді треба `restart greetd`), биті симлінки скілів.
- `/flake-bump` — `nix flake update` з перевіркою, що nixpkgs у Noctalia збігається з системним (пастка glibc),
  повна збірка без switch і підсумок `nvd diff` (ядро, mesa, hyprland, claude-code…). `flake.lock` комітить лише за згодою.
- `/arena` — турнір субагентів за одне завдання (вендорено з [arena-skill](https://github.com/Jakeschincariol/arena-skill) @ `df07b8e`, MIT). **Дорого**: 100 агентів = 595 викликів; для щоденного — `--quick` (16 агентів, 91 виклик) або `--agents 8` (43). Запускати в accept-edits (Shift+Tab), інакше — підтвердження на кожен файл у `.arena/`.

### Вендорені сторонні скіли

Скопійовано лише `SKILL.md` + ліцензію з перевіреного коміту. Хуки, телеметрію й плагінну обв'язку
свідомо не беремо.

- `/ponytail` (`lite|full|ultra|off`) — режим «лінивого сеньйора»: найменша повна зміна, без зайвих
  абстракцій і залежностей. `/ponytail-debt` — збирає коментарі `shortcut:` у список боргу.
  [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) @ `09c434a`, MIT. Без Node-хуків
  оригінального плагіна, тому сам на старті сесії не вмикається: модель бере його за описом або
  через `/ponytail`.
- `/interview-me`, `/debugging-and-error-recovery`, `/source-driven-development` — з
  [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) @ `aeac41d`, MIT. Решту 22 скіли не
  брали: дублюють `code-review`/`simplify`/`security-review` і засмічують контекст описами.
- `/graphify [шлях]` — граф знань по коду й документах (`graph.html`, `GRAPH_REPORT.md`, `graph.json` у
  `graphify-out/`). [safishamsi/graphify](https://github.com/safishamsi/graphify) @ `92741d1`, Apache-2.0/MIT.
  Наші правки: `disable-model-invocation: true` (лише вручну, переважно для мода) і пін
  `graphifyy==0.9.95` у командах встановлення. Python-частину скіл ставить сам через
  `uv tool install graphifyy==0.9.95` при першому запуску (`uv` у `home.packages`, колеса працюють через nix-ld).
  Тільки по коду, без LLM: `graphify update .`. `graphify install` **не запускати**: він дописує
  `~/.claude/CLAUDE.md`.
- `/security-audit` — аудит безпеки всього репо від Cloudflare
  ([cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) @ `c1c8a8c`, MIT), без змін.
  Звичайне питання про безпеку вмикає легкий режим без файлів. Повний аудит (6 фаз, незалежна перевірка
  кожної знахідки) запускається лише на явне «audit this codebase». **Дорого**: просити профіль `quick` і,
  за потреби, бюджет агентів. Звіти пишуться в `~/security-audit-skill/<repo>/run-N`, поза репо. Валідатори
  `.cjs` потребують `nodejs` (є в `home.packages`). Чужий код без пісочниці не запускає, знахідку лишає `needs_validation`.
  На відміну від `/security-review`, дивиться весь репозиторій, а не диф.
- `/minecraft-testing` — JUnit і NeoForge GameTests для мода
  ([jahrome907/minecraft-agent-skills](https://github.com/jahrome907/minecraft-agent-skills) @ `30137f9`, MIT; з 13 скілів репо
  взяли лише цей). Правка: в оригіналі анотаційні `@GameTestHolder` позначені як «тільки 1.21.3», хоча це API і 1.21.1
  (перевірено в `ascension-1211`). Data-driven тести з 1.21.5+ для порту не використовувати.
- `hyprland-lua` — довідник Lua-API Hyprland (`hl.bind`, `hl.dsp.*`, події, правила)
  ([janusfil/ai-skills](https://github.com/janusfil/ai-skills) @ `3082711`, Apache-2.0). Писаний під 0.55, на earth 0.56.x, тож
  головне джерело — стаби `/run/current-system/sw/share/hypr/stubs/hl.meta.lua` (у скілі виправлено з `/usr/share`).
  Додано: конфіг живе в `crew/hyprland/`, живі команди через `hyprctl eval`.
- `kotlin-coroutines-flows`, `kotlin-patterns`, `kotlin-testing` — для Orbit, з [affaan-m/ECC](https://github.com/affaan-m/ECC)
  @ `90606c8`, MIT. Узяли лише 3 SKILL.md, без хуків, пам'яті й установника ECC: вони спрацьовують на кожен виклик інструмента
  і конфліктують з нашою пам'яттю. Додано примітку: Orbit тестується на JUnit 4 і `kotlinx-coroutines-test`, тож
  Kotest, MockK, Kover, detekt і Turbine (є в `libs.versions.toml`, але не підключений) без згоди не додавати.

- `/watch <url|файл>` — «дивлюсь» відео: yt-dlp завантажує його, ffmpeg вирізає кадри на зміні сцен (до 100), текст береться
  з субтитрів, а коли їх немає, з WhisperX
  ([bradautomates/claude-video](https://github.com/bradautomates/claude-video) @ `03ceb42`, MIT). SessionStart-хук плагіна не беремо.
  Налаштування лежать у `~/.config/watch/.env`, поза репо: `WATCH_ENGINE=local`, `WATCH_WHISPER_BACKEND=whisperx`,
  `WATCH_COOKIES_FROM_BROWSER` на профіль Zen (для рілсів). WhisperX стоїть у `~/.cache/watch/whisperx-venv` (uv, CPU-torch, nix-ld).
  Gemini — лише вручну: `--engine gemini` і `GEMINI_API_KEY` у тому ж `.env`; відео тоді йде в Google.

## Statusline

`statusline.sh` — модель │ % контексту │ ліміти підписки 5h/7d (≥80% — з часом скидання ↻) │ $ сесії │ git-гілка.
Підключається в `~/.claude/settings.json` (поза репо):
`"statusLine": {"type": "command", "command": "bash ~/nebula-config/crew/claude/statusline.sh"}`.

## Агенти (`agents/`, модель haiku — економія токенів)

- `nix-builder` — запускає nix-збірки і повертає вердикт замість сирого логу.
- `log-digger` — читає journalctl/логи збірок і повертає лише суттєві рядки.

Аліас `haiku` з claude-code ≥ 2.1.295 указує на Haiku 5.5 (у 10× дешевша за 4.5).
