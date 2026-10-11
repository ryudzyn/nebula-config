#!/usr/bin/env bash
# Statusline Claude Code: модель · контекст · ліміти підписки · вартість · git-гілка.
# Підключено в ~/.claude/settings.json (statusLine.command) прямо з цього репо,
# тож правки діють з наступного оновлення рядка, без switch.
# Останній вхідний JSON зберігається в ~/.cache/claude-statusline.json --
# зручно, щоб подивитись, які поля CLI реально передає.

export LC_NUMERIC=C # printf %.2f з uk_UA чекає кому замість крапки
input=$(cat)
printf '%s' "$input" > "${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline.json" 2>/dev/null

j() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

# Колір за відсотком: зелений < 50, жовтий < 80, червоний далі
pct_color() {
  local p=${1%.*}
  if [ -z "$p" ]; then printf ''; elif [ "$p" -lt 50 ]; then printf '\033[32m'; elif [ "$p" -lt 80 ]; then printf '\033[33m'; else printf '\033[31m'; fi
}
dim=$'\033[2m'; rst=$'\033[0m'

model=$(j '.model.display_name')
ctx=$(j '.context_window.used_percentage')
cost=$(j '.cost.total_cost_usd')
h5=$(j '.rate_limits.five_hour.used_percentage')
d7=$(j '.rate_limits.seven_day.used_percentage')
dir=$(j '.workspace.current_dir')
branch=$(git -C "${dir:-.}" --no-optional-locks branch --show-current 2>/dev/null)

out="${model:-?}"
[ -n "$ctx" ] && out+=" ${dim}│${rst} ctx $(pct_color "$ctx")${ctx%.*}%${rst}"
# Ліміт ≥ 80% -- дописуємо, коли скинеться (resets_at -- unix-час)
limit() {
  local name=$1 p=$2 at=$3
  [ -z "$p" ] && return
  out+=" ${dim}│${rst} $name $(pct_color "$p")${p%.*}%${rst}"
  [ "${p%.*}" -ge 80 ] && [ -n "$at" ] && out+="${dim} ↻$(date -d "@$at" +"%a %H:%M")${rst}"
}
limit 5h "$h5" "$(j .rate_limits.five_hour.resets_at)"
limit 7d "$d7" "$(j .rate_limits.seven_day.resets_at)"
[ -n "$cost" ] && out+=" ${dim}│ \$$(printf '%.2f' "$cost")${rst}"
[ -n "$branch" ] && out+=" ${dim}│${rst}  ${branch}"
printf '%s' "$out"
