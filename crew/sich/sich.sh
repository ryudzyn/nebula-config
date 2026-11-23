# sich -- клієнт голосового асистента Січ (Nebula Hub: nebula_hub/assistant.py, voice.py).
#   sich start        -- почати запис з мікрофона (SUPER+Z натиснуто)
#   sich stop         -- зупинити й віддати Січу (SUPER+Z або Super відпущено); без запису -- нічого
#   sich type         -- ввести фразу текстом у віконці (SUPER+SHIFT+Z)
#   sich say "фраза"  -- те саме з термінала
# Слухає лише між start і stop (не довше MAX секунд). Стан показує супутник Січ в ETEA
# (modules/sich у форку: etea-ipc sich listening|think|answer|hide), відповідь ще й голосом
# (HolosTTS). ETEA не відповідає -- те саме одним сповіщенням, що оновлюється.

run="${XDG_RUNTIME_DIR:-/tmp}/sich"
hub="${SICH_HUB:-http://127.0.0.1:8095}"
MAX=30
mkdir -p "$run"

owner() { tailscale status --json | jq -r '.User[(.Self.UserID | tostring)].LoginName'; }

sat() { # супутник в ETEA; 1 -- не вийшло. Код виходу qs ipc завжди 0 (і на «Target not found»),
  # а вдалий виклик void-функції нічого не друкує -- тож судимо з виводу
  local out
  out=$(etea-ipc sich "$@" 2>&1) && [ -z "$out" ]
}

note() { # запасний шлях без ETEA: $1 -- заголовок, $2 -- текст; одне сповіщення, що оновлюється
  local id
  id=$(cat "$run/note" 2>/dev/null || echo 0)
  notify-send -a "Січ" -p -r "$id" -t "${3:-30000}" "$1" "${2:-}" >"$run/note.tmp" 2>/dev/null &&
    mv "$run/note.tmp" "$run/note"
}

answer() { # $1 -- JSON від хаба
  local heard said audio
  heard=$(jq -r '.text // ""' <<<"$1")
  said=$(jq -r '.say // ""' <<<"$1")
  audio=$(jq -r '.audio // ""' <<<"$1")
  if [ -z "$heard" ]; then
    sat answer "" "Нічого не почув." || note "Січ" "Нічого не почув." 4000
    return
  fi
  sat answer "$heard" "$said" || note "Січ" "«$heard»${said:+
$said}" 12000
  [ -n "$audio" ] && [ -f "$audio" ] && pw-play "$audio"
}

fail() {
  sat answer "" "Хаб не відповів." || note "Січ" "Хаб не відповів: $1" 8000
  exit 1
}

case "${1:-}" in
start)
  [ -f "$run/pid" ] && kill -0 "$(cat "$run/pid")" 2>/dev/null && exit 0
  # запасний бінд «відпустив Super -- стоп» (hyprland.lua ставить його таймером) після sysup
  # бувало зникав (2026-11-23) -- відновити, якщо нема
  hyprctl binds -j 2>/dev/null | jq -e 'any(.[]; .key == "Super_L" and .release)' >/dev/null ||
    hyprctl eval 'hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("sich stop"), { release = true })' >/dev/null 2>&1 || true
  rm -f "$run/rec.wav"
  timeout "$MAX" pw-record --rate 16000 --channels 1 --format s16 "$run/rec.wav" &
  echo $! >"$run/pid"
  sat listening || note "Січ слухає…" "" "$((MAX * 1000))"
  ;;
stop)
  [ -f "$run/pid" ] || exit 0
  pid=$(cat "$run/pid")
  rm -f "$run/pid"
  kill -INT "$pid" 2>/dev/null
  for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
  # коротше ~0.4 с (16 кГц × 2 байти) -- випадковий дотик, не фраза
  if [ "$(stat -c %s "$run/rec.wav" 2>/dev/null || echo 0)" -lt 13000 ]; then
    sat answer "" "Тримай Super+Z, поки говориш." || note "Січ" "Тримай Super+Z, поки говориш." 3000
    exit 0
  fi
  sat think "" || note "Січ думає…" ""
  out=$(curl -fsS --max-time 180 -H "Tailscale-User-Login: $(owner)" -H "Content-Type: audio/wav" \
    --data-binary "@$run/rec.wav" "$hub/api/assistant/voice" 2>&1) || fail "$out"
  answer "$out"
  ;;
type | say)
  if [ "$1" = type ]; then
    text=$(zenity --entry --title="Січ" --text="Що зробити?" --width=420) || exit 0
  else
    shift
    text="$*"
  fi
  [ -n "${text// /}" ] || exit 0
  sat think "$text" || note "Січ думає…" "$text"
  out=$(jq -n --arg t "$text" '{text: $t, speak: true}' |
    curl -fsS --max-time 180 -H "Tailscale-User-Login: $(owner)" -H "Content-Type: application/json" \
      --data-binary @- "$hub/api/assistant" 2>&1) || fail "$out"
  answer "$(jq --arg t "$text" '.text = $t' <<<"$out")"
  ;;
*)
  echo "usage: sich start | stop | type | say \"фраза\"" >&2
  exit 2
  ;;
esac
