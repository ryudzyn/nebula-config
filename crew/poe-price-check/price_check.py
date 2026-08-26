# Альтернатива Awakened PoE Trade: без Electron/оверлей-вікна GUI-фреймворку,
# лише stdlib (urllib + tkinter) + xclip/xdotool як зовнішні бінарники.
# Той самий офіційний trade API, що й у Awakened — різниця лише в клієнті.

import json
import os
import re
import statistics
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://www.pathofexile.com/api/trade"
NINJA_BASE = "https://poe.ninja/poe1/api/economy/stash/current"
USER_AGENT = "poe-price-check/0.2 (contact: ryudzyn@gmail.com)"
CACHE_DIR = os.path.expanduser("~/.cache/poe-price-check")
LEAGUE_TTL = 3600
STATIC_TTL = 86400
EXCHANGE_TTL = 300  # курси валют плавають, але не щохвилини -- 5хв достатньо
NINJA_TTL = 900  # poe.ninja сам оновлює economy-дані з подібною періодичністю
DIVINE_THRESHOLD = 150  # chaos, з якого варто показувати ще й у divine
REQUEST_TIMEOUT = 6
MAX_FETCH_IDS = 10

COLORS = {
    "bg": "#1a1a2e",
    "fg": "#e0e0f0",
    "accent": "#9d4edd",
    "muted": "#888888",
    "error": "#e05561",
    "entry_bg": "#2a2a44",
}


class ApiError(Exception):
    pass


class RateLimited(Exception):
    def __init__(self, retry_after):
        self.retry_after = retry_after
        super().__init__(f"rate limited, retry after {retry_after}s")


def _cache_path(name):
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, name)


def _read_cache(name, ttl):
    path = _cache_path(name)
    try:
        with open(path) as f:
            data = json.load(f)
        if time.time() - data["ts"] < ttl:
            return data["value"]
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        pass
    return None


def _write_cache(name, value):
    with open(_cache_path(name), "w") as f:
        json.dump({"ts": time.time(), "value": value}, f)


def http_json(url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data)
    req.add_header("User-Agent", USER_AGENT)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 429:
            retry_after = int(e.headers.get("Retry-After", "60"))
            raise RateLimited(retry_after)
        raise ApiError(f"HTTP {e.code} з {url}")
    except urllib.error.URLError as e:
        raise ApiError(f"мережа недоступна: {e.reason}")


def get_current_league():
    cached = _read_cache("league.json", LEAGUE_TTL)
    if cached:
        return cached
    data = http_json(f"{API_BASE}/data/leagues")
    candidates = [
        league["id"]
        for league in data["result"]
        if league["realm"] == "pc"
        and league["id"] != "Standard"
        and "Hardcore" not in league["id"]
        and "Ruthless" not in league["id"]
    ]
    league = candidates[0] if candidates else "Standard"
    _write_cache("league.json", league)
    return league


# лише ці категорії реально приймає /api/trade/exchange -- решта (Cards,
# Essences, Oils, ...) валідні id мають тільки для звичайного /search,
# інакше exchange мовчки повертає порожній список замість помилки.
EXCHANGE_CATEGORIES = {"Currency", "Fragments"}


def get_currency_map():
    cached = _read_cache("static.json", STATIC_TTL)
    if cached:
        return cached
    data = http_json(f"{API_BASE}/data/static")
    mapping = {}
    for category in data["result"]:
        if category["id"] not in EXCHANGE_CATEGORIES:
            continue
        for entry in category["entries"]:
            mapping[entry["text"]] = entry["id"]
    _write_cache("static.json", mapping)
    return mapping


# --- визначення базового типу Magic-предмету ---
#
# У Rare/Unique гра завжди показує базовий тип окремим рядком під іменем.
# У Magic — ні: рядок імені сам є "Префікс База of Суфікс" (префікс і/або
# суфікс можуть бути відсутні). /data/items не дає готового мапінгу
# "повне ім'я -> база", тож базовий тип доводиться вирізати з рядка самим,
# звіряючи проти списку всіх відомих base type.


def get_base_type_index():
    cached = _read_cache("items.json", STATIC_TTL)
    if cached is None:
        data = http_json(f"{API_BASE}/data/items")
        types = {
            entry["type"]
            for category in data["result"]
            for entry in category["entries"]
            if "type" in entry
        }
        cached = sorted(types, key=len, reverse=True)
        _write_cache("items.json", cached)
    return cached


def resolve_magic_base_type(name_line, base_types):
    """Найдовший base_type, що збігається в name_line з правильними межами:
    перед ним -- початок рядка або пробіл (кінець префіксу), після --
    кінець рядка або " of " (початок суфіксу). Перебір від найдовших назв
    до найкоротших гарантує, що напр. "Leather Belt" не програє випадковому
    короткому збігу на кшталт "Belt" (якби такий існував як base type)."""
    for base in base_types:
        idx = name_line.find(base)
        if idx == -1:
            continue
        before_ok = idx == 0 or name_line[idx - 1] == " "
        after = name_line[idx + len(base):]
        after_ok = after == "" or after.startswith(" of ")
        if before_ok and after_ok:
            return base
    return None


# --- мапінг рядків модів предмету на trade stat id (/data/stats) ---
#
# Trade API описує кожен мод шаблоном тексту з "#" на місці чисел (напр.
# "+# to maximum Life"). Щоб дізнатись stat id конкретного рядка з предмету,
# перетворюємо шаблон на regex (екрануємо все, крім "#", який стає числовою
# групою) і шукаємо повний збіг серед entries групи "explicit"/"implicit".
# Це той самий підхід, що й у Awakened PoE Trade (там -- через RePoE базу).

STAT_GROUPS = ("explicit", "implicit")

