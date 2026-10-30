--- Kick handler of a temple lantern on its chain: marks the lantern to be taken off the chain by
--- temple_lantern_chain.lua and pushes it away from the kicker. A lantern hung with the left mouse button has
--- no chain and is handled by lantern_anchor.lua.

dofile_once("mods/pick_up_your_lantern/files/scripts/utils.lua")

-- Storages shared with temple_lantern_chain.lua.
local ON_CHAIN_STORAGE = "lantern_on_chain"
local UNHOOK_STORAGE = "lantern_chain_unhook"
local KICK_FORCE_X = 40.0
local KICK_FORCE_Y = -20.0

---Called by Noita engine when the entity receives Message_Kick.
---@param entity_who_kicked number Entity ID of the kicker.
function kick(entity_who_kicked)
    local entity_id = GetUpdatedEntityID()
    if GetStorageFloat(entity_id, ON_CHAIN_STORAGE) <= 0 then
        return
    end

    SetStorageFloat(entity_id, UNHOOK_STORAGE, 1)
    if entity_who_kicked ~= nil and entity_who_kicked ~= 0 and EntityGetIsAlive(entity_who_kicked) then
        local x = EntityGetTransform(entity_id)
        local kicker_x = EntityGetTransform(entity_who_kicked)
        local dir_x = (x >= kicker_x) and 1.0 or -1.0
        PhysicsApplyForce(entity_id, dir_x * KICK_FORCE_X, KICK_FORCE_Y)
    end
end
