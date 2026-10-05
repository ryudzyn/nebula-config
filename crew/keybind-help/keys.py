"""nebula-keys -- visual Hyprland keybind cheat sheet (SUPER+SHIFT+/).

A GTK3 layer-shell overlay over everything: a drawn keyboard with every key that has a bind
lit in its group's color (hover a key for what it does with SUPER / +SHIFT / +CTRL), a
modifier switch for which layer the keyboard shows, and one card per group with each bind as
key caps + description. Typing filters everything; Esc or a click outside closes. Running it
again while it's open closes it (toggle). Data: the JSON crew/hyprland/hyprland.lua writes on
every start/reload from its own binds table, so this can't drift from the real binds.
"""

import json
import os
import signal
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango, PangoCairo  # noqa: E402

PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "nebula-keys.pid")

# Group -> (icon, color). Unknown groups fall back to the last entry's look.
GROUPS = {
    "Основні": ("🚀", "#9d4edd"),
    "Вікна": ("🪟", "#3cc8e8"),
    "Режими": ("🎛", "#e0a83c"),
    "Скріншоти й запис": ("📸", "#e05561"),
    "Scratchpad": ("🗂", "#b06fe0"),
    "Миша": ("🖱", "#8090a0"),
    "Система": ("⚙", "#6fbf4a"),
    "Огляд": ("🔭", "#3ce0a8"),
    "Утиліти": ("🧰", "#e0622c"),
    "Медіа": ("🔊", "#d04060"),
    "Фокус": ("🎯", "#5b8def"),
    "Поміняти вікна місцями": ("🔀", "#5b8def"),
    "Розмір вікна": ("↔", "#5b8def"),
    "Робочі простори": ("🔢", "#c0c0d0"),
}
FALLBACK_GROUP = ("•", "#a0a0b0")

MODIFIERS = ("SUPER", "SHIFT", "CTRL", "ALT")

# Hyprland key names -> what's printed on the cap / the keyboard key id.
KEY_ALIASES = {
    "RETURN": "Enter", "ESCAPE": "Esc", "SLASH": "/", "EQUAL": "=", "MINUS": "-", "SPACE": "Space",
    "TAB": "Tab", "PRINT": "PrtSc", "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓",
    "MOUSE:272": "ЛКМ", "MOUSE:273": "ПКМ",
    "XF86AUDIORAISEVOLUME": "Гучн+", "XF86AUDIOLOWERVOLUME": "Гучн−", "XF86AUDIOMUTE": "Mute",
    "XF86MONBRIGHTNESSUP": "Яскр+", "XF86MONBRIGHTNESSDOWN": "Яскр−",
}

# The drawn keyboard: rows of (key id, label, width in key units). Ids match KEY_ALIASES
# values / plain letters, so a bind "SUPER + Return" lights the key "Enter".
ROW_F = ([("Esc", "Esc", 1.0), (None, "", 0.5)]
         + [(f"F{i}", f"F{i}", 1.0) for i in range(1, 13)]
         + [(None, "", 0.25), ("PrtSc", "PrtSc", 1.25)])
ROW_NUM = ([("`", "`", 1.0)] + [(c, c, 1.0) for c in "1234567890"]
           + [("-", "-", 1.0), ("=", "=", 1.0), ("Backspace", "⌫", 2.0)])
ROW_TOP = ([("Tab", "Tab", 1.5)] + [(c, c, 1.0) for c in "QWERTYUIOP"]
           + [("[", "[", 1.0), ("]", "]", 1.0), ("\\", "\\", 1.5)])
ROW_HOME = ([("Caps", "Caps", 1.75)] + [(c, c, 1.0) for c in "ASDFGHJKL"]
            + [(";", ";", 1.0), ("'", "'", 1.0), ("Enter", "Enter", 2.25)])
ROW_LOW = ([("ShiftL", "Shift", 2.25)] + [(c, c, 1.0) for c in "ZXCVBNM"]
           + [(",", ",", 1.0), (".", ".", 1.0), ("/", "/", 1.0), ("ShiftR", "Shift", 2.75)])
ROW_SPACE = [("CtrlL", "Ctrl", 1.5), ("SuperL", "Super", 1.25), ("AltL", "Alt", 1.25),
             ("Space", "Space", 6.0), ("AltR", "Alt", 1.25), (None, "", 0.25),
             ("←", "←", 1.0), ("↓", "↓", 1.0), ("↑", "↑", 1.0), ("→", "→", 1.0)]
KEYBOARD = [ROW_F, ROW_NUM, ROW_TOP, ROW_HOME, ROW_LOW, ROW_SPACE]
MOD_KEY_IDS = {"SUPER": {"SuperL"}, "SHIFT": {"ShiftL", "ShiftR"}, "CTRL": {"CtrlL"}, "ALT": {"AltL", "AltR"}}
LAYERS = [("SUPER", ("SUPER",)), ("SUPER + SHIFT", ("SUPER", "SHIFT")), ("SUPER + CTRL", ("SUPER", "CTRL")),
          ("Без SUPER", ())]

