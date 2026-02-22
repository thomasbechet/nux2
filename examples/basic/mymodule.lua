function M:onInit()
    self.value = 0
end

function M:onDeinit()
    print("mymodule deinit!")
end

function M:onUpdate()
    self.value = self.value + 1
    print("value: "..self.value)
end

