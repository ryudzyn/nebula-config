# local-llm-serve -- ExecStart сервісу local-llm: запускає llama-server з моделлю,
# яку вибрав `local-llm start <модель>` (записано в $state, за замовчуванням gpt-oss).
# Усі моделі -- у ~/models, API на 127.0.0.1:8090, 4 паралельні слоти по 16k.

state="${XDG_STATE_HOME:-$HOME/.local/state}/local-llm/model"
model=$(cat "$state" 2>/dev/null || echo gpt-oss)

common=(--host 127.0.0.1 --port 8090 -c 65536 --parallel 4 --jinja)
case "$model" in
gpt-oss)
  # 12 ГБ, повністю у відеопам'яті
  args=(-m "$HOME/models/gpt-oss-20b-MXFP4.gguf" -ngl 99)
  ;;
qwen9b)
  # 9.5 ГБ, повністю у відеопам'яті
  args=(-m "$HOME/models/Qwen3.5-9B-Q8_0.gguf" -ngl 99)
  ;;
qwen35b)
  # 20.5 ГБ MoE -- не влазить у 16 ГБ; --fit сам вирішує, скільки
  # експертів лишити в оперативній пам'яті
  args=(-m "$HOME/models/Qwen3.6-35B-A3B-Q4_K_M.gguf" --fit on)
  ;;
*)
  echo "local-llm-serve: unknown model '$model' in $state" >&2
  exit 1
  ;;
esac

exec llama-server "${args[@]}" "${common[@]}"