CSS = b"""
window { background-color: transparent; }
.sheet {
  background-color: rgba(26, 26, 46, 0.97);
  border: 1px solid #3a2f5c; border-radius: 18px; padding: 20px 24px;
}
.title { font-size: 20px; font-weight: bold; color: #e6dcff; }
.subtitle { color: #8f86b0; font-size: 12px; }
entry.search {
  background-color: #12121f; color: #e6dcff; border: 1px solid #3a2f5c; border-radius: 10px;
  padding: 6px 12px; min-width: 320px; caret-color: #9d4edd;
}
.layerbtn {
  background-image: none; background-color: #232340; color: #c9c0ea; border: 1px solid #3a2f5c;
  border-radius: 999px; padding: 3px 14px; box-shadow: none; text-shadow: none;
}
.layerbtn:checked { background-color: #9d4edd; color: #ffffff; border-color: #b77aea; }
.card { background-color: #20203a; border-radius: 14px; padding: 12px 14px; }
.card-title { font-weight: bold; font-size: 14px; }
.row { padding: 3px 0; }
.desc { color: #d8d0f0; }
.keycap {
  background-color: #34345a; color: #f2eeff; border: 1px solid #4a4a78; border-bottom-width: 3px;
  border-radius: 6px; padding: 1px 7px; font-family: monospace; font-size: 12px; min-width: 14px;
}
.keycap.mod { background-color: #2a2a48; color: #c9b8ff; }
.plus { color: #6f6890; }
.empty { color: #8f86b0; font-style: italic; }
"""


def parse_key(spec):
    """'SUPER + SHIFT + Return' -> (('SUPER', 'SHIFT'), 'Enter')."""
    parts = [p.strip() for p in spec.split("+") if p.strip()]
    mods = tuple(p.upper() for p in parts if p.upper() in MODIFIERS)
    rest = [p for p in parts if p.upper() not in MODIFIERS]
    key = rest[-1] if rest else ""
    return mods, KEY_ALIASES.get(key.upper(), key.upper() if len(key) == 1 else key)


def group_look(section):
    return GROUPS.get(section, FALLBACK_GROUP)


class Keyboard(Gtk.DrawingArea):
    """The drawn keyboard: keys with a bind on the current modifier layer get their group color."""

    UNIT = 46
    GAP = 5

    def __init__(self, entries):
        super().__init__()
        self.entries = entries
        self.layer = ("SUPER",)
        self.query = ""
        self.hover_id = None
        self.rects = []  # (x, y, w, h, key_id)
        width = max(sum(w for _, _, w in row) for row in KEYBOARD)
        self.set_size_request(int(width * self.UNIT + 2), int(len(KEYBOARD) * self.UNIT + 2))
        self.set_has_tooltip(True)
        self.add_events(Gdk.EventMask.POINTER_MOTION_MASK)
        self.connect("draw", self.on_draw)
        self.connect("query-tooltip", self.on_tooltip)

    def binds_for(self, key_id, layer=None):
        out = []
        for e in self.entries:
            mods, key = e["parsed"]
            if key == key_id and (layer is None or set(mods) == set(layer)):
                out.append(e)
        return out

    def matches_query(self, e):
        q = self.query
        return not q or q in e["desc"].lower() or q in e["key"].lower() or q in e["section"].lower()

    def on_draw(self, widget, cr):
        self.rects = []
        y = 1
        for row in KEYBOARD:
            x = 1
            for key_id, label, w in row:
                kw = w * self.UNIT - self.GAP
                kh = self.UNIT - self.GAP
                if key_id is not None:
                    self.draw_key(cr, x, y, kw, kh, key_id, label)
                    self.rects.append((x, y, kw, kh, key_id))
                x += w * self.UNIT
            y += self.UNIT
        return False

    def draw_key(self, cr, x, y, w, h, key_id, label):
        binds = [e for e in self.binds_for(key_id, self.layer) if self.matches_query(e)]
        held_mod = any(key_id in MOD_KEY_IDS[m] for m in self.layer)
        if binds:
            color = Gdk.RGBA()
            color.parse(group_look(binds[0]["section"])[1])
            fill = (color.red, color.green, color.blue, 0.85)
            text = (1, 1, 1, 1)
        elif held_mod:
            fill = (0.62, 0.30, 0.87, 0.55)
            text = (1, 1, 1, 1)
        else:
            fill = (0.17, 0.17, 0.29, 1)
            text = (0.55, 0.52, 0.68, 1)
        r = 7
        cr.new_sub_path()
        cr.arc(x + w - r, y + r, r, -1.5708, 0)
        cr.arc(x + w - r, y + h - r, r, 0, 1.5708)
        cr.arc(x + r, y + h - r, r, 1.5708, 3.1416)
        cr.arc(x + r, y + r, r, 3.1416, 4.7124)
        cr.close_path()
        cr.set_source_rgba(*fill)
        cr.fill_preserve()
        if key_id == self.hover_id:
            cr.set_source_rgba(1, 1, 1, 0.9)
            cr.set_line_width(2)
        else:
            cr.set_source_rgba(0, 0, 0, 0.35)
            cr.set_line_width(1)
        cr.stroke()
        layout = PangoCairo.create_layout(cr)
        layout.set_font_description(Pango.FontDescription("Sans Bold 10"))
        layout.set_text(label, -1)
        tw, th = layout.get_pixel_size()
        cr.set_source_rgba(*text)
        cr.move_to(x + (w - tw) / 2, y + (h - th) / 2 - (5 if binds and len(binds) > 1 else 0))
        PangoCairo.show_layout(cr, layout)
        if len(binds) > 1:  # several binds on this key+layer: a small count
            layout.set_font_description(Pango.FontDescription("Sans 7"))
            layout.set_text(f"×{len(binds)}", -1)
            tw2, _ = layout.get_pixel_size()
            cr.move_to(x + (w - tw2) / 2, y + h - 14)
            PangoCairo.show_layout(cr, layout)

    def on_tooltip(self, widget, x, y, keyboard_mode, tooltip):
        hit = None
        for rx, ry, rw, rh, key_id in self.rects:
            if rx <= x <= rx + rw and ry <= y <= ry + rh:
                hit = key_id
                break
        if hit != self.hover_id:
            self.hover_id = hit
            self.queue_draw()
        if hit is None:
            return False
        lines = []
        for e in self.binds_for(hit):
            mods, _ = e["parsed"]
            combo = " + ".join(m.capitalize() for m in mods) or "без модифікаторів"
            lines.append(f"<b>{GLib.markup_escape_text(combo)}</b>  {GLib.markup_escape_text(e['desc'])}")
        if not lines:
            return False
        tooltip.set_markup("\n".join(lines))
        return True


