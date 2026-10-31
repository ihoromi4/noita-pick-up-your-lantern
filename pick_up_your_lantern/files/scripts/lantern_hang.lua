--- Hanging a held lantern for Pick Up Your Lantern mod.
--- The left mouse button no longer throws a held lantern: it hangs the lantern on the ceiling above the player,
--- or keeps it in hand if there is no ceiling within reach. The right mouse button keeps the vanilla throw.
--- A joint is only created when a physics body is first initialized, so the lantern cannot be nailed back
--- in place: the held lantern is replaced by a freshly spawned one that takes over its state.
--- The vanilla throw on the left button cannot be stopped, so lantern_throw.lua marks such a throw
--- and the lantern is returned to the hand here.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local LANTERN_TAG = "lantern"
local WAND_TAG = "wand"
local QUICK_INVENTORY_NAME = "inventory_quick"
local STORAGE_FIELDS = {
    "value_string",
    "value_int",
    "value_float",
    "value_bool",
}

-- How far above the player a ceiling is searched for, in pixels.
local HANG_MAX_DISTANCE = 16

local last_click_frame = -1

---Copies the lantern state kept in VariableStorageComponents and the remaining health.
---@param source_id number Lantern entity ID to copy from.
---@param target_id number Lantern entity ID to copy to.
---@return nil
local function CopyLanternState(source_id, target_id)
    for _, source_comp in ipairs(EntityGetComponentIncludingDisabled(source_id, "VariableStorageComponent") or {}) do
        local target_comp = GetOrCreateVariableStorage(target_id, ComponentGetValue2(source_comp, "name"))
        for _, field in ipairs(STORAGE_FIELDS) do
            ComponentSetValue2(target_comp, field, ComponentGetValue2(source_comp, field))
        end
    end

    local source_damage = EntityGetFirstComponentIncludingDisabled(source_id, "DamageModelComponent")
    local target_damage = EntityGetFirstComponentIncludingDisabled(target_id, "DamageModelComponent")
    if source_damage ~= nil and target_damage ~= nil then
        ComponentSetValue2(target_damage, "hp", ComponentGetValue2(source_damage, "hp"))
    end
end

---Replaces the held lantern with a lantern hanging on the ceiling.
---@param lantern_id number Held lantern entity ID.
---@param lantern_file string Entity file to load the hanging lantern from.
---@param hang_offset_y number Origin of the hanging lantern below the ceiling, in pixels.
---@param ceiling_x number World X coordinate of the ceiling surface.
---@param ceiling_y number World Y coordinate of the ceiling surface.
---@return boolean hung Whether the lantern was hung.
local function HangLantern(lantern_id, lantern_file, hang_offset_y, ceiling_x, ceiling_y)
    local hung_id = EntityLoad(lantern_file, ceiling_x, ceiling_y + hang_offset_y)
    if hung_id == nil or hung_id == 0 then
        return false
    end

    CopyLanternState(lantern_id, hung_id)
    -- The tier is already set, so this only refreshes the name and description and attaches the modifier script.
    EnsureLanternTraits(hung_id)
    if IsLanternExtinguished(hung_id) then
        ExtinguishLantern(hung_id)
    else
        -- The copied applied scale does not match the XML values of the new components, so apply it right away.
        ApplyLanternIllumination(hung_id, GetIlluminationScale() * GetLanternLiquidStateMultiplier(hung_id))
    end

    -- Death scripts spill burning oil; the held lantern is removed, not shattered.
    for _, lua_comp in ipairs(EntityGetComponentIncludingDisabled(lantern_id, "LuaComponent") or {}) do
        if ComponentGetValue2(lua_comp, "script_death") ~= "" then
            EntityRemoveComponent(lantern_id, lua_comp)
        end
    end
    EntityKill(lantern_id)

    return true
end

