--- @class BitsNetwork
--- @field id integer Stable client-local network id.
--- @field nodes table<integer, BitsNode> Bits nodes that currently belong to this connected component, keyed by interactable id.
--- @field version integer Value/update version for this network.
--- @field topologyVersion integer Topology rebuild version for this network.
--- @field dirty boolean True when this network needs a graph/value pass.
--- @field vanillaParents table<integer, Interactable> Vanilla interactables feeding into this network, keyed by interactable id.
--- @field vanillaChildren table<integer, Interactable> Vanilla interactables driven by this network, keyed by interactable id.

--- @class BitsBodyInteractables
--- @field body Body Body userdata shared by every interactable in this bucket.
--- @field bodyId integer Body id used as the BodyInteractables key.
--- @field lastChangeTick integer|nil Last tick used as the baseline for body:hasChanged.
--- @field interactables table<Interactable, BitsRecord> Registered Bits interactables currently on this body, keyed by interactable.

--- @class BitsRegistryState
--- @field recordsByInteractable table<Interactable, BitsRecord> Main record lookup by Scrap Mechanic interactable object.
--- @field recordsById table<integer, BitsRecord> Main record lookup by interactable id.
--- @field nodesByInteractable table<Interactable, BitsNode> Graph node lookup by Scrap Mechanic interactable object.
--- @field nodesById table<integer, BitsNode> Graph node lookup by interactable id.
--- @field dirtyTopologyNodes table<integer, boolean> Node ids whose connections/body membership need a topology rebuild.
--- @field dirtyBodies table<integer, boolean> Body ids queued for body-level processing.
--- @field networksById table<integer, BitsNetwork> Current virtual graph networks, keyed by network id.
--- @field nextNetworkId integer Next client-local network id to assign.

--- @class BitsServerState
--- @field OnPlayerJoinedSubscribers table<Interactable, true> Server interactables that want sv_onPlayerJoined forwarded from the global hook.

--- @class BitsClientState
--- @field RegisteredInteractables table<Interactable, BitsRecord> All client Bits interactables registered into the virtual graph system.
--- @field BodyInteractables table<integer, BitsBodyInteractables> Body buckets; each body is checked once, then changes fan out to all Bits interactables on it.
--- @field Registry BitsRegistryState Virtual graph records, nodes, dirty queues, and network state.

--- @class BitsState
--- @field Server BitsServerState Server-only Bits state.
--- @field Client BitsClientState Client-only Bits state and virtual graph registry.
--- @field hooked boolean True after the bindChatCommand hook has been installed.
--- @field originalBindChatCommand function|nil Original Scrap Mechanic chat command binder captured before installing the hook.
--- @field didLoadDoFile boolean|nil True after BitsDoFile.lua has been loaded through the hook.

BitsHooker = class()

local SERVER_TABLES = {
    "OnPlayerJoinedSubscribers"
}

local CLIENT_TABLES = {
    "RegisteredInteractables",
    "BodyInteractables"
}

local REGISTRY_TABLES = {
    "recordsByInteractable",
    "recordsById",
    "nodesByInteractable",
    "nodesById",
    "dirtyTopologyNodes",
    "dirtyBodies",
    "networksById"
}

local BITS_DEFAULTS = {
    hooked = false,
    didLoadDoFile = false
}

local REGISTRY_DEFAULTS = {
    nextNetworkId = 1
}

--- Ensures a child table exists and returns it without replacing existing state.
--- @param parent table Table that owns the child field.
--- @param key string Child field name to ensure.
--- @return table
local function ensureTable(parent, key)
    local value = parent[key]
    if value == nil then
        value = {}
        parent[key] = value
    end

    return value
end

--- Ensures several child table fields on the same parent.
--- @param parent table Table that owns the child fields.
--- @param keys string[] Field names to initialize as tables when missing.
local function ensureTables(parent, keys)
    for _, key in ipairs(keys) do
        ensureTable(parent, key)
    end
end

--- Assigns a default value only when the current field is nil.
--- False and other existing values are preserved across reloads.
--- @param parent table Table that owns the field.
--- @param key string Field name to default.
--- @param default any Value to assign when the field is nil.
local function ensureDefault(parent, key, default)
    if parent[key] == nil then
        parent[key] = default
    end
end

--- Applies multiple nil-only defaults to one table.
--- @param parent table Table that owns the fields.
--- @param defaults table<string, any> Map of field name to default value.
local function ensureDefaults(parent, defaults)
    for key, default in pairs(defaults) do
        ensureDefault(parent, key, default)
    end
end

--- Builds the sm.Bits state tree without discarding existing reload state.
local function ensureBitsState()
    --- @type BitsState
    sm.Bits = ensureTable(sm, "Bits")

    local bits = sm.Bits

    --- @type BitsServerState
    bits.Server = ensureTable(bits, "Server")

    --- @type BitsClientState
    bits.Client = ensureTable(bits, "Client")

    local server = bits.Server
    local client = bits.Client

    --- @type BitsRegistryState
    client.Registry = ensureTable(client, "Registry")

    local registry = client.Registry

    ensureTables(server, SERVER_TABLES)
    ensureTables(client, CLIENT_TABLES)
    ensureTables(registry, REGISTRY_TABLES)

    ensureDefaults(bits, BITS_DEFAULTS)
    ensureDefaults(registry, REGISTRY_DEFAULTS)
end

ensureBitsState()

sm.Bits.originalBindChatCommand = sm.Bits.originalBindChatCommand or sm.game.bindChatCommand

--- Hook around sm.game.bindChatCommand used to load the global Bits bootstrap once.
--- @param command string
--- @param params table|nil
--- @param callback function
--- @param help string|nil
local function bindCommandHook(command, params, callback, help)
    if not sm.Bits.didLoadDoFile then
        dofile("$CONTENT_374a306d-4b45-49ed-9cab-93a894be86ad/Scripts/Bootstrap/BitsDoFile.lua")

        sm.Bits.didLoadDoFile = true
    end

    sm.Bits.originalBindChatCommand(command, params, callback, help)
end

if not sm.Bits.hooked then
    sm.game.bindChatCommand = bindCommandHook
    sm.Bits.hooked = true
end

print("BitsHooker loaded")
