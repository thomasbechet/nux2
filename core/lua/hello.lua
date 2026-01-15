local map = InputMap.new(0);
InputMap.bindKey(map, "up", Input.KEY_W)
InputMap.bindKey(map, "down", Input.KEY_D)
-- print(Node.dump(map))
Transform.new(map)
print(map)

local transforms = {}
local prev = 0
for i = 0, 10 do
    prev = Transform.new(prev)
    transforms[i] = prev
end
Transform.new(transforms[3])

for i, v in ipairs(transforms) do
    print(v)
end

Node.delete(0)
Node.dump(transforms[0])
Node.delete(transforms[0])