# рядки-властивості (не моди), які показує гра поруч з модами -- одразу
# відкидаємо, щоб не витрачати час на regex-спроби і не зловити хибний збіг.
SKIP_LINE_PREFIXES = (
    "Quality:", "Armour:", "Evasion Rating:", "Energy Shield:", "Ward:",
    "Item Level:", "Talisman Tier:", "Requirements:", "Level:", "Str:",
    "Dex:", "Int:", "Sockets:", "Stack Size:", "Rarity:", "Corrupted",
    "Unidentified", "Note:", "Shaper Item", "Elder Item", "Warlord Item",
    "Hunter Item", "Redeemer Item", "Crusader Item", "Fractured Item",
    "Synthesised Item", "Physical Damage:", "Elemental Damage:",
    "Critical Strike Chance:", "Attacks per Second:", "Weapon Range:",
    "Chance to Block:", "Reservation:", "Cooldown Time:", "Can Store",
    "Consumes", "Experience:", "Souls Per Use:", "Base duration",
    "Radius:", "Damage Effectiveness:", "Mana Cost:", "Mana Multiplier:",
    "Limited to:", "Right-click", "Cannot be Traded", "Cannot be Modified",
    "Duplicated", "Mirrored", "Superior", "Item Class:",
    "{",  # "{ Implicit Modifier -- ... }" -- анотація категорії з Advanced Mod Descriptions
    "(",  # пояснювальний текст в дужках ("(Shock increases ...)"), теж з Advanced Mod Descriptions
)

# з увімкненим у грі "Advanced Mod Descriptions" рядок мода виглядає як
# "+20(20-30)% to Lightning Resistance" (діапазон рола в дужках одразу після
# числа) і нескейлящийся унікальний мод отримує суфікс
# "... -- Unscalable Value". Прибираємо обидва перед матчингом на stat
# id, інакше жоден шаблон з "#" не збіжиться по fullmatch.
ROLL_RANGE_RE = re.compile(r"\(-?[\d.]+--?[\d.]+\)")
UNSCALABLE_SUFFIX_RE = re.compile(r"\s*—.*$")


def normalize_mod_line(line):
    line = ROLL_RANGE_RE.sub("", line)
    line = UNSCALABLE_SUFFIX_RE.sub("", line)
    return line.strip()


def mod_candidate_lines(lines, start_idx):
    out = []
    for line in lines[start_idx:]:
        if not line or line == "--------":
            continue
        if any(line.startswith(p) for p in SKIP_LINE_PREFIXES):
            continue
        out.append(line)
    return out


def build_stat_index(stat_groups):
    index = {group: [] for group in STAT_GROUPS}
    for group in stat_groups:
        gid = group.get("id")
        if gid not in index:
            continue
        for entry in group.get("entries", []):
            text = entry.get("text", "")
            if not text:
                continue
            # деякі моди (напр. "Herald of Thunder also creates a storm...")
            # взагалі без числа -- пусте значення "#" не мають, але це все
            # одно валідний фільтр (просто без "value"), тому не пропускаємо.
            pattern = re.escape(text).replace(r"\#", r"(-?[\d.]+)")
            try:
                index[gid].append((re.compile(pattern), entry["id"]))
            except re.error:
                continue
    return index


def get_stat_index():
    stat_groups = _read_cache("stats.json", STATIC_TTL)
    if stat_groups is None:
        stat_groups = http_json(f"{API_BASE}/data/stats")["result"]
        _write_cache("stats.json", stat_groups)
    return build_stat_index(stat_groups)


def match_stat(line, entries):
    for compiled, stat_id in entries:
        m = compiled.fullmatch(line)
        if m:
            return stat_id, [float(g) for g in m.groups()]
    return None


def match_stat_any(line, entries):
    """Як match_stat, але додатково пробує варіант з переставленим
    increased/reduced -- деякі стати (напр. Attribute Requirements) trade
    API зберігає лише як "#% increased X", а "reduced" -- це та сама
    статистика з від'ємним значенням, окремого шаблону немає."""
    found = match_stat(line, entries)
    if found:
        return found
    if "reduced" in line:
        swapped = line.replace("reduced", "increased")
    elif "increased" in line:
        swapped = line.replace("increased", "reduced")
    else:
        return None
    found = match_stat(swapped, entries)
    if found:
        stat_id, values = found
        return stat_id, [-v for v in values]
    return None


def extract_roll_range(raw_line, value):
    """Дістає (min, max) фактичного діапазону рола з "(20-30)" в необробленому
    рядку -- для повзунка в overlay. Повертає None, якщо в тексті предмету
    діапазон не показаний (Advanced Mod Descriptions вимкнено або мод
    фіксований/implicit без варіації)."""
    target = format_value(abs(value))
    m = re.search(re.escape(target) + r"\((-?[\d.]+)-(-?[\d.]+)\)", raw_line)
    if not m:
        return None
    lo, hi = float(m.group(1)), float(m.group(2))
    if value < 0:
        lo, hi = -hi, -lo
    if lo == hi:
        return None
    return (min(lo, hi), max(lo, hi))


def _match_candidate(text, index):
    normalized = normalize_mod_line(text)
    return match_stat_any(normalized, index["explicit"]) or match_stat_any(normalized, index["implicit"])


