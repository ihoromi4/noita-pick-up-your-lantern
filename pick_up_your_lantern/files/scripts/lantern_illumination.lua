--- Runtime illumination scaling for lanterns.
--- Keeps LightComponent radius and fog of war hole scale of every loaded lantern in sync with mod settings,
--- the lantern quality tier, liquid state and power. Base values of each lantern type are declared in its XML file
--- and captured into VariableStorageComponents on first sight, as the components themselves are rescaled at runtime.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")

local SCALE_SETTING_ID = MOD_ID .. ".illumination_scale"
local LANTERN_TAG = "lantern"
-- Applied illumination setting multiplied by the liquid state, without the quality tier.
local APPLIED_SCALE_STORAGE = "lantern_illumination_scale"
local BASE_LIGHT_RADIUS_STORAGE = "lantern_base_light_radius"
local BASE_FOG_HOLE_SCALE_STORAGE = "lantern_base_fog_hole_scale"
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

---Finds the fog of war hole SpriteComponent of an entity, present when dynamic lighting is enabled.
---@param entity_id number Entity ID.
---@return number|nil sprite_comp
function GetFogHoleSprite(entity_id)
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        if ComponentGetValue2(sprite_comp, "fog_of_war_hole") then
            return sprite_comp
        end
    end

    return nil
end

---Captures the base light radius and fog of war hole scale declared in the lantern XML file.
---@param entity_id number Lantern entity ID.
---@return nil
function EnsureLanternBaseIllumination(entity_id)
    if GetStorageFloat(entity_id, BASE_LIGHT_RADIUS_STORAGE) > 0 then
        return
    end

    local base_radius = 0
    local base_fog_hole_scale = 0
    local light_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "LightComponent")
    if light_comp ~= nil then
        base_radius = ComponentGetValue2(light_comp, "radius")
    end
    local fog_hole_sprite = GetFogHoleSprite(entity_id)
    if fog_hole_sprite ~= nil then
        base_fog_hole_scale = ComponentGetValue2(fog_hole_sprite, "special_scale_x")
    end

    SetStorageFloat(entity_id, BASE_LIGHT_RADIUS_STORAGE, base_radius)
    SetStorageFloat(entity_id, BASE_FOG_HOLE_SCALE_STORAGE, base_fog_hole_scale)
end

---Calculates the lantern LightComponent radius for the given illumination scale.
---@param entity_id number Lantern entity ID.
---@param scale number Illumination scale multiplier.
---@return number
function GetLanternLightRadius(entity_id, scale)
    EnsureLanternBaseIllumination(entity_id)
    return math.floor(GetStorageFloat(entity_id, BASE_LIGHT_RADIUS_STORAGE) * scale)
end

---Calculates the lantern fog of war hole scale for the given illumination scale.
---@param entity_id number Lantern entity ID.
---@param scale number Illumination scale multiplier.
---@return number
function GetLanternFogHoleScale(entity_id, scale)
    EnsureLanternBaseIllumination(entity_id)
    return GetStorageFloat(entity_id, BASE_FOG_HOLE_SCALE_STORAGE) * scale
end

---Returns the full light radius of a lantern for the currently applied scale, liquid state and quality tier.
---@param entity_id number Lantern entity ID.
---@return number radius Light radius, or 0 if no scale has been applied yet.
function GetLanternAppliedLightRadius(entity_id)
    local scale = GetStorageFloat(entity_id, APPLIED_SCALE_STORAGE)
    return GetLanternLightRadius(entity_id, scale * GetLanternTierMultiplier(entity_id))
end

---Applies the illumination scale, multiplied by the quality tier, to the light and fog of war hole of a lantern.
---A lamp without power gets no light and no fog of war hole.
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

    local tier_scale = scale * GetLanternTierMultiplier(entity_id) * GetLanternPowerFactor(entity_id)
    ComponentSetValue2(light_comp, "update_properties", true)
    ComponentSetValue2(light_comp, "radius", GetLanternLightRadius(entity_id, tier_scale))

    local fog_hole_scale = GetLanternFogHoleScale(entity_id, tier_scale)
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

---Makes the illumination update apply the scale to a lantern again on the next frame, e.g. after it lost power.
---A lantern in the inventory gets it once it is held or returned to the world.
---@param entity_id number Lantern entity ID.
---@return nil
function RefreshLanternIllumination(entity_id)
    SetStorageFloat(entity_id, APPLIED_SCALE_STORAGE, 0)
    is_transitioning = true
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
---Freshly spawned lanterns get their quality tier and modifier rolled here.
---@param force_refresh boolean? Whether to start a transition immediately regardless of the frame interval.
---@return nil
function UpdateLanternIllumination(force_refresh)
    if force_refresh then
        is_transitioning = true
    end
    if not is_transitioning and GameGetFrameNum() % UPDATE_INTERVAL_FRAMES ~= 0 then
        return
    end

    local setting_scale = GetIlluminationScale()
    local has_pending = false
    for _, entity_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        -- Captured before any scale is applied, while the components still hold the XML values.
        EnsureLanternBaseIllumination(entity_id)
        if EnsureLanternTraits(entity_id) then
            -- Snap to the new tier instead of easing from the radius applied before the roll.
            SetStorageFloat(entity_id, APPLIED_SCALE_STORAGE, 0)
        end
        -- The liquid state is part of the eased scale, so the lantern changes smoothly when it takes one on.
        local target_scale = setting_scale * GetLanternLiquidStateMultiplier(entity_id)
        local current_scale = GetStorageFloat(entity_id, APPLIED_SCALE_STORAGE)
        if current_scale ~= target_scale and not IsLanternExtinguished(entity_id) then
            local next_scale = StepScale(current_scale, target_scale)
            if ApplyLanternIllumination(entity_id, next_scale) and next_scale ~= target_scale then
                has_pending = true
            end
        end
    end
    is_transitioning = has_pending
end
