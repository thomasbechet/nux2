-- Cart.begin("mycart.bin")
-- Cart.writeGlob("*")
-- File.mount("mycart.bin")
-- File.logGlob("*")
Graphics.loadGltf(Node.getRoot(), "industrial.glb")
Node.dump("Scene")

function M:onInit()
    Signal.connect(m, self.onNewGame)
end

function M:onNewGame()
end
