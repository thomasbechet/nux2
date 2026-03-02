local mymodule = require("mymodule")

File.logGlob("*")
Graphics.loadGltf(Node.getRoot(), "industrial.glb")
Node.dump(Node.getRoot())

function M:onInit()
    print("hello")
end

function M:onDeinit()
    print("deinit")
end

function M:onUpdate()
    Texture.blit("Textures/Building_1")
end
