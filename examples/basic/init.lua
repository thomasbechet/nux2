local mymodule = require("mymodule")

function M:onInit()
    File.logGlob("*")
    Graphics.loadGltf(Node.getRoot(), "industrial.glb")
    Node.dump(Node.getRoot())

    local tex = Node.newNamed(Node.root(), "MyTexture")
    Texture.loadFromFile(tex, "mytexture.png")

    local t = Node.create()
    Transform.add(t)
    StaticMesh.add(t)
    Node.delete(t)
end

function M:onDeinit()
end

function M:onUpdate()
    Texture.blit("Textures/Building_1", Math.vec2(0, 0))
    Texture.blit("Textures/Building_2", Math.vec2(256, 0))
    Texture.blit("Textures/Building_3", Math.vec2(512, 0))
end
