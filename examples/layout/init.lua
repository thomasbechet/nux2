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
    Widget.setPadding(self.panel, Math.vec4(10))
    Widget.setChildGap(self.panel, 5)

    -- Create panel
    for i=0,10 do
        local n = Node.createNamed(self.panel, "item"..i)
        Component.add(n, Widget)
        Component.add(n, Label)
        Label.setText(n, "hello")
        Widget.setBackgroundColor(n, Math.vec4(0, 0, 1, 1))
        Widget.setWidth(n, Widget.SIZING_FIXED, 100)
        if i % 2 == 0 then
            Widget.setWidth(n, Widget.SIZING_FIXED, 100)
        else
            Widget.setWidth(n, Widget.SIZING_GROW, 100)
        end
        if i == 10 then
            Widget.setHeight(n, Widget.SIZING_GROW, 0)
        else
            Widget.setHeight(n, Widget.SIZING_FIT, 32)
        end
    end
end

function M:onUpdate()
end
