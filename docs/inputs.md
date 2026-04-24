# InputMap

- Map hardware input to action.

```
InputMap.bindKey(map, "movement.forward", Input.KEY_W)
InputMap.bindKey(map, "movement.backward", Input.KEY_S)
InputMap.bindKey(map, "movement.left", Input.KEY_A)
InputMap.bindKey(map, "movement.right", Input.KEY_D)
InputMap.bindKey(map, "movement.jump", Input.KEY_SPACE)

InputMap.bindKey(map, "menu.up", Input.KEY_UP)
InputMap.bindKey(map, "menu.down", Input.KEY_DOWN)
InputMap.bindKey(map, "menu.left", Input.KEY_LEFT)
InputMap.bindKey(map, "menu.right", Input.KEY_RIGHT) 
```

# Controller

```
Input.bindControllerMap(0, map)
Input.setInputMap(0, map)
Input.setControllerMap(0, map)
```
