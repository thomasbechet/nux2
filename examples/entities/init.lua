
function M:init()
    local texture = Texture.loadFromFile("texture.png")
    local player = Entity.create("player")
    player.texture = texture
    print(player.position)
end