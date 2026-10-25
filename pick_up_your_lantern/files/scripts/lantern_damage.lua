--- Damage callback for lanterns: a lantern that takes damage without breaking (a hard fall, a throw against
--- a wall, a weak projectile hit) may crack. Cracking is part of lantern progression and does not happen
--- when it is disabled.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")

local CRACKED = GetLanternModifierDefinition(LANTERN_MODIFIER_CRACKED) --[[@as LanternModifierCracked]]

---Called by Noita engine when the lantern receives damage.
---@param damage number Damage dealt.
---@param message string Description of damage source.
---@param entity_thats_responsible number Entity ID responsible for the damage.
---@param is_fatal boolean Whether the damage kills the lantern.
---@param projectile_thats_responsible number Projectile entity ID responsible for the damage.
function damage_received(damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible)
    local entity_id = GetUpdatedEntityID()
    if is_fatal or damage <= 0 or not IsLanternProgressionEnabled() or IsLanternExtinguished(entity_id)
        or HasLanternModifier(entity_id, LANTERN_MODIFIER_CRACKED) then
        return
    end

    SetRandomSeed(GameGetFrameNum(), entity_id)
    if Random(1, 1000) <= CRACKED.crack_chance then
        AddLanternModifier(entity_id, LANTERN_MODIFIER_CRACKED)
    end
end
