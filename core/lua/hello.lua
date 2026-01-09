local vec2 = Math.vec2;
print(vec2())
print(vec2(1))
print(vec2(2, 2) + vec2(1, 2))
-- print(Transform.nw())
print("a", "b", "c")


print(Input.KEY_A)
print(Input.KEY_B)

local map = InputMap.new(0);
InputMap.bindKey(map, "up", Input.KEY_C)
InputMap.bindKey(map, "up", Input.KEY_A)
print(map);

