--- Registered client-side Bits component instance.
--- One record is shared by every lookup table so registry state can point to the same object.
--- @class BitsRecord
--- @field instance InteractiveBase Component script instance that owns this record.
--- @field interactable Interactable Scrap Mechanic interactable owned by the component.
--- @field interactableId integer Stable interactable id used for graph lookup and dirty topology keys.
--- @field bodyId integer|nil Current body bucket id, or nil while the interactable is not bucketed.
--- @field node BitsNode|nil Virtual graph node owned by this record.

--- Virtual graph node for a registered Bits component.
--- Nodes store topology and output state; records store the owning component instance.
--- @class BitsNode
--- @field id integer Interactable id for this node.
--- @field record BitsRecord Back-reference to the owning registry record.
--- @field networkId integer|nil Current virtual network id, or nil until assigned by graph rebuild.
--- @field parents BitsEdges Incoming Bits and vanilla parent connections.
--- @field children BitsEdges Outgoing Bits and vanilla child connections.
--- @field outputs table<string, BitsOutput> Named output channels produced by this node.
--- @field outputVersion integer Incremented when this node's outputs change.
--- @field topologyVersion integer Incremented when this node's connections/topology change.

--- Split edge table for Bits-to-Bits and vanilla Scrap Mechanic connections.
--- @class BitsEdges
--- @field bits table<integer, BitsNode> Bits nodes keyed by interactable id.
--- @field vanilla table<integer, Interactable> Vanilla interactables keyed by interactable id.

--- One named output value produced by a Bits node.
--- @class BitsOutput
--- @field value any Current value for this output channel.
--- @field version integer Incremented when the value changes.

Registry = {}

--- Returns the live client registry state under sm.Bits.
--- @return BitsRegistryState
local function state()
    return sm.Bits.Client.Registry
end

--- Registers a client component instance into the Bits virtual graph registry.
--- Existing records are reused so reentrant create/register calls keep stable table references.
--- @param instance InteractiveBase
--- @return BitsRecord
function Registry.Register(instance)
    local reg = state()

    local interactable = instance.interactable
    local interactableId = interactable.id

    local alreadyExists = reg.recordsByInteractable[interactable]
    if alreadyExists then
        return alreadyExists
    end

    --- @type BitsRecord
    local record = {
        instance = instance,
        interactable = interactable,
        interactableId = interactableId,
        bodyId = nil,
        node = nil
    }

    --- @type BitsNode
    local node = {
        id = record.interactableId,
        record = record, -- ref
        networkId = nil,
        parents = {bits = {}, vanilla = {}},
        children = {bits = {}, vanilla = {}},
        outputs = {},
        outputVersion = 0,
        topologyVersion = 0
    }

    record.node = node

    sm.Bits.Client.RegisteredInteractables[interactable] = record

    reg.recordsByInteractable[interactable] = record
    reg.recordsById[interactableId] = record
    reg.nodesByInteractable[interactable] = node
    reg.nodesById[interactableId] = node
    reg.dirtyTopologyNodes[interactableId] = true

    return record
end

--- Unregisters an interactable from every client registry index and body bucket.
--- Safe to call for interactables that were never registered.
--- @param interactable Interactable
function Registry.Unregister(interactable)
    local reg = state()

    local record = reg.recordsByInteractable[interactable]
    if not record then
        return
    end

    local bodyId = record.bodyId
    if bodyId then
        local bucket = sm.Bits.Client.BodyInteractables[bodyId]
        if bucket then
            bucket.interactables[interactable] = nil

            if next(bucket.interactables) == nil then
                sm.Bits.Client.BodyInteractables[bodyId] = nil
            end
        end
    end

    sm.Bits.Client.RegisteredInteractables[interactable] = nil

    reg.recordsByInteractable[interactable] = nil
    reg.recordsById[record.interactableId] = nil
    reg.nodesByInteractable[interactable] = nil
    reg.nodesById[record.interactableId] = nil
    reg.dirtyTopologyNodes[record.interactableId] = nil
end

return Registry
