local assets = Node.newEmpty(Node.getRoot())
Node.setName(assets, "assets")
Texture.load(assets, "ideas/gui/pannel0.jpg")
Texture.load(assets, "ideas/gui/pannel1.jpg")
Texture.load(assets, "ideas/gui/pannel2.jpg")

Node.dump(Node.getRoot())