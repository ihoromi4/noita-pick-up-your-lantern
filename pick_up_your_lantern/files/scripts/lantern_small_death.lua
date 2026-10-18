---Handles destruction effects for small lanterns.
---Spills fixed amount of oil (4) and fire (2), and loads vanilla death particles.

dofile_once("data/scripts/lib/utilities.lua")

local OIL_COUNT = 4
local FIRE_COUNT = 2

---Called by Noita engine when the entity dies.
---@param damage_type_bit_field number Bitfield of damage types dealt.
---@param damage_message string Description of damage source.
---@param entity_thats_responsible number Entity ID responsible for death.
---@param drop_items boolean Whether the entity should drop items.
function death(damage_type_bit_field, damage_message, entity_thats_responsible, drop_items)
    local entity_id = GetUpdatedEntityID()
    local pos_x, pos_y = EntityGetTransform(entity_id)

    GameCreateParticle("oil", pos_x, pos_y, OIL_COUNT, 0, 0, false)
    GameCreateParticle("fire", pos_x, pos_y, FIRE_COUNT, 0, 0, false)

    EntityLoad("data/entities/particles/lantern_small_death.xml", pos_x, pos_y)
end
