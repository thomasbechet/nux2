local assets = Node.newEmpty(Node.getRoot())
Node.setName(assets, "assets")
list = { 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 18, 19 }
for _, i in ipairs(list) do
    Node.setName(Texture.load(assets, "ideas/gui/pannel"..i..".jpg"), "texture"..i);
end
Node.newEmpty(Node.getRoot())

Node.dump(Node.getRoot())
Node.exportNode(Node.getRoot(), "scene.bin")
print(Node.getParent(Node.getRoot()))
