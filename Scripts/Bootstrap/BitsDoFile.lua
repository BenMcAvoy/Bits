local gameClasses = {}
local succ, cfgJson = pcall(sm.json.open, "$CONTENT_DATA/config.json")
if succ and cfgJson then
    table.insert(gameClasses, _G[cfgJson.gameScript.class])
end

for _, name in ipairs{"SurvivalGame","CreativeFlatGame","ClassicCreativeGame","CreativeCustomGame","CreativeTerrainGame","CreativeGame"} do
    local class = _G[name]
    if class then
        table.insert(gameClasses, class)
    end
end

for _, gameClass in ipairs(gameClasses) do
    local oldOnPlayerJoined = gameClass.server_onPlayerJoined

    gameClass.server_onPlayerJoined = function(self, player, newPlayer)
        for interactable, _ in pairs(sm.Bits.Server.OnPlayerJoinedSubscribers) do
            sm.event.sendToInteractable(interactable, "sv_onPlayerJoined", player)
        end

        if oldOnPlayerJoined then
            oldOnPlayerJoined(self, player, newPlayer)
        end
    end
end