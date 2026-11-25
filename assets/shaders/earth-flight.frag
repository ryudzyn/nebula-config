#version 100
precision highp float;

uniform float time;
uniform vec2 resolution;

// "Земля: політ" -- камера летить на сталій висоті вздовж звивистої долини з річкою,
// плавно закладаючи віражі: схили обабіч, у воді відбивається сутінкове небо й Місяць.
// Рельєф -- raymarch висотного поля, долина вирізана вздовж траєкторії, тож камера
// ніколи не врізається в гору і не "стрибає" по пагорбах. Пара до earth-hills.frag.
// CAM_OFFSET (SUPER+G) -- ривок уперед по маршруту.
#define CAM_OFFSET 0.0

#define WATER -1.05

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

const mat2 ROT = mat2(0.8, -0.6, 0.6, 0.8);

// Середина долини (і маршрут камери) на відстані z
float pathX(float z) {
    return 7.0 * sin(z * 0.045) + 3.0 * sin(z * 0.017 + 1.3);
}

float hills(vec2 p) {
    float h = 0.0;
    float a = 1.0;
    vec2 q = p * 0.11;
    for (int i = 0; i < 5; i++) {
        float n = noise2(q);
        h += a * (i < 2 ? n : 1.0 - abs(n * 2.0 - 1.0));
        q = ROT * q * 2.03;
        a *= 0.46;
    }
    return h * 3.4 - 1.2;
}

float terrain(vec2 p) {
    float h = hills(p);
    // долина: дно трохи нижче води біля маршруту, схили піднімаються обабіч
    float d = abs(p.x - pathX(p.y));
    float floorH = -1.25 + 0.25 * smoothstep(0.6, 2.6, d) + 0.08 * noise2(p * 0.7);
    float valley = smoothstep(1.2, 7.5, d);
    return mix(floorH, max(h, floorH), valley);
}

vec3 normalAt(vec2 p, float t) {
    float e = 0.015 + t * 0.0025;
    return normalize(vec3(terrain(p - vec2(e, 0.0)) - terrain(p + vec2(e, 0.0)), 2.0 * e,
                          terrain(p - vec2(0.0, e)) - terrain(p + vec2(0.0, e))));
}

const vec3 SUN = vec3(-0.62, 0.035, 0.78);
const vec3 MOON = vec3(0.45, 0.30, 0.84);