def match_item_mods(lines, start_idx):
    """Повертає список {"line", "id", "values", "range"} для розпізнаних
    модів. "range" -- (min, max) можливого рола для повзунка в overlay, або
    None, якщо його не вдалось дістати з тексту предмету.

    Моди з двома числами (напр. "Adds # to # Fire Damage") теж повертаються,
    але з values з двох елементів -- виклик, що будує фільтр, сам вирішує,
    чи створювати для них selectable-фільтр (UI позначає їх як недоступні).

    Деякі унікальні моди (напр. "...per Murderous Eye Jewel affecting you")
    trade API зберігає в /data/stats одним шаблоном з буквальним переносом
    рядка всередині -- те саме розбиття на два рядки гра сама зберігає і в
    скопійованому тексті предмету (перевірено живим запитом до /data/stats:
    entry["text"] містить реальний "\\n", не просто ширину тултипа). Якщо
    рядок сам по собі не збігається, пробуємо об'єднати його з наступним
    через "\\n" і зіставити як єдиний шаблон, перш ніж здатись."""
    index = get_stat_index()
    candidates = mod_candidate_lines(lines, start_idx)
    matches = []
    i = 0
    while i < len(candidates):
        line = candidates[i]
        found = _match_candidate(line, index)
        display_line, consumed = line, 1

        if not found and i + 1 < len(candidates):
            joined = f"{line}\n{candidates[i + 1]}"
            found = _match_candidate(joined, index)
            if found:
                display_line, consumed = f"{line} {candidates[i + 1]}", 2

        if found:
            stat_id, values = found
            value_range = extract_roll_range(display_line, values[0]) if len(values) == 1 else None
            matches.append({"line": display_line, "id": stat_id, "values": values, "range": value_range})
        i += consumed
    return matches


# --- парсинг предмету зі скопійованого тексту ---

SOCKETS_RE = re.compile(r"^Sockets: (.+)$", re.MULTILINE)
STACK_RE = re.compile(r"^Stack Size: (\d+)/\d+$", re.MULTILINE)


def parse_item(text):
    lines = [line.strip() for line in text.strip().splitlines()]
    rarity_idx = next((i for i, l in enumerate(lines) if l.startswith("Rarity: ")), None)
    if rarity_idx is None:
        return None

    rarity = lines[rarity_idx].split(": ", 1)[1]
    name_line = lines[rarity_idx + 1] if rarity_idx + 1 < len(lines) else ""
    if not name_line:
        return None

    base_type = name_line
    mod_start_idx = rarity_idx + 2
    if rarity in ("Rare", "Unique") and rarity_idx + 2 < len(lines):
        next_line = lines[rarity_idx + 2]
        if next_line and not next_line.startswith("--------"):
            base_type = next_line
            mod_start_idx = rarity_idx + 3

    links = 0
    m = SOCKETS_RE.search(text)
    if m:
        for group in m.group(1).split(" "):
            link_count = group.count("-") + 1
            links = max(links, link_count)

    stack_size = 1
    m = STACK_RE.search(text)
    if m:
        stack_size = int(m.group(1))

    corrupted = any(line == "Corrupted" for line in lines)

    return {
        "rarity": rarity,
        "name": name_line,
        "base_type": base_type,
        "links": links,
        "stack_size": stack_size,
        "corrupted": corrupted,
        "lines": lines,
        "mod_start_idx": mod_start_idx,
    }


# --- ціноутворення ---


def get_exchange_median(have_id, want_id, league):
    """Медіана курсу want_id за 1 have_id (до 20 лотів), кешована EXCHANGE_TTL --
    курс міняється повільно, а /exchange б'є по rate-limit значно швидше, ніж
    /data/*. Повертає (median, кількість лотів) або None, якщо активних лотів
    немає."""
    cache_name = f"exchange_{have_id}_{want_id}.json"
    cached = _read_cache(cache_name, EXCHANGE_TTL)
    if cached is not None:
        return tuple(cached) if cached else None

    body = {
        "query": {
            "status": {"option": "online"},
            "have": [have_id],
            "want": [want_id],
        },
        "sort": {"have": "asc"},
    }
    data = http_json(f"{API_BASE}/exchange/{league}", body)
    result = data.get("result")
    if not isinstance(result, dict):
        _write_cache(cache_name, [])  # [] -- явно закешоване "немає лотів",
        return None                   # None з _read_cache означає "нема кешу"

    ratios = []
    for listing in list(result.values())[:20]:
        offers = listing["listing"]["offers"]
        if not offers:
            continue
        offer = offers[0]
        have_amt = offer["exchange"]["amount"]
        want_amt = offer["item"]["amount"]
        if have_amt:
            ratios.append(want_amt / have_amt)

    if not ratios:
        _write_cache(cache_name, [])
        return None

    value = [statistics.median(ratios), len(ratios)]
    _write_cache(cache_name, value)
    return tuple(value)


def get_divine_rate(league):
    """~chaos за 1 divine, або None якщо недоступно -- не критична інформація,
    відсутність курсу не повинна ламати основний price-check."""
    try:
        ninja = get_ninja_currency(league).get("Divine Orb")
        if ninja:
            return ninja["chaos"]
        found = get_exchange_median("divine", "chaos", league)
    except (ApiError, RateLimited):
        return None
    return found[0] if found else None


def format_with_divine(chaos_amount, league):
    """Додає рядок "~X divine", якщо сума достатньо велика і курс відомий."""
    if chaos_amount < DIVINE_THRESHOLD:
        return []
    rate = get_divine_rate(league)
    if not rate:
        return []
    return [f"(~{chaos_amount / rate:.2f} divine)"]


# --- poe.ninja: агреговані ціни замість власного лайв-пошуку ---
#
# poe.ninja рахує медіану/дані по значно ширшому зрізу ринку, ніж наші власні
# до-20-лотів запити до live /exchange чи /search+/fetch, оновлюється десь
# так само часто (NINJA_TTL), і головне -- не б'є по rate-limit офіційного
# trade API. Тому для Currency/Divination Card це тепер основне джерело,
# а власний live-пошук лишається запасним варіантом (нова валюта, якої
# ninja ще не встиг проіндексувати, чи сам ninja недоступний).
# Для Unique -- ninja лише орієнтовний рядок поруч з точним live-пошуком за
# конкретними модами (він і далі головне джерело для Unique/Rare, бо ninja
# усереднює по всіх ролах, а не по руках у гравця).

