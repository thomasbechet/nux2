local map = InputMap.new(0);
InputMap.bindKey(map, "up", Input.KEY_W)
InputMap.bindKey(map, "down", Input.KEY_D)
print(Node.dump(map))
Transform.new(map)
print(map)

local prev = 0
for i = 0, 10 do
    print(i)
    prev = Transform.new(prev)
end

Node.delete(map)
