-- Cart.begin("mycart.bin")
-- Cart.writeGlob("*")
-- File.mount("mycart.bin")
File.logGlob("*")
Graphics.loadGltf(Node.getRoot(), "industrial.glb")
Node.dump(Node.getRoot())

function M:init()
    self.buttonClicked = Signal.new()
    Button.bindOnClick(self.button, self.buttonClicked)
    Signal.connect(self.buttonClicked, self.onMainMenuPressed)
end

function M:onMainMenuPressed()

end

function M:onUpdate()
    if self.health < 0 then
        Event.emit(self.onPlayerDied)
    end
end

function M:onPlayerLoaded()

end
