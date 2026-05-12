function M:onInit()
    self.inventoryOpened = Event.create(self.id, "onInventoryOpened")
    Event.bind(self.inventoryOpened, onInventoryOpened)
    Event.unbind(self.inventoryOpened, onInventoryOpened)
end

function M:onUpdate()
    Event.send(self.inventoryOpened)
end

function M:onInventoryOpened()
    print("inventory opened !")
end