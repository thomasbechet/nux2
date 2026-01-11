local map = InputMap.new(0);
InputMap.bindKey(map, "up", Input.KEY_W)
InputMap.bindKey(map, "down", Input.KEY_D)
print(Node.dump(map))
