--- @class BitsBookkeeper : ToolClass
BitsBookkeeper = class()

local sm_exists = sm.exists
local sm_game_getCurrentTick = sm.game.getCurrentTick

--- Resolves the current body for an interactable's owning component.
--- Shape body is the source of truth; Interactable does not own a body directly.
--- @param interactable Interactable
--- @param instance InteractiveBase|nil
--- @return Body|nil
local function getBody(interactable, instance)
    local shape = (instance and instance.shape) or interactable.shape
    if shape then
        return shape.body
    end

    return nil
end

--- Returns true when a table has no key/value pairs.
--- @param t table
--- @return boolean
local function isEmpty(t)
    return next(t) == nil
end

--- Queues a registered node for virtual topology rebuilding.
--- @param record BitsRecord
local function markTopologyDirty(record)
    sm.Bits.Client.Registry.dirtyTopologyNodes[record.interactableId] = true
end

--- Marks the owning node dirty and gives the component an optional body-change hook.
--- The graph system only needs the dirty flag; the callback is for component-local side effects.
--- @param record BitsRecord
--- @param body Body|nil
--- @param bodyId integer|nil
local function notifyBodyChanged(record, body, bodyId)
    markTopologyDirty(record)
    record.instance:cl_bodyChanged(body, bodyId)
end

--- Removes a record from its current body bucket.
--- Also clears empty buckets so bodies with no Bits interactables are no longer checked.
--- @param interactable Interactable
--- @param record BitsRecord
local function removeFromBodyBucket(interactable, record)
    local bodyId = record.bodyId
    if not bodyId then
        return
    end

    local bodyInteractables = sm.Bits.Client.BodyInteractables
    local bucket = bodyInteractables[bodyId]
    if bucket then
        bucket.interactables[interactable] = nil

        if isEmpty(bucket.interactables) then
            bodyInteractables[bodyId] = nil
        end
    end

    record.bodyId = nil
end

--- Adds a record to the bucket for the given body.
--- Buckets let the bookkeeper call sm.exists/body:hasChanged once per body instead of once per interactable.
--- @param tick integer
--- @param interactable Interactable
--- @param record BitsRecord
--- @param body Body
--- @param bodyId integer
local function addToBodyBucket(tick, interactable, record, body, bodyId)
    local bodyInteractables = sm.Bits.Client.BodyInteractables
    local bucket = bodyInteractables[bodyId] -- Check if bucket already exists for bodyId
    if not bucket then
        --- @type BitsBodyInteractables
        bucket = {
            body = body,
            bodyId = bodyId,
            lastChangeTick = tick,
            interactables = {}
        }
        bodyInteractables[bodyId] = bucket
    else
        bucket.body = body -- Re-use existing bucket if it exists, but update body reference
    end

    bucket.interactables[interactable] = record
    record.bodyId = bodyId
end

--- Synchronizes one record's body bucket membership.
--- Steady state is cheap: if the record still points at the same bucket body, no body API calls are made.
--- @param tick integer
--- @param interactable Interactable
--- @param record BitsRecord
local function syncRecordBody(tick, interactable, record)
    local bodyInteractables = sm.Bits.Client.BodyInteractables
    local body = getBody(interactable, record.instance)
    if not body then
        if record.bodyId then
            removeFromBodyBucket(interactable, record)
            notifyBodyChanged(record, nil, nil)
        end
        return
    end

    local currentBucket = record.bodyId and bodyInteractables[record.bodyId]
    if currentBucket and currentBucket.body == body then
        return
    end

    if not sm_exists(body) then
        if record.bodyId then
            removeFromBodyBucket(interactable, record)
            notifyBodyChanged(record, nil, nil)
        end
        return
    end

    local bodyId = body:getId()
    if record.bodyId == bodyId then
        local bucket = bodyInteractables[bodyId]
        if bucket then
            bucket.body = body
            bucket.interactables[interactable] = record
        end
        return
    end

    removeFromBodyBucket(interactable, record)
    addToBodyBucket(tick, interactable, record, body, bodyId)
    notifyBodyChanged(record, body, bodyId)
end

--- Fan-outs a body-level change to every Bits record currently in the bucket.
--- @param bucket BitsBodyInteractables
local function notifyBucketChanged(bucket)
    for _, record in pairs(bucket.interactables) do
        notifyBodyChanged(record, bucket.body, bucket.bodyId)
    end
end

--- Checks one body bucket for existence and body-level changes.
--- This is the only place that calls body:hasChanged in the steady-state bucket system.
--- @param tick integer
--- @param bodyId integer
--- @param bucket BitsBodyInteractables
local function checkBodyBucket(tick, bodyId, bucket)
    if isEmpty(bucket.interactables) then
        sm.Bits.Client.BodyInteractables[bodyId] = nil
        return
    end

    if not bucket.body or not sm_exists(bucket.body) then
        for _, record in pairs(bucket.interactables) do
            record.bodyId = nil
            notifyBodyChanged(record, nil, nil)
        end

        sm.Bits.Client.BodyInteractables[bodyId] = nil
        return
    end

    if not bucket.lastChangeTick then
        bucket.lastChangeTick = tick
        return
    end

    if bucket.body:hasChanged(bucket.lastChangeTick) then
        bucket.lastChangeTick = tick
        notifyBucketChanged(bucket)
    end
end

--- Maintains body buckets, then checks each active body bucket once.
function BitsBookkeeper:client_onFixedUpdate()
    local currentTick = sm_game_getCurrentTick()

    for interactable, record in pairs(sm.Bits.Client.RegisteredInteractables) do
        syncRecordBody(currentTick, interactable, record)
    end

    for bodyId, bucket in pairs(sm.Bits.Client.BodyInteractables) do
        checkBodyBucket(currentTick, bodyId, bucket)
    end
end
