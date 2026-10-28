--- Sparks from the end of a dangling tube lamp cable, every 10 frames.
--- The first spark comes SPARK_DELAY_FRAMES after the cable broke, so the player who broke it is not shocked
--- right away. The cable is live for LIVE_FRAMES, then the script removes itself and the cable stays dead.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local AGE_STORAGE = "cable_age_frames"
local ANCHOR_X_STORAGE = "cable_anchor_x"
local ANCHOR_Y_STORAGE = "cable_anchor_y"
local SEGMENT_LENGTH_STORAGE = "cable_segment_length"
local UPDATE_INTERVAL_FRAMES = 10
local SPARK_DELAY_FRAMES = 2 * 60
local SPARK_INTERVAL_FRAMES = 60
local LIVE_FRAMES = 3 * 60 * 60
local SPARK_ENTITY_PATH = "data/entities/misc/electricity_weak.xml"
local SPARK_PARTICLE_COUNT = 6

---Finds the end of the cable: the end of the segment body farthest from the ceiling anchor.
---@param entity_id number Cable entity ID.
---@return number|nil x
---@return number|nil y
local function FindCableEnd(entity_id)
    local anchor_x = GetStorageFloat(entity_id, ANCHOR_X_STORAGE)
    local anchor_y = GetStorageFloat(entity_id, ANCHOR_Y_STORAGE)
    local segment_length = GetStorageFloat(entity_id, SEGMENT_LENGTH_STORAGE)

    local end_x, end_y = nil, nil
    local farthest = -1
    for _, body_id in ipairs(PhysicsBodyIDGetFromEntity(entity_id) or {}) do
        local body_x, body_y, angle = PhysicsBodyIDGetTransform(body_id)
        if body_x ~= nil then
            local x, y = PhysicsPosToGamePos(body_x, body_y)
            -- The body origin is the upper end of its segment; the segment points down in its local space.
            x = x - math.sin(angle) * segment_length
            y = y + math.cos(angle) * segment_length
            local distance = (x - anchor_x) ^ 2 + (y - anchor_y) ^ 2
            if distance > farthest then
                farthest = distance
                end_x, end_y = x, y
            end
        end
    end

    return end_x, end_y
end

local entity_id = GetUpdatedEntityID()
local age = GetStorageFloat(entity_id, AGE_STORAGE) + UPDATE_INTERVAL_FRAMES
SetStorageFloat(entity_id, AGE_STORAGE, age)

if age > LIVE_FRAMES then
    EntityRemoveComponent(entity_id, GetUpdatedComponentID())
elseif age >= SPARK_DELAY_FRAMES and age % SPARK_INTERVAL_FRAMES < UPDATE_INTERVAL_FRAMES then
    local x, y = FindCableEnd(entity_id)
    if x ~= nil then
        EntityLoad(SPARK_ENTITY_PATH, x, y)
        GameCreateCosmeticParticle("spark_electric", x, y, SPARK_PARTICLE_COUNT, 0, 0)
    end
end
