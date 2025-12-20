function M:init()
    local id = transform.new(nil)
    local id = sprite.new(id)
    sprite.set_texture("main/texture.png")

    local parent = object.get(id, "..")
end
