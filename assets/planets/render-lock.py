#!/usr/bin/env python3
"""Рендерить фони hyprlock: ті самі планети, що на столах (shaders/planet.frag у ETEA).
Запуск: render-lock.py <каталог assets/planets>. Результат -- lock/<планета>.jpg."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 2560, 1440
SUN = np.array([-0.78, -0.22, 0.58])
SUN = SUN / np.linalg.norm(SUN)
RING_IN, RING_OUT, RING_S = 1.24, 2.27, 0.30

# id: текстура, розмір (частка висоти), нахил, колір обідка, хмари, кільця, поворот (рад)
PLANETS = {
    "mercury": ("2k_mercury.jpg", 0.20, 0.0, "#b8b0a6", False, False, 0.6),
    "venus": ("2k_venus_atmosphere.jpg", 0.27, 0.05, "#e0c388", False, False, 1.2),
    "earth": ("2k_earth_daymap.jpg", 0.29, -0.41, "#7fb2d9", True, False, 0.2),
    "mars": ("2k_mars.jpg", 0.24, -0.44, "#d97050", False, False, 0.0),
    "jupiter": ("2k_jupiter.jpg", 0.33, -0.05, "#d6a878", False, False, 0.4),
    "saturn": ("2k_saturn.jpg", 0.19, -0.30, "#dcc898", False, True, 0.0),
    "uranus": ("2k_uranus.jpg", 0.28, 1.2, "#9fd6dc", False, False, 0.0),
    "neptune": ("2k_neptune.jpg", 0.28, -0.49, "#6f92d6", False, False, 0.0),
}


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def sample(tex, u, v):
    h, w = tex.shape[:2]
    x = u * (w - 1)
    y = np.clip(v, 0, 1) * (h - 1)
    x0, y0 = np.floor(x).astype(int) % w, np.floor(y).astype(int)
    x1, y1 = (x0 + 1) % w, np.minimum(y0 + 1, h - 1)
    fx, fy = (x - np.floor(x))[..., None], (y - y0)[..., None]
    top = tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx
    return top * (1 - fy) + (tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx) * fy


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def over(under, rgb, a):
    return under * (1 - a[..., None]) + rgb * a[..., None]


def render(root, spec):
    name, size, tilt, rim, clouds, rings, spin = spec
    rim = np.array([int(rim[i : i + 2], 16) / 255 for i in (1, 3, 5)])
    rng = np.random.default_rng(7)
    img = np.full((H, W, 3), [0.008, 0.010, 0.014], dtype=np.float32)
    stars = rng.random((H // 2, W // 2)) > 0.9975
    bright = rng.random((H // 2, W // 2)) * 0.75 + 0.25
    field = np.kron((stars * bright * 0.8).astype(np.float32), np.ones((2, 2), dtype=np.float32))
    img[: field.shape[0], : field.shape[1]] += field[..., None]

    radius = H * size
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    px, py = (xs - W * 0.55) / radius, (ys - H * 0.52) / radius
    ct, st = np.cos(tilt), np.sin(tilt)
    qx, qy = ct * px + st * py, -st * px + ct * py
    r = np.hypot(qx, qy)
    aa = 1.5 / radius

    def ring_layer(mask):
        ring = load(root / "2k_saturn_ring_alpha.png")
        b = qy / RING_S
        rr = np.hypot(qx, b)
        t = (rr - RING_IN) / (RING_OUT - RING_IN)
        inside = mask & (t >= 0) & (t <= 1)
        alpha = np.zeros_like(r)
        alpha[inside] = sample(ring, t[inside], np.full(t[inside].shape, 0.5))[..., 3] * 0.92
        p = np.stack([qx, b * RING_S, b * np.sqrt(1 - RING_S**2)], -1)
        d = p @ SUN
        off = np.linalg.norm(p - d[..., None] * SUN, axis=-1)
        lit = np.where((d < 0) & (off < 1), 0.04, 1.0)
        return np.array([0.82, 0.76, 0.62], dtype=np.float32) * lit[..., None], alpha

    if rings:
        rgb, a = ring_layer(qy < 0)
        img = over(img, rgb, a)

    n = np.stack([qx, qy, np.sqrt(np.maximum(0, 1 - r * r))], -1)
    disc = r < 1 + aa
    u = np.mod(np.arctan2(n[..., 0], n[..., 2]) / (2 * np.pi) + 0.5 + spin / (2 * np.pi), 1)
    v = 0.5 + np.arcsin(np.clip(n[..., 1], -1, 1)) / np.pi
    albedo = np.zeros_like(img)
    albedo[disc] = sample(load(root / name), u[disc], v[disc])[..., :3]
    light = smoothstep(-0.04, 0.42, n @ SUN)
    fall = 0.7 + 0.3 * n[..., 2]
    body = albedo * (light * 1.05 + 0.008)[..., None] * fall[..., None]
    if clouds:
        cover = np.zeros_like(r)
        cu = np.mod(u + 0.31, 1)
        cover[disc] = sample(load(root / "2k_earth_clouds.jpg"), cu[disc], v[disc])[..., 0]
        white = 0.95 * (light * 1.05 + 0.004) * (0.75 + 0.25 * n[..., 2])
        body = over(body, white[..., None], smoothstep(0.08, 0.72, cover) * 0.92)
    body += rim * (np.power(1 - n[..., 2], 4) * light * 0.28)[..., None]
    img = over(img, body, 1 - smoothstep(1 - aa, 1 + aa, r))

    if rings:
        rgb, a = ring_layer(qy >= 0)
        img = over(img, rgb, a)
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


root = Path(sys.argv[1])
(root / "lock").mkdir(exist_ok=True)
for planet, spec in PLANETS.items():
    render(root, spec).save(root / "lock" / f"{planet}.jpg", quality=88)
    print(planet)
