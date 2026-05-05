local uuids = nil
local interactiveUuids = nil

Helpers = {}

function Helpers:GetUuids()
    if uuids == nil then
        uuids = {}

        local json = sm.json.open("$CONTENT_DATA/Objects/Database/ShapeSets/shapesets.shapeset")
        local partList = json.partList

        for _, part in pairs(partList) do
            print(part.name, part.uuid)
            uuids[part.name] = part.uuid
        end
    end

    return uuids
end

function Helpers:getInteractiveUuids()
    -- Need to get all vanilla interactive UUIDs so that we can check if a child is vanilla and if it is.. we need to do vanilla compatibility stuff (expensive networking so should only be done if we actually have vanilla interactives as children)

    if interactiveUuids == nil then
        interactiveUuids = {}

        local shapesetsPaths = {
            "$GAME_DATA/Objects/Database/shapesets.json",
            "$SURVIVAL_DATA/Objects/Database/shapesets.json",
            "$CHALLENGE_DATA/Objects/Database/shapesets.json",
        }

        local visitedShapeSets = {}

        for _, path in pairs(shapesetsPaths) do
            local json = sm.json.open(path)

            for _, shapeSet in pairs(json.shapeSetList) do
                if not visitedShapeSets[shapeSet] then
                    visitedShapeSets[shapeSet] = true

                    local partList = sm.json.open(shapeSet).partList
                    if partList then
                        for _, part in pairs(partList) do
                            for _, itype in pairs(sm.interactable.types) do
                                if part[itype] then
                                    interactiveUuids[part.uuid] = part.name
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return interactiveUuids
end