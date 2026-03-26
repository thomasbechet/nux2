local mymodule = require("mymodule")

local function createButton(parent, name)
    local button = Node.createNamed(parent, name)
    Component.add(button, Widget)
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
    Component.add(ui, Viewport)
    Component.add(ui, Widget)
    Viewport.setUI(ui, ui)
    local button = createButton(ui, "confirm")
    Widget.setBackgroundColor(button, Math.vec4(1, 0, 0, 1))
    local button = createButton(ui, "cancel")
    Widget.setBackgroundColor(button, Math.vec4(0, 1, 0, 1))
    local button = createButton(button, "cancel")
    Widget.setBackgroundColor(button, Math.vec4(0, 0, 1, 1))
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
