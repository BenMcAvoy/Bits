local interactable_getChildren
local interactable_getParents

local VanillaInteractiveUuids = Helpers:getInteractiveUuids()

--- @class InteractiveBase : ShapeClass
InteractiveBase = class()

InteractiveBase.pollInterval = 10 -- ticks between polls (~4Hz at 40Hz fixed update)

function InteractiveBase:client_onFixedUpdate()
    if not self._connPollInit then
        self._connPollInit = true
        self.lastChildren = 0
        self.lastParents = 0
        self.tickCount = 0
        self.nextPollTick = math.random(0, InteractiveBase.pollInterval - 1)
    end

    local tick = self.tickCount + 1
    self.tickCount = tick
    if tick < self.nextPollTick then return end
    self.nextPollTick = tick + InteractiveBase.pollInterval

    self:cl_pollConnections()
end

function InteractiveBase:cl_pollConnections()
    if not interactable_getChildren then
        interactable_getChildren = self.interactable.getChildren
        interactable_getParents = self.interactable.getParents
    end

    local interactable = self.interactable
    local children = #interactable_getChildren(interactable)
    local parents = #interactable_getParents(interactable)
    local lastChildren = self.lastChildren
    local lastParents = self.lastParents

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
end

function InteractiveBase:cl_hasVanillaChildren()
    for _, child in pairs(self.interactable:getChildren()) do
        local uuid = tostring(child.shape.uuid)
        if VanillaInteractiveUuids[uuid] then
            return true
        end
    end

    return false
end

function InteractiveBase:cl_hasVanillaParents()
    for _, parent in pairs(self.interactable:getParents()) do
        local uuid = tostring(parent.shape.uuid)
        if VanillaInteractiveUuids[uuid] then
            return true
        end
    end

    return false
end

function InteractiveBase:cl_onChildAdded() end
function InteractiveBase:cl_onChildRemoved() end
function InteractiveBase:cl_onParentAdded() end
function InteractiveBase:cl_onParentRemoved() end
function InteractiveBase:cl_onConnectionChanged() end
