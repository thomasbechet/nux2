function M:entry(name, input)
    local label_node = "/ui/" .. name

    -- Create label
    if (not Node.exists(label_node)) then
        local node = Node.createNamed(self.ui, name)
        Component.add(node, Widget)
        Component.add(node, Label)
        Widget.setPadding(node, Math.vec4(2, 2, 0, 0))
    end

    -- Create binding
    InputMap.bindButton(self.map, name, input)

    local label = Node.findGlobal(label_node)
    local value = Input.getValue(0, name)
    -- Label.setText(label, name..": "..string.format("%.30f", value))
    Label.setText(label, name..": "..value)
end

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

    -- Create inputmap
    self.map = Node.createPath(Node.getRoot(), "map")
    Component.add(self.map, InputMap)
    Input.setMap(0, self.map)
end

function M:onUpdate()
    self:entry("X", Input.GAMEPAD_X)
    self:entry("Y", Input.GAMEPAD_Y)
    self:entry("B", Input.GAMEPAD_B)
    self:entry("A", Input.GAMEPAD_A)

    self:entry("up", Input.GAMEPAD_DPAD_UP)
    self:entry("down", Input.GAMEPAD_DPAD_DOWN)
    self:entry("left", Input.GAMEPAD_DPAD_LEFT)
    self:entry("right", Input.GAMEPAD_DPAD_RIGHT)

    self:entry("lstick_up", Input.GAMEPAD_LSTICK_UP)
    self:entry("lstick_down", Input.GAMEPAD_LSTICK_DOWN)
    self:entry("lstick_right", Input.GAMEPAD_LSTICK_RIGHT)
    self:entry("lstick_left", Input.GAMEPAD_LSTICK_LEFT)

    self:entry("rstick_up", Input.GAMEPAD_RSTICK_UP)
    self:entry("rstick_down", Input.GAMEPAD_RSTICK_DOWN)
    self:entry("rstick_right", Input.GAMEPAD_RSTICK_RIGHT)
    self:entry("rstick_left", Input.GAMEPAD_RSTICK_LEFT)

    self:entry("ltrigger", Input.GAMEPAD_LTRIGGER)
    self:entry("rtrigger", Input.GAMEPAD_RTRIGGER)

    self:entry("start", Input.GAMEPAD_START)
    self:entry("end", Input.GAMEPAD_END)

    self:entry("shoulder_left", Input.GAMEPAD_SHOULDER_LEFT)
    self:entry("shoulder_right", Input.GAMEPAD_SHOULDER_RIGHT)
end
