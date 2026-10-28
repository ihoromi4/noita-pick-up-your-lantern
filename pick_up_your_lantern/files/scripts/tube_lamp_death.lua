---Handles destruction effects for tube lamps.
---Releases a fixed amount of electric sparks (40); the explosion itself comes from ExplodeOnDamageComponent.

dofile_once("data/scripts/lib/utilities.lua")

local SPARK_COUNT = 40

---Called by Noita engine when the entity dies.
---@param damage_type_bit_field number Bitfield of damage types dealt.
---@param damage_message string Description of damage source.
---@param entity_thats_responsible number Entity ID responsible for death.
---@param drop_items boolean Whether the entity should drop items.
function death(damage_type_bit_field, damage_message, entity_thats_responsible, drop_items)
    local entity_id = GetUpdatedEntityID()
    local pos_x, pos_y = EntityGetTransform(entity_id)

    GameCreateParticle("spark_electric", pos_x, pos_y, SPARK_COUNT, 0, 0, false)
end
