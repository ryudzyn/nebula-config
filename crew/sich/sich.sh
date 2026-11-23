# sich -- клієнт голосового асистента Січ (Nebula Hub: nebula_hub/assistant.py, voice.py).
#   sich start        -- почати запис з мікрофона (SUPER+Z натиснуто)
#   sich stop         -- зупинити й віддати Січу (SUPER+Z або Super відпущено); без запису -- нічого
#   sich type         -- ввести фразу текстом у віконці (SUPER+SHIFT+Z)
#   sich say "фраза"  -- те саме з термінала
# Слухає лише між start і stop (не довше MAX секунд). Відповідь -- сповіщенням і голосом
# (HolosTTS); поки нема супутника в ETEA (етап 3), стан видно в одному сповіщенні, що оновлюється.

run="${XDG_RUNTIME_DIR:-/tmp}/sich"
hub="${SICH_HUB:-http://127.0.0.1:8095}"
MAX=30
mkdir -p "$run"

owner() { tailscale status --json | jq -r '.User[(.Self.UserID | tostring)].LoginName'; }

note() { # $1 -- заголовок, $2 -- текст; одне сповіщення, що оновлюється
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
    note "Січ" "Нічого не почув." 4000
    return
  fi
  note "Січ" "«$heard»${said:+
$said}" 12000
  [ -n "$audio" ] && [ -f "$audio" ] && pw-play "$audio"
}

fail() { note "Січ" "Хаб не відповів: $1" 8000; exit 1; }

case "${1:-}" in
start)
  [ -f "$run/pid" ] && kill -0 "$(cat "$run/pid")" 2>/dev/null && exit 0
  rm -f "$run/rec.wav"
  timeout "$MAX" pw-record --rate 16000 --channels 1 --format s16 "$run/rec.wav" &
  echo $! >"$run/pid"
  note "Січ слухає…" "" "$((MAX * 1000))"
  ;;
stop)
  [ -f "$run/pid" ] || exit 0
  pid=$(cat "$run/pid")
  rm -f "$run/pid"
  kill -INT "$pid" 2>/dev/null
  for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
  # коротше ~0.4 с (16 кГц × 2 байти) -- випадковий дотик, не фраза
  if [ "$(stat -c %s "$run/rec.wav" 2>/dev/null || echo 0)" -lt 13000 ]; then
    note "Січ" "Тримай Super+Z, поки говориш." 3000
    exit 0
  fi
  note "Січ думає…" ""
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
  note "Січ думає…" "$text"
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
