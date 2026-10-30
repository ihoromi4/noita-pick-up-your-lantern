---Handles destruction effects for chain torches.
---Scatters the burning coals as fire and sparks of the torch type; the pop itself comes from ExplodeOnDamageComponent.

dofile_once("data/scripts/lib/utilities.lua")

local FIRE_COUNT = 8
local SPARK_COUNT = 12
-- The coals lie below the top of the bail, which is the torch origin.
local COALS_OFFSET_Y = 7
local SPARK_MATERIAL_STORAGE = "chain_torch_spark_material"

---Returns the spark material of the torch type, kept in its XML file.
---@param entity_id number Torch entity ID.
---@return string
local function GetSparkMaterial(entity_id)
    for _, storage_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "VariableStorageComponent") or {}) do
        if ComponentGetValue2(storage_comp, "name") == SPARK_MATERIAL_STORAGE then
            return ComponentGetValue2(storage_comp, "value_string")
        end
    end

    return "spark"
end

---Called by Noita engine when the entity dies.
---@param damage_type_bit_field number Bitfield of damage types dealt.
---@param damage_message string Description of damage source.
---@param entity_thats_responsible number Entity ID responsible for death.
---@param drop_items boolean Whether the entity should drop items.
function death(damage_type_bit_field, damage_message, entity_thats_responsible, drop_items)
    local entity_id = GetUpdatedEntityID()
    local pos_x, pos_y = EntityGetTransform(entity_id)

    GameCreateParticle("fire", pos_x, pos_y + COALS_OFFSET_Y, FIRE_COUNT, 0, 0, false)
    GameCreateParticle(GetSparkMaterial(entity_id), pos_x, pos_y + COALS_OFFSET_Y, SPARK_COUNT, 0, -20, false)
end
