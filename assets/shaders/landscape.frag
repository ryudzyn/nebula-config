#version 100
precision highp float;

uniform float time;
uniform vec2 resolution;
uniform float scene;

// "Пейзажі": на кожному робочому столі стоїш на поверхні його тіла (ідея з NMS-райсу elifouts,
// стиль earth-hills.frag). Один шейдер на всі десять столів, сцену обирає uniform scene,
// порядок той самий, що Planets.pages в ETEA:
//   0 Сонце (розпечена скеля під величезним диском), 1 Меркурій, 2 Венера, 3 Земля, 4 Марс,
//   5 Європа під Юпітером, 6 Енцелад під Сатурном, 7 Міранда під Ураном, 8 Тритон під
//   Нептуном, 9 Церера в поясі астероїдів.
// Кожна сцена -- лише набір чисел у setup(): небо, світило, тіло на небі, форма пагорбів,
// дрібниці на них (ялинки, крижані шпилі, валуни) і одна особлива штука (лава, гейзери,
// пиловий вихор, уламки в небі...). Пласкі шари з паралаксом, без raymarch -- дешево.
// CAM_OFFSET (SUPER+G) -- прокрутка до іншої ділянки.
#define CAM_OFFSET 0.0

// ---- Параметри сцени (заповнює setup) ----
vec3 skyTop; vec3 skyMid; vec3 skyLow;
float starAmt; float starFrom;
vec2 sunPos; float sunR; vec3 sunCol; vec3 haloCol; float haloAmt; float haloSpread;
int bodyType; vec2 bodyPos; float bodyR; float bodyTilt; vec3 bodyA; vec3 bodyB; vec3 bodyL; float bodyAtmo;
float cloudAmt; vec3 cloudA; vec3 cloudB;
vec3 landFar; vec3 landNear; vec3 rimCol; vec3 hazeCol; float hazeAmt;
int shape; float rough;
int prop; float propDens;
int fx;            // 1 лава в тріщинах, 2 гейзери, 3 пиловий вихор, 4 уламки в небі, 5 темні струмені, 6 смуги на кризі, 7 борозни, 8 фотосфера Сонця
bool mons; float monsH; float monsW; bool monsFire;
float lightSide;   // звідки світло для відблисків: -1 зліва, 1 справа
float relief;      // наскільки схили до світла/від світла різняться (без повітря -- різко)

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

