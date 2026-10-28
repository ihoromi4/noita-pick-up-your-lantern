--- Lantern modifier behaviour, attached at runtime to lanterns that carry modifiers.
--- Runs only while the lantern is lit in the world or in hand; effects of several modifiers combine:
--- - Flickering: the light radius is wider but wavers with occasional dips.
--- - Short-lived: the lantern leaks oil, fades as it burns, sputters near the end and goes out.
--- - Cracked: the lantern now and then leaks particles of fire, which can set the holder on fire.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local entity_id = GetUpdatedEntityID()
local light_comp = EntityGetFirstComponent(entity_id, "LightComponent")
local full_radius = GetLanternAppliedLightRadius(entity_id)
if light_comp == nil or full_radius <= 0 then
    return
end

local x, y = EntityGetTransform(entity_id)
if not ConsumeLanternFuel(entity_id, x, y) then
    ExtinguishLantern(entity_id)
    return
end

EmitCrackedFire(entity_id, x, y)

local factor = GetLanternModifierFactor(entity_id) * GetLanternPowerFactor(entity_id)

ComponentSetValue2(light_comp, "update_properties", true)
ComponentSetValue2(light_comp, "radius", math.floor(full_radius * factor))
