function M:onInit()
    -- Create UI
    self.ui = Node.createPath(Node.getRoot(), "ui")
    Component.add(self.ui, Viewport)
    Component.add(self.ui, Widget)
    Widget.setBackgroundColor(self.ui, Math.vec4(1, 0, 0, 1))
    Widget.setPadding(self.ui, Math.vec4(10))
    Viewport.setWidget(self.ui, self.ui)



    -- Create panel
    self.panel = Node.createNamed(self.ui, "panel")
    Component.add(self.panel, Widget)
    Widget.setBackgroundColor(self.panel, Math.vec4(1, 1, 0, 1))
    Widget.setPadding(self.panel, Math.vec4(10))
    Widget.setChildGap(self.panel, 5)

    -- Widget.setHeight(self.panel, Widget.SIZING_GROW, 0)

    -- Create panel
    -- for i=0,2 do
    --     local n = Node.createNamed(self.panel, "item"..i)
    --     Component.add(n, Widget)
    --     Component.add(n, Label)
    --     Label.setText(n, "hello")
    --     Widget.setBackgroundColor(n, Math.vec4(0, 0, 1, 1))
    -- end
end

function M:onUpdate()
end
