#version 300 es

struct Batch
{
    uint mode;
    uint first;
    uint count;
    uint textureWidth;
    uint textureHeight;
    vec4 color;
};

buffer BatchBlock
{
    Batch batches[];
};

in vec2 inUV;
out vec4 outColor;

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
