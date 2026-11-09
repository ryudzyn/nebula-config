# local-llm -- локальна модель (llama-server, Vulkan на Arc A770) для /arena --local.
#   local-llm start    -- запустити сервіс і дочекатися, поки модель завантажиться
#   local-llm stop     -- зупинити (звільнити відеопам'ять, напр. перед грою)
#   local-llm status   -- чи працює і на якому порту
# Сервер: systemd user unit local-llm (crew/claude/default.nix), OpenAI API на
# 127.0.0.1:8090. Модель -- ~/models/gpt-oss-20b-MXFP4.gguf.

url="http://127.0.0.1:8090"

case "${1:-status}" in
start)
  systemctl --user start local-llm
  # завантаження 12 ГБ у відеопам'ять займає до хвилини
  for _ in $(seq 1 120); do
    if curl -fsS --max-time 2 "$url/health" >/dev/null 2>&1; then
      echo "local-llm: ready at $url"
      exit 0
    fi
    systemctl --user is-active --quiet local-llm || {
      echo "local-llm: service failed, see: journalctl --user -u local-llm -n 50" >&2
      exit 1
    }
    sleep 1
  done
  echo "local-llm: not ready after 120 s, see: journalctl --user -u local-llm -n 50" >&2
  exit 1
  ;;
stop)
  systemctl --user stop local-llm
  ;;
status)
  if curl -fsS --max-time 2 "$url/health" >/dev/null 2>&1; then
    echo "local-llm: ready at $url"
  else
    echo "local-llm: not running"
    exit 1
  fi
  ;;
*)
  echo "usage: local-llm start|stop|status" >&2
  exit 2
  ;;
esac
