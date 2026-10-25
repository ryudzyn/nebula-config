# nebula-weekly-report -- щотижневий звіт про стан earth на телефон (ntfy).
# Нічого не змінює. Розділи: диск, SMART (знімок від smart-snapshot.service),
# впалі сервіси, бекап restic, оновлення флейка (на КОПІЇ flake.lock).
#   nebula-weekly-report [--print]   (--print: лише вивести, без сповіщення)

repo="${NEBULA_REPO:-$HOME/nebula-config}"
warn=0
lines=()
add() { lines+=("$1"); }
bad() {
  lines+=("⚠️ $1")
  warn=1
}

# --- Диск
read -r avail pct < <(df -h / | awk 'NR==2 {print $4, $5}')
if [ "${pct%\%}" -ge 90 ]; then bad "Диск: $pct зайнято, вільно $avail (/disk-cleanup)"; else add "💾 Диск: $pct, вільно $avail"; fi

# --- SMART
for f in /var/lib/smart-snapshot/*.json; do
  [ -s "$f" ] || continue
  dev=$(basename "$f" .json)
  passed=$(jq -r '.smart_status.passed // "?"' "$f")
  hours=$(jq -r '.power_on_time.hours // "?"' "$f")
  wear=$(jq -r '(.ata_smart_attributes.table[]? | select(.id==177) | .value) // (if .nvme_smart_health_information_log then 100 - .nvme_smart_health_information_log.percentage_used else empty end) // "?"' "$f")
  realloc=$(jq -r '(.ata_smart_attributes.table[]? | select(.id==5) | .raw.value) // 0' "$f")
  tbw=$(jq -r '(.ata_smart_attributes.table[]? | select(.id==241) | .raw.value * 512 / 1e12 | . * 10 | floor / 10) // "?"' "$f")
  age=$((($(date +%s) - $(stat -c %Y "$f")) / 86400))
  msg="$dev: SMART $passed, ресурс ${wear}%, записано ${tbw} ТБ, ${hours} год, realloc $realloc"
  if [ "$passed" != "true" ] || [ "$realloc" != 0 ] || { [ "$wear" != "?" ] && [ "$wear" -lt 20 ]; }; then bad "$msg"; else add "🩺 $msg"; fi
  [ "$age" -gt 3 ] && bad "SMART-знімок застарий ($age дн.) -- smart-snapshot.timer працює?"
done

# --- Впалі сервіси
failed=$( { systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } | awk '{print $1}' | paste -sd, -)
if [ -n "$failed" ]; then bad "Впалі сервіси: $failed"; else add "✅ Впалих сервісів немає"; fi

# --- Бекап (services.restic.backups.hetzner)
# Час останнього збереженого знімка -- з журналу: Result/ExecMainExitTimestamp юніта скидаються
# на кожному sysup (так перший звіт 2026-10-25 хибно сказав «ще не запускався»). Окремий збій
# і так шле пуш (restic-backup-failed); тут ловимо, що успішних бекапів давно немає.
if systemctl cat restic-backups-hetzner.service >/dev/null 2>&1; then
  last=$(journalctl -u restic-backups-hetzner -g 'snapshot [0-9a-f]+ saved' -n 1 -o short-unix --no-pager -q 2>/dev/null |
    awk '{print int($1)}')
  if [ -z "$last" ]; then
    bad "Бекап: жодного збереженого знімка в журналі"
  else
    days=$((($(date +%s) - last) / 86400))
    if [ "$days" -gt 2 ]; then bad "Бекап: останній успішний $days дн. тому"; else add "☁️ Бекап: ок, $days дн. тому"; fi
  fi
fi

# --- Оновлення флейка (копія flake.lock, репо не чіпаємо)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$repo/flake.nix" "$repo/flake.lock" "$tmp/"
if nix flake update --flake "path:$tmp" >/dev/null 2>&1; then
  changes=$(jq -rn --slurpfile a "$repo/flake.lock" --slurpfile b "$tmp/flake.lock" '
    ($a[0].nodes.root.inputs | to_entries[]) as $i
    | ($a[0].nodes[$i.value].locked.lastModified) as $o
    | ($b[0].nodes[$b[0].nodes.root.inputs[$i.key]].locked.lastModified) as $n
    | select($o != $n) | $i.key' | paste -sd, -)
  age=$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].locked.lastModified' "$repo/flake.lock")
  days=$((($(date +%s) - age) / 86400))
  lockstep=$(jq -r '(.nodes[.nodes.root.inputs.nixpkgs].locked.rev) == (.nodes[.nodes.noctalia.inputs.nixpkgs].locked.rev)' "$tmp/flake.lock")
  if [ -n "$changes" ]; then
    add "📦 Оновлення: $changes (nixpkgs у системі $days дн.) -- /flake-bump"
    [ "$lockstep" = "false" ] && add "   Noctalia на іншому nixpkgs -- /flake-bump перевірить glibc"
  else
    add "📦 Оновлень немає (nixpkgs $days дн.)"
  fi
else
  bad "nix flake update не вдався -- подивись вручну"
fi

msg=$(printf '%s\n' "${lines[@]}")
if [ "${1:-}" = "--print" ]; then
  echo "$msg"
else
  if [ "$warn" = 1 ]; then prio=high tags=warning; else prio=low tags=white_check_mark; fi
  notify-phone -t "earth: тижневий звіт" -p "$prio" -g "$tags" "$msg"
fi