def keycaps(spec):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
    # Caps stay one line tall even when the description beside them wraps to three.
    box.set_valign(Gtk.Align.CENTER)
    mods, key = parse_key(spec)
    if spec.strip().upper().endswith("1-9"):
        key = "1–9"
    parts = [(m.capitalize(), True) for m in mods] + ([(key, False)] if key else [])
    for i, (text, is_mod) in enumerate(parts):
        if i:
            plus = Gtk.Label(label="+")
            plus.get_style_context().add_class("plus")
            box.pack_start(plus, False, False, 0)
        cap = Gtk.Label(label=text)
        cap.get_style_context().add_class("keycap")
        if is_mod:
            cap.get_style_context().add_class("mod")
        box.pack_start(cap, False, False, 0)
    return box


class Sheet(Gtk.Window):
    def __init__(self, entries):
        super().__init__()
        self.entries = entries
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "nebula-keys")
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT,
                     GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        self.set_app_paintable(True)
        # The dim backdrop is painted here: an EventBox's CSS background never reached the
        # screen on a transparent layer-shell window (2026-10-05, seen live).
        self.connect("draw", self.paint_backdrop)
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual is not None:
            self.set_visual(visual)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Full-screen dim backdrop; a click on it (outside the sheet) closes.
        backdrop = Gtk.EventBox()
        backdrop.get_style_context().add_class("backdrop")
        backdrop.connect("button-press-event", lambda *_: self.close_sheet())
        self.add(backdrop)

        sheet_events = Gtk.EventBox()  # swallows clicks so they don't reach the backdrop
        sheet_events.connect("button-press-event", lambda *_: True)
        sheet_events.set_halign(Gtk.Align.CENTER)
        sheet_events.set_valign(Gtk.Align.CENTER)
        backdrop.add(sheet_events)

        sheet = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        sheet.get_style_context().add_class("sheet")
        sheet_events.add(sheet)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        titles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title = Gtk.Label(label="⌨  Комбінації клавіш", xalign=0)
        title.get_style_context().add_class("title")
        subtitle = Gtk.Label(label="Наведи на клавішу — побачиш, що вона робить · друкуй для пошуку · Esc — закрити",
                             xalign=0)
        subtitle.get_style_context().add_class("subtitle")
        titles.pack_start(title, False, False, 0)
        titles.pack_start(subtitle, False, False, 0)
        header.pack_start(titles, True, True, 0)
        self.search = Gtk.SearchEntry()
        self.search.get_style_context().add_class("search")
        self.search.set_placeholder_text("Пошук: «скрін», «вікно», «Q»…")
        self.search.connect("search-changed", self.on_search)
        header.pack_end(self.search, False, False, 0)
        sheet.pack_start(header, False, False, 0)

        layer_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        layer_row.set_halign(Gtk.Align.CENTER)
        self.keyboard = Keyboard(entries)
        first = None
        for label, mods in LAYERS:
            btn = Gtk.RadioButton.new_with_label_from_widget(first, label)
            btn.set_mode(False)  # look like a toggle chip, not a radio dot
            btn.get_style_context().add_class("layerbtn")
            btn.connect("toggled", self.on_layer, mods)
            layer_row.pack_start(btn, False, False, 0)
            first = first or btn
        sheet.pack_start(layer_row, False, False, 0)
        kb_holder = Gtk.Box()
        kb_holder.set_halign(Gtk.Align.CENTER)
        kb_holder.pack_start(self.keyboard, False, False, 0)
        sheet.pack_start(kb_holder, False, False, 0)

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_min_content_height(330)
        scroller.set_propagate_natural_height(True)
        self.flow = Gtk.FlowBox()
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_max_children_per_line(4)
        self.flow.set_min_children_per_line(3)
        self.flow.set_column_spacing(12)
        self.flow.set_row_spacing(12)
        self.flow.set_homogeneous(False)
        scroller.add(self.flow)
        sheet.pack_start(scroller, True, True, 0)
        self.empty = Gtk.Label(label="Нічого не знайдено")
        self.empty.get_style_context().add_class("empty")
        sheet.pack_start(self.empty, False, False, 0)

        self.cards = []  # (card widget, [(row widget, entry)])
        for section in dict.fromkeys(e["section"] for e in entries):
            icon, color = group_look(section)
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            card.get_style_context().add_class("card")
            card.set_size_request(330, -1)
            head = Gtk.Label(xalign=0)
            head.set_markup(f'<span foreground="{color}">{icon}  {GLib.markup_escape_text(section)}</span>')
            head.get_style_context().add_class("card-title")
            card.pack_start(head, False, False, 4)
            rows = []
            for e in (e for e in entries if e["section"] == section):
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                row.get_style_context().add_class("row")
                caps = keycaps(e["key"])
                caps.set_size_request(150, -1)
                row.pack_start(caps, False, False, 0)
                desc = Gtk.Label(label=e["desc"], xalign=0)
                desc.set_line_wrap(True)
                desc.set_max_width_chars(28)
                desc.get_style_context().add_class("desc")
                row.pack_start(desc, True, True, 0)
                card.pack_start(row, False, False, 0)
                rows.append((row, e))
            self.flow.add(card)
            self.cards.append((card, rows))

        self.connect("key-press-event", self.on_key)
        self.set_default_size(1, 1)
        self.show_all()
        self.empty.hide()
        self.search.grab_focus()

    def paint_backdrop(self, widget, cr):
        cr.set_source_rgba(0.03, 0.03, 0.07, 0.6)
        cr.set_operator(1)  # cairo.OPERATOR_SOURCE
        cr.paint()
        cr.set_operator(2)  # cairo.OPERATOR_OVER
        return False

    def on_layer(self, button, mods):
        if button.get_active():
            self.keyboard.layer = mods
            self.keyboard.queue_draw()

    def on_search(self, entry):
        q = entry.get_text().strip().lower()
        self.keyboard.query = q
        self.keyboard.queue_draw()
        any_visible = False
        for card, rows in self.cards:
            shown = 0
            for row, e in rows:
                visible = self.keyboard.matches_query(e)
                row.set_visible(visible)
                shown += visible
            card.get_parent().set_visible(shown > 0)  # FlowBoxChild
            any_visible = any_visible or shown > 0
        self.empty.set_visible(not any_visible)

    def on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            if self.search.get_text():
                self.search.set_text("")
            else:
                self.close_sheet()
            return True
        return False

    def close_sheet(self):
        Gtk.main_quit()
        return True


def load_entries(path):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    entries = []
    for e in raw:
        e["parsed"] = parse_key(e["key"])
        entries.append(e)
    return entries


def toggle_existing():
    """If a sheet is already open, close it and report True (SUPER+SHIFT+/ toggles)."""
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, signal.SIGTERM)
        return True
    except (OSError, ValueError):
        return False


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/nebula-hypr-keybinds.json"
    if toggle_existing():
        return
    try:
        entries = load_entries(path)
    except (OSError, ValueError) as err:
        print(f"nebula-keys: can't read {path}: {err}", file=sys.stderr)
        sys.exit(1)
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    try:
        signal.signal(signal.SIGTERM, lambda *_: GLib.idle_add(Gtk.main_quit))
        Sheet(entries)
        Gtk.main()
    finally:
        try:
            os.remove(PIDFILE)
        except OSError:
            pass


if __name__ == "__main__":
    main()