void setup(float aspect) {
    int s = int(scene + 0.5);
    // типові значення, сцени нижче міняють лише своє
    starAmt = 0.0; starFrom = 0.55;
    sunR = 0.0; haloAmt = 0.0; haloSpread = 6.0; sunCol = vec3(1.0); haloCol = vec3(1.0);
    bodyType = 0; bodyTilt = 0.0; bodyAtmo = 0.0; bodyL = normalize(vec3(-1.0, 0.3, 0.6));
    bodyPos = vec2(0.0); bodyR = 0.1; bodyA = vec3(1.0); bodyB = vec3(1.0);
    cloudAmt = 0.0; cloudA = vec3(1.0); cloudB = vec3(1.0);
    shape = 0; rough = 1.0; prop = 0; propDens = 1.0; fx = 0;
    mons = false; monsH = 0.0; monsW = 0.4; monsFire = false;
    lightSide = 1.0; hazeAmt = 0.3; relief = 0.2;
    sunPos = vec2(0.0);

    if (s == 0) { // Сонце: стоїш на самій фотосфері -- вона кипить, над нею коронні дуги
        skyTop = vec3(0.10, 0.015, 0.01); skyMid = vec3(0.48, 0.10, 0.025); skyLow = vec3(1.0, 0.56, 0.18);
        sunPos = vec2(aspect * 0.5, 0.30); haloCol = vec3(1.0, 0.70, 0.30); haloAmt = 0.35; haloSpread = 2.5;
        landFar = vec3(1.0, 0.72, 0.30); landNear = vec3(0.62, 0.13, 0.03);
        rimCol = vec3(1.0, 0.95, 0.70); hazeCol = vec3(1.0, 0.62, 0.24); hazeAmt = 0.45;
        rough = 0.8; prop = 2; propDens = 0.8; fx = 8;
        lightSide = 1.0; relief = 0.0;
    } else if (s == 1) { // Меркурій: чорне небо, сонце втричі більше за земне, кратери
        skyTop = vec3(0.0, 0.0, 0.008); skyMid = vec3(0.01, 0.01, 0.018); skyLow = vec3(0.07, 0.065, 0.06);
        starAmt = 1.0; starFrom = 0.42;
        sunPos = vec2(aspect * 0.17, 0.50); sunR = 0.075; sunCol = vec3(1.0, 0.98, 0.92);
        haloCol = vec3(0.95, 0.85, 0.65); haloAmt = 0.35; haloSpread = 9.0;
        landFar = vec3(0.44, 0.41, 0.38); landNear = vec3(0.06, 0.055, 0.05);
        rimCol = vec3(1.0, 0.97, 0.9); hazeCol = vec3(0.12, 0.11, 0.10); hazeAmt = 0.12;
        shape = 3; rough = 0.8; prop = 3; propDens = 0.7;
        lightSide = -1.0; relief = 0.6;
    } else if (s == 2) { // Венера: жовта імла, хмарна стеля, вулкан із димом
        skyTop = vec3(0.42, 0.28, 0.10); skyMid = vec3(0.74, 0.52, 0.22); skyLow = vec3(0.96, 0.72, 0.38);
        sunPos = vec2(aspect * 0.35, 0.78); sunR = 0.0; haloCol = vec3(1.0, 0.85, 0.55); haloAmt = 0.45; haloSpread = 4.0;
        cloudAmt = 0.9; cloudA = vec3(0.98, 0.78, 0.42); cloudB = vec3(0.62, 0.40, 0.16);
        landFar = vec3(0.66, 0.42, 0.18); landNear = vec3(0.15, 0.07, 0.03);
        rimCol = vec3(1.0, 0.80, 0.45); hazeCol = vec3(0.86, 0.62, 0.30); hazeAmt = 0.75;
        shape = 1; rough = 0.8; prop = 3; propDens = 0.25; fx = 1;
        mons = true; monsH = 0.20; monsW = 0.55; monsFire = true;
        lightSide = -1.0; relief = 0.12;
    } else if (s == 3) { // Земля: як earth-hills -- ялинки, Місяць, персиковий вечір
        skyTop = vec3(0.07, 0.09, 0.22); skyMid = vec3(0.36, 0.30, 0.52); skyLow = vec3(0.98, 0.66, 0.48);
        starAmt = 0.6; starFrom = 0.55;
        bodyType = 1; bodyPos = vec2(aspect * 0.72, 0.70); bodyR = 0.15;
        bodyA = vec3(0.98, 0.93, 0.86); bodyB = vec3(0.84, 0.76, 0.78); bodyL = normalize(vec3(0.5, 0.4, 1.0));
        haloCol = vec3(0.95, 0.80, 0.75); bodyAtmo = 0.25;
        cloudAmt = 0.55; cloudA = vec3(1.0, 0.75, 0.62); cloudB = vec3(0.55, 0.46, 0.68);
        landFar = vec3(0.22, 0.50, 0.44); landNear = vec3(0.03, 0.10, 0.08);
        rimCol = vec3(1.0, 0.85, 0.75); hazeCol = mix(skyLow, skyMid, 0.35); hazeAmt = 0.38;
        prop = 1; propDens = 1.1;
    } else if (s == 4) { // Марс: карамельне небо, блакитний захід, Фобос, пиловий вихор
        skyTop = vec3(0.10, 0.07, 0.09); skyMid = vec3(0.52, 0.31, 0.22); skyLow = vec3(0.84, 0.60, 0.42);
        starAmt = 0.3; starFrom = 0.72;
        sunPos = vec2(aspect * 0.30, 0.34); sunR = 0.018; sunCol = vec3(0.92, 0.96, 1.0);
        haloCol = vec3(0.45, 0.62, 0.90); haloAmt = 0.75; haloSpread = 7.0;
        bodyType = 6; bodyPos = vec2(aspect * 0.80, 0.80); bodyR = 0.032;
        bodyA = vec3(0.62, 0.55, 0.50); bodyB = vec3(0.40, 0.34, 0.30); bodyL = normalize(vec3(-1.0, -0.4, 0.4));
        cloudAmt = 0.22; cloudA = vec3(0.92, 0.70, 0.58); cloudB = vec3(0.62, 0.42, 0.38);
        landFar = vec3(0.70, 0.40, 0.25); landNear = vec3(0.18, 0.065, 0.035);
        rimCol = vec3(0.75, 0.85, 1.0); hazeCol = vec3(0.82, 0.54, 0.38); hazeAmt = 0.55;
        shape = 1; rough = 1.0; prop = 3; propDens = 0.6; fx = 3;
        lightSide = -1.0; relief = 0.3; relief = 0.15;
    } else if (s == 5) { // Європа: льодяні шпилі під величезним Юпітером
        skyTop = vec3(0.0, 0.0, 0.015); skyMid = vec3(0.015, 0.02, 0.045); skyLow = vec3(0.05, 0.07, 0.11);
        starAmt = 0.9; starFrom = 0.42;
        sunPos = vec2(aspect * 0.07, 0.86); sunR = 0.008; sunCol = vec3(1.0, 0.98, 0.94);
        haloCol = vec3(0.8, 0.85, 1.0); haloAmt = 0.15; haloSpread = 14.0;
        bodyType = 2; bodyPos = vec2(aspect * 0.64, 0.68); bodyR = 0.30; bodyTilt = 0.05;
        bodyA = vec3(0.93, 0.86, 0.74); bodyB = vec3(0.68, 0.46, 0.32); bodyL = normalize(vec3(-0.7, 0.3, 0.9));
        bodyAtmo = 0.12;
        landFar = vec3(0.66, 0.74, 0.82); landNear = vec3(0.08, 0.12, 0.18);
        rimCol = vec3(1.0, 0.92, 0.80); hazeCol = vec3(0.30, 0.38, 0.50); hazeAmt = 0.18;
        shape = 2; rough = 0.9; prop = 2; propDens = 0.9; fx = 6;
        lightSide = -1.0; relief = 0.4;
    } else if (s == 6) { // Енцелад: білий лід, гейзери, Сатурн із кільцями
        skyTop = vec3(0.0, 0.004, 0.02); skyMid = vec3(0.012, 0.02, 0.05); skyLow = vec3(0.05, 0.08, 0.13);
        starAmt = 0.85; starFrom = 0.45;
        sunPos = vec2(aspect * 0.92, 0.60); sunR = 0.007; sunCol = vec3(1.0);
        haloCol = vec3(0.8, 0.88, 1.0); haloAmt = 0.2; haloSpread = 12.0;
        bodyType = 3; bodyPos = vec2(aspect * 0.30, 0.70); bodyR = 0.15; bodyTilt = -0.32;
        bodyA = vec3(0.94, 0.87, 0.68); bodyB = vec3(0.78, 0.66, 0.48); bodyL = normalize(vec3(1.0, 0.1, 0.5));
        landFar = vec3(0.86, 0.91, 0.96); landNear = vec3(0.12, 0.19, 0.27);
        rimCol = vec3(0.92, 0.97, 1.0); hazeCol = vec3(0.35, 0.45, 0.58); hazeAmt = 0.15;
        rough = 0.75; prop = 2; propDens = 0.25; fx = 2;
        lightSide = 1.0; relief = 0.3;
    } else if (s == 7) { // Міранда: велетенські урвища, Уран із кільцями ребром
        skyTop = vec3(0.0, 0.006, 0.01); skyMid = vec3(0.01, 0.025, 0.03); skyLow = vec3(0.04, 0.08, 0.09);
        starAmt = 0.9; starFrom = 0.42;
        sunPos = vec2(aspect * 0.12, 0.80); sunR = 0.005; sunCol = vec3(1.0);
        haloCol = vec3(0.8, 0.95, 1.0); haloAmt = 0.12; haloSpread = 16.0;
        bodyType = 4; bodyPos = vec2(aspect * 0.66, 0.55); bodyR = 0.30; bodyTilt = 0.22;
        bodyA = vec3(0.66, 0.88, 0.90); bodyB = vec3(0.50, 0.76, 0.82); bodyL = normalize(vec3(-0.8, 0.3, 0.6));
        bodyAtmo = 0.15;
        // скелі підсвічені бірюзовим відблиском Урана
        landFar = vec3(0.50, 0.58, 0.62); landNear = vec3(0.04, 0.06, 0.07);
        rimCol = vec3(0.62, 0.95, 1.0); hazeCol = vec3(0.10, 0.20, 0.23); hazeAmt = 0.22;
        shape = 4; rough = 1.25; prop = 3; propDens = 0.5; fx = 7;
        lightSide = -1.0; relief = 0.55;
    } else if (s == 8) { // Тритон: рожевий азотний лід, темні струмені, синій Нептун
        skyTop = vec3(0.0, 0.004, 0.02); skyMid = vec3(0.015, 0.02, 0.06); skyLow = vec3(0.07, 0.08, 0.17);
        starAmt = 0.85; starFrom = 0.45;
        sunPos = vec2(aspect * 0.88, 0.82); sunR = 0.004; sunCol = vec3(1.0);
        haloCol = vec3(0.75, 0.8, 1.0); haloAmt = 0.1; haloSpread = 18.0;
        bodyType = 5; bodyPos = vec2(aspect * 0.26, 0.70); bodyR = 0.20; bodyTilt = -0.12;
        bodyA = vec3(0.26, 0.44, 0.90); bodyB = vec3(0.12, 0.22, 0.62); bodyL = normalize(vec3(0.9, 0.3, 0.5));
        bodyAtmo = 0.25;
        landFar = vec3(0.82, 0.70, 0.70); landNear = vec3(0.13, 0.08, 0.10);
        rimCol = vec3(0.70, 0.78, 1.0); hazeCol = vec3(0.22, 0.24, 0.42); hazeAmt = 0.3;
        rough = 0.7; shape = 2; prop = 3; propDens = 0.3; fx = 5;
        lightSide = 1.0; relief = 0.35;
    } else { // Церера: темний пил, гора Ахуна, уламки поясу в небі
        skyTop = vec3(0.0, 0.0, 0.006); skyMid = vec3(0.008, 0.008, 0.014); skyLow = vec3(0.04, 0.04, 0.045);
        starAmt = 1.0; starFrom = 0.42;
        sunPos = vec2(aspect * 0.86, 0.56); sunR = 0.018; sunCol = vec3(1.0, 0.97, 0.9);
        haloCol = vec3(0.9, 0.85, 0.75); haloAmt = 0.25; haloSpread = 10.0;
        landFar = vec3(0.36, 0.34, 0.32); landNear = vec3(0.04, 0.04, 0.04);
        rimCol = vec3(1.0, 0.96, 0.88); hazeCol = vec3(0.08, 0.08, 0.08); hazeAmt = 0.1;
        shape = 3; rough = 0.8; prop = 3; propDens = 0.8; fx = 4;
        mons = true; monsH = 0.17; monsW = 0.26; monsFire = false;
        lightSide = 1.0; relief = 0.55;
    }
}

