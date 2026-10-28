--- Power cables of tube lamps for Pick Up Your Lantern mod.
--- A tube lamp hangs on its power cable. When the player takes it down, a cable of separate segments runs from
--- the ceiling to the lamp: a segment is paid out from the ceiling whenever the cable gets too short, up to a random
--- limit, and past the limit the cable breaks with a burst of sparks. The ceiling part keeps hanging as a physics
--- chain with the paid-out segments and sparks for a while, see tube_lamp_cable_spark.lua.
--- A lamp kicked down leaves a dangling cable of random length; a lamp whose ceiling is destroyed leaves none.
--- The carried cable is simulated in Lua as a rope of verlet points, as a physics chain cannot grow once initialized.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local LANTERN_TAG = "lantern"
local TETHER_TAG = "pul_cable_tether"
local CABLE_ENTITY_PATH = "mods/" .. MOD_ID .. "/files/entities/tube_lamp_cable.xml"
local SEGMENT_ENTITY_PATH = "mods/" .. MOD_ID .. "/files/entities/tube_lamp_cable_segment.xml"
-- Lamp position while it hangs: the upper end of its wires, right under the ceiling.
local ANCHOR_X_STORAGE = "lantern_cable_anchor_x"
local ANCHOR_Y_STORAGE = "lantern_cable_anchor_y"
-- Stored on the first segment of a carried cable, to leave a dangling cable if the cable outlives this session.
local TETHER_ANCHOR_X_STORAGE = "cable_anchor_x"
local TETHER_ANCHOR_Y_STORAGE = "cable_anchor_y"
local CABLE_SEGMENT_COUNT_STORAGE = "cable_segment_count"
local CABLE_SEGMENT_LENGTH_STORAGE = "cable_segment_length"

-- Length of a cable segment, in pixels: the height of the vanilla wire sprite.
local SEGMENT_LENGTH = 5
-- Number of segments a carried cable pays out before it breaks: 20 to 80 px.
local MIN_SEGMENTS = 4
local MAX_SEGMENTS = 16
-- Number of segments of the cable left by a lamp kicked down.
local KICKED_MIN_SEGMENTS = 2
local KICKED_MAX_SEGMENTS = 16
-- How far above the anchor the ceiling is searched for, to tell a kick from a destroyed ceiling.
local CEILING_CHECK_DISTANCE = 8
-- How much a fully paid-out cable stretches before it breaks.
local BREAK_STRETCH = 1.1
local GRAVITY = 0.2
local DAMPING = 0.95
local CONSTRAINT_ITERATIONS = 8
local BREAK_SPARK_COUNT = 12

---@class CableTether
---@field lamp_id number Carried lamp entity ID.
---@field max_segments number Number of segments paid out before the cable breaks.
---@field points {x: number, y: number, prev_x: number, prev_y: number}[] Rope points from the ceiling to the lamp.
---@field segment_ids number[] Segment sprite entity IDs, one per pair of neighbour points.

---@type CableTether|nil
local tether = nil

---Spawns a dangling cable: a physics chain of segments attached to the ceiling at the anchor.
---The chain is built by the cable's own script on its first update, see tube_lamp_cable_build.lua.
---@param x number World X coordinate of the anchor, right under the ceiling.
---@param y number World Y coordinate of the anchor.
---@param segment_count number Number of segments.
---@return nil
local function SpawnDanglingCable(x, y, segment_count)
    local cable_id = EntityLoad(CABLE_ENTITY_PATH, x, y)
    if cable_id == nil or cable_id == 0 then
        return
    end

    SetStorageFloat(cable_id, CABLE_SEGMENT_COUNT_STORAGE, segment_count)
    SetStorageFloat(cable_id, CABLE_SEGMENT_LENGTH_STORAGE, SEGMENT_LENGTH)
    SetStorageFloat(cable_id, TETHER_ANCHOR_X_STORAGE, x)
    SetStorageFloat(cable_id, TETHER_ANCHOR_Y_STORAGE, y)
end

---Spawns the sprite entity of a carried cable segment.
---@param x number World X coordinate of the upper end of the segment.
---@param y number World Y coordinate of the upper end of the segment.
---@return number segment_id
local function SpawnSegment(x, y)
    return EntityLoad(SEGMENT_ENTITY_PATH, x, y)
end

