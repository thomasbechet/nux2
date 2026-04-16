#version 300 es

precision highp float;
precision highp usampler2D;

uniform mat4 uView;
uniform mat4 uProj;
uniform vec2 uScreenSize;
uniform float uTime;

uniform uint uFirst;
uniform uint uTextureWidth;
uniform uint uTextureHeight;

uniform usampler2D uQuadTex;

out vec2 outUV;

const vec2 offsets[6] = vec2[](
    vec2(0.0, 0.0),
    vec2(0.0, 1.0),
    vec2(1.0, 1.0),
    vec2(1.0, 1.0),
    vec2(1.0, 0.0),
    vec2(0.0, 0.0)
);

uvec4 loadQuad(uint index, int component) {
    // 4 pixels per quad
    uint texelIndex = index * 4u + uint(component);

    ivec2 size = textureSize(uQuadTex, 0);
    uint x = texelIndex % uint(size.x);
    uint y = texelIndex / uint(size.x);

    return texelFetch(uQuadTex, ivec2(x, y), 0);
}

void main() {
    uint quadIndex = uFirst + uint(gl_VertexID / 6);

    uvec4 posData   = loadQuad(quadIndex, 0);
    uvec4 texData   = loadQuad(quadIndex, 1);
    uvec4 sizeData  = loadQuad(quadIndex, 2);
    uvec4 scaleData = loadQuad(quadIndex, 3);

    uint pos   = posData.r;
    uint tex   = texData.r;
    uint size  = sizeData.r;
    uint scale = scaleData.r;

    vec2 vertex_pos = vec2(float(pos & 0xffffu), float(pos >> 16u));
    vec2 vertex_tex = vec2(float(tex & 0xffffu), float(tex >> 16u));
    vec2 vertex_size = vec2(float(size & 0xffffu), float(size >> 16u));

    vec2 vertex_offset = offsets[gl_VertexID % 6];

    vec2 position = (vertex_pos + vertex_size * float(scale) * vertex_offset) / uScreenSize;
    position.y = 1.0 - position.y;

    vec2 uv = floor(vertex_tex + vertex_size * vertex_offset) /
              vec2(float(uTextureWidth), float(uTextureHeight));

    gl_Position = vec4(position * 2.0 - 1.0, 0.0, 1.0);
    outUV = uv;
}