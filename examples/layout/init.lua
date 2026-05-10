local function createWidget(parent, type)
    local widget = Node.create(parent)
    Component.add(widget, Widget)
    Component.add(widget, type)
    return widget
end

function M:onInit()
    -- Create stylesheet
    local ui_atlas = Node.createNamed("/", "ui_atlas")
    Texture.addFromFile(ui_atlas, "GUI.png")
    self.stylesheet = Node.createNamed("/", "stylesheet")
    Component.add(self.stylesheet, StyleSheet)
    StyleSheet.setImage(self.stylesheet,
        StyleSheet.PROPERTY_BUTTON_PRESSED,
        "/fonts/default", Math.vec4(0), Math.vec4(0)
    )
    --     stylesheet.set(style, stylesheet.BUTTON_PRESSED, gui_tex,
    --     { 113, 97, 30, 14 },
    --     { 115, 100, 26, 8 })
    -- stylesheet.set(style, stylesheet.BUTTON_RELEASED, gui_tex,
    --     { 113, 81, 30, 14 },
    --     { 115, 83, 26, 8 })
    -- stylesheet.set(style, stylesheet.BUTTON_HOVERED, gui_tex,
    --     { 113, 113, 30, 14 },
    --     { 115, 115, 26, 8 })
    -- stylesheet.set(style, stylesheet.CHECKBOX_CHECKED, gui_tex,
    --     { 97, 257, 14, 14 },
    --     { 99, 260, 10, 8 })
    -- stylesheet.set(style, stylesheet.CHECKBOX_UNCHECKED, gui_tex,
    --     { 81, 257, 14, 14 },
    --     { 99, 261, 10, 8 })
    -- stylesheet.set(style, stylesheet.CURSOR, gui_tex,
    --     { 52, 83, 8, 7 },
    --     { 52, 83, 8, 7 })


    -- Create UI
    self.ui = Node.createPath(Node.getRoot(), "ui")
    Component.add(self.ui, Viewport)
    Component.add(self.ui, Widget)
    Widget.setBackgroundColor(self.ui, Math.vec4(0.5, 0, 0, 1))
    Widget.setChildGap(self.ui, 20)
    Widget.setAlignX(self.ui, Widget.ALIGNMENT_CENTER)
    Widget.setAlignY(self.ui, Widget.ALIGNMENT_CENTER)
    Widget.setSizeX(self.ui, Widget.SIZING_GROW, 0)
    Widget.setSizeY(self.ui, Widget.SIZING_GROW, 0)
    Viewport.setWidget(self.ui, self.ui)

    -- Label
    self.label = createWidget(self.ui, Label)
    Label.setScale(self.label, 5)
    Widget.setBackgroundColor(self.label, Math.vec4(0, 0, 0, 1))
    self.time = 0

    Node.dump(Node.getRoot())

    local modulecount = Module.count()
    for m = 0, modulecount - 1 do
        print(Module.getName(m))
        local functioncount = Function.count(m)
        for f = 0, functioncount - 1 do
            print(" function " .. Function.getName(m, f))
            local paramcount = Function.getParamCount(m, f)
            for p = 0, paramcount - 1 do
                local paramname = Function.getParamName(m, f, p)
                local paramtype = Function.getParamType(m, f, p)
                print("  param " .. paramname .. " " .. paramtype)
            end
        end
        local enumcount = Enum.count(m)
        for e = 0, enumcount - 1 do
            print(" enum " .. Enum.getName(m, e))
            local valuecount = Enum.getValueCount(m, e)
            for v = 0, valuecount - 1 do
                print("  value " .. Enum.getValueName(m, e, v))
            end
        end
    end
end

function M:onUpdate()
    self.time = self.time + 1
    Label.setText(self.label, self.time)
end