// Гора на шарі 1 (вулкан на Венері, Ахуна на Церері): одна на кожні кілька екранів
float monsAt(float x, out float vx) {
    float w = 2.4;
    vx = (floor(x / w) + 0.5) * w;
    float c = max(0.0, 1.0 - abs(x - vx) / monsW);
    // увігнутий схил, пласка вершина; у вулкана -- ще й кратер
    float h = min(pow(c, monsFire ? 1.8 : 1.2), 0.86) / 0.86;
    if (monsFire) h -= 0.05 * smoothstep(0.86, 1.0, c);
    return monsH * h;
}

// Профіль кратера в розрізі: валик по краях, чаша всередині
float craters(float u, float seed) {
    float c = floor(u);
    float f = fract(u);
    float r = hash1(c + seed * 7.1);
    if (r < 0.4) return 0.0;
    float rad = 0.18 + 0.22 * hash1(c * 3.3 + seed);
    float d = abs(f - 0.5) / rad;
    float rim = exp(-pow((d - 1.0) * 3.2, 2.0)) * 0.35;
    float bowl = 0.6 * max(0.0, 1.0 - d * d);
    // на межі комірки валик мусить сходити в нуль, інакше пагорб обривається вертикальною стіною
    return (rim - bowl) * rad * 2.0 * smoothstep(0.5, 0.42, abs(f - 0.5));
}

// Висота шару k (0 -- далекий, 4 -- ближній) в точці x
float layerHeight(float k, float x) {
    float base = 0.40 - k * 0.075;
    float amp = (0.10 + k * 0.025) * rough;
    float freq = 1.6 + k * 0.5;
    float r = ridge(x * freq, k + scene * 3.7);
    float h = r;
    if (shape == 1) { // столові гори: пласкі тераси з крутими уступами
        float t = r * 2.6;
        h = (floor(t) + smoothstep(0.72, 0.92, fract(t))) / 2.6;
    } else if (shape == 2) { // зубчасті гребені
        float n = 1.0 - abs(noise1(x * freq * 2.3 + k * 7.0) * 2.0 - 1.0);
        h = r * 0.65 + n * n * 0.5 - 0.05;
    } else if (shape == 3) { // кратери
        h = r * 0.75 + 0.12 + craters(x * freq * 0.8, k + scene);
    } else if (shape == 4) { // урвища: рівні плато, що обриваються вниз
        float u = x * freq * 0.45 + k * 3.0;
        float c = floor(u);
        float step_ = mix(hash1(c + k * 13.0), hash1(c + 1.0 + k * 13.0), smoothstep(0.86, 0.93, fract(u)));
        h = r * 0.45 + step_ * 0.75 - 0.1;
    }
    if (fx == 8) // плазма здіймається й опадає
        h += (noise2(vec2(x * freq * 1.3, time * 0.22 + k * 3.0)) - 0.5) * 0.45;
    float y = base + amp * (h - 0.5) * 2.0;
    if (mons && k == 1.0) {
        float vx;
        y += monsAt(x, vx);
    }
    return y;
}

// Ялинка: 1 всередині силуету. p -- відносно основи, hgt -- висота
float pine(vec2 p, float hgt, float px) {
    float w = hgt * 0.13;
    float y = p.y / hgt;
    float tier = fract(y * 3.0);
    float width = w * (1.0 - y) * (0.75 + 0.35 * (1.0 - tier));
    float body = smoothstep(px, -px, abs(p.x) - width) * step(0.08, y) * step(y, 1.0);
    float trunk = smoothstep(px, -px, abs(p.x) - w * 0.12) * step(0.0, y) * step(y, 0.1);
    return max(body, trunk);
}

// Крижаний шпиль: вузький, трохи нахилений
float spire(vec2 p, float hgt, float px, float lean) {
    float y = p.y / hgt;
    float w = hgt * 0.09 * (1.0 - y);
    return smoothstep(px, -px, abs(p.x - lean * y * hgt) - w) * step(0.0, y) * step(y, 1.0);
}

// Валун: напівзанурений овал
float boulder(vec2 p, float size, float px) {
    vec2 q = p / vec2(size * 1.3, size);
    return smoothstep(px / size, -px / size, length(q) - 1.0) * step(0.0, p.y);
}

vec3 drawSky(vec2 uv, float aspect, float px) {
    float sy = uv.y;
    vec3 col = mix(skyLow, skyMid, smoothstep(0.30, 0.62, sy));
    col = mix(col, skyTop, smoothstep(0.60, 1.0, sy));

    // Зорі
    if (starAmt > 0.0) {
        vec2 sg = uv * 120.0;
        vec2 cell = floor(sg);
        float sr = hash2(cell + scene * 13.0);
        if (sr > 1.0 - 0.015 * starAmt - 0.01 * starAmt * starAmt) {
            vec2 sp = cell + vec2(hash2(cell + 3.1), hash2(cell + 7.7));
            float d = length(sg - sp);
            float tw = 0.6 + 0.4 * sin(time * (1.0 + sr * 3.0) + sr * 50.0);
            col += vec3(0.9, 0.9, 1.0) * smoothstep(1.2, 0.0, d * 3.0) * tw * smoothstep(starFrom, starFrom + 0.3, sy);
        }
    }

    // Ореол світила (на Марсі -- блакитний захід, на Венері -- пляма крізь хмари)
    float sd = length(uv - sunPos);
    col += haloCol * haloAmt * exp(-max(sd - sunR, 0.0) * haloSpread);

    if (sunR > 0.0) {
        vec2 sp = (uv - sunPos) / sunR;
        float r = length(sp);
        if (r < 1.0 + px / sunR) {
            float z = sqrt(max(1.0 - r * r, 0.0));
            vec3 disk = sunCol * (0.72 + 0.28 * z);
            col = mix(col, disk, smoothstep(1.0 + px / sunR, 1.0 - px / sunR, r));
        }
    }
    return col;
}

