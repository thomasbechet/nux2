local mymodule = require("mymodule")

File.logGlob("*")
Graphics.loadGltf(Node.getRoot(), "industrial.glb")
Node.dump("Scene")

function M:onInit()
    print("hello")
end

function M:onDeinit()
    print("deinit")
end

function M:onUpdate()
end
