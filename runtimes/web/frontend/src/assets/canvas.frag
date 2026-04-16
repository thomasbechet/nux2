#version 300 es
precision highp float;

in vec2 inUV;
out vec4 outColor;

uniform sampler2D texture0;

uniform uint uMode;
uniform vec4 uColor;

void main()
{
    if (uMode == 1u)
    {
        outColor = texture(texture0, inUV) * uColor;
    }
    else
    {
        outColor = uColor;
    }
}