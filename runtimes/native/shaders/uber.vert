#version 450

#define VERTEX_POSITION uint(1 << 0)
#define VERTEX_TEXCOORD uint(1 << 1)
#define VERTEX_COLOR    uint(1 << 2)

struct Constants
{
    mat4 view;
    mat4 proj;
    uvec2 screenSize;
    float time;
};

struct Batch
{
    uint vertexOffset;
    uint vertexAttributes;
    uint transformOffset;
    uint hasTexture;
    vec4 color;
};

struct Vertex
{
    vec3 position;
    vec2 texcoord;
    vec3 color;
};

struct VertexLayout
{
    uint stride;
    uint position;
    uint texcoord;
    uint color;
};

layout(binding = 2, std140) uniform ConstantBlock
{
    Constants constants;
};
layout(binding = 3, std430) readonly buffer BatchBlock
{
    Batch batches[];
};
layout(binding = 4, std430) readonly buffer VertexBlock
{
    float vertices[];
};
layout(binding = 5, std430) readonly buffer TransformBlock
{
    mat4 transforms[];
};

layout(location = 0) out vec3 outNormal;
layout(location = 1) out vec2 outUV;
layout(location = 2) out vec3 outColor;

uniform uint batchIndex;

VertexLayout vertexLayout(uint attributes)
{
    VertexLayout l;
    l.stride = 0;
    l.position = 0;
    l.texcoord = 0;
    l.color = 0;
    if ((attributes & VERTEX_POSITION) != 0)
    {
        l.position = l.stride;
        l.stride += 3;
    }
    if ((attributes & VERTEX_TEXCOORD) != 0)
    {
        l.texcoord = l.stride;
        l.stride += 2;
    }
    if ((attributes & VERTEX_COLOR) != 0)
    {
        l.color = l.stride;
        l.stride += 3;
    }
    return l;
}

Vertex pullVertex(uint vertexOffset, uint idx, VertexLayout l)
{
    uint offset = vertexOffset + idx * l.stride;
    Vertex vertex;
    vertex.position = vec3(
            vertices[offset + l.position + 0],
            vertices[offset + l.position + 1],
            vertices[offset + l.position + 2]
        );
    vertex.texcoord = vec2(
            vertices[offset + l.texcoord + 0],
            vertices[offset + l.texcoord + 1]
        );
    vertex.color = vec3(
            vertices[offset + l.color + 0],
            vertices[offset + l.color + 1],
            vertices[offset + l.color + 2]
        );
    return vertex;
}

void main()
{
    Batch batch = batches[batchIndex];

    // Extract vertices
    uint base = (gl_VertexID / 3) * 3;
    uint vertexOffset = batch.vertexOffset;
    VertexLayout l = vertexLayout(batch.vertexAttributes);
    Vertex v0 = pullVertex(vertexOffset, base + (gl_VertexID + 0) % 3, l);
    Vertex v1 = pullVertex(vertexOffset, base + (gl_VertexID + 1) % 3, l);
    Vertex v2 = pullVertex(vertexOffset, base + (gl_VertexID + 2) % 3, l);

    // Compute vertex position
    mat4 transform = transforms[batch.transformOffset];
    vec4 worldPos = transform * vec4(v0.position, 1);
    vec4 viewPos = constants.view * worldPos;
    gl_Position = constants.proj * viewPos;
    outUV = v0.texcoord;
    if ((batch.vertexAttributes & VERTEX_COLOR) != 0)
    {
        outColor = v0.color;
    }
    else
    {
        outColor = vec3(1);
    }
    // output.normal   = normalize(cross(
    //     v2.position - v1.position,
    //     v0.position - v1.position));
}
