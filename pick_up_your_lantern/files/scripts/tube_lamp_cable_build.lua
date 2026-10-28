--- Builds a dangling tube lamp cable on its first update: a physics chain of segments attached to the ceiling,
--- like the vanilla temple lantern chain. The body is initialized from the entity's own script, as vanilla does:
--- called right after EntityLoad from a world callback, the initialization creates no bodies.
--- tube_lamp_cable.lua sets the number of segments and their length in storages right after spawning the cable.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local SEGMENT_COUNT_STORAGE = "cable_segment_count"
local SEGMENT_LENGTH_STORAGE = "cable_segment_length"
local SEGMENT_IMAGE = "data/props_breakable_gfx/wire_vertical_5_00.png"
local SEGMENT_MATERIAL = "metal_wire_nohit"

-- Joints as in the vanilla temple lantern chain.
local CEILING_BREAK_FORCE = 15
local CEILING_BREAK_DISTANCE = 20
local SEGMENT_BREAK_FORCE = 6
local SEGMENT_BREAK_DISTANCE = 3

local entity_id = GetUpdatedEntityID()
local segment_count = math.floor(GetStorageFloat(entity_id, SEGMENT_COUNT_STORAGE))
local segment_length = GetStorageFloat(entity_id, SEGMENT_LENGTH_STORAGE)
if segment_count <= 0 or segment_length <= 0 then
    return
end

local material = CellFactory_GetType(SEGMENT_MATERIAL)
for index = 1, segment_count do
    local top = (index - 1) * segment_length
    EntityAddComponent2(entity_id, "PhysicsImageShapeComponent", {
        body_id = index,
        offset_x = 0,
        offset_y = top,
        image_file = SEGMENT_IMAGE,
        material = material,
    })
    if index == 1 then
        EntityAddComponent2(entity_id, "PhysicsJoint2Component", {
            type = "REVOLUTE_JOINT_ATTACH_TO_NEARBY_SURFACE",
            offset_x = 0.5,
            offset_y = top,
            body1_id = index,
            break_force = CEILING_BREAK_FORCE,
            break_distance = CEILING_BREAK_DISTANCE,
            ray_x = 0,
            ray_y = -16,
        })
    else
        EntityAddComponent2(entity_id, "PhysicsJoint2Component", {
            type = "REVOLUTE_JOINT",
            offset_x = 0.5,
            offset_y = top,
            body1_id = index - 1,
            body2_id = index,
            break_force = SEGMENT_BREAK_FORCE,
            break_distance = SEGMENT_BREAK_DISTANCE,
        })
    end
end

PhysicsBody2InitFromComponents(entity_id)
if #(PhysicsBodyIDGetFromEntity(entity_id) or {}) == 0 then
    local x, y = EntityGetTransform(entity_id)
    print(string.format("[%s] ERROR: Tube lamp cable at %d, %d has no physics bodies", MOD_ID, x, y))
end
EntityRemoveComponent(entity_id, GetUpdatedComponentID())
