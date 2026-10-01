{ config, pkgs, ... }:
let
  # Той самий звужений (укр/eng) tesseract, що й crew/bspwm.nix -- окрема
  # копія тут навмисно, кожен crew-модуль лишається самодостатнім (див.
  # CLAUDE.md), а override -- це два рядки, не варте крос-модульного імпорту.
  tesseract-ocr = pkgs.tesseract.override { enableLanguages = [ "eng" "ukr" ]; };

  # Wayland-порт nebula-ocr з crew/bspwm.nix: maim -s -> grim+slurp,
  # xclip -> wl-copy. Та сама логіка/notify-send-патерн.
  nebula-ocr-wl = pkgs.writeShellScriptBin "nebula-ocr-wl" ''
    tmp=$(${pkgs.coreutils}/bin/mktemp --suffix=.png)
    trap 'rm -f "$tmp"' EXIT
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$tmp" || exit 1
    text=$(${tesseract-ocr}/bin/tesseract "$tmp" - -l ukr+eng 2>/dev/null)
    if [ -z "$text" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "OCR" "Текст не розпізнано"
      exit 0
    fi
    printf '%s' "$text" | ${pkgs.wl-clipboard}/bin/wl-copy
    preview=$(printf '%s' "$text" | head -c 120)
    ${pkgs.libnotify}/bin/notify-send -t 3000 "OCR → буфер" "$preview"
  '';

  # Wayland-порт nebula-color-picker: xcolor (X11-лише) -> hyprpicker,
  # яке саме копіює hex у буфер через -a.
  nebula-color-picker-wl = pkgs.writeShellScriptBin "nebula-color-picker-wl" ''
    color=$(${pkgs.hyprpicker}/bin/hyprpicker -a)
    if [ -n "$color" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 2000 "Color picker → буфер" "$color"
    fi
  '';

  # Анотований скріншот -- окремий від Noctalia-івського screenshot-region/
  # -fullscreen (той без анотацій, просто в буфер). grim+slurp той самий
  # конвеєр, що й у nebula-ocr-wl, але кадр пайпиться напряму в satty замість
  # tesseract; satty сам зберігає у файл і копіює в буфер (Enter/Ctrl+C) через
  # --copy-command.
  nebula-screenshot-satty = pkgs.writeShellScriptBin "nebula-screenshot-satty" ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/Pictures/Screenshots"
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.satty}/bin/satty \
      --filename - \
      --output-filename "$HOME/Pictures/Screenshots/satty-%Y%m%d-%H%M%S.png" \
      --copy-command ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  # nebula-space-wallpaper-wl: пікер живих космічних шпалер, наступник
  # простого on/off nebula-earth-toggle-wl -- варіантів стало два (Земля,
  # чорна діра), тож замість сліпого тогла тепер fuzzel -dmenu зі списком.
  # Додати ще один варіант -- один новий `case`-рядок нижче плюс новий
  # backend (mpvpaper для відео, glpaper для GLSL-шейдерів).
  #
  # Один спільний pidfile на всі варіанти -- завжди рівно один живий фон,
  # вибір іншого варіанта спершу гасить попередній (той самий підхід, що
  # й у старому nebula-earth-toggle-wl).
  #
  # Backend-и:
  #  - Земля: mpvpaper (реальне відео NASA SVS #5570 "Spinning Earth with
  #    clouds, atmosphere, and night lights", public domain), легкий --
  #    апаратне декодування відео (VAAPI), -p (auto-pause) сам глушить
  #    рендер, коли фон нічим не видно.
  #  - Чорна діра (відео): той самий mpvpaper, реальний науково точний
  #    рендер NASA SVS #14619 "Black Hole with Accretion Disk Visualization"
  #    (Дж. Шнітмен, 2019, public domain) -- Айнштайнове кільце, спотворений
  #    диск над і під тінню горизонту, доплерівське підсилення яскравості.
  #    Фотореалістичніший за власний шейдер нижче, і так само легкий
  #    (апаратне декодування, не per-піксельний рендер).
  #  - Чорна діра (шейдер): glpaper + процедурний GLSL-шейдер власного письма
  #    (assets/shaders/blackhole.frag) -- гравітаційне лінзування через
  #    наближену інтеграцію викривлення променя (bend ~ 1/r²), не справжня
  #    геодезика, але вигляд класичний ("тінь" горизонту подій + лінзована
  #    дуга з дальнього боку акреційного диска). Живо підібрані параметри
  #    камери й дисків через ітеративні скріншоти. ПОМІТНО важчий за
  #    mpvpaper -- fragment-shader рахується на кожен піксель щокадру без
  #    обмеження fps типу auto-pause, тому -f 30 (glpaper) обрізає частоту
  #    рендеру до 30 fps замість частоти монітора (143 Hz), щоб не грілось
  #    дарма. glpaper на відміну від mpvpaper НЕ приймає '*' (усі виходи) --
  #    бере перший монітор з hyprctl monitors -j.
  #  - Чорна діра (Гаргантюа): другий шейдер (assets/shaders/blackhole-
  #    gargantua.frag), портований з готового однопрохідного Shadertoy-
  #    шейдера користувача (не власного письма, як blackhole.frag) --
  #    майже edge-on вид з тонким білим фотонним кільцем, як класичний
  #    рендер Interstellar/Gargantua. Дві заміни під glpaper: iChannel0
  #    (текстура туманності) -> процедурний 3D fbm-шум (glpaper не має
  #    текстурних входів), iMouse (кут камери/зум мишею) -> захардкоджені
  #    константи, підібрані живими скріншотами під потрібний ракурс. 3D-шум
  #    для фону навмисно (не 2D lat/long розгортка неба) -- гравітаційне
  #    лінзування заводить промені в будь-який напрямок, тож 2D-проєкція
  #    неба показує або шов на зворотній півплощині, або полюсну
  #    сингулярність десь у кадрі (обидва живо впіймані й виправлені); а
  #    fbm (кілька октав) замість одночастотного шуму -- бо саме
  #    лінзування майже радіально-симетричне, і одна частота "розгортається"
  #    у видимі концентричні кільця.
  #  - Туманність (шейдер): третій шейдер (assets/shaders/nebula-dust.frag),
  #    портований з готового однопрохідного Shadertoy-шейдера "Dusty nebula 4"
  #    (Duke, https://www.shadertoy.com/view/MsVXWW) -- raymarch крізь хмару
  #    процедурного spiral-шуму (otaviogood-стиль) із зорею-джерелом світла
  #    в центрі, а не чорна діра. Єдина заміна під glpaper: iChannel0 (iq-
  #    івська шумова текстура) -> та сама схема хеш+трилінійна інтерполяція,
  #    що й у фоні blackhole-gargantua.frag вище; iChannel1 (клавіатура для
  #    зуму 1/2/3) просто відкинутий як несуттєвий, камера завжди на
  #    фіксованій відстані. На відміну від чорних дір тут немає гравітаційного
  #    лінзування (промені йдуть прямо), тому жодних швів/полюсів не було
  #    навіть із першої спроби.
  #  - Кротовина (шейдер): assets/shaders/wormhole.frag -- перший ПОВНІСТЮ
  #    власний шейдер серед космічних шпалер (не порт із Shadertoy), написаний
  #    саме для цього проєкту, перевикористовуючи вже перевірений raymarch-
  #    рушій зі згином променя (bend ~ k/r²) з blackhole.frag/-gargantua, але
  #    без "горизонту" -- промені не поглинаються, а виринають по інший бік і
  #    показують ІНШИЙ зоряний всесвіт (інша палітра/фон, той самий трюк
  #    "інший seed для хешу", що й у фонах чорних дір). Портал читається як
  #    компактна лінзована куля: глибоке занурення (малий minR вздовж шляху
  #    променя) -> інший бік, промені що пройшли повз -> практично незмінний
  #    "наш" бік; тонке гало -- гаусів пік навколо minR == portalR.
  #    Кілька живих ітерацій із користувачем виявили нетривіальні пастки:
  #     - "наш" бік рахувати з НЕзігнутого rd, не з фінального dir -- інакше
  #       навіть далекі від порталу пікселі показують "потріскану" картинку
  #       (немає горизонту, що ховав би зону хаотичного перемішування
  #       напрямку, як у чорній дірі -- тут ця зона займає весь кадр);
  #     - частота зоряної сітки залежить від кута огляду камери -- вужчий
  #       FOV, ніж у чорних дір, вимагав вищої частоти (900/320 замість
  #       400/137), інакше комірки візуально розпадаються на блоки;
  #     - обертання зоряної (не туманної) сітки навколо власної осі -> зорі
  #       "миготять", перескакуючи через межі комірок -- тому лише гладка fbm-
  #       туманність "того боку" обертається (swirl), зоряні комірки лишені
  #       нерухомими відносно напрямку променя;
  #     - на відміну від чорних дір, компенсація обертання камери (щоб зорі
  #       стояли на місці) тут НЕ застосовується навмисно -- портал і без
  #       того візуально симетричний під орбітою, і без видимого дрейфу фону
  #       сама орбіта була б непомітною (живо підтверджено: з компенсацією
  #       користувач бачив статичну картинку). Дрейф висоти камери також
  #       пробували й відкинули -- ламав точність компенсації (яка тоді ще
  #       була) і давав легке миготіння зовнішніх зірок.
  #  - Пульсар (шейдер): assets/shaders/pulsar.frag -- ще один повністю
  #    власний шейдер (не порт), нейтронна зоря, що швидко обертається, з
  #    двома променями-маяками вздовж нахиленої магнітної осі (класична
  #    pulsar-геометрія: магнітна вісь нахилена відносно осі спіну, тому
  #    промінь описує конус і періодично зачіпає камеру -- звідси й
  #    "пульсація" в назві) + невеликий акреційний диск. На відміну від
  #    чорних дір і кротовини НЕМАЄ гравітаційного лінзування -- нейтронна
  #    зоря не викривляє простір-час так драматично, це свідоме рішення
  #    (навіть коли Gemini пропонував додати лінзування зірок, відмовились
  #    із цієї ж причини вдруге).
  #    Ядро зорі й диск -- аналітичні (point-line distance до початку
  #    координат для ядра; пряме перетинання площини y=0 для диска, той
  #    самий continuous-gradient+kepler-ротація прийом, що й diskColorAt у
  #    blackhole.frag, плюс доплерівська асиметрія та "розхитаний" шумом
  #    радіус кілець замість ідеальних кіл -- обидві ідеї від Gemini,
  #    приймали вибірково). Промені-маяки -- легкий об'ємний raymarch
  #    (дизеринг кроку, як nebula-dust.frag) з вузьким конусом, двошаровою
  #    волокнистою текстурою й "ударними хвилями" вздовж осі; ОБРИВАЄТЬСЯ
  #    на диску (перевіряє parameter t проти перетину площини диска), якщо
  #    цього не робити -- промінь видно крізь непрозорий диск, що й сталось
  #    у першій версії.
  #    Камера НЕ компенсує власне обертання для фону (як і в кротовині) --
  #    користувач явно попросив бачити саму орбіту. Періодичний "спалах",
  #    коли промінь дивиться майже на камеру, підсвічує лише КРАЇ кадру
  #    (маска росте від центру назовні) -- так вікна/іконки посередині
  #    робочого стола не засвічуються, а по краях ефект лишається помітним.
  #  - Спіральна галактика (шейдер): assets/shaders/galaxy.frag -- портовано
  #    з готового однопрохідного CC0 Shadertoy-шейдера "Spiral galaxy" (автор
  #    невідомий з коду, ліцензія CC0) -- вибрано ЗАМІСТЬ першої власної
  #    спроби (косинусна логарифмічна спіраль + fbm-пил), бо рельєфне
  #    затінення height-field дає набагато органічнішу текстуру пилових
  #    волокон і об'єм, якого проста кольорова спіраль не давала. Повністю
  #    самодостатній (жодних iChannel/iMouse), тож портувався майже без
  #    компромісів -- єдина правка: GLSL ES 1.00 не має вбудованого tanh
  #    (з'явився лише в ES 3.00), додано власну реалізацію через exp() з
  #    клемпом аргументу.
  #    Дві доробки поверх оригіналу: (1) ширше кадрування -- в оригіналі
  #    галактика виходила за краї екрану з усіх боків (камера дистанція
  #    *0.75), розсунуто до *1.9 з запасом для віньєтки; (2) додана повільна
  #    орбіта камери навколо вертикальної осі -- в оригіналі камера була
  #    статичною (рухалась лише сама галактика через внутрішній rot()), для
  #    узгодженості зі стилем решти шейдерів (кротовина/пульсар/спіраль)
  #    додано той самий видимий рух камери.
  #  Усі шість шейдерів тримаються паралельно (крайова оцінка/смак), новий
  #  не заміняє попередні.
  # nebula-space-wallpaper-rotate (SUPER+G): цикл 4 фіксованих ракурсів
  # (0°/90°/180°/270°) для АКТИВНОГО шейдера. glpaper не приймає live-uniform
  # (лише time/resolution фіксовано на старті) -- єдиний спосіб змінити
  # "камеру" на льоту це підмінити `#define CAM_OFFSET 0.0` у файлі шейдера
  # через sed і перезапустити glpaper з нової копії. Перезапуск скидає time
  # до нуля -- видима коротка пауза/стрибок анімації при кожному натисканні,
  # неминучий побічний ефект цього підходу (живо перевірено й прийнято як
  # компроміс, справжнього live-uniform у glpaper нема).
  # shaderfile/offsetfile пишуться нижче, у nebula-space-wallpaper-wl, кожного
  # разу, коли обирається саме ШЕЙДЕР (не відео, не "вимкнути") -- так rotate
  # знає, який .frag підміняти і з якого кута продовжувати цикл.
  nebula-space-wallpaper-rotate = pkgs.writeShellScriptBin "nebula-space-wallpaper-rotate" ''
    set -eu
    pidfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.pid"
    shaderfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.shader"
    offsetfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.camoffset"
    tmpfrag="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth-rotated.frag"

    if [ ! -f "$shaderfile" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Зараз активна не шейдер-шпалера (відео або вимкнено) — нема що обертати"
      exit 0
    fi
    src=$(cat "$shaderfile")

    idx=0
    [ -f "$offsetfile" ] && idx=$(cat "$offsetfile")
    idx=$(( (idx + 1) % 4 ))
    echo "$idx" > "$offsetfile"

    case "$idx" in
      0) deg=0 ;;
      1) deg=90 ;;
      2) deg=180 ;;
      3) deg=270 ;;
    esac
    rad=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.6f\", $deg * 3.14159265 / 180 }")

    ${pkgs.gnused}/bin/sed "s/#define CAM_OFFSET .*/#define CAM_OFFSET $rad/" "$src" > "$tmpfrag"

    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
      kill "$(cat "$pidfile")"
    fi
    output=$(hyprctl monitors -j | jq -r '.[0].name')
    ${pkgs.glpaper}/bin/glpaper -f 30 "$output" "$tmpfrag" &
    echo $! > "$pidfile"
    ${pkgs.libnotify}/bin/notify-send -t 1200 "Ракурс" "$deg°"
  '';

  nebula-space-wallpaper-wl = pkgs.writeShellScriptBin "nebula-space-wallpaper-wl" ''
    set -eu
    pidfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.pid"
    shaderfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.shader"
    offsetfile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.camoffset"

    stop_current() {
      if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        kill "$(cat "$pidfile")"
      fi
      rm -f "$pidfile" "$shaderfile" "$offsetfile"
    }

    # Escape/пусто в fuzzel -> exit-код 1 -> з `set -e` скрипт впав би тут,
    # не діставшись case -- `|| exit 0` явно лишає поточний фон недоторканим
    # замість того, щоб мовчки його вимкнути.
    choice=$(printf 'Вимкнути\nЗемля (NASA відео)\nЧорна діра (NASA відео)\nЧорна діра (шейдер)\nЧорна діра (Гаргантюа)\nТуманність (шейдер)\nКротовина (шейдер)\nПульсар (шейдер)\nГалактика (шейдер)\n' | ${pkgs.fuzzel}/bin/fuzzel --dmenu -p "Космічна шпалера:") || exit 0

    case "$choice" in
      "Земля (NASA відео)")
        stop_current
        ${pkgs.mpvpaper}/bin/mpvpaper -p -o "no-audio loop" '*' ${../../assets/video/earth-spin-nasa.mp4} &
        echo $! > "$pidfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Земля"
        ;;
      "Чорна діра (NASA відео)")
        stop_current
        ${pkgs.mpvpaper}/bin/mpvpaper -p -o "no-audio loop" '*' ${../../assets/video/blackhole-nasa.mp4} &
        echo $! > "$pidfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Чорна діра (відео)"
        ;;
      "Чорна діра (шейдер)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/blackhole.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/blackhole.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Чорна діра"
        ;;
      "Чорна діра (Гаргантюа)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/blackhole-gargantua.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/blackhole-gargantua.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Чорна діра (Гаргантюа)"
        ;;
      "Туманність (шейдер)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/nebula-dust.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/nebula-dust.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Туманність"
        ;;
      "Кротовина (шейдер)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/wormhole.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/wormhole.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Кротовина"
        ;;
      "Пульсар (шейдер)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/pulsar.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/pulsar.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Пульсар"
        ;;
      "Галактика (шейдер)")
        stop_current
        output=$(hyprctl monitors -j | jq -r '.[0].name')
        ${pkgs.glpaper}/bin/glpaper -f 30 "$output" ${../../assets/shaders/galaxy.frag} &
        echo $! > "$pidfile"
        echo ${../../assets/shaders/galaxy.frag} > "$shaderfile"
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Галактика"
        ;;
      "Вимкнути")
        stop_current
        ${pkgs.libnotify}/bin/notify-send -t 1500 "Космічна шпалера" "Вимкнено"
        ;;
      *)
        # незнайомий вибір (не мало б траплятись) -- нічого не робимо
        ;;
    esac
  '';

  # Wayland-порт nebula-gamemode-toggle (crew/bspwm.nix): там вимикався
  # picom (X11-композитор) цілком; Hyprland сам Є композитором, вимкнути
  # його не можна без завершення сесії -- натомість вимикаємо blur/анімації
  # напряму через `hyprctl eval` (Hyprland тут з нативним Lua-конфігом,
  # legacy `hyprctl keyword` живо перевірено й відкидається помилкою
  # "keyword can't work with non-legacy parsers. Use eval." -- `eval` виконує
  # довільний Lua, той самий `hl.config({...})`, що й у tweaks.lua, тільки
  # runtime, без правки файлу). Сповіщення -- через noctalia msg
  # notification-dnd-set (Noctalia сама їх обробляє під Hyprland, dunst тут
  # не піднятий, на відміну від bspwm-сесії). Земля вимикається так само,
  # як і в bspwm-версії, якщо активна.
  nebula-gamemode-toggle-wl = pkgs.writeShellScriptBin "nebula-gamemode-toggle-wl" ''
    statefile="''${XDG_RUNTIME_DIR:-/tmp}/nebula-gamemode.state"
    earthpid="''${XDG_RUNTIME_DIR:-/tmp}/nebula-earth.pid"
    if [ -f "$statefile" ]; then
      rm -f "$statefile"
      hyprctl eval 'hl.config({ decoration = { blur = { enabled = true } }, animations = { enabled = true } })'
      noctalia msg notification-dnd-set false
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Game mode" "Вимкнено — блюр/анімації й сповіщення повернуто"
    else
      touch "$statefile"
      hyprctl eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false } })'
      noctalia msg notification-dnd-set true
      if [ -f "$earthpid" ] && kill -0 "$(cat "$earthpid")" 2>/dev/null; then
        kill "$(cat "$earthpid")"
        rm -f "$earthpid"
      fi
      ${pkgs.libnotify}/bin/notify-send -t 1500 "Game mode" "Увімкнено — блюр/анімації вимкнено, сповіщення на паузі"
    fi
  '';

  # Toggle-запис екрана: перший виклик стартує wf-recorder у фон і пише pid,
  # другий (той самий бінд) бачить живий pid і шле SIGINT -- wf-recorder сам
  # коректно фіналізує mp4 на SIGINT, "kill -9"/обрив файлу не дає.
  nebula-record-toggle = pkgs.writeShellScriptBin "nebula-record-toggle" ''
    set -eu
    pidfile="/tmp/nebula-wf-recorder.pid"
    outdir="$HOME/Videos/Recordings"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir"
    if [ -f "$pidfile" ] && ${pkgs.coreutils}/bin/kill -0 "$(cat "$pidfile")" 2>/dev/null; then
      ${pkgs.coreutils}/bin/kill -INT "$(cat "$pidfile")"
      rm -f "$pidfile"
      ${pkgs.libnotify}/bin/notify-send -t 2000 "Запис екрана" "Зупинено"
    else
      ${pkgs.wf-recorder}/bin/wf-recorder -f "$outdir/record-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).mp4" &
      echo $! > "$pidfile"
      ${pkgs.libnotify}/bin/notify-send -t 2000 "Запис екрана" "Почато"
    fi
  '';

  # Ctrl+D (і всі інші глобальні хоткеї Awakened) не працюють на XWayland:
  # уся детекція клавіш іде через вбудований uiohook-napi 1.5.4, чий
  # load_input_helper() (libuiohook/src/x11/input_helper.c) намагається
  # визначити evdev-vs-xfree86 нумерацію кодів клавіш через XkbGetKeyboard() —
  # цей виклик на XWayland ЗАВЖДИ повертає NULL (підтверджено issues
  # SnosMe/awakened-poe-trade#1643 і #956 на цьому самому Arch+Hyprland
  # сетапі), тому is_evdev лишається false назавжди, і клавіші читаються по
  # НЕПРАВИЛЬНІЙ (xfree86) таблиці замість evdev, яку завжди використовує
  # XWayland. Живо перевірено (build/config.gypi підтверджує, що USE_EVDEV
  # дефайниться на Linux) -- мінімальний патч: захардкодити is_evdev=true
  # замість зламаної автодетекції, і перезібрати саме цей N-API аддон (ABI-
  # стабільний, не залежить від точної версії Node/Electron).
  uiohook-napi-x11-fix = pkgs.stdenv.mkDerivation {
    pname = "uiohook-napi-x11-fix";
    version = "1.5.4";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/uiohook-napi/-/uiohook-napi-1.5.4.tgz";
      hash = "sha256-qsCLLc1KKDsvr7/aOLsXcBlJPeOUwnIIJs2WBzgkcp8=";
    };

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.node-gyp
      pkgs.python3
      pkgs.pkg-config
      pkgs.gnumake
    ];
    buildInputs = [
      pkgs.libx11
      pkgs.libxrandr
      pkgs.libxtst
      pkgs.libxt
    ];

    postPatch = ''
      substituteInPlace libuiohook/src/x11/input_helper.c \
        --replace-fail 'static bool is_evdev = false;' 'static bool is_evdev = true;'
    '';

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      node-gyp rebuild
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp build/Release/uiohook_napi.node "$out/node.napi.node"
      runHook postInstall
    '';
  };

  # Exiled Exchange 2 (PoE2 price-checker) -- неофіційний наступник Awakened
  # PoE Trade, той самий package.json: electron-overlay-window@4.0.2,
  # uiohook-napi@1.5.4 (перевірено -- точно та сама версія, той самий
  # node.napi.node з uiohook-napi-x11-fix вище підходить без перезбірки).
  # Живий тест на "чистій" версії (2026-09-27) підтвердив той самий
  # is_evdev/XkbGetKeyboard баг у логах -- тому тут одразу з обома фіксами
  # (той самий рецепт, що й awakened-poe-trade-x11 нижче):
  # --ozone-platform=x11 + патчений uiohook.
  exiled-exchange-2 = pkgs.stdenv.mkDerivation rec {
    pname = "exiled-exchange-2";
    version = "0.16.3";

    src = pkgs.fetchurl {
      url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v${version}/Exiled-Exchange-2-${version}.AppImage";
      hash = "sha256-aAHFELdlL7cccpzAW9ROHF1hZDAnQGTLLtDonS0CT2Q=";
    };

    appImageContents = pkgs.appimageTools.extract { inherit pname src version; };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/exiled-exchange-2"
      cp -a "${appImageContents}"/{locales,resources} "$out/share/exiled-exchange-2"
      chmod -R u+w "$out/share/exiled-exchange-2"

      cp ${uiohook-napi-x11-fix}/node.napi.node \
        "$out/share/exiled-exchange-2/resources/app.asar.unpacked/node_modules/uiohook-napi/prebuilds/linux-x64/node.napi.node"

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper ${pkgs.lib.getExe pkgs.electron} "$out/bin/exiled-exchange-2" \
        --add-flags "$out/share/exiled-exchange-2/resources/app.asar --ozone-platform=x11" \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.libxtst pkgs.libxt ]}
    '';
  };

  # Нативний Wayland-режим Electron ламає click-through оверлею — вікно
  # ловить весь інпут і блокує кнопки гри під собою. Форсуємо XWayland
  # через --ozone-platform=x11 (живо перевірено на Hyprland: з цим флагом
  # кнопки PoE знову клікабельні).
  #
  # symlinkJoin тут не годиться -- треба підмінити один файл усередині вже
  # готового пакета (app.asar.unpacked лишається звичайною директорією на
  # диску, не всередині asar-архіву, тож підміна безпечна й не чіпає решту
  # Electron-застосунку), тому копіюємо все дерево пакета і патчимо на місці.
  # Nixpkgs-овий bin/awakened-poe-trade -- це вже сам по собі wrapper
  # (makeWrapper), і всередині нього ЖОРСТКО закодований абсолютний шлях на
  # app.asar в ОРИГІНАЛЬНОМУ /nix/store/...-awakened-poe-trade-3.28.103 --
  # навіть після copy-і-патчу цей текстовий рядок лишається старим, тому
  # electron продовжував би вантажити непатчений app.asar.unpacked (жива
  # перевірка: hyprctl/ps показував старий шлях, попри те, що ми запускали
  # бінарник з нового шляху). Тому останній `exec`-рядок відкидаємо і пишемо
  # свій, з коректним шляхом на copies у $out; решту скрипта (LD_LIBRARY_PATH
  # тощо, налаштовані апстрімом) лишаємо як є -- це стійкіше до майбутніх
  # змін залежностей electron у nixpkgs, ніж передруковувати їх вручну.
  awakened-poe-trade-x11 = pkgs.runCommand "awakened-poe-trade-x11" { } ''
    mkdir -p "$out"
    cp -rL ${pkgs.awakened-poe-trade}/. "$out/"
    chmod -R u+w "$out"

    cp ${uiohook-napi-x11-fix}/node.napi.node \
      "$out/share/awakened-poe-trade/resources/app.asar.unpacked/node_modules/uiohook-napi/prebuilds/linux-x64/node.napi.node"

    electron_path=$(grep -m1 '^exec "' "$out/bin/awakened-poe-trade" | sed -E 's/^exec "([^"]+)".*/\1/')
    head -n -1 "$out/bin/awakened-poe-trade" > "$out/bin/awakened-poe-trade.new"
    echo "exec \"$electron_path\" \"$out/share/awakened-poe-trade/resources/app.asar\" --ozone-platform=x11 \"\$@\"" \
      >> "$out/bin/awakened-poe-trade.new"
    mv "$out/bin/awakened-poe-trade.new" "$out/bin/awakened-poe-trade"
    chmod +x "$out/bin/awakened-poe-trade"
  '';
