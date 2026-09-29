#version 100
precision highp float;

uniform vec2 resolution;
uniform float time;

// Підмінюється через sed скриптом nebula-space-wallpaper-rotate (SUPER+G,
// "наступний ракурс") -- glpaper не приймає live-uniform, тож ротація
// фіксованих 4 ракурсів реалізована перегенерацією файлу.
#define CAM_OFFSET 0.0

#define ROTATION
#define DITHERING
#define BACKGROUND

#define pi 3.14159265
#define R(p, a) p=cos(a)*p+sin(a)*vec2(p.y, -p.x)

float hash3(vec3 p){
    p = fract(p * vec3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

// Заміна iq-івської шумової текстури (iChannel0) -- glpaper не має
// текстурних входів. Той самий вид шуму (трилінійна інтерполяція
// випадкових значень у вузлах ґратки), тільки хеш-функція замість
// вибірки з готової текстури.
float noise( in vec3 x )
{
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash3(i + vec3(0.0,0.0,0.0));
    float n100 = hash3(i + vec3(1.0,0.0,0.0));
    float n010 = hash3(i + vec3(0.0,1.0,0.0));
    float n110 = hash3(i + vec3(1.0,1.0,0.0));
    float n001 = hash3(i + vec3(0.0,0.0,1.0));
    float n101 = hash3(i + vec3(1.0,0.0,1.0));
    float n011 = hash3(i + vec3(0.0,1.0,1.0));
    float n111 = hash3(i + vec3(1.0,1.0,1.0));
    float nx00 = mix(n000, n100, f.x);
    float nx10 = mix(n010, n110, f.x);
    float nx01 = mix(n001, n101, f.x);
    float nx11 = mix(n011, n111, f.x);
    float nxy0 = mix(nx00, nx10, f.y);
    float nxy1 = mix(nx01, nx11, f.y);
    return mix(nxy0, nxy1, f.z);
}

float rand(vec2 co)
{
    return fract(sin(dot(co*0.123,vec2(12.9898,78.233))) * 43758.5453);
}

//=====================================
// otaviogood's noise from https://www.shadertoy.com/view/ld2SzK
const float nudge = 0.739513;
const float normalizer = 0.804023;

float SpiralNoiseC(vec3 p)
{
    float n = 0.0;
    float iter = 1.0;
    for (int i = 0; i < 8; i++)
    {
        n += -abs(sin(p.y*iter) + cos(p.x*iter)) / iter;
        p.xy += vec2(p.y, -p.x) * nudge;
        p.xy *= normalizer;
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        iter *= 1.733733;
    }
    return n;
}

float SpiralNoise3D(vec3 p)
{
    float n = 0.0;
    float iter = 1.0;
    for (int i = 0; i < 5; i++)
    {
        n += (sin(p.y*iter) + cos(p.x*iter)) / iter;
        p.xz += vec2(p.z, -p.x) * nudge;
        p.xz *= normalizer;
        iter *= 1.33733;
    }
    return n;
}

float NebulaNoise(vec3 p)
{
    float final = p.y + 4.5;
    final -= SpiralNoiseC(p.xyz);
    final += SpiralNoiseC(p.zxy*0.5123+100.0)*4.0;
    final -= SpiralNoise3D(p);

    return final;
}

float map(vec3 p)
{
    #ifdef ROTATION
    // iMouse.x замінено на статичну фазу (0.0) -- обертання все одно
    // анімується через time*0.1, миші під шпалерою нема.
    R(p.xz, 0.0*0.008*pi + time*0.1 + CAM_OFFSET);
    #endif

    float NebNoise = abs(NebulaNoise(p/0.5)*0.5);

    return NebNoise+0.03;
}

vec3 computeColor( float density, float radius )
{
    vec3 result = mix( vec3(1.0,0.9,0.8), vec3(0.4,0.15,0.1), density );

    vec3 colCenter = 7.*vec3(0.8,1.0,1.0);
    vec3 colEdge = 1.5*vec3(0.48,0.53,0.5);
    result *= mix( colCenter, colEdge, min( (radius+.05)/.9, 1.15 ) );

    return result;
}

bool RaySphereIntersect(vec3 org, vec3 dir, out float near, out float far)
{
    float b = dot(dir, org);
    float c = dot(org, org) - 8.;
    float delta = b*b - c;
    if( delta < 0.0)
        return false;
    float deltasqrt = sqrt(delta);
    near = -b - deltasqrt;
    far = -b + deltasqrt;
    return far > 0.0;
}

void main()
{
    vec2 fragCoord = gl_FragCoord.xy;

    // iMouse/iChannel1-клавіатурний "key" (зум 1-2-3) відкинуто -- завжди
    // фіксована відстань камери, як у стані спокою оригіналу (key=0).
    vec3 rd = normalize(vec3((fragCoord.xy-0.5*resolution.xy)/resolution.y, 1.));
    vec3 ro = vec3(0., 0., -6.0);

    R(rd.yz, -pi*3.93);
    R(rd.xz, pi*3.2);
    R(ro.yz, -pi*3.93);
    R(ro.xz, pi*3.2);

    #ifdef DITHERING
    vec2 dpos = ( fragCoord.xy / resolution.xy );
    vec2 seed = dpos + fract(time);
    #endif

    float ld=0., td=0., w=0.;
    float d=1., t=0.;

    const float h = 0.1;

    vec4 sum = vec4(0.0);

    float min_dist=0.0, max_dist=0.0;

    if(RaySphereIntersect(ro, rd, min_dist, max_dist))
    {
        t = min_dist*step(t,min_dist);

        for (int i=0; i<56; i++)
        {
            vec3 pos = ro + t*rd;

            if(td>0.9 || d<0.1*t || t>10. || sum.a > 0.99 || t>max_dist) break;

            float d = map(pos);

            d = max(d,0.08);

            vec3 ldst = vec3(0.0)-pos;
            float lDist = max(length(ldst), 0.001);

            vec3 lightColor=vec3(1.0,0.5,0.25);
            sum.rgb+=(lightColor/(lDist*lDist)/30.);

            if (d<h)
            {
                ld = h - d;
                w = (1. - td) * ld;
                td += w + 1./200.;

                vec4 col = vec4( computeColor(td,lDist), td );

                col.a *= 0.185;
                col.rgb *= col.a;
                sum = sum + col*(1.0 - sum.a);
            }

            td += 1./70.;

            d = max(d, 0.04);

            #ifdef DITHERING
            d=abs(d)*(.8+0.2*rand(seed*vec2(i)));
            #endif

            t += max(d * 0.1 * max(min(length(ldst),length(ro)),1.0), 0.02);
        }

        sum *= 1. / exp( ld * 0.2 ) * 0.6;

        sum = clamp( sum, 0.0, 1.0 );

        sum.xyz = sum.xyz*sum.xyz*(3.0-2.0*sum.xyz);
    }

    #ifdef BACKGROUND
    if (td<.8)
    {
        vec3 stars = vec3(noise(rd*500.0)*0.5+0.5);
        vec3 starbg = vec3(0.0);
        starbg = mix(starbg, vec3(0.8,0.9,1.0), smoothstep(0.99, 1.0, stars)*clamp(dot(vec3(0.0),rd)+0.75,0.0,1.0));
        starbg = clamp(starbg, 0.0, 1.0);
        sum.xyz += starbg;
    }
    #endif

    gl_FragColor = vec4(sum.xyz,1.0);
}
