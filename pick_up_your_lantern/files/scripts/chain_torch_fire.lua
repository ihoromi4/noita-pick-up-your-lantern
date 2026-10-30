--- Dousing and lighting again of a chain torch, in the world and in hand; runs every 10 frames.
--- - The fire itself comes from the particle emitters of the torch in the world. In hand the engine turns and
---   mirrors the emitters with the aim of the player, so lantern_in_hand.lua makes the fire at the coals of the
---   swinging sprite instead, and lantern_belt.lua on the belt (EmitOpenFire()).
--- - A torch whose coals are in a liquid is doused: its light, fog of war hole and fire are gone, and it shows the
---   dark sprite. Solid materials do not douse it. Doused, it lights again from fire: in the world when it catches
---   fire itself, in hand when its holder burns.
--- A torch that has burned out for good (Short-lived) is handled by ExtinguishLantern() and skipped here.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/hanging_rope.lua")

-- Coals below the top of the bail, which is the torch origin, in the world and in hand, where the sprite is drawn
-- at 60% of its size.
local COALS_OFFSET_Y = 6
local HAND_COALS_OFFSET_Y = 3.6
-- Ignition probability of the DamageModelComponent of a doused torch, so it can catch fire in the world.
local DOUSED_IGNITION_PROBABILITY = 1

local entity_id = GetUpdatedEntityID()
if IsLanternExtinguished(entity_id) then
    return
end

local x, y, rotation = EntityGetTransform(entity_id)
local root_id = EntityGetRootEntity(entity_id)
local in_hand = root_id ~= entity_id
local coals_x, coals_y
if in_hand then
    -- The sprite hangs down from the hand, turned by the swing of lantern_in_hand.lua. The rotation of the entity
    -- may still follow the aim of the player here, when this script runs before the swing is applied.
    coals_x, coals_y = OffsetToWorld(x, y, GetStorageFloat(entity_id, "lantern_swing_angle"), 0, HAND_COALS_OFFSET_Y)
else
    coals_x, coals_y = OffsetToWorld(x, y, rotation, 0, COALS_OFFSET_Y)
end

---Checks whether the coals are in a liquid: a short ray through them stops at a liquid cell but not at a solid one.
---The ray stays inside the bail, clear of the torch body.
---@return boolean
local function AreCoalsInLiquid()
    local hit_liquid = RaytraceSurfacesAndLiquiform(coals_x, coals_y - 1, coals_x, coals_y + 1)
    return hit_liquid and not RaytraceSurfaces(coals_x, coals_y - 1, coals_x, coals_y + 1)
end

---Checks whether fire reaches the torch: the torch itself burns in the world, its holder in hand.
---@return boolean
local function IsTouchedByFire()
    local damage_model = EntityGetFirstComponent(in_hand and root_id or entity_id, "DamageModelComponent")
    return damage_model ~= nil and ComponentGetValue2(damage_model, "is_on_fire")
end

---Switches the emitters of the torch on or off, and lets it catch fire in the world while doused.
---@param is_doused boolean
---@return nil
local function ApplyDousedComponents(is_doused)
    for _, emitter_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "ParticleEmitterComponent") or {}) do
        ComponentSetValue2(emitter_comp, "is_emitting", not is_doused)
    end

    local damage_model = EntityGetFirstComponentIncludingDisabled(entity_id, "DamageModelComponent")
    if damage_model ~= nil then
        ComponentSetValue2(damage_model, "fire_probability_of_ignition", is_doused and DOUSED_IGNITION_PROBABILITY or 0)
        ComponentSetValue2(damage_model, "is_on_fire", false)
    end
end

---Puts the torch out or lights it again: switches its emitters, light, fog of war hole and sprites.
---@param is_doused boolean
---@return nil
local function SetDoused(is_doused)
    SetLanternDoused(entity_id, is_doused)
    ApplyDousedComponents(is_doused)
    if is_doused then
        GameCreateCosmeticParticle("smoke", coals_x, coals_y, 6, 0, -20)
    end
    RefreshLanternIllumination(entity_id)
end

if IsLanternDoused(entity_id) then
    if IsTouchedByFire() and not AreCoalsInLiquid() then
        SetDoused(false)
    else
        -- A torch hung with the left mouse button is a new entity that copied only the doused state.
        ApplyDousedComponents(true)
    end
elseif AreCoalsInLiquid() then
    SetDoused(true)
end
