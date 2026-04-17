#version 300 es

precision highp float;
precision highp int;
precision highp usampler2D;
precision highp sampler2D;

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

layout(std140) uniform ConstantBlock
{
    Constants constants;
};

uniform usampler2D QuadBlockTex;
uniform usampler2D BatchBlockTex;

uniform uint batchIndex;

out vec2 inUV;

void main()
{
    const vec2 offsets[6] = vec2[](
        vec2(0.0, 0.0),
        vec2(0.0, 1.0),
        vec2(1.0, 1.0),
        vec2(1.0, 1.0),
        vec2(1.0, 0.0),
        vec2(0.0, 0.0)
    );

    // ======================================================
    // Load Batch (SSBO emulated via texture fetch)
    // ======================================================
    uint batchBase = batchIndex * 6u;

    Batch batch;
    batch.mode          = texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 0u)), 0).r;
    batch.first         = texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 1u)), 0).r;
    batch.count         = texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 2u)), 0).r;
    batch.textureWidth  = texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 3u)), 0).r;
    batch.textureHeight = texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 4u)), 0).r;
    batch.color         = vec4(
        texelFetch(BatchBlockTex, ivec2(0, int(batchBase + 5u)), 0)
    );

    // ======================================================
    // Quad index
    // ======================================================
    uint quadIndex = batch.first + uint(gl_VertexID / 6);

    uint base = quadIndex * 4u;

    uint pos   = texelFetch(QuadBlockTex, ivec2(0, int(base + 0u)), 0).r;
    uint tex   = texelFetch(QuadBlockTex, ivec2(0, int(base + 1u)), 0).r;
    uint size  = texelFetch(QuadBlockTex, ivec2(0, int(base + 2u)), 0).r;
    uint scale = texelFetch(QuadBlockTex, ivec2(0, int(base + 3u)), 0).r;

    // ======================================================
    // Decode packed values
    // ======================================================
    vec2 vertex_pos  = vec2(float(pos & 0xffffu),  float(pos >> 16u));
    vec2 vertex_tex  = vec2(float(tex & 0xffffu),  float(tex >> 16u));
    vec2 vertex_size = vec2(float(size & 0xffffu), float(size >> 16u));

    vec2 vertex_offset = offsets[gl_VertexID % 6];

    vec2 position =
        (vertex_pos + vertex_size * float(scale) * vertex_offset)
        / vec2(constants.screenSize);

    position.y = 1.0 - position.y;

    vec2 uv =
        floor(vertex_tex + vertex_size * vertex_offset)
        / vec2(batch.textureWidth, batch.textureHeight);

    gl_Position = vec4(position * 2.0 - 1.0, 0.0, 1.0);
    inUV = uv;
}