---Handles destruction effects for chain torches.
---Scatters the burning coals as fire and sparks of the torch type; the pop itself comes from ExplodeOnDamageComponent.

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/pick_up_your_lantern/files/scripts/lantern_traits.lua")

local FIRE_COUNT = 8
local SPARK_COUNT = 12
-- The coals lie below the top of the bail, which is the torch origin.
local COALS_OFFSET_Y = 7

---Called by Noita engine when the entity dies.
---@param damage_type_bit_field number Bitfield of damage types dealt.
---@param damage_message string Description of damage source.
---@param entity_thats_responsible number Entity ID responsible for death.
---@param drop_items boolean Whether the entity should drop items.
function death(damage_type_bit_field, damage_message, entity_thats_responsible, drop_items)
    local entity_id = GetUpdatedEntityID()
    local pos_x, pos_y = EntityGetTransform(entity_id)
    local _, lantern_type = GetLanternType(entity_id)
    local spark_material = lantern_type.open_fire ~= nil and lantern_type.open_fire.spark_material or "spark"

    GameCreateParticle("fire", pos_x, pos_y + COALS_OFFSET_Y, FIRE_COUNT, 0, 0, false)
    GameCreateParticle(spark_material, pos_x, pos_y + COALS_OFFSET_Y, SPARK_COUNT, 0, -20, false)
end
