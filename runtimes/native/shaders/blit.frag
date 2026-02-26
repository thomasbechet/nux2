#version 450

layout(location = 0) in vec2 inUV;
layout(location = 0) out vec4 outColor;

uniform sampler2D texture0;
uniform uint textureWidth;
uniform uint textureHeight;

vec4 sampleColor(vec2 uv)
{
    // uint idx = canvas.Sample(sampler0, uv).r;
    // return colormap.Sample(sampler1, vec2(float(idx) / 255.0, 0));
    return texture(texture0, uv);
}

// https://www.shadertoy.com/view/4s3fDB
vec4 bilinearFiltering(vec2 uv, vec2 res)
{
    vec2 st = uv * res - 0.5;

    vec2 iuv = floor(st);
    vec2 fuv = fract(st);

    vec4 a = sampleColor((iuv + vec2(0.5, 0.5)) / res);
    vec4 b = sampleColor((iuv + vec2(1.5, 0.5)) / res);
    vec4 c = sampleColor((iuv + vec2(0.5, 1.5)) / res);
    vec4 d = sampleColor((iuv + vec2(1.5, 1.5)) / res);

    return mix(mix(a, b, fuv.x), mix(c, d, fuv.x), fuv.y);
}

vec2 uvFiltering(vec2 uv, vec2 textureSize)
{
    vec2 pixel = uv * textureSize;
    vec2 seam = floor(pixel + 0.5);
    vec2 dudv = fwidth(pixel);
    pixel = seam + clamp((pixel - seam) / dudv, -0.5, 0.5);
    return pixel / textureSize;
}

void main()
{
    const vec2 textureSize = vec2(textureWidth, textureHeight);
    vec2 uv = inUV;
    uv = uvFiltering(uv, textureSize);
    outColor = bilinearFiltering(uv, textureSize);
}
