--- Belt lantern for Pick Up Your Lantern mod.
--- Shows the first lantern of the quick inventory on the player's belt while the hands hold anything
--- but a lantern, and gives it a dim passive light. Holding any lantern hides the belt lantern.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local PLAYER_TAG = "player_unit"
local LANTERN_TAG = "lantern"
local BELT_TAG = "pul_belt"
local BELT_ENTITY_PATH = "mods/" .. MOD_ID .. "/files/entities/lantern_belt.xml"
local QUICK_INVENTORY_NAME = "inventory_quick"
local LANTERN_ID_STORAGE = "belt_lantern_id"
local LANTERN_LIT_STORAGE = "belt_lantern_lit"
local LIGHT_SCALE_SETTING_ID = MOD_ID .. ".belt_light_scale"
local DEFAULT_LIGHT_SCALE = 0.5

-- Belt lantern is smaller than the one in hand so it does not reach below the feet.
local SPRITE_SCALE = 0.6
-- Player is drawn at 0.6, lower values are drawn in front of it.
local SPRITE_Z_INDEX = 0.5

---Retrieves the share of the in-hand light radius and fog of war hole used by the belt lantern.
---@return number
local function GetBeltLightScale()
    local val = ModSettingGet(LIGHT_SCALE_SETTING_ID)
    if val == nil then
        val = ModSettingGetNextValue(LIGHT_SCALE_SETTING_ID)
    end
    local scale_num = tonumber(val)
    if scale_num == nil or scale_num < 0 then
        return DEFAULT_LIGHT_SCALE
    end

    return scale_num
end
---Finds the player entity, ignoring polymorphed forms that have no inventory.
---@return number player_id Player entity ID, or 0 if not found.
local function FindPlayer()
    local players = EntityGetWithTag(PLAYER_TAG) or {}
    return players[1] or 0
end

---Returns the item currently held by the player.
---@param player_id number Player entity ID.
---@return number item_id Held item entity ID, or 0 if the hands are empty.
local function GetHeldItem(player_id)
    local inventory_comp = EntityGetFirstComponentIncludingDisabled(player_id, "Inventory2Component")
    if inventory_comp == nil then
        return 0
    end

    local item_id = ComponentGetValue2(inventory_comp, "mActiveItem") or 0
    if item_id ~= 0 and not EntityGetIsAlive(item_id) then
        return 0
    end

    return item_id
end

---Finds the lantern in the lowest quick inventory slot.
---@param player_id number Player entity ID.
---@return number lantern_id Lantern entity ID, or 0 if the quick inventory has no lanterns.
local function FindFirstLantern(player_id)
    local quick_inventory = 0
    for _, child_id in ipairs(EntityGetAllChildren(player_id) or {}) do
        if EntityGetName(child_id) == QUICK_INVENTORY_NAME then
            quick_inventory = child_id
            break
        end
    end
    if quick_inventory == 0 then
        return 0
    end

    local first_lantern = 0
    local first_slot = math.huge
    for _, item_id in ipairs(EntityGetAllChildren(quick_inventory) or {}) do
        if EntityHasTag(item_id, LANTERN_TAG) then
            local item_comp = EntityGetFirstComponentIncludingDisabled(item_id, "ItemComponent")
            local slot = item_comp ~= nil and ComponentGetValue2(item_comp, "inventory_slot") or math.huge
            if slot < first_slot then
                first_lantern = item_id
                first_slot = slot
            end
        end
    end

    return first_lantern
end

---Finds the in-hand SpriteComponent of a lantern; it shows the flame, or the burned-out variant.
---@param lantern_id number Lantern entity ID.
---@return number|nil sprite_comp
local function GetHandSprite(lantern_id)
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(lantern_id, "SpriteComponent") or {}) do
        if ComponentGetValue2(sprite_comp, "image_file"):find("_in_hand") then
            return sprite_comp
        end
    end

    return nil
end

