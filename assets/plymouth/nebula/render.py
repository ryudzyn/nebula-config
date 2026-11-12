#!/usr/bin/env python3
"""Рендерить картинки Plymouth-теми "nebula": Земля з хмарами (те саме світло, що в
ETEA/shaders/planet.frag і assets/planets/render-lock.py), Місяць, точки орбіти,
зоряне тло й напис. Запуск: render.py <assets/planets> <шрифт .ttf> <каталог теми>.
PNG лежать у initrd, тому все дрібне: квантування до палітри, де можна."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SUN = np.array([-0.78, -0.22, 0.58])
SUN = SUN / np.linalg.norm(SUN)
RIM = np.array([0x7F, 0xB2, 0xD9]) / 255  # обідок Землі, як у render-lock.py
INK = (0x9F, 0xB0, 0xBF)  # колір тексту hyprlock


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def sample(tex, u, v):
    h, w = tex.shape[:2]
    x, y = u * (w - 1), np.clip(v, 0, 1) * (h - 1)
    x0, y0 = np.floor(x).astype(int) % w, np.floor(y).astype(int)
    x1, y1 = (x0 + 1) % w, np.minimum(y0 + 1, h - 1)
    fx, fy = (x - np.floor(x))[..., None], (y - y0)[..., None]
    top = tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx
    return top * (1 - fy) + (tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx) * fy


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def sphere(root, tex, size, tilt, spin, clouds=False, rim=None, glow=0.0):
    """Освітлена куля на прозорому тлі; glow -- ширина атмосфери в радіусах."""
    pad = int(size * glow / 2) + 2
    n_px = size + 2 * pad
    radius = size / 2
    ys, xs = np.mgrid[0:n_px, 0:n_px].astype(np.float32) + 0.5
    px, py = (xs - n_px / 2) / radius, (ys - n_px / 2) / radius
    ct, st = np.cos(tilt), np.sin(tilt)
    qx, qy = ct * px + st * py, -st * px + ct * py
    r = np.hypot(qx, qy)
    aa = 1.5 / radius
    n = np.stack([qx, qy, np.sqrt(np.maximum(0, 1 - r * r))], -1)
    disc = r < 1 + aa
    u = np.mod(np.arctan2(n[..., 0], n[..., 2]) / (2 * np.pi) + 0.5 + spin / (2 * np.pi), 1)
    v = 0.5 + np.arcsin(np.clip(n[..., 1], -1, 1)) / np.pi
    albedo = np.zeros((n_px, n_px, 3), np.float32)
    albedo[disc] = sample(load(root / tex), u[disc], v[disc])[..., :3]
    light = smoothstep(-0.04, 0.42, n @ SUN)
    body = albedo * (light * 1.05 + 0.008)[..., None] * (0.7 + 0.3 * n[..., 2])[..., None]
    if clouds:
        cover = np.zeros_like(r)
        cu = np.mod(u + 0.31, 1)
        cover[disc] = sample(load(root / "2k_earth_clouds.jpg"), cu[disc], v[disc])[..., 0]
        white = 0.95 * (light * 1.05 + 0.004) * (0.75 + 0.25 * n[..., 2])
        a = smoothstep(0.08, 0.72, cover) * 0.92
        body = body * (1 - a[..., None]) + white[..., None] * a[..., None]
    if rim is not None:
        body += rim * (np.power(1 - n[..., 2], 4) * light * 0.28)[..., None]
    alpha = 1 - smoothstep(1 - aa, 1 + aa, r)
    rgb = body
    if glow:
        # Атмосфера за краєм диска -- лише з освітленого боку, гасне назовні
        side = np.clip((qx * SUN[0] + qy * SUN[1]) / np.maximum(r, 1e-3) * 0.8 + 0.45, 0, 1)
        halo = np.exp(-np.maximum(r - 1, 0) / (glow * 0.35)) * (r >= 1 - aa) * side * 0.55
        a_out = alpha + halo * (1 - alpha)
        rgb = (body * alpha[..., None] + rim * (halo * (1 - alpha))[..., None]) / np.maximum(a_out, 1e-6)[..., None]
        alpha = a_out
    out = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def dot(d, rgb, soft):
    ys, xs = np.mgrid[0:d, 0:d].astype(np.float32) + 0.5
    r = np.hypot(xs - d / 2, ys - d / 2) / (d / 2)
    a = np.clip(1 - smoothstep(soft, 1, r), 0, 1)
    out = np.dstack([np.broadcast_to(np.array(rgb) / 255, (d, d, 3)), a])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def stars(w, h):
    """Зорі на прозорому тлі -- колір неба малює сам Plymouth (Window.SetBackground*)."""
    rng = np.random.default_rng(7)
    a = np.zeros((h, w), np.float32)
    n = int(w * h * 0.0009)
    xs, ys = rng.integers(0, w, n), rng.integers(0, h, n)
    a[ys, xs] = rng.random(n) ** 2 * 0.7 + 0.12
    rgb = np.broadcast_to(np.array([0.82, 0.87, 0.93], np.float32), (h, w, 3))
    out = np.dstack([rgb, a])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def text(font_path, s, size, spacing):
    font = ImageFont.truetype(str(font_path), size)
    widths = [font.getlength(c) for c in s]
    w = int(sum(widths) + spacing * (len(s) - 1)) + 4
    img = Image.new("RGBA", (w, int(size * 1.4)), (0, 0, 0, 0))
    d, x = ImageDraw.Draw(img), 2.0
    for c, cw in zip(s, widths):
        d.text((x, 0), c, font=font, fill=INK + (235,))
        x += cw + spacing
    return img.crop(img.getbbox())


def save(img, path, colors=None):
    if colors:
        img = img.quantize(colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    img.save(path, optimize=True)


planets, font, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
save(sphere(planets, "2k_earth_daymap.jpg", 560, -0.41, 0.2, clouds=True, rim=RIM, glow=0.16), out / "earth.png")
# Окремої текстури Місяця немає -- Меркурій у сірому дає той самий кратерний вигляд
moon = sphere(planets, "2k_mercury.jpg", 40, 0.0, 1.1).convert("LA").convert("RGBA")
save(moon, out / "moon.png")
save(dot(12, (0xC8, 0xD6, 0xE2), 0.35), out / "dot-on.png")
save(dot(12, (0x3A, 0x46, 0x54), 0.35), out / "dot-off.png")
save(dot(14, (0xDD, 0xE6, 0xF0), 0.0), out / "glint.png")
save(stars(1920, 1080), out / "stars.png", 64)
save(text(font, "NEBULA OS", 30, 22), out / "title.png")
for f in sorted(out.glob("*.png")):
    print(f.name, f.stat().st_size // 1024, "KiB")