---Finds the item to take in hand once the held lantern is gone: the wand in the lowest quick inventory slot,
---otherwise the item in the lowest slot.
---@param player_id number Player entity ID.
---@param excluded_id number Item entity ID to skip.
---@return number item_id Item entity ID, or 0 if the quick inventory has nothing else.
local function FindNextHeldItem(player_id, excluded_id)
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

    local next_item = 0
    local next_is_wand = false
    local next_slot = math.huge
    for _, item_id in ipairs(EntityGetAllChildren(quick_inventory) or {}) do
        if item_id ~= excluded_id then
            local is_wand = EntityHasTag(item_id, WAND_TAG)
            local item_comp = EntityGetFirstComponentIncludingDisabled(item_id, "ItemComponent")
            local slot = item_comp ~= nil and ComponentGetValue2(item_comp, "inventory_slot") or math.huge
            if (is_wand and not next_is_wand) or (is_wand == next_is_wand and slot < next_slot) then
                next_item = item_id
                next_is_wand = is_wand
                next_slot = slot
            end
        end
    end

    return next_item
end

---Puts a lantern thrown with the left mouse button back into the player's hands.
---@param player_id number Player entity ID.
---@return nil
local function ReturnThrownLantern(player_id)
    local lantern_id = GetStorageFloat(player_id, RETURN_LANTERN_STORAGE)
    if lantern_id == 0 then
        return
    end
    SetStorageFloat(player_id, RETURN_LANTERN_STORAGE, 0)

    if EntityGetIsAlive(lantern_id) and EntityGetRootEntity(lantern_id) == lantern_id then
        GamePickUpInventoryItem(player_id, lantern_id, false)
        -- After the throw the engine has already equipped another item, which has to be unequipped properly.
        SelectHeldItem(player_id, lantern_id, false)
    end
end

---Checks whether the inventory window is open, where clicks belong to the inventory.
---@param player_id number Player entity ID.
---@return boolean
local function IsInventoryOpen(player_id)
    local inventory_gui = EntityGetFirstComponentIncludingDisabled(player_id, "InventoryGuiComponent")
    return inventory_gui ~= nil and ComponentGetValue2(inventory_gui, "mActive")
end

---Takes over the left mouse button while a lantern is held. Runs every frame in OnWorldPreUpdate.
---The click is handled right away, while the vanilla throw waits for the end of the throw animation.
---@return nil
function UpdateLanternHang()
    local player_id = FindPlayer()
    if player_id == 0 then
        return
    end

    ReturnThrownLantern(player_id)

    local lantern_id = GetHeldItem(player_id)
    if lantern_id == 0 or not EntityHasTag(lantern_id, LANTERN_TAG) then
        return
    end

    local controls_comp = EntityGetFirstComponent(player_id, "ControlsComponent")
    if controls_comp == nil then
        return
    end

    -- The click frame may be written either before or after this hook in a frame, so a one-frame lag is accepted.
    local click_frame = ComponentGetValue2(controls_comp, "mButtonFrameFire")
    if click_frame == last_click_frame or GameGetFrameNum() - click_frame > 1 then
        return
    end
    last_click_frame = click_frame

    if IsInventoryOpen(player_id) then
        return
    end

    -- A lantern that cannot be hung is thrown with the left button as usual, see lantern_throw.lua.
    -- The first file of the type is the one to hang, whichever file the held lantern was loaded from.
    local _, lantern_type = GetLanternType(lantern_id)
    local lantern_file = lantern_type.files[1]
    if lantern_type.hang_offset_y == nil then
        return
    end

    local x, y = EntityGetTransform(player_id)
    local has_ceiling, ceiling_x, ceiling_y = RaytraceSurfaces(x, y, x, y - HANG_MAX_DISTANCE)
    if has_ceiling and HangLantern(lantern_id, lantern_file, lantern_type.hang_offset_y, ceiling_x, ceiling_y) then
        local next_item = FindNextHeldItem(player_id, lantern_id)
        if next_item ~= 0 then
            SelectHeldItem(player_id, next_item, true)
        end
    end
end
