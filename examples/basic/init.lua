local mymodule = require("mymodule")

function createText(parent, text)
    local node = Node.create(parent)
    Component.add(node, Widget)
    Component.add(node, Label)
    Label.setText(node, text)
    Widget.setPadding(node, Math.vec4(10, 10, 0, 0))
end

function M:onInit()
    -- Gltf.loadGltf(Node.getRoot(), "industrial.glb")
    -- local c = Collection.exportNode(Node.getRoot(), Node.getRoot())
    -- Collection.instantiate(c, Node.getRoot())
    -- Node.dump(Node.getRoot())

    -- local gui = GUI.add(Node.getRoot())
    -- local widget = Widget.add(gui)

    local ui = Node.createNamed("/", "ui")
    Component.add(ui, Viewport)
    Component.add(ui, Widget)
    Widget.setSizeX(ui, Widget.SIZING_GROW, 0, 0)
    Widget.setSizeY(ui, Widget.SIZING_GROW, 0, 0)
    Widget.setBackgroundColor(ui, Math.vec4(0, 0, 0, 1))
    Widget.setPadding(ui, Math.vec4(10))
    Viewport.setWidget(ui, ui)

    local panel = Node.createNamed(ui, "panel")
    Component.add(panel, Widget)
    Widget.setBackgroundColor(panel, Math.vec4(0.1, 0.1, 0.1, 1))
    Widget.setBorder(panel, Math.vec4(2))
    Widget.setBorderColor(panel, Math.vec4(1, 1, 1, 1))

    -- local label = Node.createNamed(panel, "label")
    -- Component.add(label, Widget)
    -- Component.add(label, Label)
    -- Widget.setAlignX(label, Widget.ALIGNMENT_X_CENTER)
    -- Widget.setAlignY(label, Widget.ALIGNMENT_Y_CENTER)
    -- Label.setText(label, "Hello World !")
    -- Label.setColor(label, Math.vec4(1, 0.5, 0, 1))
    -- self.label = label

    -- local version = Node.createNamed(panel, "version")
    -- Component.add(version, Widget)
    -- Component.add(version, Label)
    -- Widget.setAlignX(version, Widget.ALIGNMENT_X_RIGHT)
    -- Widget.setAlignY(version, Widget.ALIGNMENT_Y_BOTTOM)

    -- Widget.setPadding(version, Math.vec4(0, 10, 0, 10))
    -- Widget.setSizeX(version, Widget.SIZING_FIT, 0, 0)
    -- Widget.setSizeY(version, Widget.SIZING_FIT, 0, 0)
    -- Label.setText(version, "1.0.0-dev")

    -- local df = Node.create(Node.getRoot())
    -- DataTable.put("alive", Primitive.BOOL, false)
    -- DataTable.put("speed", Primitive.VEC3, Math.vec3(0, 1, 1))
    -- DataTable.put("version", Primitive.STRING, "Hello World")

    -- print(Transform.id)
    -- print(Widget.id)

    local module_count = Module.count()
    for m=1,module_count do
        local module_name = Module.getName(m-1)
        createText(panel, module_name)
        local function_count = Function.count(m-1)
        for f=1,function_count do
            local ret = Function.getReturnType(m-1,f-1)
            print(module_name.."."..Function.getName(m-1, f-1).."("..ret..")")
        end
    end
end

function M:onDeinit()
end

function M:onUpdate()
    -- Texture.blit("Textures/Building_1", Math.vec2(0, 0))
    -- Texture.blit("Textures/Building_2", Math.vec2(256, 0))
    -- Texture.blit("Textures/Building_3", Math.vec2(512, 0))
end
