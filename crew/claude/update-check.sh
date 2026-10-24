# nebula-update-check -- щотижневий звіт про доступні оновлення інпутів флейка.
# Нічого не змінює: оновлює КОПІЮ flake.lock у тимчасовій теці, порівнює дати,
# перевіряє, чи nixpkgs у Noctalia не відстає від системного (пастка glibc), і шле
# підсумок на телефон. Застосування -- вручну через /flake-bump.
#   nebula-update-check [--print]   (--print: лише вивести, без сповіщення)

repo="${NEBULA_REPO:-$HOME/nebula-config}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$repo/flake.nix" "$repo/flake.lock" "$tmp/"
nix flake update --flake "path:$tmp" >/dev/null 2>&1 || {
  msg="nix flake update не вдався -- подивись вручну"
  if [ "${1:-}" = "--print" ]; then
    echo "$msg"
  else
    notify-phone -t "nebula: перевірка оновлень" -p high -g warning "$msg"
  fi
  exit 1
}

# Дати кожного кореневого інпуту: було -> стало
changes=$(jq -rn --slurpfile a "$repo/flake.lock" --slurpfile b "$tmp/flake.lock" '
  ($a[0].nodes.root.inputs | to_entries[]) as $i
  | ($a[0].nodes[$i.value].locked.lastModified) as $o
  | ($b[0].nodes[$b[0].nodes.root.inputs[$i.key]].locked.lastModified) as $n
  | select($o != $n)
  | "\($i.key): \($o | strftime("%d.%m")) → \($n | strftime("%d.%m"))"')

age=$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].locked.lastModified' "$repo/flake.lock")
days=$((($(date +%s) - age) / 86400))

lockstep=$(jq -r '
  (.nodes[.nodes.root.inputs.nixpkgs].locked.rev) as $s
  | (.nodes[.nodes.noctalia.inputs.nixpkgs].locked.rev) as $n
  | if $s == $n then "Noctalia в lockstep з nixpkgs ✅"
    else "⚠️ Noctalia на іншому nixpkgs — перед bump перевірити glibc (/flake-bump)" end' "$tmp/flake.lock")

if [ -z "$changes" ]; then
  msg="Оновлень немає. nixpkgs у системі: $days дн."
  prio=low
else
  msg=$(printf 'Доступні оновлення:\n%s\n\nnixpkgs у системі: %s дн.\n%s\nЗастосувати: /flake-bump' "$changes" "$days" "$lockstep")
  prio=default
fi

if [ "${1:-}" = "--print" ]; then
  echo "$msg"
else
  notify-phone -t "nebula: оновлення" -p "$prio" -g package "$msg"
fi