vec3 skyColor(vec3 rd, float z, bool stars) {
    vec3 sunDir = normalize(SUN);
    vec3 moonDir = normalize(MOON);
    float sunAmt = max(dot(rd, sunDir), 0.0);
    float horizon = 1.0 - max(rd.y, 0.0);
    vec3 col = mix(vec3(0.09, 0.12, 0.30), vec3(0.45, 0.42, 0.62), pow(horizon, 3.0));
    col = mix(col, vec3(1.0, 0.62, 0.38), pow(horizon, 12.0) * (0.4 + 0.6 * sunAmt));
    col += vec3(1.0, 0.55, 0.25) * pow(sunAmt, 24.0) * 0.6;

    if (stars) {
        vec2 sc = rd.xy / (rd.z + 1.2) * 260.0;
        vec2 cell = floor(sc);
        if (hash2(cell) > 0.988) {
            float d = length(fract(sc) - 0.5);
            col += vec3(0.85, 0.9, 1.0) * smoothstep(0.25, 0.0, d) * smoothstep(0.15, 0.45, rd.y)
                 * (0.6 + 0.4 * sin(time * 2.0 + hash2(cell + 1.0) * 40.0));
        }
    }

    // Місяць: куля з фазою, нічний бік -- темніше небо з попелястим світлом
    float mr = 0.12;
    vec3 mrt = normalize(cross(vec3(0.0, 1.0, 0.0), moonDir));
    vec3 mup = cross(moonDir, mrt);
    vec2 mp = vec2(dot(rd, mrt), dot(rd, mup)) / mr;
    float md = length(mp);
    float front = step(0.0, dot(rd, moonDir));
    col += vec3(0.8, 0.75, 0.9) * 0.16 * exp(-max(md - 1.0, 0.0) * 1.8) * front;
    if (md < 1.02 && front > 0.0) {
        vec3 n = vec3(mp, sqrt(max(1.0 - md * md, 0.0)));
        vec3 nw = normalize(n.x * mrt + n.y * mup - n.z * moonDir);
        vec3 moonLight = normalize(sunDir + vec3(0.3, 0.1, -1.4));
        float lit = smoothstep(-0.05, 0.25, dot(nw, moonLight));
        float maria = noise2(mp * 2.2 + 3.0) * 0.6 + noise2(mp * 6.0) * 0.3 + noise2(mp * 18.0) * 0.1;
        vec3 surf = mix(vec3(0.93, 0.90, 0.86), vec3(0.60, 0.58, 0.63), smoothstep(0.50, 0.60, maria));
        vec3 moon = mix(col * 0.55 + surf * 0.05, surf * 0.88, lit);
        col = mix(col, moon, smoothstep(1.02, 0.98, md));
    }

    // Хмари: тонкий шар високо в небі
    if (rd.y > 0.0) {
        vec2 cp = rd.xz / rd.y * 3.0 + vec2(time * 0.03, z * 0.1);
        float c = noise2(cp * 0.5) * 0.6 + noise2(cp * 1.3) * 0.3 + noise2(cp * 3.1) * 0.1;
        c = smoothstep(0.52, 0.8, c) * smoothstep(0.0, 0.25, rd.y);
        vec3 cc = mix(vec3(0.42, 0.38, 0.56), vec3(1.0, 0.7, 0.55), pow(sunAmt, 2.0) * 0.8 + 0.2);
        col = mix(col, cc, c * 0.7);
    }
    return col;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;
    vec3 sunDir = normalize(SUN);
    vec3 moonDir = normalize(MOON);

    // Камера: стала висота над річкою, дивиться туди, куди повертає долина
    float z = time * 0.55 + CAM_OFFSET * 25.0;
    vec3 ro = vec3(pathX(z), -0.15, z);
    vec3 ta = vec3(pathX(z + 5.0), -0.3, z + 5.0);
    vec3 fw = normalize(ta - ro);
    // крен у віраж: друга похідна маршруту
    float bank = (pathX(z + 3.0) - 2.0 * pathX(z) + pathX(z - 3.0)) * 0.18;
    vec3 upW = normalize(vec3(sin(bank), cos(bank), 0.0));
    vec3 rt = normalize(cross(upW, fw));
    vec3 up = cross(fw, rt);
    vec3 rd = normalize(fw + 0.9 * (uv.x * rt + (uv.y + 0.12) * up));

    vec3 col = skyColor(rd, z, true);
    vec3 fogCol = mix(vec3(0.50, 0.48, 0.62), vec3(1.0, 0.66, 0.45), pow(max(dot(rd, sunDir), 0.0), 3.0));

    // Рельєф
    float t = 0.1;
    float hit = -1.0;
    for (int i = 0; i < 128; i++) {
        vec3 p = ro + rd * t;
        float d = p.y - terrain(p.xz);
        if (d < 0.0015 * t) { hit = t; break; }
        t += max(d * 0.4, 0.008 + t * 0.003);
        if (t > 60.0) break;
    }
    // Вода -- площина WATER, якщо до неї ближче, ніж до землі
    float tw = rd.y < 0.0 ? (WATER - ro.y) / rd.y : -1.0;
    bool water = tw > 0.0 && (hit < 0.0 || tw < hit);

    if (water) {
        vec3 p = ro + rd * tw;
        vec2 w = p.xz * 2.0 + vec2(0.0, time * 0.4);
        vec3 n = normalize(vec3((noise2(w) - 0.5) * 0.1, 1.0, (noise2(w * 1.7 + 5.0) - 0.5) * 0.1));
        vec3 rr = reflect(rd, n);
        float fres = 0.25 + 0.75 * pow(1.0 - max(dot(-rd, n), 0.0), 4.0);
        vec3 refl = skyColor(rr, z, false) * 0.8;
        vec3 wc = mix(vec3(0.03, 0.06, 0.08), refl, fres);
        float fog = 1.0 - exp(-tw * 0.05);
        col = mix(wc, fogCol, fog);
    } else if (hit > 0.0) {
        vec3 p = ro + rd * hit;
        vec3 n = normalAt(p.xz, hit);
        float slope = n.y;
        float grass = smoothstep(0.6, 0.85, slope);
        float forest = smoothstep(0.42, 0.62, noise2(p.xz * 1.3)) * grass * smoothstep(-0.9, -0.6, p.y);
        vec3 alb = mix(vec3(0.33, 0.31, 0.30), vec3(0.22, 0.40, 0.16), grass);
        alb *= 0.85 + 0.3 * noise2(p.xz * 9.0);
        alb = mix(alb, vec3(0.05, 0.14, 0.07), forest);
        // мокрий берег
        alb = mix(alb, vec3(0.12, 0.13, 0.10), smoothstep(WATER + 0.12, WATER, p.y));
        float dif = max(dot(n, sunDir), 0.0);
        float moonL = max(dot(n, moonDir), 0.0);
        vec3 light = vec3(1.0, 0.62, 0.38) * dif * 1.4 + vec3(0.36, 0.38, 0.60) * (0.5 + 0.5 * n.y) * 0.85
                   + vec3(0.5, 0.5, 0.7) * moonL * 0.15;
        float fog = 1.0 - exp(-hit * 0.05);
        col = mix(alb * light, fogCol, fog);
    }

    col = pow(col, vec3(0.92));
    vec2 vq = gl_FragCoord.xy / resolution.xy - 0.5;
    col *= 1.0 - 0.4 * dot(vq, vq);
    gl_FragColor = vec4(col, 1.0);
}
