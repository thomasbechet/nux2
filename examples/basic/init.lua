local mymodule = require("mymodule")

local function createButton(parent, name)
    local button = Node.createNamed(parent, name)
    Component.add(button, UIElement)
    Component.add(button, Button)
    return button
end

function M:onInit()
    -- File.logGlob("*")
    -- Gltf.loadGltf(Node.getRoot(), "industrial.glb")
    -- local c = Collection.exportNode(Node.getRoot(), Node.getRoot())
    -- Collection.instantiate(c, Node.getRoot())
    -- Node.dump(Node.getRoot())

    -- local gui = GUI.add(Node.getRoot())
    -- local widget = Widget.add(gui)

    local ui = Node.createNamed("/", "ui")
    local button = createButton(ui, "confirm")
    local button = createButton(ui, "cancel")
    Node.dump(ui)

    -- print(Transform.id)
    -- print(Widget.id)
end

function M:onDeinit()
end

function M:onUpdate()
    -- Texture.blit("Textures/Building_1", Math.vec2(0, 0))
    -- Texture.blit("Textures/Building_2", Math.vec2(256, 0))
    -- Texture.blit("Textures/Building_3", Math.vec2(512, 0))
end
