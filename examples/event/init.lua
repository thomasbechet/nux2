function M:onInit()
    self.inventoryOpened = Event.create("inventoryOpened")
    -- Event.bind(self.inventoryOpened, onInventoryOpened)

    Event.create(self.id)
end

function M:onUpdate()
    Event.emit(self.inventoryOpened)
end

function M:onInventoryOpened()
    local node = Event.getSource()
    print("inventory opened !")
end
