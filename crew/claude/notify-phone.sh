# notify-phone -- пуш на телефон через локальний ntfy (constellations/comms.nix).
#   notify-phone "текст"                       -- звичайне сповіщення
#   notify-phone -t "Заголовок" -p high -g warning "текст"
# -p: min|low|default|high|urgent, -g: теги ntfy (emoji-шорткоди, через кому).
# Топік: $NOTIFY_TOPIC (за замовчуванням claude).

title="Claude Code"
priority="default"
tags=""
while getopts "t:p:g:" opt; do
  case "$opt" in
  t) title="$OPTARG" ;;
  p) priority="$OPTARG" ;;
  g) tags="$OPTARG" ;;
  *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || {
  echo "usage: notify-phone [-t title] [-p priority] [-g tags] message" >&2
  exit 2
}

# Заголовок -- параметром URL, не HTTP-хедером: хедери не несуть кирилицю надійно
curl -fsS --max-time 10 \
  --url-query "title=$title" --url-query "priority=$priority" ${tags:+--url-query "tags=$tags"} \
  --data-binary "$*" "http://127.0.0.1:2586/${NOTIFY_TOPIC:-claude}" >/dev/null
