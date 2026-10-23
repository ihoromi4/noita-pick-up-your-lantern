--- Runtime illumination scaling for lanterns.
--- Keeps LightComponent radius and fog of war hole scale of every loaded lantern in sync with mod settings.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local SCALE_SETTING_ID = MOD_ID .. ".illumination_scale"
local LANTERN_TAG = "lantern"
local APPLIED_SCALE_STORAGE = "lantern_illumination_scale"
local BASE_LIGHT_RADIUS = 240
local BASE_FOG_HOLE_SCALE = 1.0
local UPDATE_INTERVAL_FRAMES = 30
local TRANSITION_SPEED = 0.03
local SNAP_EPSILON = 0.01

local is_transitioning = false

---Retrieves the illumination scale multiplier from mod settings.
---@return number
function GetIlluminationScale()
    local val = ModSettingGet(SCALE_SETTING_ID)
    if val == nil then
        val = ModSettingGetNextValue(SCALE_SETTING_ID)
    end
    local scale_num = tonumber(val)
    if scale_num == nil or scale_num <= 0 then
        return 1.0
    end

    return scale_num
end

---Calculates the lantern LightComponent radius for the given illumination scale.
---@param scale number Illumination scale multiplier.
---@return number
function GetLanternLightRadius(scale)
    return math.floor(BASE_LIGHT_RADIUS * scale)
end

---Applies the illumination scale to the light and fog of war hole of a lantern entity.
---Lanterns stored in the inventory are skipped: touching their disabled components makes them render
---again, so they are updated once the lantern is held or returned to the world.
---@param entity_id number Lantern entity ID.
---@param scale number Illumination scale multiplier.
---@return boolean applied Whether the scale was applied.
function ApplyLanternIllumination(entity_id, scale)
    local light_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "LightComponent")
    if light_comp == nil or not ComponentGetIsEnabled(light_comp) then
        return false
    end

    ComponentSetValue2(light_comp, "update_properties", true)
    ComponentSetValue2(light_comp, "radius", GetLanternLightRadius(scale))

    local fog_hole_scale = BASE_FOG_HOLE_SCALE * scale
    local sprites = EntityGetComponent(entity_id, "SpriteComponent") or {}
    for _, sprite_comp in ipairs(sprites) do
        if ComponentGetValue2(sprite_comp, "fog_of_war_hole") then
            ComponentSetValue2(sprite_comp, "has_special_scale", true)
            ComponentSetValue2(sprite_comp, "special_scale_x", fog_hole_scale)
            ComponentSetValue2(sprite_comp, "special_scale_y", fog_hole_scale)
            EntityRefreshSprite(entity_id, sprite_comp)
        end
    end

    SetStorageFloat(entity_id, APPLIED_SCALE_STORAGE, scale)
    return true
end

---Moves the current scale towards the target scale with exponential easing.
---Lanterns without an applied scale yet (freshly spawned or streamed in) snap to the target.
---@param current_scale number Scale currently applied to the lantern, or 0 if none.
---@param target_scale number Scale from mod settings.
---@return number
local function StepScale(current_scale, target_scale)
    if current_scale <= 0 or math.abs(target_scale - current_scale) < SNAP_EPSILON then
        return target_scale
    end

    return current_scale + (target_scale - current_scale) * TRANSITION_SPEED
end

---Applies the current illumination scale to loaded lanterns that are out of sync.
---Runs every frame while a transition is in progress, otherwise every UPDATE_INTERVAL_FRAMES frames
---to catch lanterns streamed in from saved chunks or taken out of the inventory.
---@param force_refresh boolean? Whether to start a transition immediately regardless of the frame interval.
---@return nil
function UpdateLanternIllumination(force_refresh)
    if force_refresh then
        is_transitioning = true
    end
    if not is_transitioning and GameGetFrameNum() % UPDATE_INTERVAL_FRAMES ~= 0 then
        return
    end

    local target_scale = GetIlluminationScale()
    local has_pending = false
    for _, entity_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local current_scale = GetStorageFloat(entity_id, APPLIED_SCALE_STORAGE)
        if current_scale ~= target_scale then
            local next_scale = StepScale(current_scale, target_scale)
            if ApplyLanternIllumination(entity_id, next_scale) and next_scale ~= target_scale then
                has_pending = true
            end
        end
    end
    is_transitioning = has_pending
end
