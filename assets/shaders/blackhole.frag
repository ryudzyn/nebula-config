#version 100
precision highp float;

uniform float time;
uniform vec2 resolution;

// Підмінюється через sed нижнім скриптом nebula-space-wallpaper-rotate
// (SUPER+G, "наступний ракурс") -- glpaper не приймає live-uniform, тож
// ротація фіксованих 4 ракурсів реалізована перегенерацією файлу.
#define CAM_OFFSET 0.0

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm2(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise2(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}

// Оберт навколо Y на кут -a -- компенсує власний оберт камери (camAngle)
// перед вибіркою зоряного поля, щоб фон лишався нерухомим, поки камера
// кружляє навколо діри. Без цього напрямок до "неба" обертається разом
// із камерою, і зовнішні зорі здаються рухомими/закрученими.
vec3 rotateY(vec3 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
}

// Три шари зірок різного масштабу -- один шар лишає "порожні" плями там,
// де промінь сильно зігнутий і вибірка напрямків стискається у вузький
// діапазон (жива перевірка: без цього навколо кільця з'являлась суцільна
// темна пляма, схожа на "діру в дірі").
// Мерехтіння -- яскравість кожної зірки гойдається з власною випадковою
// фазою (друге hash від тієї ж комірки), а не позиція -- так зоряне поле
// лишається нерухомим (не крутиться разом з камерою, як було), але й не
// виглядає "мертвим" статичним кадром.
float twinkle(vec3 cell, float speed) {
    float phase = hash(cell + 3.7) * 62.83;
    return 0.55 + 0.45 * sin(time * speed + phase);
}

vec3 starfield(vec3 dir) {
    vec3 col = vec3(0.02, 0.015, 0.05);

    vec3 cell1 = floor(dir * 400.0);
    col += vec3(pow(hash(cell1), 75.0)) * 5.0 * twinkle(cell1, 1.4);

    vec3 cell2 = floor(dir * 137.0) + 91.7;
    col += vec3(pow(hash(cell2), 160.0)) * 3.5 * twinkle(cell2, 1.0);

    vec3 cell3 = floor(dir * 733.0) + 13.3;
    col += vec3(pow(hash(cell3), 210.0)) * 4.0 * twinkle(cell3, 2.0);

    return col;
}

// Один безперервний градієнт біло-блакитне->золоте->темно-червоне замість
// трьох різких щаблів -- на референсному NASA-відео (той самий рендер,
// що й у nebula-space-wallpaper-wl як відео-варіант) колір диска плавно
// перетікає по всій ширині, без видимих меж між зонами.
vec3 diskColorAt(float rr, float angle, float diskInner, float diskOuter, float camAngle) {
    float radial = clamp((rr - diskInner) / (diskOuter - diskInner), 0.0, 1.0);

    // Kepler-подібна диференціальна ротація: внутрішні кільця обертаються
    // швидше за зовнішні (як і в реальному акреційному диску) -- замість
    // статичної текстури з ледь помітним часовим зсувом (як було) це дає
    // видиме "перетікання" матеріалу, різне на різних радіусах.
    float orbitSpeed = 1.4 / sqrt(max(rr, diskInner));
    float flowAngle = angle - time * orbitSpeed * 0.4;

    vec2 flowUv = vec2(flowAngle * 4.0, rr * 3.0);
    float turb = fbm2(flowUv * 1.5);
    // Другий, дрібніший шар турбулентності -- теж рухомий, тим самим
    // потоком, додає дрібну "зернистість", що тече разом з великими
    // візерунками, а не окремо.
    float turb2 = fbm2(flowUv * 4.5 + 7.0);

    float density = smoothstep(1.0, 0.85, radial) * 0.35 + 0.55
        + (turb - 0.5) * 0.45 + (turb2 - 0.5) * 0.2;

    vec3 whiteHot = vec3(1.0, 1.0, 1.0);
    vec3 gold = vec3(1.0, 0.78, 0.4);
    vec3 darkRed = vec3(0.25, 0.06, 0.02);
    vec3 diskCol = mix(whiteHot, gold, smoothstep(0.0, 0.35, radial));
    diskCol = mix(diskCol, darkRed, smoothstep(0.25, 1.0, radial));

    // Релятивістське доплерівське підсилення -- матерія, що рухається на
    // нас, яскравіша/біліша за ту, що рухається від нас.
    float doppler = 0.5 + 1.1 * (0.5 + 0.5 * sin(angle - camAngle));

    return diskCol * density * doppler;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;

    float camAngle = time * 0.08 + CAM_OFFSET;
    float camDist = 11.0;
    // Майже edge-on вид (малий нахил, не строго 0) -- під таким кутом
    // дальній бік диска, зігнутий гравітацією, з'єднується з ближнім у
    // суцільну смугу навколо тіні, а не в рівне кільце (вигляд згори).
    vec3 ro = vec3(sin(camAngle) * camDist, 1.1, cos(camAngle) * camDist);

    vec3 target = vec3(0.0);
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    // Ширший FOV (менший множник forward), ніж у попередній версії -- диск
    // на референсі широкий і плаский, займає майже всю ширину кадру, а не
    // компактне кільце по центру.
    vec3 rd = normalize(forward * 0.55 + uv.x * right + uv.y * up);

    float horizon = 0.15;
    float diskInner = 0.28;
    // Набагато ширший диск відносно тіні, ніж у першій версії -- саме це
    // головна відмінність від референсу, яку виявило порівняння кадрів.
    // Тінь ще зменшена (0.22->0.15), кільце ще розширене (6.0->7.0) за
    // проханням користувача.
    float diskOuter = 7.0;

    vec3 pos = ro;
    vec3 dir = rd;
    vec3 col = vec3(0.0);
    bool done = false;

    for (int i = 0; i < 160; i++) {
        float r = length(pos);
        if (r < horizon) {
            col = vec3(0.0);
            done = true;
            break;
        }
        if (r > 30.0) {
            col = starfield(rotateY(dir, camAngle));
            done = true;
            break;
        }

        float stepSize = clamp(r * 0.12, 0.03, 0.4);
        vec3 toCenter = -pos / r;
        float bend = 1.7 / (r * r);
        dir = normalize(dir + toCenter * bend * stepSize);
        vec3 newPos = pos + dir * stepSize;

        if (pos.y * newPos.y < 0.0) {
            float t = pos.y / (pos.y - newPos.y);
            vec3 hitPos = mix(pos, newPos, t);
            float rr = length(hitPos.xz);
            if (rr > diskInner && rr < diskOuter) {
                float angle = atan(hitPos.z, hitPos.x);
                col = diskColorAt(rr, angle, diskInner, diskOuter, camAngle);
                done = true;
                break;
            }
        }

        pos = newPos;
    }

    if (!done) {
        col = starfield(rotateY(dir, camAngle));
    }

    float vig = 1.0 - 0.2 * dot(uv, uv);
    col *= vig;

    gl_FragColor = vec4(col, 1.0);
}
