--- Damage hook of a studied enemy: raises the damage dealt by the player by the enemy study bonus.
--- Added to the enemy by files/scripts/enemy_study.lua when its study begins.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/enemy_study.lua")

---Called by Noita engine before the enemy receives damage; the returned values replace the incoming ones.
---@param damage number Incoming damage.
---@param x number World X coordinate of the hit.
---@param y number World Y coordinate of the hit.
---@param entity_thats_responsible number Entity ID responsible for the damage.
---@param critical_hit_chance number Critical hit chance of the damage.
---@return number damage, number critical_hit_chance
function damage_about_to_be_received(damage, x, y, entity_thats_responsible, critical_hit_chance)
    if damage <= 0 or not IsEnemyStudyEnabled() or not IsPlayerEntity(entity_thats_responsible) then
        return damage, critical_hit_chance
    end

    return damage * (1 + GetEnemyStudyBonus(GetUpdatedEntityID())), critical_hit_chance
end
