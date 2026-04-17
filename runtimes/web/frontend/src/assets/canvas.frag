#version 300 es

precision highp float;
precision highp int;
precision highp usampler2D;

struct Batch
{
    uint mode;
    uint first;
    uint count;
    uint textureWidth;
    uint textureHeight;
    vec4 color;
};

uniform usampler2D BatchBlockTex;

uniform sampler2D texture0;
uniform uint batchIndex;

in vec2 inUV;
out vec4 outColor;

// helper: load batch
Batch loadBatch(uint i)
{
    uint base = i * 6u;

    Batch b;

    b.mode          = texelFetch(BatchBlockTex, ivec2(0, int(base + 0u)), 0).r;
    b.first         = texelFetch(BatchBlockTex, ivec2(0, int(base + 1u)), 0).r;
    b.count         = texelFetch(BatchBlockTex, ivec2(0, int(base + 2u)), 0).r;
    b.textureWidth  = texelFetch(BatchBlockTex, ivec2(0, int(base + 3u)), 0).r;
    b.textureHeight = texelFetch(BatchBlockTex, ivec2(0, int(base + 4u)), 0).r;

    b.color = vec4(
        texelFetch(BatchBlockTex, ivec2(0, int(base + 5u)), 0)
    );

    return b;
}

void main()
{
    Batch batch = loadBatch(batchIndex);

    if (batch.mode == 1u)
    {
        outColor = texture(texture0, inUV) * batch.color;
    }
    else
    {
        outColor = batch.color;
    }
}