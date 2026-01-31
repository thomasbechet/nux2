require("hello2")
require("hello2")
-- local n = Node.new(Node.getRoot())
-- n = Node.new(n)
-- n = Node.new(n)
-- n = Node.new(n)
-- n = Node.new(n)
-- n = Node.new(n)
-- Node.dump(Node.getRoot())
local assets = Node.new(Node.getRoot())
Node.setName(assets, "assets")
list = { 0, 1, 2, 3, 4, 5, 7, 9, 10, 11, 18, 19 }
for _, i in ipairs(list) do
    Node.setName(Texture.load(assets, "ideas/gui/pannel" .. i .. ".jpg"), "texture" .. i);
end
Node.new(Node.getRoot())
Node.new(assets)

Node.newPath(Node.getRoot(), "coucou/Julia/Comment/ça/va")
-- Node.newPath(Node.getRoot(), "coucou/Julia/Comment/coucou/va")
Node.dump(Node.getRoot())

-- Disk.listFiles()
