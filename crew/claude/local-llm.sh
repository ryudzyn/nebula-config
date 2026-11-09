# local-llm -- локальна модель (llama-server, Vulkan на Arc A770) для /arena --local.
#   local-llm start [модель]  -- запустити (або перемкнути) модель і дочекатися готовності
#   local-llm stop            -- зупинити (звільнити відеопам'ять, напр. перед грою)
#   local-llm status          -- чи працює, яка модель
#   local-llm models          -- список моделей
# Моделі (у ~/models): gpt-oss (за замовчуванням), qwen9b, qwen35b -- параметри
# кожної в local-llm-serve.sh. Сервер: systemd user unit local-llm
# (crew/claude/default.nix), OpenAI API на 127.0.0.1:8090.

url="http://127.0.0.1:8090"
state="${XDG_STATE_HOME:-$HOME/.local/state}/local-llm/model"
models="gpt-oss qwen9b qwen35b"

current() { cat "$state" 2>/dev/null || echo gpt-oss; }

case "${1:-status}" in
start)
  model="${2:-$(current)}"
  case " $models " in
  *" $model "*) ;;
  *)
    echo "local-llm: unknown model '$model' (one of: $models)" >&2
    exit 2
    ;;
  esac
  mkdir -p "$(dirname "$state")"
  echo "$model" >"$state"
  # restart: якщо працює інша модель -- перемкнути на вибрану
  systemctl --user restart local-llm
  # завантаження моделі у відеопам'ять займає до кількох хвилин
  for _ in $(seq 1 300); do
    if curl -fsS --max-time 2 "$url/health" >/dev/null 2>&1; then
      echo "local-llm: $model ready at $url"
      exit 0
    fi
    systemctl --user is-active --quiet local-llm || {
      echo "local-llm: service failed, see: journalctl --user -u local-llm -n 50" >&2
      exit 1
    }
    sleep 1
  done
  echo "local-llm: not ready after 300 s, see: journalctl --user -u local-llm -n 50" >&2
  exit 1
  ;;
stop)
  systemctl --user stop local-llm
  ;;
status)
  if curl -fsS --max-time 2 "$url/health" >/dev/null 2>&1; then
    echo "local-llm: $(current) ready at $url"
  else
    echo "local-llm: not running (selected model: $(current))"
    exit 1
  fi
  ;;
models)
  echo "$models"
  ;;
*)
  echo "usage: local-llm start [gpt-oss|qwen9b|qwen35b] | stop | status | models" >&2
  exit 2
  ;;
esac
