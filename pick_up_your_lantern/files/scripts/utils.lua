---Utility functions for Pick Up Your Lantern mod.

local PLAYER_TAG = "player_unit"

---Retrieves an existing VariableStorageComponent by name, or creates a new one.
---@param entity_id number The target entity ID.
---@param name string The unique name of the variable storage.
---@return number component_id The found or newly created component ID.
function GetOrCreateVariableStorage(entity_id, name)
    local comps = EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent")
    if comps ~= nil then
        for _, comp in ipairs(comps) do
            if ComponentGetValue2(comp, "name") == name then
                return comp
            end
        end
    end

    return EntityAddComponent2(entity_id, "VariableStorageComponent", {
        _tags = "enabled_in_world,enabled_in_hand,enabled_in_inventory",
        name = name,
        value_float = 0.0,
    })
end

---Reads a float value from a named VariableStorageComponent.
---@param entity_id number The target entity ID.
---@param name string The variable storage name.
---@return number value The float value stored, or 0.0 if not found.
function GetStorageFloat(entity_id, name)
    local comp = GetOrCreateVariableStorage(entity_id, name)
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
---@return string value The string value stored, or an empty string if not found.
function GetStorageString(entity_id, name)
    local comp = GetOrCreateVariableStorage(entity_id, name)
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
