#!/bin/sh
# port-qt.sh <in.frag> <out.frag>: шейдер шпалери (GLSL ES 1.00) -> GLSL 440 для Qt 6 у ETEA.
# time, ракурс і роздільність стають живими uniform, тому перезапуск для них не потрібен.
# scene -- номер сцени для шейдерів на кожен стіл (landscape.frag), решта його не читає.
{
cat <<'H'
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 etea_fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float camOffset;
    vec2 resolution;
    float scene;
};
#define gl_FragColor etea_fragColor
#define gl_FragCoord vec4(qt_TexCoord0.x * resolution.x, (1.0 - qt_TexCoord0.y) * resolution.y, 0.0, 1.0)
#define tanh nebula_tanh
H
sed -E '/^#version/d; /^precision /d; /^uniform (float time|vec2 resolution|float scene);/d; s/^#define CAM_OFFSET .*/#define CAM_OFFSET camOffset/; s/\bhighp //g; s/^void main\(\)/void nebula_main()/' "$1"
# Qt не застосовує opacity до власних шейдерів сам: без цього фон не тьмяніє й не проступає
printf '\nvoid main() {\n    nebula_main();\n    etea_fragColor *= qt_Opacity;\n}\n'
} > "$2"
