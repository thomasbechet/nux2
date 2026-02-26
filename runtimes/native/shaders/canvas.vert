#version 450

struct Constants
{
    mat4 view;
    mat4 proj;
    uvec2 screenSize;
    float time;
};

struct Batch
{
    uint mode;
    uint first;
    uint count;
    uint textureWidth;
    uint textureHeight;
    vec4 color;
};

layout(binding = 2, std430) readonly buffer BatchBlock
{
    Batch batches[];
};

layout(binding = 0, std140) uniform ConstantBlock
{
    Constants constants;
};
layout(binding = 1, std430) readonly buffer QuadBlock
{
    uint quads[];
};

layout(location = 0) out vec2 outUV;

uniform uint batchIndex;

void main()
{
    const vec2 offsets[6] = vec2[](
            vec2(0, 0),
            vec2(0, 1),
            vec2(1, 1),
            vec2(1, 1),
            vec2(1, 0),
            vec2(0, 0)
        );

    // Extract quad data
    Batch batch = batches[batchIndex];
    uint index = batch.first + gl_VertexID / 6;
    uint pos = quads[index * 3 + 0];
    uint tex = quads[index * 3 + 1];
    uint size = quads[index * 3 + 2];

    // Decode quad data
    vec2 vertex_pos = vec2(float(pos & 0xffffu), float(pos >> 16u));
    vec2 vertex_tex = vec2(float(tex & 0xffffu), float(tex >> 16u));
    vec2 vertex_size = vec2(float(size & 0xffffu), float(size >> 16u));

    // Compute vertex offset based on the vertex index
    vec2 vertex_offset = offsets[gl_VertexID % 6];

    // Apply offset and normalize
    vec2 position = (vertex_pos + vertex_size * vertex_offset) / constants.screenSize;
    position.y = 1 - position.y;
    vec2 uv = floor(vertex_tex + vertex_size * vertex_offset) / vec2(batch.textureWidth, batch.textureHeight);

    // Store output
    // output.position = float4(position * 2 - 1, depth, 1);
    gl_Position = vec4(position * 2 - 1, 0, 1);
    outUV = uv;
}
