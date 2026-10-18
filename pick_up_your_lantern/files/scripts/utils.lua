---Utility functions for Pick Up Your Lantern mod.

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

