local vec2 = vmath.vec2;
print(vec2())
print(vec2(1))
print(vec2(2, 2) + vec2(1, 2))
-- print(Transform.nw())
print("a", "b", "c")


print(input.KEY_A)
print(input.KEY_B)

local map = InputMap.new(0);
InputMap.bindKey(map, "up", 12312891724)
InputMap.bindKey(map, "up", Input.KEY_A)
print(map);
