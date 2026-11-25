--- Item Radar filter for Pick Up Your Lantern mod.
--- Returns a replacement for EntityGetInRadiusWithTag used by data/scripts/perks/radar_item.lua.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local SETTING_ID = MOD_ID .. ".show_lanterns_on_item_radar"
local RADAR_TAG = "item_pickup"
local LANTERN_TAG = "lantern"

local EntityGetInRadiusWithTagOriginal = EntityGetInRadiusWithTag

---Returns entities in radius with tag, excluding lanterns from Item Radar results unless enabled in settings.
---@param x number Center X coordinate.
---@param y number Center Y coordinate.
---@param radius number Search radius.
---@param tag string Entity tag to search for.
---@return number[]
local function EntityGetInRadiusWithTagFiltered(x, y, radius, tag)
    local entities = EntityGetInRadiusWithTagOriginal(x, y, radius, tag)
    if tag ~= RADAR_TAG or ModSettingGet(SETTING_ID) == true then
        return entities
    end

    local filtered = {}
    for _, entity_id in ipairs(entities) do
        if not EntityHasTag(entity_id, LANTERN_TAG) then
            filtered[#filtered + 1] = entity_id
        end
    end
    return filtered
end

return EntityGetInRadiusWithTagFiltered