NINJA_UNIQUE_CATEGORIES = (
    "UniqueWeapon", "UniqueArmour", "UniqueAccessory", "UniqueFlask", "UniqueJewel", "UniqueMap",
)


def _ninja_json(path, league, item_type):
    query = urllib.parse.urlencode({"league": league, "type": item_type})
    return http_json(f"{NINJA_BASE}/{path}?{query}")


def get_ninja_currency(league):
    """{ім'я -- {"chaos", "trend"}} для Currency + Fragment, кешовано NINJA_TTL."""
    cached = _read_cache("ninja_currency.json", NINJA_TTL)
    if cached is not None:
        return cached

    prices = {}
    for item_type in ("Currency", "Fragment"):
        data = _ninja_json("currency/overview", league, item_type)
        for line in data.get("lines", []):
            name, chaos = line.get("currencyTypeName"), line.get("chaosEquivalent")
            if name and chaos:
                trend = (line.get("receiveSparkLine") or {}).get("totalChange") or 0
                prices[name] = {"chaos": chaos, "trend": trend}
    _write_cache("ninja_currency.json", prices)
    return prices


def get_ninja_divcards(league):
    """{ім'я -- {"chaos", "trend"}} для Divination Card, кешовано NINJA_TTL."""
    cached = _read_cache("ninja_divcards.json", NINJA_TTL)
    if cached is not None:
        return cached

    prices = {}
    data = _ninja_json("item/overview", league, "DivinationCard")
    for line in data.get("lines", []):
        name, chaos = line.get("name"), line.get("chaosValue")
        if name and chaos:
            trend = (line.get("sparkLine") or {}).get("totalChange") or 0
            prices[name] = {"chaos": chaos, "trend": trend}
    _write_cache("ninja_divcards.json", prices)
    return prices


def get_ninja_uniques(league):
    """{ім'я -- [{"chaos", "links", "trend"}, ...]} по всіх категоріях уніків
    одразу -- імена уніків унікальні глобально, окрема категорія тут лише
    деталь запиту до ninja, не потрібна для пошуку за іменем."""
    cached = _read_cache("ninja_uniques.json", NINJA_TTL)
    if cached is not None:
        return cached

    prices = {}
    for item_type in NINJA_UNIQUE_CATEGORIES:
        data = _ninja_json("item/overview", league, item_type)
        for line in data.get("lines", []):
            name, chaos = line.get("name"), line.get("chaosValue")
            if not name or not chaos:
                continue
            trend = (line.get("sparkLine") or {}).get("totalChange") or 0
            prices.setdefault(name, []).append(
                {"chaos": chaos, "links": line.get("links") or 0, "trend": trend}
            )
    _write_cache("ninja_uniques.json", prices)
    return prices


def ninja_unique_match(uniques, name, links):
    entries = uniques.get(name)
    if not entries:
        return None
    # найближчий за лінками варіант, що не перевищує предмет гравця --
    # 6-лінковий рядок ціни не має сенсу пропонувати як орієнтир для 5-лінка.
    candidates = [e for e in entries if e["links"] <= links] or entries
    return max(candidates, key=lambda e: e["links"])


def trend_suffix(pct):
    if not pct:
        return ""
    arrow = "↑" if pct > 0 else "↓"
    return f", {arrow}{abs(pct):.0f}%"


