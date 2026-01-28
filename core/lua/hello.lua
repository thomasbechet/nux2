-- local n = Node.newEmpty(Node.getRoot())
-- n = Node.newEmpty(n)
-- n = Node.newEmpty(n)
-- n = Node.newEmpty(n)
-- n = Node.newEmpty(n)
-- n = Node.newEmpty(n)
-- Node.dump(Node.getRoot())
local assets = Node.newEmpty(Node.getRoot())
Node.setName(assets, "assets")
list = { 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 18, 19 }
for _, i in ipairs(list) do
    Node.setName(Texture.load(assets, "ideas/gui/pannel"..i..".jpg"), "texture"..i);
end
Node.newEmpty(Node.getRoot())
Node.newEmpty(assets)

Node.dump(Node.getRoot())
Node.exportNode(Node.getRoot(), "scene.bin")
local tex = Node.find(Node.getRoot(), "/assets/$Texture")
print(Node.getName(tex))
Node.importNode(Node.getRoot(), "scene.bin")
Node.dump(Node.getRoot())
