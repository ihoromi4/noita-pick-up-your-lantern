---Utility functions for Pick Up Your Lantern mod.

local PLAYER_TAG = "player_unit"

-- Player storage with a lantern thrown with the left mouse button, to be returned to the hand.
RETURN_LANTERN_STORAGE = "pul_return_lantern_id"

-- Tag of entities and their LightComponents that count as light for enemy study: lanterns, the Light spell modifier.
-- Lantern XML files declare it directly, so a change here must be repeated there.
LIGHT_SOURCE_TAG = "pul_light_source"

-- Tag of fire-related enemies, set by the fire enemy glow when it lights them.
FIRE_ENEMY_TAG = "pul_fire_enemy"
-- Tag of enemies the fire enemy glow has checked: only then is it known whether they are fire-related.
FIRE_GLOW_CHECKED_TAG = "pul_fire_glow_checked"

---Finds an existing VariableStorageComponent by name without creating one.
---@param entity_id number The target entity ID.
---@param name string The unique name of the variable storage.
---@return number|nil component_id The found component ID, or nil if the entity has none.
function FindVariableStorage(entity_id, name)
    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent") or {}) do
        if ComponentGetValue2(comp, "name") == name then
            return comp
        end
    end

    return nil
end

---Retrieves an existing VariableStorageComponent by name, or creates a new one.
---@param entity_id number The target entity ID.
---@param name string The unique name of the variable storage.
---@return number component_id The found or newly created component ID.
function GetOrCreateVariableStorage(entity_id, name)
    local comp = FindVariableStorage(entity_id, name)
    if comp ~= nil then
        return comp
    end

    return EntityAddComponent2(entity_id, "VariableStorageComponent", {
        _tags = "enabled_in_world,enabled_in_hand,enabled_in_inventory",
        name = name,
        value_float = 0.0,
    })
end

---Reads a float value from a named VariableStorageComponent. A missing storage reads as 0 and is not created, so
---reading does not add components to every entity it checks.
---@param entity_id number The target entity ID.
---@param name string The variable storage name.
---@return number value The float value stored, or 0.0 if not found.
function GetStorageFloat(entity_id, name)
    local comp = FindVariableStorage(entity_id, name)
    if comp == nil then
        return 0.0
    end

    return ComponentGetValue2(comp, "value_float") or 0.0
end

---Writes a float value to a named VariableStorageComponent.
---@param entity_id number The target entity ID.
---@param name string The variable storage name.
---@param value number The float value to write.
function SetStorageFloat(entity_id, name, value)
    local comp = GetOrCreateVariableStorage(entity_id, name)
    ComponentSetValue2(comp, "value_float", value)
end

---Reads a string value from a named VariableStorageComponent.
---@param entity_id number The target entity ID.
---@param name string The variable storage name.
---@return string value The string value stored, or an empty string if not found. Not created when missing.
function GetStorageString(entity_id, name)
    local comp = FindVariableStorage(entity_id, name)
    if comp == nil then
        return ""
    end

    return ComponentGetValue2(comp, "value_string") or ""
end

---Writes a string value to a named VariableStorageComponent.
---@param entity_id number The target entity ID.
---@param name string The variable storage name.
---@param value string The string value to write.
function SetStorageString(entity_id, name, value)
    local comp = GetOrCreateVariableStorage(entity_id, name)
    ComponentSetValue2(comp, "value_string", value)
end

---Finds the player entity, ignoring polymorphed forms that have no inventory.
---@return number player_id Player entity ID, or 0 if not found.
function FindPlayer()
    local players = EntityGetWithTag(PLAYER_TAG) or {}
    return players[1] or 0
end

---Returns the item currently held by the player.
---@param player_id number Player entity ID.
---@return number item_id Held item entity ID, or 0 if the hands are empty.
function GetHeldItem(player_id)
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

---Puts an inventory item into the player's hands.
---The engine switches from mActualActiveItem to mActiveItem, unequipping the item that was in hand.
---When that item is gone, resetting mActualActiveItem makes the engine equip mActiveItem anyway,
---as vanilla perk_list.lua does. Resetting it while an item is still equipped leaves that item
---stuck in its in-hand state.
---@param player_id number Player entity ID.
---@param item_id number Item entity ID from the player's inventory.
---@param is_held_item_gone boolean Whether the item currently in hand has been removed.
---@return nil
function SelectHeldItem(player_id, item_id, is_held_item_gone)
    local inventory_comp = EntityGetFirstComponentIncludingDisabled(player_id, "Inventory2Component")
    if inventory_comp == nil then
        return
    end

    ComponentSetValue2(inventory_comp, "mActiveItem", item_id)
    if is_held_item_gone then
        ComponentSetValue2(inventory_comp, "mActualActiveItem", 0)
    end
end
