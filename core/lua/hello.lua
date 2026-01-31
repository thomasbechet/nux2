local source = SourceFile.load(Node.getRoot(), "hello2.lua")
print(SourceFile.getSource(source))
local script = Script.new(Node.getRoot(), source)
Node.dump(Node.getRoot())
