--- Throw callback for lanterns: marks a lantern thrown with the left mouse button to be returned to the hand.
--- Clearing the fire button in OnWorldPreUpdate does not stop the vanilla item throw, so a left-button throw
--- still happens when there is no ceiling to hang the lantern on. UpdateLanternHang returns the lantern on the
--- next frame, outside of the engine throw. Lantern types that cannot be hung are thrown with the left button as usual.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")

-- The throw is released after the throw animation, a few frames after the click.
local THROW_INPUT_WINDOW = 60

---Checks whether the last throw input of the player came from the left mouse button.
---Drops from the open inventory are dragged with the left button too, so they are excluded.
---@param player_id number Player entity ID.
---@return boolean
local function IsThrownWithLeftButton(player_id)
    local inventory_gui = EntityGetFirstComponentIncludingDisabled(player_id, "InventoryGuiComponent")
    if inventory_gui ~= nil and ComponentGetValue2(inventory_gui, "mActive") then
        return false
    end

    local controls_comp = EntityGetFirstComponent(player_id, "ControlsComponent")
    if controls_comp == nil then
        return false
    end

    local fire_frame = ComponentGetValue2(controls_comp, "mButtonFrameFire")
    local throw_frame = ComponentGetValue2(controls_comp, "mButtonFrameThrow")
    return fire_frame > throw_frame and GameGetFrameNum() - fire_frame <= THROW_INPUT_WINDOW
end

---Called by Noita engine when the lantern receives Message_ThrowItem.
---@param from_x number Throw start X coordinate.
---@param from_y number Throw start Y coordinate.
---@param to_x number Throw target X coordinate.
---@param to_y number Throw target Y coordinate.
function throw_item(from_x, from_y, to_x, to_y)
    local player_id = FindPlayer()
    if player_id == 0 or not IsThrownWithLeftButton(player_id) then
        return
    end

    local lantern_id = GetUpdatedEntityID()
    local _, lantern_type = GetLanternType(lantern_id)
    if lantern_type.hang_offset_y == nil then
        return
    end

    SetStorageFloat(player_id, RETURN_LANTERN_STORAGE, lantern_id)
end
