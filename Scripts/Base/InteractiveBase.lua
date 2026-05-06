local VanillaInteractiveUuids = Helpers:getInteractiveUuids()

--- Base class for Bits interactables.
--- Handles registry registration and connection-change callbacks shared by Bits components.
--- @class InteractiveBase : ShapeClass
--- @field interactable Interactable Scrap Mechanic interactable owned by this component.
--- @field bitsRecord BitsRecord Registry record assigned during client_onCreate.
--- @field bitsNode BitsNode Virtual graph node assigned during client_onCreate.
--- @field lastChildren integer|nil Last observed child connection count.
--- @field lastParents integer|nil Last observed parent connection count.
InteractiveBase = class()

--- Poll delay used by older connection polling code.
--- Current dirty-topology flow only polls when the registry marks this node dirty.
InteractiveBase.pollInterval = 10 -- ticks between polls (~4Hz at 40Hz fixed update)

--- Registers this component into the client virtual graph and captures initial connection state.
function InteractiveBase:client_onCreate()
    self.bitsRecord = Registry.Register(self)
    self.bitsNode = self.bitsRecord.node

    self.lastChildren = #self.interactable:getChildren()
    self.lastParents = #self.interactable:getParents()
    self:cl_onConnectionChanged()
end

--- Removes this component from the client virtual graph registry.
function InteractiveBase:client_onDestroy()
    Registry.Unregister(self.interactable)
end

--- Processes topology work when the bookkeeper has marked this node dirty.
function InteractiveBase:client_onFixedUpdate()
    local dirtyTopology = sm.Bits.Client.Registry.dirtyTopologyNodes
    if not dirtyTopology[self.interactable.id] then
        return
    end

    local interactable = self.interactable
    local children = #interactable:getChildren()
    local parents = #interactable:getParents()
    local lastChildren = self.lastChildren or 0
    local lastParents = self.lastParents or 0

    if children ~= lastChildren or parents ~= lastParents then
        local childrenDelta = children - lastChildren
        local parentsDelta = parents - lastParents

        if childrenDelta > 0 then
            self:cl_onChildAdded()
        elseif childrenDelta < 0 then
            self:cl_onChildRemoved()
        end

        if parentsDelta > 0 then
            self:cl_onParentAdded()
        elseif parentsDelta < 0 then
            self:cl_onParentRemoved()
        end

        self.lastChildren = children
        self.lastParents = parents

        self:cl_onConnectionChanged()
    end

    sm.Bits.Client.Registry.dirtyTopologyNodes[self.interactable.id] = nil
end

--- Returns true if this component currently drives at least one vanilla child interactable.
--- Bits children are ignored here because they are handled by the virtual graph.
--- @return boolean
function InteractiveBase:cl_hasVanillaChildren()
    for _, child in pairs(self.interactable:getChildren()) do
        local uuid = tostring(child.shape.uuid)
        if VanillaInteractiveUuids[uuid] then
            return true
        end
    end

    return false
end

--- Returns true if this component currently reads at least one vanilla parent interactable.
--- Bits parents are ignored here because they are handled by the virtual graph.
--- @return boolean
function InteractiveBase:cl_hasVanillaParents()
    for _, parent in pairs(self.interactable:getParents()) do
        local uuid = tostring(parent.shape.uuid)
        if VanillaInteractiveUuids[uuid] then
            return true
        end
    end

    return false
end

--- Called when the number of child connections increases.
function InteractiveBase:cl_onChildAdded()
    print("Child added to " .. tostring(self.interactable.id)) --- IGNORE ---
end

--- Called when the number of child connections decreases.
function InteractiveBase:cl_onChildRemoved()
    print("Child removed from " .. tostring(self.interactable.id)) --- IGNORE ---
end

--- Called when the number of parent connections increases.
function InteractiveBase:cl_onParentAdded()
    print("Parent added to " .. tostring(self.interactable.id)) --- IGNORE ---
end

--- Called when the number of parent connections decreases.
function InteractiveBase:cl_onParentRemoved()
    print("Parent removed from " .. tostring(self.interactable.id)) --- IGNORE ---
end

--- Called after any parent/child connection count changes.
function InteractiveBase:cl_onConnectionChanged()
    print("Connection changed for " .. tostring(self.interactable.id)) --- IGNORE ---
end

--- Called when the owning body changes, disappears, or body:hasChanged reports true.
--- @param body Body|nil
--- @param bodyId integer|nil
function InteractiveBase:cl_bodyChanged(body, bodyId) end
