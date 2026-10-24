# screen-rec -- коротке відео екрана Hyprland для /watch (wf-recorder).
#   screen-rec [-s секунди] [-w | -o монітор | -g "x,y WxH" | -r] [-a] [вихідний.mp4]
#   -s  тривалість, за замовчуванням 10
#   -w  лише активне вікно;  -o  конкретний монітор;  -g  область;  -r  вибрати мишкою (slurp)
#   -a  зі звуком (системний вихід за замовчуванням)
# Без -w/-o/-g/-r -- монітор у фокусі. Друкує шлях до файлу.

secs=10 mode=focused geom="" output="" audio=""
while getopts "s:wo:g:ra" opt; do
  case "$opt" in
  s) secs="$OPTARG" ;;
  w) mode=window ;;
  o) mode=output output="$OPTARG" ;;
  g) mode=geom geom="$OPTARG" ;;
  r) mode=geom geom=$(slurp) ;;
  a) audio=1 ;;
  *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
file="${1:-$(mktemp -u "${TMPDIR:-/tmp}/screen-rec-XXXXXX.mp4")}"

# Фонові сесії (Claude Code job, ssh) не мають змінних робочого столу -- знаходимо самі
run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(find "$run/hypr" -mindepth 1 -maxdepth 1 -printf '%f\n' | head -1)
  export HYPRLAND_INSTANCE_SIGNATURE
fi
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  WAYLAND_DISPLAY=$(find "$run" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1)
  export WAYLAND_DISPLAY XDG_RUNTIME_DIR="$run"
fi
case "$mode" in
focused) output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name') ;;
window) geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
esac

args=(-y -f "$file" -r 30 -c libx264 -p preset=veryfast -p crf=28)
if [ -n "$geom" ]; then args+=(-g "$geom"); else args+=(-o "$output"); fi
[ -n "$audio" ] && args+=(--audio)

# wf-recorder пише до SIGINT; timeout шле саме його, щоб mp4 коректно закрився
timeout -s INT "$secs" wf-recorder "${args[@]}" >/dev/null 2>&1 || true
[ -s "$file" ] || {
  echo "screen-rec: запис не вдався" >&2
  exit 1
}
echo "$file"