in
{
  # Рішення "Awakened чи poe-price-check" (див. план міграції) прийняте
  # 2026-09-20 після живого тесту на Hyprland: Awakened працює нормально з
  # цими двома фіксами → лишається основним, Windows dual-boot не потрібен.
  home.packages = [
    awakened-poe-trade-x11
    exiled-exchange-2
    # Скріншот-біндинги в hyprland.lua (Print, super+shift+s) -- Wayland-
    # еквівалент bspwm-івського maim+xclip з crew/bspwm.nix: grim знімає,
    # slurp обирає ділянку, wl-clipboard -- буфер обміну для Wayland (xclip
    # там працює тільки з X11-застосунками через XWayland).
    pkgs.grim
    pkgs.slurp
    pkgs.wl-clipboard
    nebula-ocr-wl
    nebula-color-picker-wl
    nebula-screenshot-satty
    nebula-record-toggle
    nebula-space-wallpaper-wl
    nebula-space-wallpaper-rotate
    nebula-gamemode-toggle-wl
    # rofi/nwg-look вже стоять через crew/bspwm.nix/theming.nix (спільний
    # home-manager профіль, доступні і в Hyprland-сесії); pavucontrol/
    # hyprpicker там нема -- додаю тут.
    pkgs.pavucontrol
    pkgs.hyprpicker
    pkgs.satty
    pkgs.wf-recorder
    # hyprsunset -- Wayland-native нічний фільтр (redshift з crew/bspwm.nix --
    # X11-лише, під Hyprland не працює), автостарт у hyprland.lua.
    pkgs.hyprsunset
    # hyprpolkitagent -- GUI-агент автентифікації polkit для Hyprland-сесії.
    # Живо виявлено 2026-09-29: без нього тут крутиться лише сам polkitd
    # (бекенд), а будь-який запит підвищення прав (pkexec, "Format" у GNOME
    # Disks тощо) не показує діалог пароля взагалі -- просто мовчки не
    # спрацьовує. Перша спроба (жорсткий шлях на libexec/ у per-user
    # профілі, за аналогією з hyprspace) не спрацювала: на відміну від
    # lib/, каталог libexec/ пакета НЕ потрапляє в per-user профіль
    # home-manager взагалі (живо перевірено -- шляху просто нема). Пакет
    # сам постачає systemd user-юніт (нижче через systemd.user.packages),
    # це і є правильний шлях.
    pkgs.hyprpolkitagent
    # imv -- нативний Wayland переглядач картинок. nsxiv (core/packages.nix)
    # лишається X11-лише навмисно (коментар там), тут окремо, тільки для
    # Hyprland-сесії, де nsxiv тягнув би XWayland.
    pkgs.imv
    # Калькулятор (super+equal) -- rofi-calc замінено на Qalculate (набагато
    # потужніший: одиниці виміру, наукові функції, константи, конвертація
    # валют), окреме GTK-вікно замість rofi-попапу.
    pkgs.qalculate-gtk
    # Рулетка (super+shift+r) -- той самий assets/cprogram/roulette.html, але
    # тепер у власному вікні через surf (suckless, мінімальний WebKitGTK,
    # без вкладок/адресного рядка) замість вкладки в основному браузері.
    pkgs.surf
  ];

  # hyprland.lua/tweaks.lua лишаються звичайними файлами в репо (не в .nix) —
  # mkOutOfStoreSymlink лінкує ~/.config/hypr/* прямо на файл у чекауті
  # nebula-config, а не на копію в /nix/store. Редагування (вручну або через
  # UI-твікалку типу GZML) видно одразу, Hyprland сам перечитує конфіг при
  # зміні файлу — без `nh os switch`.
  home.file.".config/hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/hyprland/hyprland.lua";
  home.file.".config/hypr/tweaks.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nebula-config/crew/hyprland/tweaks.lua";

  # Курсор не видно на боці глядача при трансляції екрана через браузерний
  # Discord (2026-09-30, живе питання користувача) -- xdg-desktop-portal-
  # hyprland за замовчуванням шле курсор ОКРЕМИМ PipeWire "metadata"-потоком
  # (cursor_mode=hidden у самому кадрі), а не вбудовує його в кадр. Це
  # нормально для споживачів, що вміють малювати metadata-курсор самі (OBS
  # умів -- звідси й курсор був видно там), але Chromium цього не підтримує,
  # тож desktopCapturer у браузерному Discord бачить кадр узагалі без
  # курсора. cursor_mode=2 ("embedded") форсує портал одразу запікати курсор
  # у сам відеокадр на боці компоузитора -- працює для БУДЬ-якого споживача
  # незалежно від підтримки metadata-режиму, ціна -- курсор більше не можна
  # вибірково приховати з боку клієнта (не актуально для нашого юзкейсу).
  home.file.".config/hypr/xdph.conf".text = ''
    screencopy {
      cursor_mode = 2
    }
  '';

  # hyprpolkitagent постачає власний share/systemd/user/hyprpolkitagent.service
  # -- systemd.user.packages лінкує його в per-user systemd, так стає видимим
  # для `systemctl --user` (той самий підхід, що вже є для noctalia.service
  # нижче в hyprland.lua). WantedBy=graphical-session.target у самому юніті
  # НЕ спрацьовує на цьому Hyprland-сетапі (той самий давно відомий нюанс,
  # що й з noctalia.service -- таргет ніколи сам не активується), тому старт
  # усе одно явний, через hl.exec_cmd у hyprland.lua.
  systemd.user.packages = [ pkgs.hyprpolkitagent ];
}
