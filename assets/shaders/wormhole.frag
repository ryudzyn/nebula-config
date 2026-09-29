#version 100
precision highp float;

uniform float time;
uniform vec2 resolution;

// Підмінюється через sed скриптом nebula-space-wallpaper-rotate (SUPER+G,
// "наступний ракурс") -- glpaper не приймає live-uniform, тож ротація
// фіксованих 4 ракурсів реалізована перегенерацією файлу.
#define CAM_OFFSET 0.0

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash3(vec3 p) {
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);
    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);
    return mix(nxy0, nxy1, f.z);
}

float fbm3(vec3 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise3(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return v;
}

vec3 rotateY(vec3 v, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec3(v.x * c - v.z * s, v.y, v.x * s + v.z * c);
}

// Наш бік -- звичайне зоряне поле, той самий тришаровий підхід (різні
// частоти проти "порожніх плям" при стисканні напрямків), що й у
// blackhole.frag.
vec3 starsHere(vec3 dir) {
    vec3 col = vec3(0.01, 0.012, 0.02);
    vec3 c1 = floor(dir * 900.0);
    col += vec3(pow(hash(c1), 110.0)) * 5.0;
    vec3 c2 = floor(dir * 320.0) + 91.7;
    col += vec3(pow(hash(c2), 210.0)) * 3.5 * vec3(0.8, 0.9, 1.0);
    return col;
}

// Інший бік -- чужий всесвіт: інша палітра (біолюмінесцентний ціан/пурпур
// замість теплого біло-золотого), інший зсув хешу, щоб візерунок зірок не
// збігався з "нашим" -- саме ця відмінність продає ілюзію іншого місця.
vec3 starsBeyond(vec3 dir, float swirl) {
    vec3 seedDir = dir + vec3(37.1, 11.7, 5.3);

    // Обертання -- лише для гладкої fbm-туманності. Зоряні комірки нижче
    // навмисно НЕ обертаються: floor()-сітка на високій частоті, зсувана
    // обертанням, дає зорям миготіти (перескакують через межі комірок) --
    // тут лишаємо їх нерухомими відносно камери, так само як зовні порталу.
    vec3 nebSeedDir = rotateY(dir, swirl) + vec3(37.1, 11.7, 5.3);
    float neb = fbm3(nebSeedDir * 2.2);
    float neb2 = fbm3(nebSeedDir * 2.2 + 19.0);
    vec3 nebCol = mix(vec3(0.25, 0.05, 0.45), vec3(0.05, 0.35, 0.4), neb2);
    vec3 col = nebCol * pow(neb, 1.1) * 3.2;

    vec3 c1 = floor(seedDir * 900.0);
    col += vec3(pow(hash(c1), 105.0)) * 5.0 * mix(vec3(0.6, 1.0, 0.9), vec3(1.0, 0.5, 1.0), hash(c1 + 4.0));
    vec3 c2 = floor(seedDir * 320.0) + 61.3;
    col += vec3(pow(hash(c2), 195.0)) * 4.0 * vec3(0.6, 1.0, 1.0);

    return col;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;

    float camAngle = time * 0.09 + CAM_OFFSET;
    float camDist = 9.0;
    // Чиста орбіта на фіксованій висоті -- компенсація зірок (rotateY на
    // camAngle) точна лише тоді, коли камера обертається по колу навколо
    // Y без зміни висоти; дрейф по Y (як було) трохи ламав цю компенсацію
    // і давав легке миготіння зовнішніх зірок при русі.
    vec3 ro = vec3(sin(camAngle) * camDist, 0.5, cos(camAngle) * camDist);

    vec3 target = vec3(0.0);
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(forward * 1.0 + uv.x * right + uv.y * up);

    float portalR = 1.0;
    float k = 0.4;

    vec3 pos = ro;
    vec3 dir = rd;
    float minR = 1000.0;

    for (int i = 0; i < 140; i++) {
        float r = length(pos);
        minR = min(minR, r);
        if (r > 40.0) {
            break;
        }

        float stepSize = clamp(r * 0.1, 0.02, 0.5);
        vec3 toCenter = -pos / r;
        // Підлога на r*r -- без неї згин вибухає біля центру (немає
        // горизонту, що "з'їдав" би промінь, як у чорній дірі, тож промені
        // проходять наскрізь навіть крізь найглибшу точку).
        float bend = k / max(r * r, 0.05);
        dir = normalize(dir + toCenter * bend * stepSize);
        pos += dir * stepSize;
    }

    // "Наш" бік -- завжди з НЕзігнутого rd: далеко від порталу він майже не
    // впливає на траєкторію, але накопичена за весь шлях крихітна кривизна
    // все одно хаотично перемішує 'dir' між сусідніми пікселями (немає
    // горизонту, що ховав би цю зону, як у чорній дірі) -- звідси
    // "потріскана" картинка була по всьому кадру. "Той бік" навпаки МАЄ
    // виглядати лінзовано-викривленим, тому саме йому лишаємо зігнутий dir.
    //
    // На відміну від чорних дір тут НЕ компенсуємо обертання камери --
    // портал симетричний, і без видимого дрейфу фону сама орбіта була б
    // непомітною (користувач прямо просив залишити тільки орбіту й бачити
    // рух). Тому зорі тут навмисно повільно "пропливають" разом з orbітою.
    vec3 colHere = starsHere(rd);
    vec3 colBeyond = starsBeyond(dir, time * 0.08);

    // Глибоке занурення (малий minR) -> показуємо інший бік; промені, що
    // пройшли повз, майже не зігнулись -> лишається наш бік практично без
    // змін. Так портал читається як компактна лінзована куля, а не суцільна
    // підміна всього неба.
    float portalMix = 1.0 - smoothstep(portalR * 1.1, portalR * 2.2, minR);
    vec3 col = mix(colHere, colBeyond, portalMix);

    // Тонке гало на межі порталу (гаусів пік навколо minR == portalR) --
    // продає саме "поверхню" порталу, а не просто плавний перехід кольору.
    float rim = exp(-pow((minR - portalR) / 0.2, 2.0));
    col += rim * vec3(0.65, 0.82, 1.0) * 1.4;

    col *= 1.0 - 0.15 * dot(uv, uv);

    gl_FragColor = vec4(col, 1.0);
}
