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

float fbm2(vec2 p) {
    vec3 q = vec3(p, 0.0);
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * noise3(q);
        q *= 2.0;
        amp *= 0.5;
    }
    return v;
}

vec3 rotateAxis(vec3 v, vec3 axis, float a) {
    float s = sin(a);
    float c = cos(a);
    return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

vec3 starfield(vec3 dir) {
    vec3 col = vec3(0.015, 0.015, 0.02);
    vec3 c1 = floor(dir * 700.0);
    col += vec3(pow(hash(c1), 140.0)) * 3.0;
    vec3 c2 = floor(dir * 250.0) + 91.7;
    col += vec3(pow(hash(c2), 260.0)) * 2.2 * vec3(0.85, 0.9, 1.0);
    return col;
}

// Той самий підхід, що й diskColorAt у blackhole.frag: один безперервний
// градієнт + kepler-подібна диференціальна ротація замість статичної
// текстури.
vec3 diskColorAt(float rr, float angle, float diskInner, float diskOuter, float camAngle) {
    float radial = clamp((rr - diskInner) / (diskOuter - diskInner), 0.0, 1.0);

    float orbitSpeed = 2.8 / sqrt(max(rr, diskInner));
    float flowAngle = angle - time * orbitSpeed * 0.9;
    vec2 flowUv = vec2(flowAngle * 3.0, rr * 4.0);
    float turb = fbm2(flowUv * 1.5);

    // Деформація самого радіуса шумом (domain warp) -- за ідеєю Gemini,
    // без цього межі кольорових зон були ідеальними колами ("як платівка").
    // Той самий turb-шум, тільки трохи іншого масштабу, щоб хвилі кольору
    // не збігалися один-в-один із хвилями щільності нижче.
    float warp = fbm2(flowUv * 0.6 + 31.0 + time * 0.06) - 0.5;
    warp += (fbm2(flowUv * 1.3 + 77.0 - time * 0.1) - 0.5) * 0.6;
    float radialWarped = clamp(radial + warp * 0.4, 0.0, 1.0);

    float density = smoothstep(1.0, 0.85, radial) * 0.35 + 0.55 + (turb - 0.5) * 0.75;

    vec3 hot = vec3(0.75, 0.85, 1.0);
    vec3 mid = vec3(0.5, 0.55, 1.0);
    vec3 cool = vec3(0.15, 0.1, 0.35);
    vec3 col = mix(hot, mid, smoothstep(0.0, 0.4, radialWarped));
    col = mix(col, cool, smoothstep(0.3, 1.0, radialWarped));

    // Доплерівська асиметрія -- бік диска, що рухається на камеру,
    // яскравіший/біліший за той, що рухається від неї (за ідеєю Gemini,
    // той самий прийом, що й doppler у blackhole.frag).
    float doppler = 0.55 + 1.0 * (0.5 + 0.5 * sin(angle - camAngle));

    return col * density * doppler;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * resolution) / resolution.y;

    float camAngle = time * 0.05 + CAM_OFFSET;
    float camDist = 12.0;
    vec3 ro = vec3(sin(camAngle) * camDist, 3.2, cos(camAngle) * camDist);

    vec3 target = vec3(0.0);
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    vec3 rd = normalize(forward * 1.3 + uv.x * right + uv.y * up);

    // На відміну від першої версії, тут НЕ компенсуємо обертання камери --
    // як і в кротовині, користувач хоче бачити саму орбіту, а не лише спін
    // маяка; фон тепер природно повільно "пропливає".
    // Камера завжди дивиться точно на зорю (target = origin), тож вона рівно
    // в центрі кадру за побудовою -- отже "затьмарення" довколишніх зірок
    // ближче до неї це просто затухання за відстанню від центру uv.
    float starDim = smoothstep(0.05, 0.65, length(uv));
    vec3 col = starfield(rd) * starDim;

    // Тонкий диск -- пряме перетинання площини y=0 (без лінзування, пульсар
    // не такий екстремальний, як чорна діра).
    float diskInner = 0.55;
    float diskOuter = 2.3;
    // diskBlocksAt -- t уздовж променя, де він проходить крізь непрозорий
    // (в межах diskInner..diskOuter) диск; промінь-маяк нижче має
    // зупинятись тут, а не "просвічувати" крізь диск, як було.
    bool diskBlocks = false;
    float diskBlocksAt = 1.0e9;
    if (abs(rd.y) > 0.0001) {
        float tPlane = -ro.y / rd.y;
        if (tPlane > 0.0) {
            vec3 hit = ro + tPlane * rd;
            float rr = length(hit.xz);
            if (rr > diskInner && rr < diskOuter) {
                float angle = atan(hit.z, hit.x);
                vec3 diskCol = diskColorAt(rr, angle, diskInner, diskOuter, camAngle);
                float edgeFade = smoothstep(diskOuter, diskOuter * 0.9, rr)
                    * smoothstep(diskInner, diskInner * 1.15, rr);
                col = mix(col, diskCol, edgeFade);
                diskBlocks = true;
                diskBlocksAt = tPlane;
            }
        }
    }

    // Магнітна вісь нахилена відносно осі обертання (спіну) -- класична
    // pulsar-геометрія, саме через цей нахил промінь "маяка" описує конус і
    // періодично зачіпає спостерігача, а не світить рівномірно.
    vec3 spinAxis = vec3(0.0, 1.0, 0.0);
    vec3 tiltedAxis = normalize(vec3(sin(0.6), cos(0.6), 0.0));
    vec3 beamAxis = rotateAxis(tiltedAxis, spinAxis, time * 1.1);

    // Об'ємний raymarch тільки для променів-маяків -- той самий прийом
    // дизерингу кроку (rand зі stepSize), що й у nebula-dust.frag, інакше
    // грубий крок дає видиму "смугастість" на вузькому конусі.
    vec2 seed = gl_FragCoord.xy / resolution.xy + fract(time);
    float tt = 0.2;
    vec3 beamCol = vec3(0.0);
    for (int i = 0; i < 40; i++) {
        if (diskBlocks && tt > diskBlocksAt) {
            break;
        }
        vec3 pos = ro + rd * tt;
        float dCenter = length(pos);
        if (dCenter > 22.0) {
            break;
        }
        vec3 dirFromStar = pos / max(dCenter, 0.0001);
        float coneCos = dot(dirFromStar, beamAxis);
        // Вужчий конус (0.978 замість 0.93) -- вузький, чіткий струмінь
        // замість широкого туману прожектора, але трохи ширший за перший
        // варіант (0.985) -- щільніший, не такий прозорий/розсіяний.
        float lobe = smoothstep(0.978, 1.0, coneCos) + smoothstep(0.978, 1.0, -coneCos);
        // Швидше згасання -- промінь читається як компактний струмінь
        // біля зорі, а не нескінченний прожекторний конус, що світить
        // однаково далеко.
        float falloff = 1.0 / (1.0 + dCenter * dCenter * 0.35);
        // Волокниста текстура вздовж променя (магнітні силові лінії) --
        // два шари шуму різного масштабу замість одного, для більш
        // турбулентного, менш рівномірного вигляду плазми (за ідеєю Gemini).
        float streak = 0.6 + 0.4 * noise3(dirFromStar * 6.0 + vec3(0.0, 0.0, dCenter * 0.8 - time * 1.5));
        streak *= 0.75 + 0.25 * noise3(dirFromStar * 17.0 + vec3(0.0, 0.0, dCenter * 2.3 - time * 3.0));
        // Ударні хвилі -- яскраві "вузли", що біжать вздовж струменя назовні
        // від зорі з часом, як згустки плазми, а не рівномірне світіння.
        float shock = 0.7 + 0.3 * sin(dCenter * 2.2 - time * 3.2);
        vec3 beamTint = mix(vec3(1.0, 1.0, 1.0), vec3(0.4, 0.65, 1.0), clamp(dCenter * 0.15, 0.0, 1.0));
        float stepSize = mix(0.3, 0.45, hash(vec3(seed * float(i + 1), tt)));
        beamCol += beamTint * lobe * falloff * streak * shock * stepSize * 3.4;
        tt += stepSize;
    }
    col += beamCol;

    // Аналітичне яскраве ядро самої нейтронної зорі (найближча точка
    // променя до початку координат) -- без окремого raymarch, той самий
    // прийом point-line distance, що й для "глибини" в дірі.
    float tClosest = max(-dot(ro, rd), 0.0);
    float distCore = length(ro + tClosest * rd);
    float core = exp(-pow(distCore / 0.22, 2.0));
    col += core * vec3(0.85, 0.92, 1.0) * 6.0;

    // Пульсар в'явно пульсує -- звідси й назва: раз на пів-оберту промінь
    // проходить повз камеру. Світимо тільки по краях кадру (центр -- де
    // зазвичай вікна/іконки на робочому столі -- лишаємо чистим): маска
    // росте від 0 у центрі до 1 ближче до країв.
    float flash = pow(max(dot(normalize(-ro), beamAxis), 0.0), 5.0)
        + pow(max(-dot(normalize(-ro), beamAxis), 0.0), 5.0);
    float edgeMask = smoothstep(0.25, 0.95, length(uv));
    flash *= edgeMask;
    col *= 1.0 + flash * 0.9;
    col += flash * vec3(0.6, 0.8, 1.0) * 0.8;

    col *= 1.0 - 0.15 * dot(uv, uv);

    gl_FragColor = vec4(col, 1.0);
}
