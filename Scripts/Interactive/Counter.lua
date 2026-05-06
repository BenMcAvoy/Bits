dofile("$CONTENT_DATA/Scripts/Shared/Helpers.lua")
dofile("$CONTENT_DATA/Scripts/Base/InteractiveBase.lua")
dofile("$CONTENT_DATA/Scripts/Shared/Registry.lua")

--- Client-owned state mirrored back to the server when needed.
--- @class CounterSvclState
--- @field value integer Current counter value.
--- @field dirty boolean True when the value should be saved on the server.
--- @field hasVanillaChildren boolean|nil True when this counter drives at least one vanilla child.
--- @field hasVanillaParents boolean|nil True when this counter reads at least one vanilla parent.

--- Value payload sent from server storage to clients.
--- @class CounterClientData
--- @field value integer Counter value to apply on the client.

--- Persisted counter storage payload.
--- @class CounterStorageData
--- @field value integer Last saved counter value.

--- Interactive counter component.
--- Counts vanilla active parent pulses, stores its value, and exposes a small edit GUI.
--- @class Counter : InteractiveBase
--- @field sv_savedValue integer|nil Last value known by the server/storage side.
--- @field svcl_state CounterSvclState|nil Shared local state used by both client logic and server save logic.
--- @field cl_gui GuiInterface|nil Counter edit GUI instance.
--- @field cl_debugTag GuiInterface|nil Floating debug name tag shown above the counter.
--- @field cl_bitsRecord BitsRecord|nil Client registry record if this component stores one locally.
--- @field cl_bitsNode BitsNode|nil Client graph node if this component stores one locally.
--- @field cl_lastText string|nil Last accepted GUI input text, used to restore invalid input.
--- @diagnostic disable-next-line: param-type-mismatch
Counter = class(InteractiveBase)

--- @type integer
Counter.connectionOutput = sm.interactable.connectionType.logic

--- @type integer
Counter.connectionInput = sm.interactable.connectionType.logic

--- @type integer
Counter.maxParentCount = 256

--- @type integer
Counter.maxChildCount = 256

Counter.colorHighlight = sm.color.new( "FF725F" )
Counter.colorNormal = sm.color.new( "FF6753" )

--- Loads saved storage and subscribes to global player-join forwarding.
function Counter:server_onCreate()
    --- @type CounterStorageData
    local saved = self.storage:load() or { value = 0 }
    self.sv_savedValue = saved.value
    self.storage:save(saved)

    self.network:sendToClients("cl_setClientData", { value = saved.value })

    sm.Bits.Server.OnPlayerJoinedSubscribers[self.interactable] = true
end

--- Removes this interactable from the server player-join subscriber list.
function Counter:server_onDestroy()
    sm.Bits.Server.OnPlayerJoinedSubscribers[self.interactable] = nil
end

--- Flushes dirty host-client state into storage before the server instance unloads.
function Counter:server_onUnload()
    local state = self:sv_getHostClientState()
    if state and state.dirty then
        self.storage:save({ value = state.value })
        self.sv_savedValue = state.value
        state.dirty = false
    end
end

--- Returns the host/client state object the server reads for storage and vanilla output.
--- @return CounterSvclState|nil
function Counter:sv_getHostClientState()
    return self.svcl_state
end

--- Saves dirty counter values and drives vanilla child output when needed.
function Counter:server_onFixedUpdate()
    --- @type CounterSvclState|nil
    local state = self:sv_getHostClientState()
    if not state then
        return
    end

    if state.dirty then
        self.storage:save({ value = state.value })
        self.sv_savedValue = state.value
        state.dirty = false
    end

    if state.hasVanillaChildren then
        self.interactable.active = state.value ~= 0
    end
end

--- Creates GUI state and registers the component with InteractiveBase.
function Counter:client_onCreate()
    --- @type GuiInterface
    self.cl_gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Counter.layout")

    self.cl_gui:setButtonCallback("IncreaseButton", "cl_guiInteract")
    self.cl_gui:setButtonCallback("DecreaseButton", "cl_guiInteract")

    self.cl_gui:setTextAcceptedCallback("ValueInput", "cl_guiInteract")
    self.cl_gui:setTextChangedCallback("ValueInput", "cl_guiInteractTextChanged")

    self.cl_gui:setOnCloseCallback("cl_onGuiCloseCallback")

    --- @type CounterSvclState
    self.svcl_state = self.svcl_state or {
        value = 0,
        dirty = false, -- needs saving
    }

    InteractiveBase.client_onCreate(self)
end