// Кільце в системі планети: e -- точка в площині кілець (розтягнута), повертає прозорість
float ringAlpha(vec2 q, float squash, out float front) {
    vec2 e = vec2(q.x, q.y / squash);
    float rr = length(e);
    front = step(q.y, 0.0);
    if (bodyType == 3) {
        float a = smoothstep(1.24, 1.30, rr) * smoothstep(2.30, 2.22, rr);
        a *= 0.55 + 0.45 * noise1(rr * 34.0);
        a *= 1.0 - 0.9 * smoothstep(0.035, 0.0, abs(rr - 1.88)); // щілина Кассіні
        return a * 0.9;
    }
    // Уран: кілька тонких темних кілець
    float a = 0.0;
    a += smoothstep(0.018, 0.0, abs(rr - 1.55));
    a += smoothstep(0.014, 0.0, abs(rr - 1.68));
    a += smoothstep(0.03, 0.0, abs(rr - 1.95));
    return min(a, 1.0) * 0.6;
}

vec3 drawBody(vec3 col, vec2 uv, float px) {
    if (bodyType == 0) return col;
    vec2 p = (uv - bodyPos) / bodyR;
    float e = px / bodyR;
    float c = cos(bodyTilt);
    float s = sin(bodyTilt);
    vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
    float r = length(p);
    if (bodyType == 6) // Фобос -- нерівна картоплина
        r *= 1.0 + 0.16 * (noise1(atan(p.y, p.x) * 1.6 + 2.0) - 0.5) * 2.0;

    // м'яке сяйво атмосфери/відбите світло навколо
    col += mix(bodyA, haloCol, 0.5) * bodyAtmo * exp(-max(r - 1.0, 0.0) * 9.0);

    bool ringed = bodyType == 3 || bodyType == 4;
    float squash = bodyType == 3 ? 0.30 : 0.07;
    vec3 ringCol = bodyType == 3 ? vec3(0.86, 0.78, 0.62) : vec3(0.42, 0.50, 0.52);
    float front = 0.0;
    float ra = ringed ? ringAlpha(q, squash, front) : 0.0;
    // задня половина кільця -- за диском
    if (ringed && front < 0.5 && r > 1.0) col = mix(col, ringCol, ra);

    if (r < 1.0 + e) {
        float z = sqrt(max(1.0 - r * r, 0.0));
        vec3 n = vec3(p, z);
        float lit = smoothstep(-0.08, 0.35, dot(n, bodyL));
        vec3 base = bodyA;
        if (bodyType == 1 || bodyType == 6) {
            // моря -- м'які темніші плями, і дрібні кратери зі світлим краєм
            float spots = noise2(q * 1.7 + 4.0) * 0.65 + noise2(q * 4.5 + 1.0) * 0.35;
            base = mix(bodyA, mix(bodyB, bodyA, 0.3) * 0.94, smoothstep(0.44, 0.78, spots));
            vec2 cg = q * 5.0;
            vec2 cc = floor(cg);
            float ch = hash2(cc + 2.0);
            if (ch > 0.72) {
                float cr = 0.08 + 0.18 * hash2(cc + 5.0);
                vec2 cv = (cg - cc - 0.5 - 0.3 * (vec2(hash2(cc + 7.0), hash2(cc + 9.0)) - 0.5)) / cr;
                float cd = length(cv);
                // чаша в тіні з боку світла, край зі світлом навпроти
                float side = dot(normalize(cv + 1e-4), normalize(bodyL.xy));
                base *= 1.0 - 0.09 * smoothstep(1.0, 0.6, cd) * (0.6 + 0.4 * side)
                      + 0.05 * smoothstep(0.3, 0.0, abs(cd - 1.0)) * max(-side, 0.0);
            }
        } else if (bodyType == 2) { // Юпітер: смуги з вихорами, Велика червона пляма
            float lat = q.y;
            float warp = noise2(vec2(q.x * 3.0 + time * 0.004, lat * 9.0)) + 0.5 * noise2(vec2(q.x * 9.0, lat * 26.0));
            float b = sin(lat * 15.0 + warp * 2.2);
            base = mix(bodyA, bodyB, smoothstep(-0.2, 0.6, b));
            base = mix(base, vec3(0.80, 0.70, 0.62), smoothstep(0.25, -0.2, b) * 0.4);
            base = mix(base, bodyB * 0.75, smoothstep(0.72, 0.98, abs(lat)));
            float g = length((q - vec2(0.30 + 0.0 * time, -0.30)) / vec2(0.20, 0.11));
            base = mix(base, vec3(0.78, 0.40, 0.26), smoothstep(1.0, 0.65, g));
            base = mix(base, vec3(0.95, 0.85, 0.75), smoothstep(1.15, 1.0, g) * smoothstep(0.9, 1.0, g) * 0.6);
        } else if (bodyType == 3) { // Сатурн: ніжні смуги
            float b = sin(q.y * 12.0 + noise2(vec2(q.x * 2.0, q.y * 6.0)) * 1.2);
            base = mix(bodyA, bodyB, smoothstep(-0.4, 0.8, b) * 0.6);
            base = mix(base, vec3(0.62, 0.66, 0.64), smoothstep(0.75, 0.98, q.y) * 0.5);
        } else if (bodyType == 4) { // Уран: майже рівний бірюзовий
            base = mix(bodyB, bodyA, smoothstep(-0.8, 0.9, q.y));
            base *= 0.96 + 0.04 * sin(q.y * 10.0);
        } else if (bodyType == 5) { // Нептун: смуги, темна пляма, білі перисті хмари
            float b = sin(q.y * 9.0 + noise2(vec2(q.x * 2.5, q.y * 5.0)) * 1.4);
            base = mix(bodyA, bodyB, smoothstep(-0.5, 0.8, b) * 0.7);
            float dsp = length((q - vec2(-0.22, -0.25)) / vec2(0.18, 0.09));
            base = mix(base, vec3(0.06, 0.10, 0.32), smoothstep(1.0, 0.6, dsp));
            float cir = noise2(vec2(q.x * 7.0 + time * 0.006, q.y * 12.0));
            float band = smoothstep(0.07, 0.0, abs(q.y + 0.42)) + smoothstep(0.05, 0.0, abs(q.y - 0.33));
            base = mix(base, vec3(0.92, 0.95, 1.0), smoothstep(0.62, 0.85, cir) * band * 0.85);
        }
        base *= 0.72 + 0.28 * z;
        vec3 bc = base * (0.06 + 0.94 * lit);
        col = mix(col, bc, smoothstep(1.0 + e, 1.0 - e, r));
        if (bodyType == 2) { // тінь Іо на хмарах -- лише коли Іо перед Юпітером
            float ang = fract(time / 300.0) * 6.2832;
            vec2 io = vec2(-1.7 * cos(ang), -0.18 + 0.05 * sin(ang));
            vec2 sh = io - bodyL.xy * 0.22;
            col = mix(col, col * 0.15, smoothstep(0.065 + e, 0.065 - e, length(p - sh)) * step(0.0, sin(ang)) * smoothstep(1.0, 0.95, r));
        }
    }
    if (bodyType == 2) { // Іо кружляє: пів оберту перед Юпітером, пів -- за ним (там диск її ховає)
        float ang = fract(time / 300.0) * 6.2832;
        vec2 io = vec2(-1.7 * cos(ang), -0.18 + 0.05 * sin(ang));
        vec2 ip = (p - io) / 0.07;
        float ir = length(ip);
        bool front = sin(ang) > 0.0;
        if ((front || r > 1.0 + e) && ir < 1.0 + e / 0.07) {
            vec3 n = vec3(ip, sqrt(max(1.0 - ir * ir, 0.0)));
            float spots = noise2(ip * 3.0 + 11.0);
            vec3 ic = mix(vec3(0.95, 0.86, 0.48), vec3(0.78, 0.52, 0.25), smoothstep(0.5, 0.7, spots));
            ic *= 0.08 + 0.92 * smoothstep(-0.08, 0.35, dot(n, bodyL));
            col = mix(col, ic, smoothstep(1.0 + e / 0.07, 1.0 - e / 0.07, ir));
        }
    }
    // передня половина кільця -- поверх диска (з тінню планети на ньому -- пропустимо)
    if (ringed && front > 0.5) col = mix(col, ringCol * (r < 1.0 ? 0.85 : 1.0), ra);
    return col;
}

