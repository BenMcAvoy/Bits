BitsHooker = class()

sm.Bits = {
    RegisteredInteractables = {},

    hooked = false,
}

local oldBindCommand = sm.game.bindChatCommand

local function bindCommandHook(command, params, callback, help)
    if not sm.Bits.hooked then
        dofile("$CONTENT_374a306d-4b45-49ed-9cab-93a894be86ad/Scripts/Bootstrap/BitsDoFile.lua")

        sm.Bits.hooked = true
    end

    oldBindCommand(command, params, callback, help)
end

sm.game.bindChatCommand = bindCommandHook

print("BitsHooker loaded")
