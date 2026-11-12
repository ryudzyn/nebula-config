{ pkgs, ... }:
let
  # Безкоштовний DaVinci Resolve на Linux не декодує H.264/H.265 і AAC (ліцензійне
  # обмеження Blackmagic, не баг пакета) -- такі кліпи в медіапулі сірі. А це майже все:
  # телефон, OBS (x264 у mp4), завантажене. resolve-prep перекодовує у DNxHR SQ + PCM у
  # .mov, які Resolve читає. Змінна частота кадрів (телефон, OBS) -> постійна, бо з VFR
  # Resolve розсинхронізує звук. Результат -- поруч, у підкаталозі resolve/.
  # ~0,5 ГБ на хвилину вже для 720p30 (живо виміряно), для 1080p/1440p -- більше, тож
  # перекодовувати лише те, що монтуєш.
  resolve-prep = pkgs.writeShellApplication {
    name = "resolve-prep";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.libnotify
    ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: resolve-prep відео... (або каталоги)" >&2
        exit 2
      fi

      files=()
      for arg in "$@"; do
        if [ -d "$arg" ]; then
          while IFS= read -r -d "" f; do files+=("$f"); done < <(
            find "$arg" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' \
              -o -iname '*.webm' -o -iname '*.m4v' -o -iname '*.avi' \) -print0
          )
        else
          files+=("$arg")
        fi
      done

      notify-send -a "resolve-prep" "DaVinci: перекодування" "Файлів: ''${#files[@]}"
      done_n=0
      failed=()
      for f in "''${files[@]}"; do
        dir=$(dirname "$f")/resolve
        out="$dir/$(basename "''${f%.*}").mov"
        mkdir -p "$dir"
        if [ -e "$out" ] && [ "$out" -nt "$f" ]; then
          done_n=$((done_n + 1))
          continue
        fi
        echo "==> $f"
        if ffmpeg -hide_banner -loglevel error -stats -y -i "$f" \
          -map 0:v:0 -map "0:a?" -fps_mode cfr \
          -c:v dnxhd -profile:v dnxhr_sq -pix_fmt yuv422p \
          -c:a pcm_s16le -ar 48000 \
          "$out.part.mov"; then
          mv "$out.part.mov" "$out"
          done_n=$((done_n + 1))
        else
          rm -f "$out.part.mov"
          failed+=("$(basename "$f")")
        fi
      done

      if [ ''${#failed[@]} -eq 0 ]; then
        notify-send -a "resolve-prep" "DaVinci: готово" "$done_n файл(ів) у підкаталозі resolve/"
      else
        notify-send -u critical -a "resolve-prep" "DaVinci: помилки" "Не вдалося: ''${failed[*]}"
        exit 1
      fi
    '';
  };
in
{
  home.packages = [ resolve-prep ];

  # ПКМ по відео (або кількох) у Nemo -> "Підготувати для DaVinci"
  xdg.dataFile."nemo/actions/resolve-prep.nemo_action".text = ''
    [Nemo Action]
    Name=Підготувати для DaVinci
    Comment=Перекодувати в DNxHR, який читає безкоштовний DaVinci Resolve
    Exec=resolve-prep %F
    Icon-Name=video-x-generic
    Selection=notnone
    Extensions=mp4;mkv;mov;webm;m4v;avi;
    Quote=double
  '';
}
