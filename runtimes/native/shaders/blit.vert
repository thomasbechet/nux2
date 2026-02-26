#version 450

layout(location = 0) out vec2 outUV;

void main()
{
    float x = float((gl_VertexID & 1) << 2);
    float y = float((gl_VertexID & 2) << 1);
    gl_Position = vec4(x - 1, y - 1, 0, 1);
    outUV = vec2(x, y) * 0.5;
}
