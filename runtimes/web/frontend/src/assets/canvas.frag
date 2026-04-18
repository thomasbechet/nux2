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
    uint _pad0[3];
    vec4 color;
    uint _pad1[3];
};

uniform usampler2D batchesTexture;

uniform sampler2D texture0;
uniform uint batchIndex;

in vec2 inUV;
out vec4 outColor;

Batch fetchBatch(uint i)
{
    const uint textureWidth = 16384u;
    uint pixelIndex = i * 4u; // 4 pixels per batch
    uint x = pixelIndex % textureWidth;
    uint y = pixelIndex / textureWidth;

    uvec4 p0 = texelFetch(batchesTexture, ivec2(x + 0u, y), 0).rgba;
    uvec4 p1 = texelFetch(batchesTexture, ivec2(x + 1u, y), 0).rgba;
    uvec4 p2 = texelFetch(batchesTexture, ivec2(x + 2u, y), 0).rgba;
    uvec4 p3 = texelFetch(batchesTexture, ivec2(x + 3u, y), 0).rgba;

    Batch b;
    b.mode         = p0.r;
    b.first        = p0.g;
    b.count        = p0.b;
    b.textureWidth = p0.a;
    b.textureWidth = p1.r;
    b.color        = uintBitsToFloat(p2.rgba);
    return b;
}

void main()
{
    Batch batch = fetchBatch(batchIndex);

    if (batch.mode == 1u)
    {
        outColor = texture(texture0, inUV) * batch.color;
    }
    else
    {
        outColor = batch.color;
    }
}