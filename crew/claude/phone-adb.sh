# phone-adb -- adb до телефона через Tailscale без кабелю.
# Бездротове налагодження Android міняє порт при кожному ввімкненні, а спарювання
# (adb pair) лишається -- тож шукаємо відкритий порт і підключаємось самі.
#   phone-adb            -> друкує serial (export ANDROID_SERIAL=$(phone-adb))
#   phone-adb <args...>  -> adb -s <serial> <args...>
# Ім'я пристрою в tailnet: $PHONE_ADB_HOST (за замовчуванням pixel-11).

name="${PHONE_ADB_HOST:-pixel-11}"
host=$(tailscale ip -4 "$name" 2>/dev/null) || {
  echo "phone-adb: '$name' не знайдено в tailnet" >&2
  exit 1
}

connected() {
  adb devices | awk -v h="$host" '$2 == "device" && index($1, h ":") == 1 { print $1; exit }'
}

serial=$(connected)
if [ -z "$serial" ]; then
  # Порт бездротового налагодження -- випадковий з діапазону ефемерних
  ports=$(nmap -Pn -T5 --min-rate 5000 -p 30000-49999 --open -oG - "$host" 2>/dev/null |
    grep -oE '[0-9]+/open' | cut -d/ -f1)
  for p in $ports; do
    adb connect "$host:$p" >/dev/null 2>&1 || true
    # одразу після connect пристрій кілька сотень мс "offline"
    for _ in 1 2 3 4 5 6; do
      serial=$(connected)
      [ -n "$serial" ] && break 2
      sleep 0.5
    done
    adb disconnect "$host:$p" >/dev/null 2>&1 || true
  done
fi

if [ -z "$serial" ]; then
  echo "phone-adb: не підключився до $name. Телефон у Wi-Fi і Бездротове налагодження увімкнене? (на мобільних даних Android його вимикає)" >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "$serial"
else
  exec adb -s "$serial" "$@"
fi
