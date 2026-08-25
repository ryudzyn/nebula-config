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
import urllib.request

API_BASE = "https://www.pathofexile.com/api/trade"
USER_AGENT = "poe-price-check/0.1 (contact: ryudzyn@gmail.com)"
CACHE_DIR = os.path.expanduser("~/.cache/poe-price-check")
LEAGUE_TTL = 3600
STATIC_TTL = 86400
REQUEST_TIMEOUT = 6
MAX_FETCH_IDS = 10

COLORS = {
    "bg": "#1a1a2e",
    "fg": "#e0e0f0",
    "accent": "#9d4edd",
    "muted": "#888888",
    "error": "#e05561",
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
    if rarity in ("Rare", "Unique") and rarity_idx + 2 < len(lines):
        next_line = lines[rarity_idx + 2]
        if next_line and not next_line.startswith("--------"):
            base_type = next_line

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
    }


# --- ціноутворення ---


def price_currency(item, league):
    currency_map = get_currency_map()
    currency_id = currency_map.get(item["name"])
    if not currency_id:
        return item_search_floor(item["base_type"], league)

    if currency_id == "chaos":
        lines = ["1 chaos (базова валюта)"]
        if item["stack_size"] > 1:
            lines.append(f"стак {item['stack_size']} шт.")
        return {"title": item["name"], "lines": lines, "error": False}

    body = {
        "query": {
            "status": {"option": "online"},
            "have": [currency_id],
            "want": ["chaos"],
        },
        "sort": {"have": "asc"},
    }
    try:
        data = http_json(f"{API_BASE}/exchange/{league}", body)
    except ApiError:
        return item_search_floor(item["base_type"], league)

    result = data.get("result")
    if not isinstance(result, dict):
        return item_search_floor(item["base_type"], league)

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
        return {"title": item["name"], "lines": ["Немає активних лотів на обмін"], "error": False}

    median = statistics.median(ratios)
    total = median * item["stack_size"]
    lines = [f"~{median:.1f} chaos за 1 шт. ({len(ratios)} лотів)"]
    if item["stack_size"] > 1:
        lines.append(f"стак {item['stack_size']} шт. -> ~{total:.0f} chaos")
    return {"title": item["name"], "lines": lines, "error": False}


def item_search_floor(type_text, league, rarity_option=None, name=None, links=0):
    query = {"status": {"option": "online"}, "type": type_text}
    if name:
        query["name"] = name
    filters = {}
    if rarity_option:
        filters.setdefault("type_filters", {}).setdefault("filters", {})["rarity"] = {
            "option": rarity_option
        }
    if links >= 5:
        filters.setdefault("socket_filters", {}).setdefault("filters", {})["links"] = {
            "min": links
        }
    if filters:
        query["filters"] = filters

    body = {"query": query, "sort": {"price": "asc"}}
    data = http_json(f"{API_BASE}/search/{league}", body)
    ids = data.get("result", [])[:MAX_FETCH_IDS]
    if not ids:
        if links >= 5:
            # без збігу за лінками -- пробуємо ще раз без фільтра лінків,
            # чесно позначаючи це в результаті нижче.
            return item_search_floor(type_text, league, rarity_option, name, links=0)
        return {"title": type_text, "lines": ["Лотів не знайдено"], "error": False}

    query_id = data["id"]
    fetch = http_json(f"{API_BASE}/fetch/{','.join(ids)}?query={query_id}")

    listing_lines = []
    for entry in (fetch.get("result") or [])[:5]:
        price = entry.get("listing", {}).get("price")
        if not price:
            continue
        listing_lines.append(f"{price['amount']} {price['currency']}")

    if not listing_lines:
        return {"title": type_text, "lines": ["Лоти без вказаної ціни"], "error": False}

    title = name or type_text
    lines = [f"floor: {listing_lines[0]}"] + [f"  {extra}" for extra in listing_lines[1:4]]
    return {"title": title, "lines": lines, "error": False}


def price_item(item, league):
    rarity = item["rarity"]
    if rarity in ("Currency", "Divination Card"):
        return price_currency(item, league)
    if rarity == "Gem":
        return item_search_floor(item["name"], league)
    if rarity == "Unique":
        return item_search_floor(
            item["base_type"], league, rarity_option="unique", name=item["name"], links=item["links"]
        )
    if rarity == "Rare":
        return item_search_floor(item["base_type"], league, rarity_option="rare")
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


# --- overlay (tkinter, override_redirect -- bspwm його взагалі не бачить,
# тож не потрібне жодне floating-правило на відміну від Awakened) ---


def show_overlay(title, lines, is_error):
    import tkinter as tk

    root = tk.Tk(className="PoePriceCheck")
    root.overrideredirect(True)
    root.attributes("-topmost", True)
    try:
        root.attributes("-alpha", 0.92)
    except tk.TclError:
        pass
    root.configure(bg=COLORS["bg"])

    accent = COLORS["error"] if is_error else COLORS["accent"]
    pad = tk.Frame(root, bg=COLORS["bg"], highlightbackground=accent, highlightthickness=2)
    pad.pack(padx=1, pady=1)

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

    tk.Frame(pad, bg=COLORS["bg"], height=8).pack()

    root.update_idletasks()
    width = root.winfo_reqwidth()
    height = root.winfo_reqheight()
    screen_w = root.winfo_screenwidth()
    x = screen_w - width - 24
    y = 24
    root.geometry(f"{width}x{height}+{x}+{y}")

    root.bind("<Button-1>", lambda _e: root.destroy())
    root.bind("<Escape>", lambda _e: root.destroy())
    root.after(7000, root.destroy)
    root.mainloop()


def print_result(title, lines, is_error):
    prefix = "[error] " if is_error else ""
    print(f"{prefix}{title}")
    for line in lines:
        print(f"  {line}")


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

    try:
        league = get_current_league()
        result = price_item(item, league)
    except RateLimited as e:
        output("Помилка", [f"Ліміт запитів API, спробуй через {e.retry_after}с"], True)
        return
    except ApiError as e:
        output("Помилка", [str(e)], True)
        return

    output(result["title"], result["lines"], result["error"])


if __name__ == "__main__":
    main()
