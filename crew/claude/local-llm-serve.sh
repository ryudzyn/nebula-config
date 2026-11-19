# local-llm-serve -- ExecStart сервісу local-llm: запускає llama-server з моделлю,
# яку вибрав `local-llm start <модель>` (записано в $state, за замовчуванням qwen35b).
# Усі моделі -- у ~/models, API на 127.0.0.1:8090, 4 паралельні слоти зі спільним контекстом 64k
# (--kv-unified, 2026-11-19: по 16k на слот довгі запити арени обрізались або висли до таймауту).

state="${XDG_STATE_HOME:-$HOME/.local/state}/local-llm/model"
model=$(cat "$state" 2>/dev/null || echo qwen35b)

common=(--host 127.0.0.1 --port 8090 -c 65536 --parallel 4 --kv-unified --jinja)
case "$model" in
qwen9b)
  # 9.5 ГБ, повністю у відеопам'яті
  args=(-m "$HOME/models/Qwen3.5-9B-Q8_0.gguf" -ngl 99)
  vision="$HOME/models/mmproj-Qwen3.5-9B-F16.gguf"
  ;;
qwen35b)
  # 20.5 ГБ MoE -- не влазить у 16 ГБ; --fit сам вирішує, скільки
  # експертів лишити в оперативній пам'яті
  args=(-m "$HOME/models/Qwen3.6-35B-A3B-Q4_K_M.gguf" --fit on)
  vision="$HOME/models/mmproj-Qwen3.6-35B-A3B-Q8_0.gguf"
  ;;
*)
  echo "local-llm-serve: unknown model '$model' in $state" >&2
  exit 1
  ;;
esac

# Зір (фото в запитах; автопідписи медіатеки Nebula Hub): проєктор з того ж репозиторію HF, що й
# модель (unsloth/Qwen3.5-9B-GGUF mmproj-F16, ggml-org/Qwen3.6-35B-A3B-GGUF mmproj-Q8_0). Немає
# файлу -- модель стартує як раніше, без зору.
[ -n "${vision:-}" ] && [ -f "$vision" ] && args+=(--mmproj "$vision")

exec llama-server "${args[@]}" "${common[@]}"
