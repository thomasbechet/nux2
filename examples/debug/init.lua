function M:onInit()
    -- Create UI
    self.ui = Node.createPath(Node.getRoot(), "ui")
    Component.add(self.ui, Viewport)
    Component.add(self.ui, Widget)
    Widget.setWidth(self.ui, Widget.SIZING_GROW, 0)
    Widget.setHeight(self.ui, Widget.SIZING_GROW, 0)
    Widget.setBackgroundColor(self.ui, Math.vec4(0, 0, 0, 1))
    Widget.setPadding(self.ui, Math.vec4(2))
    Viewport.setWidget(self.ui, self.ui)

    -- Create InputMap
    self.map = Node.createPath(Node.getRoot(), "map")
    Component.add(self.map, InputMap)
    Input.setMap(0, self.map)
    InputMap.bindButton(self.map, "up", Input.GAMEPAD_LSTICK_UP)

    -- Create Label
    self.label = Node.createNamed(self.ui, "label")
    Component.add(self.label, Widget)
    Component.add(self.label, Label)
    Widget.setPadding(self.label, Math.vec4(0, 0, 0, 0))

    self.label2 = Node.createNamed(self.ui, "label2")
    Component.add(self.label2, Widget)
    Component.add(self.label2, Label)
    Label.setText(self.label2, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    -- Label.setText(self.label2, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    Widget.setPadding(self.label2, Math.vec4(0, 0, 0, 0))

    self.label3 = Node.createNamed(self.ui, "label3")
    Component.add(self.label3, Widget)
    Component.add(self.label3, Label)
    Label.setText(self.label3, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    -- Label.setText(self.label3, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    Widget.setPadding(self.label3, Math.vec4(0, 0, 0, 0))

    -- self.label4 = Node.createNamed(self.ui, "label4")
    -- Component.add(self.label4, Widget)
    -- Component.add(self.label4, Label)
    -- Label.setText(self.label4, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    -- Label.setText(self.label4, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    -- Widget.setPadding(self.label4, Math.vec4(0, 0, 0, 0))

    Node.dump(Node.getRoot())
end

function M:onUpdate()
    local value = Input.getValue(0, "up")
    Label.setText(self.label, value)
    -- Label.setText(self.label2, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    -- Label.setText(self.label3, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB")
end
