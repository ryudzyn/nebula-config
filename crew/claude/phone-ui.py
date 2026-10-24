"""phone-ui -- керування телефоном "по тексту" через uiautomator (поверх phone-adb).

  phone-ui dump              -- що на екрані: застосунок + елементи з текстом/описом/id
  phone-ui find TEXT         -- елементи, де TEXT входить у text/content-desc/resource-id
  phone-ui tap TEXT [-n N]   -- натиснути N-й (з 1) знайдений елемент (центр його меж)
  phone-ui long TEXT [-n N]  -- довге натискання
  phone-ui type "рядок"      -- ввести текст у поле у фокусі (лише ASCII -- обмеження adb input)
  phone-ui key BACK|HOME|ENTER|APP_SWITCH|...  -- клавіша (KEYCODE_ додається сам)
  phone-ui open PACKAGE      -- запустити застосунок

Перед натисканнями перевіряй `phone-ui dump`: в якому застосунку фокус
(див. правило про синтетичний ввід у пам'яті Claude).
"""

import re
import subprocess
import sys
import xml.etree.ElementTree as ET


def adb(*args, capture=True):
    r = subprocess.run(["phone-adb", *args], capture_output=capture, text=True)
    if r.returncode != 0:
        sys.exit(f"phone-ui: phone-adb {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def focus():
    out = adb("shell", "dumpsys window | grep -m1 mCurrentFocus")
    m = re.search(r"u0 ([^/ }]+)", out)
    return m.group(1) if m else "?"


def nodes():
    # "could not get idle state" іде в stderr, а дамп усе одно повний
    # rm спершу: інакше при збої дампу прочитали б старий файл (так і було при першому тесті)
    xml = adb("exec-out", "rm -f /sdcard/.ui.xml; uiautomator dump /sdcard/.ui.xml >/dev/null 2>&1; cat /sdcard/.ui.xml 2>/dev/null; rm -f /sdcard/.ui.xml")
    if "<?xml" not in xml:
        sys.exit(f"phone-ui: uiautomator не зміг зняти дамп (фокус: {focus()}). Він чекає, поки екран "
                 "перестане змінюватись -- на анімаціях, відео, курсорі Termux цього не буває. "
                 "Використай скриншот: phone-adb exec-out screencap -p > shot.png")
    xml = xml[xml.find("<?xml"):]
    for n in ET.fromstring(xml).iter("node"):
        a = n.attrib
        label = a.get("text") or a.get("content-desc") or ""
        rid = a.get("resource-id", "").split("/")[-1]
        if not (label or rid):
            continue
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", a["bounds"]))
        yield {
            "label": label, "id": rid, "cls": a["class"].split(".")[-1],
            "click": a.get("clickable") == "true", "x": (x1 + x2) // 2, "y": (y1 + y2) // 2,
            "pkg": a.get("package", ""),
        }


def match(q):
    q = q.lower()
    return [n for n in nodes() if q in n["label"].lower() or q in n["id"].lower()]


def show(ns):
    for i, n in enumerate(ns, 1):
        mark = "*" if n["click"] else " "
        print(f"{i:3}{mark} {n['label'][:60]!r:62} id={n['id'] or '-':24} {n['cls']} ({n['x']},{n['y']})")


def pick(argv):
    n = 1
    if "-n" in argv:
        k = argv.index("-n")
        n = int(argv[k + 1])
        argv = argv[:k] + argv[k + 2:]
    ns = match(" ".join(argv))
    if not ns:
        sys.exit(f"phone-ui: не знайдено {' '.join(argv)!r} (фокус: {focus()})")
    if n > len(ns):
        sys.exit(f"phone-ui: знайдено лише {len(ns)}")
    return ns[n - 1]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd, argv = sys.argv[1], sys.argv[2:]
    if cmd == "dump":
        print(f"фокус: {focus()}")
        show(list(nodes()))
    elif cmd == "find":
        show(match(" ".join(argv)))
    elif cmd in ("tap", "long"):
        n = pick(argv)
        if cmd == "tap":
            adb("shell", "input", "tap", str(n["x"]), str(n["y"]))
        else:
            adb("shell", "input", "swipe", str(n["x"]), str(n["y"]), str(n["x"]), str(n["y"]), "800")
        print(f"{cmd}: {n['label'] or n['id']!r} ({n['x']},{n['y']})")
    elif cmd == "type":
        s = " ".join(argv)
        if not s.isascii():
            sys.exit("phone-ui: adb input text не вміє не-ASCII; встав через буфер обміну вручну")
        adb("shell", "input", "text", s.replace(" ", "%s").replace("'", "\\'"))
    elif cmd == "key":
        k = argv[0].upper()
        adb("shell", "input", "keyevent", k if k.startswith("KEYCODE_") else "KEYCODE_" + k)
    elif cmd == "open":
        adb("shell", "monkey", "-p", argv[0], "-c", "android.intent.category.LAUNCHER", "1")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
