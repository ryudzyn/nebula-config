#version 100
precision highp float;

uniform float time;
uniform vec2 resolution;

// "Земля: пагорби" -- пейзаж у плаському мальованому стилі (натхнення: NMS-райс elifouts):
// шари пагорбів із паралаксом, тонкі ялинки, великий Місяць, зорі, хмари, кораблик
// раз на 4 хв. Перший крок ідеї "пейзаж на кожен воркспейс" (2026-11-24).
// CAM_OFFSET (SUPER+G) -- пейзаж прокручується до іншої ділянки.
#define CAM_OFFSET 0.0

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise1(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float ridge(float x, float seed) {
    float h = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        h += a * noise1(x + seed * 17.3);
        x *= 2.03;
        a *= 0.45;
    }
    return h;
}

// Висота шару k (0 -- далекий, 4 -- ближній) в точці x
float layerHeight(float k, float x) {
    float base = 0.40 - k * 0.075;
    float amp = 0.10 + k * 0.025;
    float freq = 1.6 + k * 0.5;
    return base + amp * (ridge(x * freq, k) - 0.5) * 2.0;
}

// Ялинка: 1 всередині силуету. p -- відносно основи, hgt -- висота
float pine(vec2 p, float hgt, float px) {
    float w = hgt * 0.13;
    float y = p.y / hgt;
    // три яруси гілок, кожен трохи ширший унизу
    float tier = fract(y * 3.0);
    float width = w * (1.0 - y) * (0.75 + 0.35 * (1.0 - tier));
    float body = smoothstep(px, -px, abs(p.x) - width) * step(0.08, y) * step(y, 1.0);
    float trunk = smoothstep(px, -px, abs(p.x) - w * 0.12) * step(0.0, y) * step(y, 0.1);
    return max(body, trunk);
}

void main() {
    float px = 1.5 / resolution.y;
    vec2 uv = gl_FragCoord.xy / resolution.y;
    float aspect = resolution.x / resolution.y;
    float pan = time * 0.012 + CAM_OFFSET * 3.0;

    // Небо: глибокий синій угорі -> бузковий -> персиковий біля горизонту
    vec3 skyTop = vec3(0.07, 0.09, 0.22);
    vec3 skyMid = vec3(0.36, 0.30, 0.52);
    vec3 skyLow = vec3(0.98, 0.66, 0.48);
    float sy = uv.y;
    vec3 col = mix(skyLow, skyMid, smoothstep(0.30, 0.62, sy));
    col = mix(col, skyTop, smoothstep(0.60, 1.0, sy));

    // Зорі -- тільки у верхній, темній частині
    vec2 sg = uv * 120.0;
    vec2 cell = floor(sg);
    float sr = hash2(cell);
    if (sr > 0.985) {
        vec2 sp = cell + vec2(hash2(cell + 3.1), hash2(cell + 7.7));
        float d = length(sg - sp);
        float tw = 0.6 + 0.4 * sin(time * (1.0 + sr * 3.0) + sr * 50.0);
        col += vec3(0.9, 0.9, 1.0) * smoothstep(1.2, 0.0, d * 3.0) * tw * smoothstep(0.55, 0.85, sy);
    }

    // Місяць: великий, з м'яким сяйвом і плямами
    vec2 mc = vec2(aspect * 0.72, 0.70);
    float mr = 0.15;
    float md = length(uv - mc);
    col += vec3(0.95, 0.80, 0.75) * 0.25 * exp(-max(md - mr, 0.0) * 9.0);
    if (md < mr + px) {
        vec2 mp = (uv - mc) / mr;
        float spots = noise2(mp * 2.2 + 4.0) * 0.7 + noise2(mp * 6.0) * 0.3;
        vec3 moon = mix(vec3(0.98, 0.93, 0.86), vec3(0.84, 0.76, 0.78), smoothstep(0.58, 0.62, spots));
        // легка тінь з лівого боку -- об'єм
        moon *= 0.80 + 0.20 * smoothstep(-1.0, 0.6, mp.x + mp.y * 0.3);
        col = mix(col, moon, smoothstep(mr + px, mr - px, md));
    }

    // Хмари -- витягнуті м'які смуги, повільно пливуть
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float cy = 0.46 + fi * 0.07;
        vec2 cp = vec2(uv.x * 1.4 + time * (0.004 + fi * 0.002) + fi * 3.0, (uv.y - cy) * 14.0);
        float c = noise2(vec2(cp.x * 2.0, fi)) * smoothstep(1.0, 0.0, abs(cp.y));
        c = smoothstep(0.45, 0.75, c);
        vec3 cc = mix(vec3(1.0, 0.75, 0.62), vec3(0.55, 0.46, 0.68), fi / 2.0);
        col = mix(col, cc, c * 0.55);
    }

    // Кораблик: маленький силует, що раз на кілька хвилин перетинає небо
    float st = fract(time / 240.0);
    vec2 sp2 = vec2(mix(-0.2, aspect + 0.2, st), 0.80 + 0.03 * sin(st * 6.28));
    vec2 q = (uv - sp2) * vec2(1.0, 3.2);
    float ship = smoothstep(0.012 + px, 0.012 - px, length(q) + q.x * 0.6);
    col = mix(col, vec3(0.12, 0.10, 0.22), ship);
    col += vec3(1.0, 0.6, 0.3) * smoothstep(0.006, 0.0, length(uv - sp2 + vec2(0.017, 0.0)));

    // Пагорби: від далекого до ближнього, з серпанком і ялинками
    vec3 hazeCol = mix(skyLow, skyMid, 0.35);
    for (int i = 0; i < 5; i++) {
        float k = float(i);
        float x = uv.x + pan * (0.2 + k * 0.35) + k * 11.0;
        float h = layerHeight(k, x);
        vec3 lc = mix(vec3(0.22, 0.50, 0.44), vec3(0.03, 0.10, 0.08), k / 4.0);
        lc = mix(lc, hazeCol, (1.0 - k / 4.0) * 0.38);
        // підсвічений місяцем край пагорба
        vec3 rim = mix(lc, vec3(1.0, 0.85, 0.75), 0.35 * (1.0 - k / 5.0));

        float inside = smoothstep(-px, px, h - uv.y);
        float edge = smoothstep(0.006, 0.0, h - uv.y) * inside;
        vec3 hc = mix(lc, rim, edge);

        // ялинки на шарах 1..4
        float trees = 0.0;
        if (i > 0) {
            float cw = 0.035 - k * 0.004;
            float cx = floor(x / cw);
            float r = hash1(cx + k * 91.0);
            float dens = noise1(cx * 0.15 + k * 5.0);
            if (r < dens * 1.1) {
                float tx = (cx + 0.3 + 0.4 * hash1(cx * 3.7 + k)) * cw;
                float th = (0.045 + 0.05 * hash1(cx * 1.3 + k)) * (0.6 + k * 0.25);
                float base = layerHeight(k, tx) - 0.01;
                trees = pine(vec2(x - tx, uv.y - base), th, px);
            }
        }
        float m = max(inside, trees);
        col = mix(col, mix(hc, lc * 0.85, trees * (1.0 - inside)), m);
    }

    // Віньєтка
    vec2 vq = gl_FragCoord.xy / resolution.xy - 0.5;
    col *= 1.0 - 0.35 * dot(vq, vq);

    gl_FragColor = vec4(col, 1.0);
}
