function M:onInit()
    -- Create stylesheet
    self.stylesheet = Node.createNamed("/", "stylesheet")
    Component.add(self.stylesheet, StyleSheet)
    StyleSheet.setImage(self.stylesheet,
        StyleSheet.PROPERTY_BUTTON_PRESSED,
        "/fonts/default", Math.vec4(0), Math.vec4(0)
    )

    -- Create UI
    self.ui = Node.createPath(Node.getRoot(), "ui")
    Component.add(self.ui, Viewport)
    Component.add(self.ui, Widget)
    Widget.setBackgroundColor(self.ui, Math.vec4(0.5, 0, 0, 1))
    Widget.setPadding(self.ui, Math.vec4(50))
    Widget.setChildGap(self.ui, 20)
    Widget.setBorder(self.ui, Math.vec4(10))
    Widget.setAlignX(self.ui, Widget.ALIGNMENT_CENTER)
    Widget.setAlignY(self.ui, Widget.ALIGNMENT_CENTER)
    Widget.setSizeX(self.ui, Widget.SIZING_GROW, 0)
    Widget.setSizeY(self.ui, Widget.SIZING_GROW, 0)
    Viewport.setWidget(self.ui, self.ui)

    -- -- Create panel
    -- self.panel = Node.createNamed(self.ui, "panel")
    -- Component.add(self.panel, Widget)
    -- Widget.setBackgroundColor(self.panel, Math.vec4(1, 1, 0, 1))
    -- Widget.setPadding(self.panel, Math.vec4(10))
    -- Widget.setChildGap(self.panel, 5)
    --
    -- -- Create panel 2
    -- self.panel2 = Node.createNamed(self.ui, "panel2")
    -- Component.add(self.panel2, Widget)
    -- Component.add(self.panel2, Label)
    -- Label.setText(self.panel2, "TEST")
    -- Widget.setBackgroundColor(self.panel2, Math.vec4(0.5, 0, 1, 1))
    -- Widget.setPadding(self.panel2, Math.vec4(10))
    -- Widget.setChildGap(self.panel2, 5)
    -- -- Widget.setSizeX(self.panel2, Widget.SIZING_GROW, 0)
    -- Widget.setSizeY(self.panel2, Widget.SIZING_FIT, 0)
    -- Widget.setSizeX(self.panel2, Widget.SIZING_FIT, 0)
    --
    -- -- Create panel 3
    -- self.panel3 = Node.createNamed(self.ui, "panel3")
    -- Component.add(self.panel3, Widget)
    -- Widget.setBackgroundColor(self.panel3, Math.vec4(0.5, 0.5, 1, 1))
    -- Widget.setPadding(self.panel3, Math.vec4(10))
    -- Widget.setChildGap(self.panel3, 5)
    -- Widget.setSizeY(self.panel3, Widget.SIZING_GROW, 1)
    -- -- Widget.setSizeX(self.panel3, Widget.SIZING_FIXED, 400)
    -- Widget.setBorder(self.panel3, Math.vec4(2))

    -- Create panel
    self:addLabel(self.ui,
    -- "test")
"At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio. Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis doloribus asperiores repellat.")
    -- self:addSpacer(self.ui)
    -- self:addLabel(self.ui)
    -- self:addLabel(self.ui)
    -- self:addLabel(self.ui)

    Node.dump(Node.getRoot())
end

function M:addSpacer(parent)
    local widget = Node.create(parent)
    Component.add(widget, Widget)
    -- Widget.setSizeX(widget, Widget.SIZING_GROW, 0)
    Widget.setSizeY(widget, Widget.SIZING_GROW, 0)
end

function M:addLabel(parent, text)
    local label = Node.create(parent)
    Component.add(label, Widget)
    Component.add(label, Label)
    Label.setText(label, text)
    Label.setScale(label, 3)
    Widget.setBackgroundColor(label, Math.vec4(0, 0, 0.5, 1))
    -- Widget.setBorder(label, Math.vec4(1))
    Widget.setPadding(label, Math.vec4(20))
end