---Finds where the carried cable ends: at the lamp in hand or in the world, at its holder while it is in the
---inventory, as the transform of an item in the inventory is not kept up to date.
---@param lamp_id number Lamp entity ID.
---@return number x
---@return number y
local function GetTetherEnd(lamp_id)
    local root_id = EntityGetRootEntity(lamp_id)
    if root_id ~= lamp_id and GetHeldItem(root_id) ~= lamp_id then
        return EntityGetTransform(root_id)
    end

    return EntityGetTransform(lamp_id)
end

---Removes the carried cable and leaves its ceiling part hanging, with a burst of sparks at the break.
---@param break_x number|nil World X coordinate of the break; no sparks without it.
---@param break_y number|nil World Y coordinate of the break.
---@return nil
local function BreakTether(break_x, break_y)
    if tether == nil then
        return
    end

    local anchor = tether.points[1]
    SpawnDanglingCable(anchor.x, anchor.y, #tether.segment_ids)
    if break_x ~= nil then
        GameCreateCosmeticParticle("spark_electric", break_x, break_y, BREAK_SPARK_COUNT, 0, 0)
    end
    for _, segment_id in ipairs(tether.segment_ids) do
        EntityKill(segment_id)
    end
    tether = nil
end

---Starts a carried cable from the ceiling anchor to a lamp the player took down.
---@param lamp_id number Lamp entity ID.
---@param anchor_x number World X coordinate of the anchor.
---@param anchor_y number World Y coordinate of the anchor.
---@return nil
local function StartTether(lamp_id, anchor_x, anchor_y)
    BreakTether(nil, nil)

    local lamp_x, lamp_y = GetTetherEnd(lamp_id)
    local distance = math.sqrt((lamp_x - anchor_x) ^ 2 + (lamp_y - anchor_y) ^ 2)
    SetRandomSeed(anchor_x + GameGetFrameNum(), anchor_y)
    local max_segments = Random(MIN_SEGMENTS, MAX_SEGMENTS)
    local segment_count = math.max(1, math.ceil(distance / SEGMENT_LENGTH))
    if segment_count > max_segments then
        -- The lamp is already too far, e.g. picked up in a hurry from a high ceiling.
        SpawnDanglingCable(anchor_x, anchor_y, max_segments)
        GameCreateCosmeticParticle("spark_electric", lamp_x, lamp_y, BREAK_SPARK_COUNT, 0, 0)
        return
    end

    tether = { lamp_id = lamp_id, max_segments = max_segments, points = {}, segment_ids = {}, }
    for index = 0, segment_count do
        local t = index / segment_count
        local x = anchor_x + (lamp_x - anchor_x) * t
        local y = anchor_y + (lamp_y - anchor_y) * t
        table.insert(tether.points, { x = x, y = y, prev_x = x, prev_y = y, })
        if index < segment_count then
            table.insert(tether.segment_ids, SpawnSegment(x, y))
        end
    end
    SetStorageFloat(tether.segment_ids[1], TETHER_ANCHOR_X_STORAGE, anchor_x)
    SetStorageFloat(tether.segment_ids[1], TETHER_ANCHOR_Y_STORAGE, anchor_y)
end

---Pays out one more segment from the ceiling: a new point appears between the anchor and the next point.
---@return nil
local function PayOutSegment()
    local anchor = tether.points[1]
    local next_point = tether.points[2]
    local x = (anchor.x + next_point.x) / 2
    local y = (anchor.y + next_point.y) / 2
    table.insert(tether.points, 2, { x = x, y = y, prev_x = x, prev_y = y, })
    table.insert(tether.segment_ids, SpawnSegment(x, y))
end

---Moves the free rope points with verlet integration, then pulls stretched segments back to their length.
---The first point is held by the ceiling and the last one by the lamp. Slack segments are left as they are.
---@return nil
local function SimulateTether()
    local points = tether.points
    for index = 2, #points - 1 do
        local point = points[index]
        local vel_x = (point.x - point.prev_x) * DAMPING
        local vel_y = (point.y - point.prev_y) * DAMPING
        point.prev_x, point.prev_y = point.x, point.y
        point.x = point.x + vel_x
        point.y = point.y + vel_y + GRAVITY
    end

    for _ = 1, CONSTRAINT_ITERATIONS do
        for index = 1, #points - 1 do
            local a, b = points[index], points[index + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > SEGMENT_LENGTH then
                local correction = (distance - SEGMENT_LENGTH) / distance
                local a_free = index > 1
                local b_free = index + 1 < #points
                local share = (a_free and b_free) and 0.5 or 1
                if a_free then
                    a.x, a.y = a.x + dx * correction * share, a.y + dy * correction * share
                end
                if b_free then
                    b.x, b.y = b.x - dx * correction * share, b.y - dy * correction * share
                end
            end
        end
    end
end

---Places each segment sprite between its two rope points: turned along the segment and stretched to its length.
---@return nil
local function RenderTether()
    local points = tether.points
    for index, segment_id in ipairs(tether.segment_ids) do
        local a, b = points[index], points[index + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local length = math.sqrt(dx * dx + dy * dy)
        -- The sprite points down; the rotation turns (0, 1) into the segment direction.
        EntitySetTransform(segment_id, a.x, a.y, math.atan2(-dx, dy), 1, length / SEGMENT_LENGTH)
    end
end

---Moves the carried cable after the lamp, pays out segments and breaks the cable once it is too long.
---@return nil
local function UpdateTether()
    local lamp_id = tether.lamp_id
    local last = tether.points[#tether.points]
    if not EntityGetIsAlive(lamp_id) then
        BreakTether(last.x, last.y)
        return
    end

    local lamp_x, lamp_y = GetTetherEnd(lamp_id)
    last.x, last.y = lamp_x, lamp_y

    local anchor = tether.points[1]
    local distance = math.sqrt((lamp_x - anchor.x) ^ 2 + (lamp_y - anchor.y) ^ 2)
    while distance > #tether.segment_ids * SEGMENT_LENGTH and #tether.segment_ids < tether.max_segments do
        PayOutSegment()
    end
    if distance > tether.max_segments * SEGMENT_LENGTH * BREAK_STRETCH then
        BreakTether(lamp_x, lamp_y)
        return
    end

    SimulateTether()
    RenderTether()
end

---Removes carried cable segments left from an earlier session, e.g. after a save and reload, leaving their ceiling
---part as a dangling cable.
---@return nil
local function CleanUpStaleTethers()
    local stale_ids = EntityGetWithTag(TETHER_TAG) or {}
    if #stale_ids == 0 then
        return
    end

    for _, segment_id in ipairs(stale_ids) do
        local anchor_comp = FindVariableStorage(segment_id, TETHER_ANCHOR_X_STORAGE)
        if anchor_comp ~= nil then
            local anchor_x = ComponentGetValue2(anchor_comp, "value_float")
            local anchor_y = GetStorageFloat(segment_id, TETHER_ANCHOR_Y_STORAGE)
            SpawnDanglingCable(anchor_x, anchor_y, #stale_ids)
        end
        EntityKill(segment_id)
    end
end

---Watches tube lamps that still hang on their cable and handles the moment they lose power.
---@return nil
local function UpdateHangingLamps()
    for _, lamp_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local _, lantern_type = GetLanternType(lamp_id)
        if lantern_type.needs_power and GetLanternPowerFactor(lamp_id) > 0 then
            local has_anchor = FindVariableStorage(lamp_id, ANCHOR_X_STORAGE) ~= nil
            if UpdateLanternPower(lamp_id) then
                RefreshLanternIllumination(lamp_id)
                if has_anchor then
                    local anchor_x = GetStorageFloat(lamp_id, ANCHOR_X_STORAGE)
                    local anchor_y = GetStorageFloat(lamp_id, ANCHOR_Y_STORAGE)
                    if EntityGetRootEntity(lamp_id) ~= lamp_id then
                        StartTether(lamp_id, anchor_x, anchor_y)
                    elseif RaytraceSurfaces(anchor_x, anchor_y, anchor_x, anchor_y - CEILING_CHECK_DISTANCE) then
                        SetRandomSeed(anchor_x + GameGetFrameNum(), anchor_y)
                        SpawnDanglingCable(anchor_x, anchor_y, Random(KICKED_MIN_SEGMENTS, KICKED_MAX_SEGMENTS))
                    end
                end
            else
                local x, y = EntityGetTransform(lamp_id)
                SetStorageFloat(lamp_id, ANCHOR_X_STORAGE, x)
                SetStorageFloat(lamp_id, ANCHOR_Y_STORAGE, y)
            end
        end
    end
end

---Updates tube lamp cables. Runs every frame in OnWorldPostUpdate, after physics, so the carried cable follows the
---lamp in the same frame before rendering.
---@return nil
function UpdateTubeLampCables()
    if tether == nil then
        CleanUpStaleTethers()
    end

    UpdateHangingLamps()
    if tether ~= nil then
        UpdateTether()
    end
end
