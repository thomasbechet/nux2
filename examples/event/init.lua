function M:onInit()
    Event.add('inventoryOpened')
    Event.bind('.', 'inventoryOpened',)
    Event.bind('')
end

function M:onUpdate()
    Event.emit('.',)
end

function M:onInventoryOpened()
    local button = Signal.getEventSource()
    print("inventory opened !")
end
