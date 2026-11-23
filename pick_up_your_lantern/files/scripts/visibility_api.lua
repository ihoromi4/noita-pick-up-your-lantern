--- Visibility API for Pick Up Your Lantern mod.
--- Exported for other mods (such as In Game Wiki) to check whether a world point or entity
--- is illuminated by a light source (lanterns in the world or in hand, Light spell modifier).
--- Usage from another mod:
---   if ModIsEnabled("pick_up_your_lantern") then
---       local visibility = dofile_once("mods/pick_up_your_lantern/files/scripts/visibility_api.lua")
---       if visibility.IsEntityVisible(enemy_id) then ... end
---   end

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

-- Share of the lantern light radius that looks visibly lit: calibrated in-game against darkness.
local LIT_RADIUS_FACTOR = 0.35
-- Belt lantern entity tag: not tagged with `pul_light_source` so creature attraction/fear ignore it,
-- but included here with its own reduced `LightComponent.radius` (`belt_light_scale`).
local BELT_TAG = "pul_belt"

local cached_frame = nil
local cached_lit_areas = {}

---Appends a lit circle from a LightComponent to `areas` when its effective radius is positive.
---@param areas table[] Lit circles as `{ x, y, radius_sq }`.
---@param source_id number Light source entity ID.
---@param light_comp number|nil Enabled LightComponent ID.
---@return nil
local function AddLitArea(areas, source_id, light_comp)
    if light_comp == nil then
        return
    end

    -- The current radius already includes the quality tier, liquid state, modifiers, and belt scale.
    local radius = ComponentGetValue2(light_comp, "radius") * LIT_RADIUS_FACTOR
    local x, y = EntityGetTransform(source_id)
    if radius > 0 and x ~= nil then
        table.insert(areas, { x, y, radius * radius, })
    end
end

---Gathers the areas lit by light sources: lanterns in the world, in the player's hands, on the player's belt,
---and projectiles with the Light spell modifier. Lanterns in the inventory have their light disabled, and
---extinguished lanterns have none, so neither counts.
---For tagged light sources, only the tagged LightComponent is read, as a projectile may carry its own light.
---@return table[] areas Lit circles as `{ x, y, radius_sq }`.
local function CollectLitAreas()
    local areas = {}
    for _, source_id in ipairs(EntityGetWithTag(LIGHT_SOURCE_TAG) or {}) do
        local light_comp = EntityGetFirstComponent(source_id, "LightComponent", LIGHT_SOURCE_TAG)
        AddLitArea(areas, source_id, light_comp)
    end
    for _, belt_id in ipairs(EntityGetWithTag(BELT_TAG) or {}) do
        local light_comp = EntityGetFirstComponent(belt_id, "LightComponent")
        AddLitArea(areas, belt_id, light_comp)
    end

    return areas
end

---Returns the lit areas for the current frame, caching them so multiple queries in one frame scan sources once.
---@return table[] areas Lit circles as `{ x, y, radius_sq }`.
local function GetLitAreasForFrame()
    local frame = GameGetFrameNum()
    if cached_frame ~= frame then
        cached_frame = frame
        cached_lit_areas = CollectLitAreas()
    end

    return cached_lit_areas
end

---Returns the centre of the entity hitbox, or its position if it has no hitbox.
---@param entity_id number Entity ID.
---@return number|nil x, number|nil y
local function GetEntityCenter(entity_id)
    local x, y = EntityGetFirstHitboxCenter(entity_id)
    if x == nil then
        x, y = EntityGetTransform(entity_id)
    end

    return x, y
end

---Checks whether a world point is illuminated by a light source.
---@param x number World X coordinate.
---@param y number World Y coordinate.
---@return boolean
local function IsPointVisible(x, y)
    if x == nil or y == nil then
        return false
    end

    for _, area in ipairs(GetLitAreasForFrame()) do
        local dx = x - area[1]
        local dy = y - area[2]
        if dx * dx + dy * dy <= area[3] then
            return true
        end
    end

    return false
end

---Checks whether an entity is illuminated by a light source.
---@param entity_id number Entity ID.
---@return boolean
local function IsEntityVisible(entity_id)
    if entity_id == nil or entity_id == 0 or not EntityGetIsAlive(entity_id) then
        return false
    end

    local x, y = GetEntityCenter(entity_id)
    return IsPointVisible(x, y)
end

return {
    GetLitAreas = GetLitAreasForFrame,
    IsPointVisible = IsPointVisible,
    IsEntityVisible = IsEntityVisible,
}