def robust_stackable_price(name, league):
    """Запасний варіант для Divination Card / незнайомої валюти, коли poe.ninja
    не має даних. Офіційний trade API не дає історію реально проданого --
    тільки активні виставлені лоти, тож "останньої проданої ціни" в принципі
    нема звідки взяти. Найближчий чесний орієнтир: пропустити перший
    "квартиль" відсортованого за ціною списку (типова зона бейт/помилкових
    лотів на дорогих картках -- продавець виставляє за 1 chaos, щоб
    з'явитись першим і домовлятись у приваті вручну) і взяти медіану
    наступної вибірки, а не наївний мінімум. Той самий один виклик /search
    вже повертає повний відсортований список id, тож пропуск нічого не
    коштує додатково -- лише інший зріз перед /fetch."""
    body = {"query": {"status": {"option": "online"}, "type": name}, "sort": {"price": "asc"}}
    data = http_json(f"{API_BASE}/search/{league}", body)
    ids_all = data.get("result", [])
    if not ids_all:
        return {"title": name, "lines": ["Лотів не знайдено"], "error": False}

    skip = min(len(ids_all) // 4, 20) if len(ids_all) > MAX_FETCH_IDS else 0
    sample_ids = ids_all[skip:skip + MAX_FETCH_IDS] or ids_all[:MAX_FETCH_IDS]

    query_id = data["id"]
    fetch = http_json(f"{API_BASE}/fetch/{','.join(sample_ids)}?query={query_id}")
    listings = _top_listings(fetch)
    if not listings:
        return {"title": name, "lines": ["Лоти без вказаної ціни"], "error": False}

    by_currency = {}
    for listing in listings:
        by_currency.setdefault(listing["currency"], []).append(listing["amount"])
    currency, amounts = max(by_currency.items(), key=lambda kv: len(kv[1]))
    median = statistics.median(amounts)

    skip_note = ", пропущено дешевші як імовірний бейт" if skip else ""
    lines = [f"~{format_price(median)} {currency} (медіана {len(amounts)} лотів{skip_note})"]
    cheapest = min(listings, key=lambda entry: entry["amount"])
    if cheapest["amount"] < median * 0.5:
        lines.append(f"  найдешевший лот: {_format_listing(cheapest)} -- можливо помилка/бейт")
    if currency == "chaos":
        lines += format_with_divine(median, league)
    return {"title": name, "lines": lines, "error": False, "whisper": listings[0]["whisper"]}


def price_currency(item, league):
    currency_map = get_currency_map()
    currency_id = currency_map.get(item["name"])

    if item["rarity"] == "Divination Card":
        try:
            ninja = get_ninja_divcards(league).get(item["name"])
        except (ApiError, RateLimited):
            ninja = None
        if not ninja:
            return robust_stackable_price(item["name"], league)
        total = ninja["chaos"] * item["stack_size"]
        lines = [f"~{ninja['chaos']:.1f} chaos за 1 шт. (poe.ninja{trend_suffix(ninja['trend'])})"]
        if item["stack_size"] > 1:
            lines.append(f"стак {item['stack_size']} шт. -> ~{total:.0f} chaos")
        lines += format_with_divine(total, league)
        return {"title": item["name"], "lines": lines, "error": False}

    if not currency_id:
        return robust_stackable_price(item["base_type"], league)

    if currency_id == "chaos":
        lines = ["1 chaos (базова валюта)"]
        if item["stack_size"] > 1:
            lines.append(f"стак {item['stack_size']} шт.")
            lines += format_with_divine(item["stack_size"], league)
        return {"title": item["name"], "lines": lines, "error": False}

    try:
        ninja = get_ninja_currency(league).get(item["name"])
    except (ApiError, RateLimited):
        ninja = None

    if ninja:
        median, source_note = ninja["chaos"], f"poe.ninja{trend_suffix(ninja['trend'])}"
    else:
        try:
            found = get_exchange_median(currency_id, "chaos", league)
        except ApiError:
            return robust_stackable_price(item["base_type"], league)
        if not found:
            return {"title": item["name"], "lines": ["Немає активних лотів на обмін"], "error": False}
        median, source_note = found[0], f"{found[1]} лотів"

    total = median * item["stack_size"]
    lines = [f"~{median:.1f} chaos за 1 шт. ({source_note})"]
    if item["stack_size"] > 1:
        lines.append(f"стак {item['stack_size']} шт. -> ~{total:.0f} chaos")
    lines += format_with_divine(total, league)
    return {"title": item["name"], "lines": lines, "error": False}


def _base_filters(rarity_option, links):
    filters = {}
    if rarity_option:
        filters.setdefault("type_filters", {}).setdefault("filters", {})["rarity"] = {
            "option": rarity_option
        }
    if links >= 5:
        filters.setdefault("socket_filters", {}).setdefault("filters", {})["links"] = {
            "min": links
        }
    return filters


def _top_listings(fetch_result):
    """{"amount", "currency", "stack_size", "whisper"} на лот, до 10 (весь
    /fetch-батч, не обрізаний до 5) -- amount вже поділений на item.stackSize.
    Без цього поділу ціна цілого стеку (напр. "1 chaos" за лот із 3
    картками) показувалась би як ціна за одну штуку -- саме так і сплутало
    гравців з The Sephirot (реальний лот був за пачку, а не за карту).
    Trade API сортує /search за сирою ціною лота, не за ціною за одиницю,
    тож сортуємо повторно вже після нормалізації -- в межах отриманого
    батчу, повний перегляд усього ринку так і так недоступний за один
    запит (ліміт /fetch -- 10 id)."""
    listings = []
    for entry in fetch_result.get("result") or []:
        listing = entry.get("listing", {})
        price = listing.get("price")
        if not price:
            continue
        stack_size = entry.get("item", {}).get("stackSize") or 1
        listings.append({
            "amount": price["amount"] / stack_size,
            "currency": price["currency"],
            "stack_size": stack_size,
            "whisper": listing.get("whisper"),
        })
    listings.sort(key=lambda entry: entry["amount"])
    return listings[:5]


def format_price(v):
    """2 знаки після коми -- не плутати з format_value() нижче (без округлення,
    для точних значень ролів модів в інтерактивному overlay)."""
    if v == int(v):
        return str(int(v))
    return f"{v:.2f}"


def _format_listing(listing):
    text = f"{format_price(listing['amount'])} {listing['currency']}"
    if listing["stack_size"] > 1:
        text += f" (за 1, стек {listing['stack_size']})"
    return text


TROLL_LISTING_RATIO = 0.5  # той самий поріг, що й у robust_stackable_price


def _floor_line(listing, league, reference_chaos=None):
    line = f"floor: {_format_listing(listing)}"
    if listing["currency"] == "chaos":
        extra = format_with_divine(listing["amount"], league)
        if extra:
            line += f" {extra[0]}"
        if reference_chaos and listing["amount"] < reference_chaos * TROLL_LISTING_RATIO:
            # напр. живий floor-лот у 10 chaos поруч з poe.ninja ~130 chaos на
            # той самий унік -- майже напевно тролль/помилковий буaут, а не
            # реальна ринкова ціна (перевірено вручну на реальному предметі).
            line += " ⚠ можливо тролль-лот"
    return line


def item_search_floor(type_text, league, rarity_option=None, name=None, links=0, reference_chaos=None):
    query = {"status": {"option": "online"}, "type": type_text}
    if name:
        query["name"] = name
    filters = _base_filters(rarity_option, links)
    if filters:
        query["filters"] = filters

    body = {"query": query, "sort": {"price": "asc"}}
    data = http_json(f"{API_BASE}/search/{league}", body)
    ids = data.get("result", [])[:MAX_FETCH_IDS]
    if not ids:
        if links >= 5:
            # без збігу за лінками -- пробуємо ще раз без фільтра лінків,
            # чесно позначаючи це в результаті нижче.
            return item_search_floor(
                type_text, league, rarity_option, name, links=0, reference_chaos=reference_chaos
            )
        return {"title": type_text, "lines": ["Лотів не знайдено"], "error": False}

    query_id = data["id"]
    fetch = http_json(f"{API_BASE}/fetch/{','.join(ids)}?query={query_id}")
    listings = _top_listings(fetch)

    if not listings:
        return {"title": type_text, "lines": ["Лоти без вказаної ціни"], "error": False}

    title = name or type_text
    lines = [_floor_line(listings[0], league, reference_chaos)] + [
        f"  {_format_listing(extra)}" for extra in listings[1:4]
    ]
    return {"title": title, "lines": lines, "error": False, "whisper": listings[0]["whisper"]}


RARITY_OPTIONS = {"Unique": "unique", "Rare": "rare", "Magic": "magic"}


def item_search_stats(item, league, stat_filters, reference_chaos=None):
    """Пошук з урахуванням конкретних модів (stat_filters -- список
    {"id", "value": {"min": ...}}), як робить Awakened PoE Trade."""
    rarity_option = RARITY_OPTIONS.get(item["rarity"], "rare")
    query = {"status": {"option": "online"}, "type": item["base_type"]}
    if item["rarity"] == "Unique":
        query["name"] = item["name"]
    filters = _base_filters(rarity_option, item["links"])
    if filters:
        query["filters"] = filters
    if stat_filters:
        query["stats"] = [{"type": "and", "filters": stat_filters}]

    body = {"query": query, "sort": {"price": "asc"}}
    data = http_json(f"{API_BASE}/search/{league}", body)
    ids = data.get("result", [])[:MAX_FETCH_IDS]
    if not ids:
        return {"lines": ["Лотів не знайдено з такими фільтрами"], "error": False}

    query_id = data["id"]
    fetch = http_json(f"{API_BASE}/fetch/{','.join(ids)}?query={query_id}")
    listings = _top_listings(fetch)

    if not listings:
        return {"lines": ["Лоти без вказаної ціни"], "error": False}

    lines = [f"{_floor_line(listings[0], league, reference_chaos)} ({len(ids)} лотів)"] + [
        f"  {_format_listing(extra)}" for extra in listings[1:4]
    ]
    return {"lines": lines, "error": False, "whisper": listings[0]["whisper"]}


def ninja_unique_lookup(item, league):
    """Сирий матч Unique з poe.ninja (chaos/links/trend), або None -- число
    ще потрібне окремо (не лише для format_ninja_unique_line() нижче) як
    reference_chaos для позначення підозріло дешевих floor-лотів у
    item_search_floor/item_search_stats вище."""
    try:
        return ninja_unique_match(get_ninja_uniques(league), item["name"], item["links"])
    except (ApiError, RateLimited):
        return None


def format_ninja_unique_line(match):
    return f"poe.ninja: ~{match['chaos']:.0f} chaos{trend_suffix(match['trend'])}"


def price_item(item, league):
    rarity = item["rarity"]
    if rarity in ("Currency", "Divination Card"):
        return price_currency(item, league)
    if rarity == "Gem":
        return item_search_floor(item["name"], league)
    if rarity == "Unique":
        ninja_match = ninja_unique_lookup(item, league)
        result = item_search_floor(
            item["base_type"], league, rarity_option="unique", name=item["name"], links=item["links"],
            reference_chaos=ninja_match["chaos"] if ninja_match else None,
        )
        if ninja_match:
            result["lines"] = [format_ninja_unique_line(ninja_match)] + result["lines"]
        return result
    if rarity == "Rare":
        return item_search_floor(item["base_type"], league, rarity_option="rare")
    if rarity == "Magic":
        base_type = resolve_magic_base_type(item["name"], get_base_type_index())
        if base_type is None:
            return {
                "title": item["name"],
                "lines": ["Не вдалось визначити базовий тип (Magic)"],
                "error": True,
            }
        return item_search_floor(base_type, league, rarity_option="magic")
    return {
        "title": item.get("name", "?"),
        "lines": [f"Rarity '{rarity}' поки не підтримується"],
        "error": True,
    }


# --- отримання предмету ---


def read_clipboard():
    result = subprocess.run(
        ["xclip", "-selection", "clipboard", "-o"], capture_output=True, text=True
    )
    return result.stdout


def copy_hovered_item():
    subprocess.run(["xdotool", "key", "--clearmodifiers", "ctrl+c"])
    time.sleep(0.15)


def copy_to_clipboard(text):
    subprocess.run(["xclip", "-selection", "clipboard"], input=text, text=True)


# --- overlay (tkinter, override_redirect -- bspwm його взагалі не бачить,
# тож не потрібне жодне floating-правило на відміну від Awakened) ---


def _make_root(accent):
    import tkinter as tk

    root = tk.Tk(className="PoePriceCheck")
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    try:
        root.attributes("-alpha", 0.92)
    except tk.TclError:
        pass
    root.configure(bg=COLORS["bg"])

    pad = tk.Frame(root, bg=COLORS["bg"], highlightbackground=accent, highlightthickness=2)
    pad.pack(padx=1, pady=1)
    return root, pad


def _place_top_right(root):
    root.update_idletasks()
    width = root.winfo_reqwidth()
    height = root.winfo_reqheight()
    screen_w = root.winfo_screenwidth()
    x = screen_w - width - 24
    y = 24
    root.geometry(f"{width}x{height}+{x}+{y}")


def show_overlay(title, lines, is_error, whisper=None):
    import tkinter as tk

    accent = COLORS["error"] if is_error else COLORS["accent"]
    root, pad = _make_root(accent)

    tk.Label(
        pad,
        text=title,
        fg=accent,
        bg=COLORS["bg"],
        font=("monospace", 12, "bold"),
        justify="left",
        anchor="w",
    ).pack(fill="x", padx=10, pady=(8, 2))

    for line in lines:
        tk.Label(
            pad,
            text=line,
            fg=COLORS["fg"],
            bg=COLORS["bg"],
            font=("monospace", 11),
            justify="left",
            anchor="w",
        ).pack(fill="x", padx=10)

    if whisper:
        # з кнопкою "клік будь-де закриває" вимикаємо: <ButtonPress-1> на
        # самій кнопці спливає до root-біндингу раніше за <ButtonRelease-1>,
        # яка викликає command -- вікно закрилось би до копіювання. Замість
        # цього -- явна кнопка "Закрити", як у show_stat_overlay нижче.
        btn_row = tk.Frame(pad, bg=COLORS["bg"])
        btn_row.pack(fill="x", padx=10, pady=(4, 0))
        tk.Button(
            btn_row,
            text="Скопіювати whisper",
            command=lambda: copy_to_clipboard(whisper),
            bg=COLORS["entry_bg"],
            fg=COLORS["fg"],
            activebackground=accent,
            relief="flat",
        ).pack(side="left")
        tk.Button(
            btn_row,
            text="Закрити",
            command=root.destroy,
            bg=COLORS["entry_bg"],
            fg=COLORS["fg"],
            activebackground=COLORS["error"],
            relief="flat",
        ).pack(side="left", padx=(6, 0))
    else:
        root.bind("<Button-1>", lambda _e: root.destroy())

    tk.Frame(pad, bg=COLORS["bg"], height=8).pack()

    _place_top_right(root)

    root.bind("<Escape>", lambda _e: root.destroy())
    root.after(7000, root.destroy)
    root.mainloop()


def format_value(v):
    if v == int(v):
        return str(int(v))
    return f"{v:g}"


def show_stat_overlay(item, mods, league, ninja_line=None, reference_chaos=None):
    """Інтерактивний overlay у стилі Awakened PoE Trade: список розпізнаних
    модів з чекбоксами й полями мін.значення, автопошук одразу з усіма
    модами увімкненими, кнопка ручного оновлення після зміни вибору."""
    import tkinter as tk

    root, pad = _make_root(COLORS["accent"])

    tk.Label(
        pad,
        text=item["name"],
        fg=COLORS["accent"],
        bg=COLORS["bg"],
        font=("monospace", 12, "bold"),
        justify="left",
        anchor="w",
    ).pack(fill="x", padx=10, pady=(8, 2))

    if ninja_line:
        tk.Label(
            pad,
            text=ninja_line,
            fg=COLORS["muted"],
            bg=COLORS["bg"],
            font=("monospace", 10),
            justify="left",
            anchor="w",
        ).pack(fill="x", padx=10)

    result_container = tk.Frame(pad, bg=COLORS["bg"])
    result_container.pack(fill="x", padx=10, pady=(2, 6))

    mod_rows = []
    if mods:
        mods_frame = tk.Frame(pad, bg=COLORS["bg"], highlightbackground=COLORS["muted"], highlightthickness=1)
        mods_frame.pack(fill="x", padx=10, pady=(0, 4))
        for mod in mods:
            n_values = len(mod["values"])
            # 0 значень -- "статичний" мод без числа (checkbox без поля);
            # 1 значення -- звичний числовий мод (checkbox + мін.значення);
            # 2+ значень ("Adds # to # ...") -- фільтр не будуємо, тільки показ.
            filterable = n_values <= 1
            row = tk.Frame(mods_frame, bg=COLORS["bg"])
            row.pack(fill="x", pady=1, padx=4)

            # усі -- вимкнені за замовчуванням: перший автопошук нижче дає
            # швидку базову ціну за типом/рідкістю (як старий floor-пошук),
            # а не "0 лотів" -- бо із увімкненими одразу всіма модами з
            # min=точний ролл шанс знайти лот, що задовольняє геть усі
            # умови водночас, майже нульовий. Користувач сам відмічає 1-2
            # моди, які хоче звузити.
            var = tk.BooleanVar(value=False)
            cb = tk.Checkbutton(
                row,
                variable=var,
                bg=COLORS["bg"],
                activebackground=COLORS["bg"],
                fg=COLORS["fg"],
                selectcolor=COLORS["bg"],
                highlightthickness=0,
            )
            if not filterable:
                cb.configure(state="disabled")
            cb.pack(side="left")

            val_var = None
            if n_values == 1:
                value = mod["values"][0]
                val_var = tk.StringVar(value=format_value(value))
                value_range = mod.get("range")

                if value_range is not None:
                    lo, hi = value_range
                    resolution = 1 if all(v == int(v) for v in (lo, hi, value)) else 0.1
                    num_var = tk.DoubleVar(value=value)

                    def on_scale_move(new_val, val_var=val_var):
                        val_var.set(format_value(float(new_val)))

                    def on_entry_edit(*_a, num_var=num_var, val_var=val_var):
                        try:
                            parsed = float(val_var.get())
                        except ValueError:
                            return
                        if abs(num_var.get() - parsed) > 1e-9:
                            num_var.set(parsed)

                    val_var.trace_add("write", on_entry_edit)
                    tk.Scale(
                        row,
                        variable=num_var,
                        from_=lo,
                        to=hi,
                        resolution=resolution,
                        orient="horizontal",
                        length=80,
                        showvalue=False,
                        command=on_scale_move,
                        bg=COLORS["bg"],
                        fg=COLORS["fg"],
                        troughcolor=COLORS["entry_bg"],
                        highlightthickness=0,
                        sliderrelief="flat",
                        bd=0,
                    ).pack(side="left", padx=(2, 4))

                entry = tk.Entry(
                    row,
                    textvariable=val_var,
                    width=6,
                    bg=COLORS["entry_bg"],
                    fg=COLORS["fg"],
                    insertbackground=COLORS["fg"],
                    relief="flat",
                )
                entry.pack(side="left", padx=(2, 6))

            tk.Label(
                row,
                text=mod["line"],
                fg=COLORS["fg"] if filterable else COLORS["muted"],
                bg=COLORS["bg"],
                font=("monospace", 10),
                anchor="w",
                justify="left",
            ).pack(side="left", fill="x")

            mod_rows.append((var, val_var, mod, filterable))
    else:
        tk.Label(
            pad,
            text="Моди не розпізнано -- пошук лише за типом предмету.",
            fg=COLORS["muted"],
            bg=COLORS["bg"],
            font=("monospace", 10),
            anchor="w",
            justify="left",
        ).pack(fill="x", padx=10, pady=(0, 4))

    def render_result(lines, is_error):
        for child in result_container.winfo_children():
            child.destroy()
        for line in lines:
            tk.Label(
                result_container,
                text=line,
                fg=COLORS["error"] if is_error else COLORS["fg"],
                bg=COLORS["bg"],
                font=("monospace", 11),
                anchor="w",
                justify="left",
            ).pack(fill="x")
        _place_top_right(root)

    whisper_state = {"value": None}

    def run_search():
        stat_filters = []
        for var, val_var, mod, filterable in mod_rows:
            if not filterable or not var.get():
                continue
            if val_var is None:
                stat_filters.append({"id": mod["id"]})
                continue
            try:
                min_val = float(val_var.get())
            except ValueError:
                continue
            stat_filters.append({"id": mod["id"], "value": {"min": min_val}})

        render_result(["Пошук..."], False)
        root.update()
        whisper_state["value"] = None
        try:
            result = item_search_stats(item, league, stat_filters, reference_chaos=reference_chaos)
            render_result(result["lines"], result["error"])
            whisper_state["value"] = result.get("whisper")
        except RateLimited as e:
            render_result([f"Ліміт запитів API, спробуй через {e.retry_after}с"], True)
        except ApiError as e:
            render_result([str(e)], True)
        whisper_btn.configure(state="normal" if whisper_state["value"] else "disabled")

    btn_row = tk.Frame(pad, bg=COLORS["bg"])
    btn_row.pack(fill="x", padx=10, pady=(0, 8))
    tk.Button(
        btn_row,
        text="Оновити пошук",
        command=run_search,
        bg=COLORS["entry_bg"],
        fg=COLORS["fg"],
        activebackground=COLORS["accent"],
        relief="flat",
    ).pack(side="left")
    whisper_btn = tk.Button(
        btn_row,
        text="Whisper",
        command=lambda: copy_to_clipboard(whisper_state["value"]),
        state="disabled",
        bg=COLORS["entry_bg"],
        fg=COLORS["fg"],
        activebackground=COLORS["accent"],
        relief="flat",
    )
    whisper_btn.pack(side="left", padx=(6, 0))
    tk.Button(
        btn_row,
        text="Закрити",
        command=root.destroy,
        bg=COLORS["entry_bg"],
        fg=COLORS["fg"],
        activebackground=COLORS["error"],
        relief="flat",
    ).pack(side="left", padx=(6, 0))

    root.bind("<Escape>", lambda _e: root.destroy())
    _place_top_right(root)
    root.after(100, run_search)
    root.mainloop()


def print_result(title, lines, is_error, whisper=None):
    prefix = "[error] " if is_error else ""
    print(f"{prefix}{title}")
    for line in lines:
        print(f"  {line}")
    if whisper:
        print(f"  whisper: {whisper}")


def main():
    args = sys.argv[1:]
    use_stdin = "--stdin" in args
    from_clipboard = "--from-clipboard" in args
    no_gui = "--no-gui" in args

    if use_stdin:
        text = sys.stdin.read()
    else:
        if not from_clipboard:
            copy_hovered_item()
        text = read_clipboard()

    output = print_result if no_gui else show_overlay

    item = parse_item(text)
    if item is None:
        output(
            "Помилка",
            ["Не знайдено предмет у буфері.", "Наведи курсор на предмет в грі і спробуй ще раз."],
            True,
        )
        return

    # Rare/Unique/Magic у GUI-режимі -- інтерактивний вибір модів (як Awakened
    # PoE Trade), а не одразу тихий floor-пошук лише за базовим типом.
    if not no_gui and item["rarity"] in ("Rare", "Unique", "Magic"):
        try:
            league = get_current_league()
            if item["rarity"] == "Magic":
                base_type = resolve_magic_base_type(item["name"], get_base_type_index())
                if base_type is None:
                    show_overlay("Помилка", ["Не вдалось визначити базовий тип (Magic)."], True)
                    return
                item = dict(item, base_type=base_type)
            mods = match_item_mods(item["lines"], item["mod_start_idx"])
            ninja_match = ninja_unique_lookup(item, league) if item["rarity"] == "Unique" else None
        except RateLimited as e:
            show_overlay("Помилка", [f"Ліміт запитів API, спробуй через {e.retry_after}с"], True)
            return
        except ApiError as e:
            show_overlay("Помилка", [str(e)], True)
            return
        ninja_line = format_ninja_unique_line(ninja_match) if ninja_match else None
        reference_chaos = ninja_match["chaos"] if ninja_match else None
        show_stat_overlay(item, mods, league, ninja_line=ninja_line, reference_chaos=reference_chaos)
        return

    try:
        league = get_current_league()
        result = price_item(item, league)
    except RateLimited as e:
        output("Помилка", [f"Ліміт запитів API, спробуй через {e.retry_after}с"], True)
        return
    except ApiError as e:
        output("Помилка", [str(e)], True)
        return

    output(result["title"], result["lines"], result["error"], result.get("whisper"))


if __name__ == "__main__":
    main()
