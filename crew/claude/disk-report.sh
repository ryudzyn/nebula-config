# disk-report -- що займає місце на earth і що з цього безпечно прибрати.
# Лише читає: нічого не видаляє (це робить скіл /disk-cleanup після підтвердження).
# ~/Downloads показується тільки розміром -- його користувач чистить сам.
#   disk-report [--steam-orphans]   (--steam-orphans: лише список шляхів для видалення)

steam="$HOME/.local/share/Steam/steamapps"
sz() { du -sh "$@" 2>/dev/null | awk '{print $1}' | head -1; }

# compatdata/shadercache без appmanifest = рештки видалених ігор.
# ID >= 2^31 -- ярлики non-Steam ігор (Lutris, emulators...), їх не чіпаємо.
steam_orphans() {
  [ -d "$steam" ] || return 0
  for kind in compatdata shadercache; do
    for d in "$steam/$kind"/*/; do
      id=$(basename "$d")
      case "$id" in '' | *[!0-9]*) continue ;; esac
      [ "$id" -ge 2147483648 ] && continue
      [ "$id" = 0 ] && continue
      [ -e "$steam/appmanifest_$id.acf" ] || echo "${d%/}"
    done
  done
  # Теки в common/, на які не посилається жоден appmanifest (installdir)
  installed=$(grep -h '"installdir"' "$steam"/appmanifest_*.acf 2>/dev/null | cut -d'"' -f4)
  for d in "$steam/common"/*/; do
    name=$(basename "$d")
    printf '%s\n' "$installed" | grep -Fxq "$name" || echo "${d%/}"
  done
}

if [ "${1:-}" = "--steam-orphans" ]; then
  steam_orphans
  exit 0
fi

df -h / | awk 'NR==2 {printf "Диск /: зайнято %s з %s (%s), вільно %s\n\n", $3, $2, $5, $4}'

echo "== Nix"
gens=$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l)
hm=$(find "$HOME/.local/state/nix/profiles" -maxdepth 1 -name 'home-manager-*-link' 2>/dev/null | wc -l)
echo "  /nix/store: $(sz /nix/store)   поколінь системи: $gens, home-manager: $hm"
echo "  журнал systemd: $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]')"

echo "== Steam"
if [ -d "$steam" ]; then
  echo "  ігри (common): $(sz "$steam/common")   compatdata: $(sz "$steam/compatdata")   shadercache: $(sz "$steam/shadercache")"
  orphans=$(steam_orphans)
  if [ -n "$orphans" ]; then
    echo "  рештки видалених ігор: $(printf '%s\n' "$orphans" | wc -l) тек, $(printf '%s\n' "$orphans" | tr '\n' '\0' | du -csh --files0-from=- 2>/dev/null | tail -1 | cut -f1)"
    printf '%s\n' "$orphans" | tr '\n' '\0' | du -sh --files0-from=- 2>/dev/null | sort -rh | head -10 | sed 's/^/    /'
  else
    echo "  решток видалених ігор немає"
  fi
  echo "  найбільші встановлені ігри:"
  du -sh "$steam/common"/*/ 2>/dev/null | sort -rh | head -8 | sed "s|$steam/common/||; s/^/    /"
fi

echo "== Кеші й тимчасове (відновлюються самі)"
for p in "$HOME/.gradle/caches" "$HOME/.cache/uv" "$HOME/.cache/appimage-run" "$HOME/.cache/mesa_shader_cache" \
  "$HOME/.local/share/Trash" "$HOME/.cache"; do
  [ -e "$p" ] && printf '  %-40s %s\n' "${p/#$HOME/\~}" "$(sz "$p")"
done

echo "== Android"
for p in "$HOME/.android/avd" "$HOME/Android/Sdk/system-images" "$HOME/Android"; do
  [ -e "$p" ] && printf '  %-40s %s\n' "${p/#$HOME/\~}" "$(sz "$p")"
done

echo "== Не чіпаємо"
printf '  %-40s %s (користувач чистить сам)\n' "${HOME/#$HOME/\~}/Downloads" "$(sz "$HOME/Downloads")"

echo "== Найбільше в ~ (верхній рівень)"
du -xsh "$HOME"/* "$HOME"/.[!.]* 2>/dev/null | sort -rh | head -8 | sed "s|$HOME|~|; s/^/  /"