// Падуча зоря (де є атмосфера): не в кожен цикл, спалахує на секунду
vec3 drawMeteor(vec3 col, vec2 uv, float aspect, float px) {
    float T = 23.0;
    float n = floor(time / T);
    float t = time - n * T - 4.0 * hash1(n * 9.1 + scene);
    if (hash1(n * 1.7 + scene) < 0.4 || t < 0.0 || t > 1.6) return col;
    float dur = 0.9;
    vec2 a = vec2((0.15 + 0.7 * hash1(n * 3.1)) * aspect, 0.70 + 0.22 * hash1(n * 5.9));
    vec2 dir = normalize(vec2(hash1(n * 7.3) < 0.5 ? -1.0 : 1.0, -0.45 - 0.3 * hash1(n * 2.2)));
    float head = clamp(t / dur, 0.0, 1.0) * 0.32;
    vec2 d = uv - a;
    float along = dot(d, dir);
    float across = abs(d.x * dir.y - d.y * dir.x);
    float tail = 0.13;
    float m = smoothstep(px * 1.2, 0.0, across) * smoothstep(head - tail, head, along) * step(along, head);
    float fade = 1.0 - smoothstep(dur, 1.6, t);
    col += vec3(0.95, 0.95, 1.0) * m * fade * 0.9;
    col += vec3(1.0, 0.95, 0.85) * exp(-length(uv - a - dir * head) * 260.0) * fade * step(t, dur) * 0.8;
    return col;
}

// Комета (безповітряні світи): за кілька хвилин перетинає небо, хвости -- геть від сонця
vec3 drawComet(vec3 col, vec2 uv, float aspect) {
    float ph = fract(time / 420.0 + scene * 0.29);
    vec2 head = vec2(mix(-0.4, aspect + 0.4, ph), 0.80 + 0.07 * sin(ph * 3.14 + scene));
    vec2 away = normalize(head - sunPos + vec2(0.0, 0.001));
    vec2 d = uv - head;
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        vec2 dir = normalize(away + vec2(-away.y, away.x) * fi * 0.18); // пиловий хвіст трохи вигнутий
        float along = dot(d, dir) + fi * 0.03 * pow(max(dot(d, dir), 0.0) * 4.0, 2.0);
        float across = abs(d.x * dir.y - d.y * dir.x);
        float len = 0.30 - fi * 0.08;
        float w = 0.003 + max(along, 0.0) * (0.05 + fi * 0.05);
        float m = exp(-pow(across / w, 2.0)) * smoothstep(-0.003, 0.004, along) * pow(max(1.0 - along / len, 0.0), 1.5);
        col += mix(vec3(0.55, 0.75, 1.0), vec3(1.0, 0.92, 0.75), fi) * m * (0.45 - fi * 0.15);
    }
    col += vec3(0.9, 0.97, 1.0) * exp(-length(d) * 220.0) * 0.9;
    return col;
}

// Світлячки на Землі: мерехтять між ялинками ближнього плану
vec3 drawFireflies(vec3 col, vec2 uv) {
    vec2 g = uv * 13.0;
    vec2 cell = floor(g);
    float h = hash2(cell + 5.0);
    if (h < 0.55 || uv.y > 0.26) return col;
    vec2 pos = cell + 0.5 + 0.35 * vec2(sin(time * 0.4 + h * 30.0), cos(time * 0.33 + h * 17.0));
    float blink = smoothstep(0.55, 1.0, sin(time * (0.8 + h) + h * 40.0));
    float d = length(g - pos);
    col += vec3(0.85, 1.0, 0.45) * (smoothstep(0.06, 0.0, d) + exp(-d * 9.0) * 0.25) * blink;
    return col;
}