--- Runs client-side counting, visual frame updates, debug drawing, and base topology checks.
function Counter:client_onFixedUpdate()
    InteractiveBase.client_onFixedUpdate(self)

    local foundActive = false
    if self.svcl_state.hasVanillaParents then
        for _, parent in ipairs(self.interactable:getParents()) do
            if parent.active then
                foundActive = true
                break
            end
        end

        if foundActive then
            self.svcl_state.value = self.svcl_state.value + 1
            self.svcl_state.dirty = true -- needs saving
        end
    end

    local offset = foundActive and 6 or 0
    local frameIndex = (math.floor(math.abs(self.svcl_state.value) / 3) % 6) + offset
    self.interactable:setUvFrameIndex(frameIndex)

    self:cl_debugDraw()
end

--- Draws a floating debug tag with current value and connection counts.
function Counter:cl_debugDraw()
    if not self.cl_debugTag then
        --- @type GuiInterface
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

    local color = self.svcl_state.dirty and "#ffaa00" or "#00ff88"
    local text = string.format(
        '%sValue: %d  parents: %d/%d  children: %d/%d%s',
        color,
        self.svcl_state.value,
        activeParents,
        #parents,
        activeChildren,
        #children,
        self.svcl_state.dirty and "  *" or ""
    )

    self.cl_debugTag:setWorldPosition(origin)
    self.cl_debugTag:setText("Text", text)
end

--- Destroys client GUI/debug resources and unregisters from the virtual graph.
function Counter:client_onDestroy()
    InteractiveBase.client_onDestroy(self)

    self.cl_bitsRecord = nil
    self.cl_bitsNode = nil

    if self.cl_debugTag then
        self.cl_debugTag:close()
        self.cl_debugTag:destroy()
        self.cl_debugTag = nil
    end
end

--- Opens the edit GUI when the player interacts with the counter.
--- @param _ any
--- @param lookAt boolean
function Counter:client_onInteract(_, lookAt)
    if not lookAt then
        return
    end

    self.cl_gui:open()
    self.cl_gui:setFocus("ValueInput")

    self.cl_gui:setText("ValueInput", tostring(self.svcl_state.value))
end

--- Handles button clicks and accepted text entry from the counter GUI.
--- @param widgetName string
--- @param parameter string|number
function Counter:cl_guiInteract(widgetName, parameter)
    if widgetName == "ValueInput" then
        self.network:sendToServer("sv_setValue", tonumber(parameter) or 0)
        return
    end

    if widgetName == "IncreaseButton" then
        self.network:sendToServer("sv_setValue", self.svcl_state.value + 1)
    elseif widgetName == "DecreaseButton" then
        self.network:sendToServer("sv_setValue", self.svcl_state.value - 1)
    end
end

--- Validates GUI text input and toggles the unsaved indicator.
--- @param _ any
--- @param text string
function Counter:cl_guiInteractTextChanged(_, text)
    if text ~= "" and not tonumber(text) then
        self.cl_gui:setText("ValueInput", self.cl_lastText or tostring(self.svcl_state.value))
        return
    end

    self.cl_lastText = text
    self.cl_gui:setVisible("UnsavedIndicator", text ~= tostring(self.svcl_state.value))
end

--- Restores GUI text/indicator state when the edit GUI closes.
function Counter:cl_onGuiCloseCallback()
    self.cl_lastText = tostring(self.svcl_state.value)

    self.cl_gui:setText("ValueInput", tostring(self.svcl_state.value))
    self.cl_gui:setVisible("UnsavedIndicator", false)
end

--- Applies server-provided counter data on the client.
--- @param data CounterClientData
--- @param _ any
function Counter:cl_setClientData(data, _)
    --- @type CounterSvclState
    self.svcl_state = self.svcl_state or {
        value = 0,
        dirty = false,
    }
    self.svcl_state.value = data.value

    if self.cl_gui then
        self.cl_gui:setText("ValueInput", tostring(data.value))
        self.cl_gui:setVisible("UnsavedIndicator", false)
    end
end

--- Allows players to interact with the counter.
--- @return boolean
function Counter:client_canInteract()
    return true
end

--- Recomputes whether this counter is connected to vanilla parents/children.
function Counter:cl_onConnectionChanged()
    self.svcl_state.hasVanillaChildren = self:cl_hasVanillaChildren()
    self.svcl_state.hasVanillaParents = self:cl_hasVanillaParents()
end

--- Sets the authoritative saved value and broadcasts it to clients.
--- @param value integer
function Counter:sv_setValue(value)
    self.sv_savedValue = value
    self.storage:save({ value = value })
    self.network:sendToClients("cl_setClientData", { value = value })
end

--- Sends the current value to a player who just joined.
--- @param player Player
function Counter:sv_onPlayerJoined(player)
    local state = self:sv_getHostClientState()
    local value = state and state.value or self.sv_savedValue or 0
    self.network:sendToClient(player, "cl_setClientData", { value = value })
end

--- Called when the counter's body bucket changes or its body reports a change.
function Counter:cl_bodyChanged()
end
