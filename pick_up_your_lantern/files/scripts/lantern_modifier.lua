--- Lantern modifier behaviour, attached at runtime to lanterns that rolled a modifier.
--- Runs only while the lantern is lit in the world or in hand:
--- - Flickering: the light radius wavers with occasional dips.
--- - Short-lived: the lantern burns for a limited time, sputters near the end and goes out.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local FLICKER_DEPTH = 0.45
local SPUTTER_FRAMES = 20 * 60
local SPUTTER_DEPTH = 0.6
local SPUTTER_MIN_FACTOR = 0.3

---Calculates a smooth pseudo-random flicker factor from layered sine waves with rare deep dips.
---@param frame number Current game frame.
---@param phase number Per-lantern phase offset.
---@param depth number Maximum relative brightness drop.
---@return number factor Light multiplier in the range [1 - depth, 1].
local function GetFlickerFactor(frame, phase, depth)
    local wave = math.sin(frame * 0.11 + phase) * 0.5
        + math.sin(frame * 0.27 + phase * 2.3) * 0.3
        + math.sin(frame * 0.63 + phase * 1.1) * 0.2
    local dip = math.max(0, math.sin(frame * 0.031 + phase)) ^ 12
    local amount = math.min(1, 0.35 * (0.5 + 0.5 * wave) + 0.65 * dip)

    return 1 - depth * amount
end

local entity_id = GetUpdatedEntityID()
local light_comp = EntityGetFirstComponent(entity_id, "LightComponent")
local full_radius = GetLanternAppliedLightRadius(entity_id)
if light_comp == nil or full_radius <= 0 then
    return
end

local frame = GameGetFrameNum()
local phase = entity_id * 1.7
local modifier_id = GetLanternModifier(entity_id)
local factor = 1.0

if modifier_id == LANTERN_MODIFIER_FLICKERING then
    factor = GetFlickerFactor(frame, phase, FLICKER_DEPTH)
elseif modifier_id == LANTERN_MODIFIER_SHORT_LIVED then
    local burn_frames = GetLanternBurnFrames(entity_id) - 1
    if burn_frames <= 0 then
        ExtinguishLantern(entity_id)
        return
    end
    SetLanternBurnFrames(entity_id, burn_frames)

    if burn_frames < SPUTTER_FRAMES then
        local fuel = burn_frames / SPUTTER_FRAMES
        factor = (SPUTTER_MIN_FACTOR + (1 - SPUTTER_MIN_FACTOR) * fuel) * GetFlickerFactor(frame, phase, SPUTTER_DEPTH)
    end
end

ComponentSetValue2(light_comp, "update_properties", true)
ComponentSetValue2(light_comp, "radius", math.floor(full_radius * factor))
