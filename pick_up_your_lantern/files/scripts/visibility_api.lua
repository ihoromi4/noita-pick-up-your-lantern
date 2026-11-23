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

-- Share of the lantern light radius that looks lit: the soft outer edge of the light does not count.
local LIT_RADIUS_FACTOR = 0.6

local cached_frame = nil
local cached_lit_areas = {}

---Gathers the areas lit by light sources: lanterns in the world and in the player's hands, and projectiles with
---the Light spell modifier. Lanterns in the inventory have their light disabled, extinguished lanterns have none,
---and the belt lantern is a separate entity without the light source tag, so none of them count.
---Only the tagged LightComponent is read, as a projectile may also carry its own light.
---@return table[] areas Lit circles as `{ x, y, radius_sq }`.
local function CollectLitAreas()
    local areas = {}
    for _, source_id in ipairs(EntityGetWithTag(LIGHT_SOURCE_TAG) or {}) do
        local light_comp = EntityGetFirstComponent(source_id, "LightComponent", LIGHT_SOURCE_TAG)
        if light_comp ~= nil then
            -- The current radius already includes the quality tier, liquid state and modifiers of lanterns.
            local radius = ComponentGetValue2(light_comp, "radius") * LIT_RADIUS_FACTOR
            local x, y = EntityGetTransform(source_id)
            if radius > 0 and x ~= nil then
                table.insert(areas, { x, y, radius * radius, })
            end
        end
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
    IsPointVisible = IsPointVisible,
    IsEntityVisible = IsEntityVisible,
}
