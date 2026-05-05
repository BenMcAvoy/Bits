dofile("$CONTENT_DATA/Scripts/Shared/Helpers.lua")
dofile("$CONTENT_DATA/Scripts/Base/InteractiveBase.lua")

--- @class Counter : InteractiveBase
Counter = class(InteractiveBase)

Counter.connectionOutput = sm.interactable.connectionType.logic
Counter.connectionInput = sm.interactable.connectionType.logic

Counter.maxParentCount = 256
Counter.maxChildCount = 256

Counter.colorHighlight = sm.color.new( "FF725F" )
Counter.colorNormal = sm.color.new( "FF6753" )

--- Called when the counter is created
function Counter:server_onCreate()
    local saved = self.storage:load() or { value = 0 }
    self.savedValue = saved.value
    self.storage:save(saved)

    self.network:sendToClients("cl_setClientData", { value = saved.value })

    sm.Bits.RegisteredInteractables[self.interactable] = true
end

function Counter:server_onDestroy()
    sm.Bits.RegisteredInteractables[self.interactable] = nil
end

function Counter:server_onUnload()
    local state = self:sv_getHostClientState()
    if state and state.dirty then
        self.storage:save({ value = state.value })
        self.savedValue = state.value
        state.dirty = false
    end
end

function Counter:sv_getHostClientState()
    return self.state
end

-- Saving
function Counter:server_onFixedUpdate()
    local state = self:sv_getHostClientState()
    if not state then
        return
    end

    if state.dirty then
        self.storage:save({ value = state.value })
        self.savedValue = state.value
        state.dirty = false
    end

    if state.hasVanillaChildren then
        self.interactable.active = state.value ~= 0
    end
end

function Counter:client_onCreate()
    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Counter.layout")

    self.gui:setButtonCallback("IncreaseButton", "cl_guiInteract")
    self.gui:setButtonCallback("DecreaseButton", "cl_guiInteract")

    self.gui:setTextAcceptedCallback("ValueInput", "cl_guiInteract")
    self.gui:setTextChangedCallback("ValueInput", "cl_guiInteractTextChanged")

    self.gui:setOnCloseCallback("cl_onGuiCloseCallback")

    self.state = self.state or {
        value = 0,
        dirty = false, -- needs saving
    }
end

function Counter:client_onFixedUpdate()
    InteractiveBase.client_onFixedUpdate(self)

    local foundActive = false
    if self.state.hasVanillaParents then
        for _, parent in ipairs(self.interactable:getParents()) do
            if parent.active then
                foundActive = true
                break
            end
        end

        if foundActive then
            self.state.value = self.state.value + 1
            self.state.dirty = true -- needs saving
        end
    end

    local offset = foundActive and 6 or 0
    local frameIndex = (math.floor(math.abs(self.state.value) / 3) % 6) + offset
    self.interactable:setUvFrameIndex(frameIndex)

    self:cl_debugDraw()
end

function Counter:cl_debugDraw()
    if not self.cl_debugTag then
        self.cl_debugTag = sm.gui.createNameTagGui()
        self.cl_debugTag:setRequireLineOfSight(false)
        self.cl_debugTag:setMaxRenderDistance(50)
        self.cl_debugTag:open()
    end

    local origin = self.shape.worldPosition + self.shape.at * 0.4

    local parents = self.interactable:getParents()
    local activeParents = 0
    for _, parent in ipairs(parents) do
        if parent.active then
            activeParents = activeParents + 1
        end
    end

    local children = self.interactable:getChildren()
    local activeChildren = 0
    for _, child in ipairs(children) do
        if child.active then
            activeChildren = activeChildren + 1
        end
    end

    local color = self.state.dirty and "#ffaa00" or "#00ff88"
    local text = string.format(
        '%sValue: %d  parents: %d/%d  children: %d/%d%s',
        color,
        self.state.value,
        activeParents,
        #parents,
        activeChildren,
        #children,
        self.state.dirty and "  *" or ""
    )

    self.cl_debugTag:setWorldPosition(origin)
    self.cl_debugTag:setText("Text", text)
end

function Counter:client_onDestroy()
    if self.cl_debugTag then
        self.cl_debugTag:close()
        self.cl_debugTag:destroy()
        self.cl_debugTag = nil
    end
end

function Counter:client_onInteract(_, lookAt)
    if not lookAt then
        return
    end

    self.gui:open()
    self.gui:setFocus("ValueInput")

    self.gui:setText("ValueInput", tostring(self.state.value))
end

function Counter:cl_guiInteract(widgetName, parameter)
    if widgetName == "ValueInput" then
        self.network:sendToServer("sv_setValue", tonumber(parameter) or 0)
        return
    end

    if widgetName == "IncreaseButton" then
        self.network:sendToServer("sv_setValue", self.state.value + 1)
    elseif widgetName == "DecreaseButton" then
        self.network:sendToServer("sv_setValue", self.state.value - 1)
    end
end

function Counter:cl_guiInteractTextChanged(_, text)
    if text ~= "" and not tonumber(text) then
        self.gui:setText("ValueInput", self.lastText or tostring(self.state.value))
        return
    end

    self.lastText = text
    self.gui:setVisible("UnsavedIndicator", text ~= tostring(self.state.value))
end

function Counter:cl_onGuiCloseCallback()
    self.lastText = tostring(self.state.value)

    self.gui:setText("ValueInput", tostring(self.state.value))
    self.gui:setVisible("UnsavedIndicator", false)
end

function Counter:cl_setClientData(data, _)
    self.state = self.state or {
        value = 0,
        dirty = false,
    }
    self.state.value = data.value

    if self.gui then
        self.gui:setText("ValueInput", tostring(data.value))
        self.gui:setVisible("UnsavedIndicator", false)
    end
end

function Counter:client_canInteract()
    return true
end

function Counter:cl_onConnectionChanged()
    self.state.hasVanillaChildren = self:cl_hasVanillaChildren()
    self.state.hasVanillaParents = self:cl_hasVanillaParents()
end

function Counter:sv_setValue(value)
    self.savedValue = value
    self.storage:save({ value = value })
    self.network:sendToClients("cl_setClientData", { value = value })
end

function Counter:sv_onPlayerJoined(player)
    local state = self:sv_getHostClientState()
    local value = state and state.value or self.savedValue or 0
    self.network:sendToClient(player, "cl_setClientData", { value = value })
end
