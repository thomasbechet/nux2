local source = SourceFile.newFromPath(Node.getRoot(), "hello2.lua")
print(SourceFile.getSource(source))
local script = Script.newFromSourceFile(Node.getRoot(), source)
Node.dump(Node.getRoot())

-- Graphics.loadGltf("examples/basic/industrial.glb")
