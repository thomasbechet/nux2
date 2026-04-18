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
    uint _pad0;
};

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

struct Quad
{
    uint pos;
    uint tex;
    uint size;
    uint scale;
};

layout(std140) uniform ConstantBlock
{
    Constants constants;
};

uniform usampler2D quadsTexture;
uniform usampler2D batchesTexture;

uniform uint batchIndex;

out vec2 inUV;

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

Quad fetchQuad(uint i)
{
    const uint textureWidth = 16384u;
    uint x = i % textureWidth;
    uint y = i / textureWidth;

    uvec4 p0 = texelFetch(quadsTexture, ivec2(x, y), 0).rgba;

    Quad q;
    q.pos   = p0.r;
    q.tex   = p0.g;
    q.size  = p0.b;
    q.scale = p0.a;
    return q;

}

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

    // Fetch texture data
    Batch batch = fetchBatch(batchIndex);
    uint quadIndex = batch.first + uint(gl_VertexID / 6);
    Quad quad  = fetchQuad(quadIndex);

    // Decode quad
    vec2 vertex_pos  = vec2(float(quad.pos & 0xffffu),  float(quad.pos >> 16u));
    vec2 vertex_tex  = vec2(float(quad.tex & 0xffffu),  float(quad.tex >> 16u));
    vec2 vertex_size = vec2(float(quad.size & 0xffffu), float(quad.size >> 16u));

    // Compute vertex offset based on the vertex index
    vec2 vertex_offset = offsets[gl_VertexID % 6];

    // Apply offset and normalize
    vec2 position = (vertex_pos + vertex_size * vertex_offset * float(quad.scale)) / vec2(constants.screenSize);
    position.y = 1.f - position.y;
    vec2 uv = floor(vertex_tex + vertex_size * vertex_offset) / vec2(batch.textureWidth, batch.textureHeight);

    // Store result
    gl_Position = vec4(position * 2.0 - 1.0, 0.0, 1.0);
    inUV = uv;
}