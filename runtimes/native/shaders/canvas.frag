#version 450

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

layout(binding = 2, std430) readonly buffer BatchBlock
{
    Batch batches[];
};

layout(location = 0) in vec2 inUV;
layout(location = 0) out vec4 outColor;

uniform sampler2D texture0;
uniform uint batchIndex;

void main()
{
    if (batches[batchIndex].mode == 1)
    {
        outColor = texture(texture0, inUV) * batches[batchIndex].color;
    }
    else
    {
        outColor = batches[batchIndex].color;
    }
}