// Коронні дуги над фотосферою: магнітні петлі, вздовж яких тече плазма. Одна з них раз на
// півтори хвилини розростається й відривається -- викид у космос.
vec3 drawLoops(vec3 col, vec2 uv, float aspect, float pan) {
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float a = 0.16 + 0.10 * hash1(fi * 5.3);           // напівширина між основами
        float b = 0.20 + 0.16 * hash1(fi * 2.1 + 1.0);     // висота
        b *= 1.0 + 0.08 * sin(time * 0.07 + fi * 2.0);     // дихає
        float fade = 1.0;
        if (i == 0) { // викид
            float ph = fract(time / 90.0);
            float grow = smoothstep(0.55, 1.0, ph);
            b *= 1.0 + grow * 2.6;
            a *= 1.0 + grow * 0.7;
            fade = 1.0 - smoothstep(0.75, 1.0, ph);
        }
        float cx = fract(hash1(fi * 9.7) - pan * 0.08) * (aspect + 0.8) - 0.4;
        vec2 p = vec2(uv.x - cx, uv.y - 0.30);
        if (p.y < -0.05) continue;
        float tilt = (hash1(fi * 3.9) - 0.5) * 0.5;        // петлі трохи нахилені
        p.x -= p.y * tilt;
        vec2 e = p / vec2(a, b);
        float r = length(e);
        float ang = atan(e.y, e.x);                         // 0..pi вздовж петлі
        float glow = 0.0;
        for (int j = 0; j < 3; j++) { // кілька волокон поруч
            float fj = float(j);
            float rr = 1.0 + (fj - 1.0) * 0.06;
            float d = abs(r - rr) * min(a, b) * 1.6;
            float w = 0.004 + 0.003 * fj;
            float flow = 0.45 + 0.55 * noise1(ang * 9.0 - time * (0.5 + 0.2 * fj) + fi * 7.0 + fj * 3.0);
            glow += exp(-pow(d / w, 2.0)) * flow;
        }
        float halo = exp(-abs(r - 1.0) * min(a, b) * 18.0) * 0.35;
        float m = (glow + halo) * fade * smoothstep(-0.05, 0.02, p.y);
        col += vec3(1.0, 0.55, 0.18) * m * 0.75 + vec3(1.0, 0.9, 0.6) * glow * fade * 0.25 * smoothstep(-0.05, 0.02, p.y);
    }
    return col;
}

// Уламки поясу, що повільно пливуть небом у три шари
vec3 drawRocks(vec3 col, vec2 uv, float px) {
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float sc = 9.0 - fi * 3.0;
        vec2 g = vec2(uv.x * sc + time * (0.010 + fi * 0.012) + fi * 7.0, uv.y * sc);
        vec2 cell = floor(g);
        float h = hash2(cell + fi * 31.0);
        if (h < 0.87) continue;
        vec2 ctr = cell + 0.25 + 0.5 * vec2(hash2(cell + 1.7), hash2(cell + 4.3));
        vec2 d = g - ctr;
        float rad = 0.10 + 0.22 * hash2(cell + 9.1);
        float ang = atan(d.y, d.x) + time * 0.02 * (h - 0.9);
        float rr = rad * (1.0 + 0.22 * (noise1(ang * 1.9 + h * 40.0) - 0.5) * 2.0);
        float m = smoothstep(rr + px * sc, rr - px * sc, length(d)) * smoothstep(0.42, 0.55, uv.y);
        float lit = smoothstep(-0.3, 0.6, dot(normalize(d + 1e-4), normalize(vec2(lightSide, 0.25))) * (length(d) / rr));
        vec3 rc = mix(vec3(0.05, 0.05, 0.05), vec3(0.55, 0.52, 0.48), lit) * (0.6 + 0.4 * fi / 2.0);
        col = mix(col, rc, m);
    }
    return col;
}