---Spawns the belt lantern and attaches it to the player.
---The sprite, light and fog of war hole are copied from the carried lantern.
---@param player_id number Player entity ID.
---@param lantern_id number Carried lantern entity ID.
---@param is_lit boolean Whether the belt lantern emits light.
---@return number belt_id Belt lantern entity ID, or 0 if it could not be spawned.
local function SpawnBelt(player_id, lantern_id, is_lit)
    local hand_sprite = GetHandSprite(lantern_id)
    if hand_sprite == nil then
        return 0
    end

    -- Spawned at the player, as the attached entity is not moved to the belt until the next update.
    local x, y = EntityGetTransform(player_id)
    local belt_id = EntityLoad(BELT_ENTITY_PATH, x, y)
    if belt_id == nil or belt_id == 0 then
        return 0
    end

    EntityAddComponent2(belt_id, "SpriteComponent", {
        image_file = ComponentGetValue2(hand_sprite, "image_file"),
        offset_x = ComponentGetValue2(hand_sprite, "offset_x"),
        offset_y = ComponentGetValue2(hand_sprite, "offset_y"),
        rect_animation = "default",
        z_index = SPRITE_Z_INDEX,
        has_special_scale = true,
        special_scale_x = SPRITE_SCALE,
        special_scale_y = SPRITE_SCALE,
    })

    if is_lit then
        local lantern_light = EntityGetFirstComponentIncludingDisabled(lantern_id, "LightComponent")
        EntityAddComponent2(belt_id, "LightComponent", {
            radius = 0,
            r = lantern_light ~= nil and ComponentGetValue2(lantern_light, "r") or 255,
            g = lantern_light ~= nil and ComponentGetValue2(lantern_light, "g") or 255,
            b = lantern_light ~= nil and ComponentGetValue2(lantern_light, "b") or 255,
            update_properties = true,
        })

        local fog_hole_sprite = GetFogHoleSprite(lantern_id)
        if fog_hole_sprite ~= nil then
            EntityAddComponent2(belt_id, "SpriteComponent", {
                image_file = ComponentGetValue2(fog_hole_sprite, "image_file"),
                alpha = ComponentGetValue2(fog_hole_sprite, "alpha"),
                smooth_filtering = true,
                fog_of_war_hole = true,
                has_special_scale = true,
                special_scale_x = 0,
                special_scale_y = 0,
            })
        end
    end

    SetStorageFloat(belt_id, LANTERN_ID_STORAGE, lantern_id)
    SetStorageFloat(belt_id, LANTERN_LIT_STORAGE, is_lit and 1 or 0)
    EntityAddChild(player_id, belt_id)

    return belt_id
end

---Checks whether an existing belt lantern still shows the given lantern in the given state.
---@param belt_id number Belt lantern entity ID.
---@param player_id number Player entity ID.
---@param lantern_id number Carried lantern entity ID.
---@param is_lit boolean Whether the carried lantern is lit.
---@return boolean
local function IsBeltUpToDate(belt_id, player_id, lantern_id, is_lit)
    return EntityGetParent(belt_id) == player_id
        and GetStorageFloat(belt_id, LANTERN_ID_STORAGE) == lantern_id
        and (GetStorageFloat(belt_id, LANTERN_LIT_STORAGE) > 0) == is_lit
end

---Scales the belt light and fog of war hole by the lantern tier, illumination setting and modifier.
---@param belt_id number Belt lantern entity ID.
---@param lantern_id number Carried lantern entity ID.
---@return nil
local function UpdateBeltLight(belt_id, lantern_id)
    local scale = GetIlluminationScale() * GetLanternTierMultiplier(lantern_id) * GetBeltLightScale()

    local light_comp = EntityGetFirstComponent(belt_id, "LightComponent")
    if light_comp ~= nil then
        local radius = math.floor(GetLanternLightRadius(lantern_id, scale) * GetLanternModifierFactor(lantern_id))
        ComponentSetValue2(light_comp, "update_properties", true)
        ComponentSetValue2(light_comp, "radius", radius)
    end

    local fog_hole_sprite = GetFogHoleSprite(belt_id)
    local fog_hole_scale = GetLanternFogHoleScale(lantern_id, scale)
    if fog_hole_sprite ~= nil and ComponentGetValue2(fog_hole_sprite, "special_scale_x") ~= fog_hole_scale then
        ComponentSetValue2(fog_hole_sprite, "special_scale_x", fog_hole_scale)
        ComponentSetValue2(fog_hole_sprite, "special_scale_y", fog_hole_scale)
        EntityRefreshSprite(belt_id, fog_hole_sprite)
    end
end

---Shows, updates or removes the belt lantern. Runs every frame in OnWorldPostUpdate.
---The belt lantern burns the fuel of a short-lived lantern while it is lit; the lantern itself goes out
---the next time it is held or dropped, so its disabled inventory components are left untouched.
---@return nil
function UpdateLanternBelt()
    local player_id = FindPlayer()
    local lantern_id = 0
    if player_id ~= 0 then
        local held_id = GetHeldItem(player_id)
        if held_id == 0 or not EntityHasTag(held_id, LANTERN_TAG) then
            lantern_id = FindFirstLantern(player_id)
        end
    end

    local is_lit = lantern_id ~= 0 and not IsLanternExtinguished(lantern_id) and ConsumeLanternFuel(lantern_id)

    -- Belt lanterns restored with the player after loading or polymorph refer to stale lantern IDs.
    local belt_id = 0
    for _, entity_id in ipairs(EntityGetWithTag(BELT_TAG) or {}) do
        if belt_id == 0 and lantern_id ~= 0 and IsBeltUpToDate(entity_id, player_id, lantern_id, is_lit) then
            belt_id = entity_id
        else
            EntityKill(entity_id)
        end
    end

    if lantern_id == 0 then
        return
    end
    if belt_id == 0 then
        belt_id = SpawnBelt(player_id, lantern_id, is_lit)
        if belt_id == 0 then
            return
        end
    end

    local _, _, _, player_scale_x = EntityGetTransform(player_id)
    local facing = (player_scale_x or 1) < 0 and -1 or 1
    local x, y, rotation = EntityGetTransform(belt_id)
    EntitySetTransform(belt_id, x, y, rotation, facing, 1)

    if is_lit then
        UpdateBeltLight(belt_id, lantern_id)
    end
end
