function M:onInit()
    -- Create UI
    self.ui = Node.createPath(Node.getRoot(), "ui")
    Component.add(self.ui, Viewport)
    Component.add(self.ui, Widget)
    Widget.setWidth(self.ui, Widget.SIZING_GROW, 0, 0)
    Widget.setHeight(self.ui, Widget.SIZING_GROW, 0, 0)
    Widget.setBackgroundColor(self.ui, Math.vec4(1, 0, 0, 1))
    Widget.setPadding(self.ui, Math.vec4(10))
    Viewport.setWidget(self.ui, self.ui)

    -- Create panel
    self.panel = Node.createNamed(self.ui, "panel")
    Component.add(self.panel, Widget)
    Widget.setBackgroundColor(self.panel, Math.vec4(1, 1, 0, 1))
end

function M:onUpdate()
end