void main() {
    float px = 1.5 / resolution.y;
    vec2 uv = gl_FragCoord.xy / resolution.y;
    float aspect = resolution.x / resolution.y;
    float pan = time * 0.012 + CAM_OFFSET * 3.0;
    setup(aspect);

    vec3 col = drawSky(uv, aspect, px);
    int sc = int(scene + 0.5);
    // комета -- до тіла на небі, щоб Юпітер чи Нептун її закривали
    if (sc == 1 || sc == 5 || sc == 7 || sc == 8 || sc == 9) col = drawComet(col, uv, aspect);
    col = drawBody(col, uv, px);
    if (sc == 7) { // Аріель: тонкий серп іншого супутника Урана
        vec2 ap = (uv - vec2(aspect * 0.22, 0.80)) / 0.022;
        float ar = length(ap);
        float lit = smoothstep(-0.1, 0.3, dot(vec3(ap, sqrt(max(1.0 - ar * ar, 0.0))), normalize(vec3(-0.9, 0.2, 0.3))));
        col = mix(col, vec3(0.80, 0.82, 0.84) * (0.04 + 0.96 * lit), smoothstep(1.0 + px / 0.022, 1.0 - px / 0.022, ar));
    }
    if (fx == 4) col = drawRocks(col, uv, px);
    if (fx == 8) {
        // пасма корони, що повільно течуть угору
        float wisp = noise2(vec2(uv.x * 2.2 + sin(uv.y * 3.0) * 0.4, uv.y * 1.2 - time * 0.015));
        wisp = wisp * 0.6 + 0.4 * noise2(vec2(uv.x * 6.0, uv.y * 3.0 - time * 0.03));
        col += vec3(1.0, 0.42, 0.12) * 0.22 * smoothstep(0.35, 0.85, wisp) * smoothstep(0.3, 0.75, uv.y);
        col = drawLoops(col, uv, aspect, time * 0.012);
    }

    // Хмари -- витягнуті м'які смуги; на Венері -- суцільна стеля
    if (cloudAmt > 0.0) {
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float cy = 0.46 + fi * 0.07 + (cloudAmt > 0.8 ? 0.25 + fi * 0.04 : 0.0);
            float thick = cloudAmt > 0.8 ? 5.0 : 14.0;
            vec2 cp = vec2(uv.x * 1.4 + time * (0.004 + fi * 0.002) + fi * 3.0, (uv.y - cy) * thick);
            float cl = noise2(vec2(cp.x * 2.0, fi + scene)) * smoothstep(1.0, 0.0, abs(cp.y));
            cl = smoothstep(0.45 - 0.2 * step(0.8, cloudAmt), 0.75, cl);
            vec3 cc = mix(cloudA, cloudB, fi / 2.0);
            col = mix(col, cc, cl * cloudAmt * (cloudAmt > 0.8 ? 0.6 : 1.0));
        }
    }

    // Короткі події в небі -- щоб пейзаж жив, навіть коли нічого не робиш
    if (sc == 3 || sc == 4) col = drawMeteor(col, uv, aspect, px);
    if (sc == 2) { // блискавки в хмарній стелі Венери
        float n = floor(time / 6.0);
        float t = time - n * 6.0 - 3.0 * hash1(n * 4.3);
        if (t > 0.0 && t < 0.4 && hash1(n * 8.1) > 0.3) {
            float flick = step(0.45, fract(t * 13.0 + hash1(n)));
            vec2 p0 = vec2(hash1(n * 2.7) * aspect, 0.74 + 0.16 * hash1(n * 6.1));
            col += vec3(1.0, 0.96, 0.88) * (1.0 - 0.6 * t / 0.4) * flick * (0.9 * exp(-length(uv - p0) * 5.0) + 0.12);
        }
    }

    // Кораблик раз на кілька хвилин
    float st = fract(time / 240.0 + scene * 0.13);
    vec2 sp2 = vec2(mix(-0.2, aspect + 0.2, st), 0.80 + 0.03 * sin(st * 6.28));
    vec2 q = (uv - sp2) * vec2(1.0, 3.2);
    float ship = smoothstep(0.012 + px, 0.012 - px, length(q) + q.x * 0.6);
    col = mix(col, vec3(0.12, 0.10, 0.22) * 0.6, ship);
    col += vec3(1.0, 0.6, 0.3) * smoothstep(0.006, 0.0, length(uv - sp2 + vec2(0.017, 0.0)));

    // Пагорби: від далекого до ближнього, з серпанком і дрібницями
    for (int i = 0; i < 5; i++) {
        float k = float(i);
        float x = uv.x + pan * (0.2 + k * 0.35) + k * 11.0;
        float h = layerHeight(k, x);
        vec3 lc = mix(landFar, landNear, k / 4.0);
        lc = mix(lc, hazeCol, (1.0 - k / 4.0) * hazeAmt);
        // схил під цією точкою: до світла -- світліший, від світла -- у тіні
        // нахил по широкому відрізку: дрібні зубці не мають давати смуг, лише великі схили
        float slope = (layerHeight(k, x + 0.04) - h) / 0.04;
        float facing = clamp(-slope * lightSide * 1.2, -1.0, 1.0);
        float depthIn = h - uv.y;
        vec3 rim = mix(lc, rimCol, (0.35 + 0.25 * facing * step(0.01, relief)) * (1.0 - k / 5.0));

        float inside = smoothstep(-px, px, depthIn);
        float edge = smoothstep(0.006, 0.0, depthIn) * inside;
        vec3 lcs = lc * max(0.15, 1.0 + facing * relief * exp(-depthIn * 14.0));
        if (fx != 8) lcs *= mix(1.0, 0.82, smoothstep(0.0, 0.2, depthIn)); // нижче -- темніше, шар має товщину
        vec3 hc = mix(lcs, rim, edge);

        // Особливі текстури на поверхні
        if (fx == 1 && i >= 2) { // лава в тріщинах, що пульсує
            float cr = noise2(vec2(x * 6.0, uv.y * 30.0) + k * 5.0);
            float line = smoothstep(0.955, 0.99, 1.0 - abs(cr * 2.0 - 1.0));
            float pulse = 0.65 + 0.35 * sin(time * 0.6 + x * 3.0 + k);
            hc += vec3(1.0, 0.38, 0.06) * line * pulse * (0.4 + 0.15 * k) * smoothstep(0.0, 0.02, h - uv.y);
        }
        if (fx == 8) { // гранули: світлі комірки плазми з темними межами, що повільно кипить
            vec2 gp = vec2(x * (9.0 - k * 1.4), uv.y * (26.0 - k * 3.5)); // без викривлення по краю шару -- інакше шви
            vec2 gc = floor(gp);
            float d1 = 9.0;
            float d2 = 9.0;
            vec2 near = gc;
            for (int gy = -1; gy <= 1; gy++) {
                for (int gx = -1; gx <= 1; gx++) {
                    vec2 c = gc + vec2(float(gx), float(gy));
                    float hh = hash2(c + k * 17.0);
                    vec2 o = 0.5 + 0.4 * vec2(sin(time * 0.35 + hh * 6.28), cos(time * 0.29 + hh * 9.1));
                    float dd = length(gp - c - o);
                    if (dd < d1) { d2 = d1; d1 = dd; near = c; } else if (dd < d2) { d2 = dd; }
                }
            }
            float lane = smoothstep(0.0, 0.35, d2 - d1);
            float bright = 0.85 + 0.3 * hash2(near + 3.3 * k); // яскравість гранули, а не клітинки сітки -- інакше квадрати
            hc *= mix(0.72, 1.15 * bright, lane) * (1.0 - 0.18 * d1);
            hc += vec3(1.0, 0.85, 0.5) * 0.25 * (1.0 - smoothstep(0.0, 0.6, d1)) * (1.0 - k / 5.0);
        }
        if (fx == 6 && i >= 1) { // руді смуги-тріщини на кризі Європи
            float cr = noise2(vec2(x * 2.2 + uv.y * 4.0, uv.y * 46.0) + k * 9.0);
            float line = smoothstep(0.92, 0.985, 1.0 - abs(cr * 2.0 - 1.0));
            hc = mix(hc, vec3(0.50, 0.30, 0.20) * (1.2 - k * 0.2), line * 0.55 * smoothstep(0.0, 0.015, h - uv.y));
        }

        if (fx == 7 && i <= 2) { // борозни Міранди: світлі смуги паралельно краю
            float g = sin((h - uv.y) * 260.0 + noise1(x * 3.0 + k) * 7.0);
            float patch_ = smoothstep(0.55, 0.75, noise1(x * 1.7 + k * 4.0));
            hc = mix(hc, hc * 1.25 + 0.02, smoothstep(0.6, 0.95, g) * 0.35 * patch_ * smoothstep(0.004, 0.02, h - uv.y));
        }

        // Дрібниці на шарах 1..4
        float things = 0.0;
        float lit = 0.0;
        if (i > 0 && prop > 0) {
            float cw = prop == 1 ? 0.035 - k * 0.004 : (prop == 2 ? 0.05 - k * 0.006 : 0.07 - k * 0.008);
            float cx = floor(x / cw);
            float r = hash1(cx + k * 91.0 + scene * 3.0);
            float dens = noise1(cx * 0.15 + k * 5.0) * propDens;
            if (r < dens) {
                float tx = (cx + 0.3 + 0.4 * hash1(cx * 3.7 + k)) * cw;
                float th = (0.045 + 0.05 * hash1(cx * 1.3 + k)) * (0.6 + k * 0.25);
                if (fx == 8) th *= 0.1 + 0.9 * smoothstep(0.35, 1.0, noise1(time * 0.6 + cx * 3.1 + k));
                float base = layerHeight(k, tx) - 0.01;
                vec2 pp = vec2(x - tx, uv.y - base);
                if (prop == 1) things = pine(pp, th, px);
                else if (prop == 2) things = spire(pp, th * 1.2, px, (hash1(cx * 5.1) - 0.5) * 0.4);
                else {
                    // валун -- верхня половина овалу, трохи втоплена в ґрунт (на схилі не висить)
                    float bs = th * 0.2;
                    pp.y += bs * 0.25;
                    // лише на рівному: на крутому схилі пласке дно висіло б у повітрі
                    float tilt_ = abs(layerHeight(k, tx + bs * 1.3) - layerHeight(k, tx - bs * 1.3));
                    things = boulder(pp, bs, px) * step(tilt_, bs * 0.35);
                    vec2 bq = pp / vec2(bs * 1.3, bs);
                    lit = clamp(0.5 + 0.8 * (bq.x * lightSide + bq.y * 0.6), 0.0, 1.0);
                }
                if (prop != 3) lit = smoothstep(0.0, 0.6, pp.x * lightSide / max(th * 0.1, 1e-3));
                if (fx == 8) things *= 1.0 - 0.85 * clamp(pp.y / (th * 1.2), 0.0, 1.0); // спікула гасне до вершини
            }
        }
        vec3 thingCol = prop == 1 ? lc * 0.85 : (prop == 3 ? lc * mix(0.55, 1.0 + relief, lit) : mix(lc * 0.9, rim, lit * 0.6));
        if (fx == 8) thingCol = vec3(1.0, 0.62, 0.25);
        if (fx == 8) {
            col += thingCol * things * (1.0 - inside) * 0.55;
            things = 0.0;
        }
        float m = max(inside, things);
        col = mix(col, mix(hc, thingCol, things * (1.0 - inside)), m);

        // Гора: лава біля кратера й дим (Венера), світлі смуги на схилах (Церера)
        if (mons && i == 1) {
            float vx;
            float mh = monsAt(x, vx);
            float top = layerHeight(1.0, vx);
            vec2 mp = vec2(x - vx, uv.y - top);
            if (monsFire) {
                float lava = smoothstep(0.93, 0.98, noise1((x - vx) * 70.0 + sin(mp.y * 55.0) * 0.6 + 3.0)) * smoothstep(-0.16, 0.0, mp.y) * step(mp.y, 0.0) * smoothstep(-0.18, -0.01, mp.y) * inside * smoothstep(monsW * 0.7, 0.0, abs(mp.x));
                col += vec3(1.0, 0.42, 0.08) * lava * 0.9;
                col += vec3(1.0, 0.45, 0.10) * 0.55 * exp(-length(mp * vec2(1.0, 2.0)) * 40.0);
                // дим, який зносить вітер
                vec2 sm = mp;
                sm.x -= sm.y * sm.y * 2.2 + sm.y * 0.2;
                float w = 0.012 + max(sm.y, 0.0) * 0.28;
                float smoke = exp(-pow(sm.x / w, 2.0)) * smoothstep(0.0, 0.02, sm.y) * smoothstep(0.42, 0.05, sm.y);
                smoke *= 0.55 + 0.45 * noise2(vec2(sm.x * 30.0, sm.y * 14.0 - time * 0.25));
                col = mix(col, mix(vec3(0.30, 0.18, 0.10), vec3(0.55, 0.38, 0.22), smoothstep(0.0, 0.3, sm.y)), smoke * 0.85);
            } else {
                float streak = smoothstep(0.6, 0.88, noise1((x - vx) / max(-mp.y, 0.012) * 3.0 + 9.0)) * inside * step(mp.y, 0.0) * smoothstep(-mh * 0.9, -0.005, mp.y) * smoothstep(monsW * 0.6, 0.0, abs(mp.x));
                col = mix(col, vec3(0.88, 0.86, 0.82), streak * 0.75);
            }
        }

        // Гейзери Енцелада на шарах 2-3
        if (fx == 2 && (i == 2 || i == 3)) {
            float W = 0.85;
            float c = floor(x / W);
            if (hash1(c + k * 17.0) > 0.35) {
                float gx = (c + 0.3 + 0.4 * hash1(c * 2.3 + k)) * W;
                float base = layerHeight(k, gx);
                vec2 gp = vec2(x - gx, uv.y - base);
                float H = 0.22 + 0.16 * hash1(c * 4.1 + k);
                float t = gp.y / H;
                float w = 0.004 + max(t, 0.0) * 0.055;
                float plume = exp(-pow(gp.x / w, 2.0)) * smoothstep(0.0, 0.03, t) * pow(max(1.0 - t, 0.0), 1.6);
                plume *= 0.6 + 0.4 * noise2(vec2(gp.x * 50.0, gp.y * 22.0 - time * 0.9));
                col += vec3(0.85, 0.92, 1.0) * plume * (0.55 + 0.2 * k / 4.0);
            }
        }
        // Темні струмені Тритона: стовп угору, а нагорі вітер тягне шлейф убік
        if (fx == 5 && (i == 1 || i == 2)) {
            float W = 0.9;
            // шлейф довший за відстань до межі комірки, тож дивимось і на сусідню зліва
            for (int j = 0; j < 2; j++) {
            float c = floor(x / W) - float(j);
            if (hash1(c + k * 23.0) > 0.3) {
                float gx = (c + 0.3 + 0.4 * hash1(c * 2.9 + k)) * W;
                float base = layerHeight(k, gx);
                vec2 gp = vec2(x - gx, uv.y - base);
                float H = 0.16 + 0.08 * hash1(c * 1.7 + k);
                float cw = 0.0025 + max(gp.y, 0.0) * 0.012;
                float column = exp(-pow(gp.x / cw, 2.0)) * smoothstep(0.0, 0.01, gp.y) * smoothstep(H + 0.01, H - 0.01, gp.y);
                float tw = 0.006 + max(gp.x, 0.0) * 0.07;
                float tail = exp(-pow((gp.y - H + 0.004 - gp.x * 0.04) / tw, 2.0)) * smoothstep(-0.01, 0.01, gp.x) * smoothstep(0.55, 0.0, gp.x);
                tail *= 0.55 + 0.45 * noise2(vec2(gp.x * 18.0 - time * 0.12, gp.y * 30.0));
                float a = max(column * 0.8, tail * 0.85);
                vec3 pc = mix(vec3(0.16, 0.12, 0.14), vec3(0.46, 0.42, 0.50), step(base + 0.004, uv.y) * smoothstep(0.0, 0.3, gp.x + gp.y));
                col = mix(col, pc, a);
            }
            }
        }
        // Пиловий вихор на Марсі, що повзе рівниною
        if (fx == 3 && i == 2) {
            float dx = fract(time / 420.0) * (aspect + 0.6) - 0.3;
            float base = layerHeight(k, dx + pan * (0.2 + k * 0.35) + k * 11.0);
            vec2 dp = vec2(uv.x - dx, uv.y - base + 0.005);
            float H = 0.26;
            float t = dp.y / H;
            float w = 0.003 + pow(max(t, 0.0), 1.3) * 0.035;
            float swirl = noise2(vec2(dp.x / w * 1.5 + time * 3.0, dp.y * 40.0 - time * 2.0));
            float dust = exp(-pow(dp.x / w, 2.0)) * smoothstep(0.0, 0.03, t) * smoothstep(1.0, 0.6, t) * (0.5 + 0.5 * swirl);
            col = mix(col, vec3(0.80, 0.56, 0.40), dust * 0.5);
        }
    }

    if (int(scene + 0.5) == 3) col = drawFireflies(col, uv);

    // Віньєтка
    vec2 vq = gl_FragCoord.xy / resolution.xy - 0.5;
    col *= 1.0 - 0.35 * dot(vq, vq);

    gl_FragColor = vec4(col, 1.0);
}
