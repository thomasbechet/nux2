import "nux" for Component, Widget, Node, Viewport, Math, Label

class Game {
    static onInit() {
        // Create UI root
        var ui = Node.createPath(Node.getRoot(), "ui")
        Component.add(ui, Viewport)
        Component.add(ui, Widget)

        Widget.setBackgroundColor(ui, Math.vec4(0.5, 0, 0, 1))
        // Widget.setPadding(ui, Math.vec4(10))
        Widget.setChildGap(ui, 10)
        Widget.setAlignX(ui, Widget.ALIGNMENT_CENTER)
        Widget.setAlignY(ui, Widget.ALIGNMENT_CENTER)

        Viewport.setWidget(ui, ui)

        for (i in 0..0) {
            var n = Node.createNamed(ui, "item%(i)")
            Component.add(n, Widget)
            Component.add(n, Label)

            Label.setText(n, "First line\nSecond line\nThird line%(i)")

            // Widget.setSizeX(n, Widget.SIZING_FIT, 0)
            // Widget.setSizeY(n, Widget.SIZING_FIT, 0)

            Widget.setBackgroundColor(n, Math.vec4(0, 0, 0.5, 1))
            // Widget.setBorder(n, Math.vec4(1))
            Widget.setPadding(n, Math.vec4(10))
        }

        Node.dump(Node.getRoot())
    }
}
