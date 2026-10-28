--- Power cables of tube lamps for Pick Up Your Lantern mod.
--- A tube lamp hangs on its power cable. When the player takes it down, a cable of separate segments runs from
--- the ceiling to the lamp and keeps it powered: a segment is paid out from the ceiling whenever the cable gets too
--- short, up to a random limit, and past the limit the cable snaps with a burst of sparks and the lamp goes dark.
--- A lamp in the world is held back by its cable like by a leash. The ceiling part keeps hanging, and after
--- SPARK_DELAY_FRAMES its end shocks creatures around it for LIVE_FRAMES. A lamp kicked down leaves a hanging cable
--- of random length; a lamp whose ceiling is destroyed leaves none.
--- A cable is a rope of verlet points simulated in Lua, one sprite entity per segment: a physics chain built at
--- runtime gets no bodies when spawned by the mod, and could not grow anyway. A cable entity at the ceiling anchor
--- keeps the segment count and age in storages, so cables are rebuilt after a save and reload.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local LANTERN_TAG = "lantern"
local CABLE_TAG = "pul_cable"
local SEGMENT_TAG = "pul_cable_segment"
local CABLE_ENTITY_PATH = "mods/" .. MOD_ID .. "/files/entities/tube_lamp_cable.xml"
local SEGMENT_ENTITY_PATH = "mods/" .. MOD_ID .. "/files/entities/tube_lamp_cable_segment.xml"
local SPARK_ENTITY_PATH = "data/entities/misc/electricity_weak.xml"
local ELECTROCUTION_EFFECT_PATH = "data/entities/misc/effect_electricity.xml"
-- Lamp position while it hangs: the upper end of its wires, right under the ceiling.
local ANCHOR_X_STORAGE = "lantern_cable_anchor_x"
local ANCHOR_Y_STORAGE = "lantern_cable_anchor_y"
-- Set while a lamp hangs, so the moment it leaves the ceiling is told apart from a lamp loaded off the ceiling.
local HANGING_STORAGE = "lantern_cable_hanging"
local SEGMENT_COUNT_STORAGE = "cable_segment_count"
local AGE_STORAGE = "cable_age_frames"

-- Length of a cable segment, in pixels: the height of the vanilla wire sprite.
local SEGMENT_LENGTH = 5
-- Number of segments a carried cable pays out before it snaps: 40 to 160 px.
local MIN_SEGMENTS = 8
local MAX_SEGMENTS = 32
-- Number of segments of the cable left by a lamp kicked down.
local KICKED_MIN_SEGMENTS = 4
local KICKED_MAX_SEGMENTS = 32
-- How far above the anchor the ceiling is searched for, to tell a kick from a destroyed ceiling.
local CEILING_CHECK_DISTANCE = 8
-- How much a fully paid-out cable stretches before it snaps when the player pulls the lamp.
local BREAK_STRETCH = 1.1
-- A lamp in the world is pulled back by a stretched cable, and snaps it only when flung this much farther.
local WORLD_BREAK_STRETCH = 2
local LEASH_FORCE_PER_PIXEL = 3
local LEASH_MAX_FORCE = 60
local BREAK_SPARK_COUNT = 12
-- The first spark comes 2 seconds after the cable snapped, so the player who broke it is not shocked right away.
local SPARK_DELAY_FRAMES = 2 * 60
local SPARK_INTERVAL_FRAMES = 60
local SPARK_PARTICLE_COUNT = 6
-- Each spark shocks creatures around the end of the cable, unless a wall is in between.
local INDUCTION_RADIUS = 40
local INDUCTION_DAMAGE = 0.08
local INDUCTION_TAGS = { "enemy", "player_unit", }
local INDUCTION_ARC_PARTICLES = 6
-- A torn cable is live for 3 minutes, then it keeps hanging without sparks.
local LIVE_FRAMES = 3 * 60 * 60
local GRAVITY = 0.2
local DAMPING = 0.95
local CONSTRAINT_ITERATIONS = 8

---@class CablePoint
---@field x number
---@field y number
---@field prev_x number
---@field prev_y number

---@class CableRope
---@field cable_id number Cable entity ID at the ceiling anchor.
---@field points CablePoint[] Rope points from the ceiling to the end of the cable.
---@field segment_ids number[] Segment sprite entity IDs, one per pair of neighbour points.
---@field lamp_id number|nil Lamp the cable is attached to while the player carries it.
---@field max_segments number Number of segments paid out before a carried cable snaps.

---Cables simulated this session, by cable entity ID.
---@type table<number, CableRope>
local ropes = {}

---Cable attached to a lamp the player carries; only one at a time.
---@type CableRope|nil
local carried = nil

---Spawns the sprite entity of a cable segment.
---@param x number World X coordinate of the upper end of the segment.
---@param y number World Y coordinate of the upper end of the segment.
---@return number segment_id
local function SpawnSegment(x, y)
    return EntityLoad(SEGMENT_ENTITY_PATH, x, y)
end

---Creates the rope of a cable: points on a straight line from the anchor to the end, one segment between each two.
---@param cable_id number Cable entity ID.
---@param end_x number World X coordinate of the end of the cable.
---@param end_y number World Y coordinate of the end of the cable.
---@param segment_count number Number of segments.
---@return CableRope
local function CreateRope(cable_id, end_x, end_y, segment_count)
    local anchor_x, anchor_y = EntityGetTransform(cable_id)
    local rope = { cable_id = cable_id, points = {}, segment_ids = {}, lamp_id = nil, max_segments = segment_count, }
    for index = 0, segment_count do
        local t = index / segment_count
        local x = anchor_x + (end_x - anchor_x) * t
        local y = anchor_y + (end_y - anchor_y) * t
        table.insert(rope.points, { x = x, y = y, prev_x = x, prev_y = y, })
        if index < segment_count then
            table.insert(rope.segment_ids, SpawnSegment(x, y))
        end
    end
    ropes[cable_id] = rope

    return rope
end

---Spawns a cable hanging from the ceiling at the anchor; its segments start straight down and settle.
---@param anchor_x number World X coordinate of the anchor, right under the ceiling.
---@param anchor_y number World Y coordinate of the anchor.
---@param segment_count number Number of segments.
---@return CableRope|nil rope
local function SpawnHangingCable(anchor_x, anchor_y, segment_count)
    local cable_id = EntityLoad(CABLE_ENTITY_PATH, anchor_x, anchor_y)
    if cable_id == nil or cable_id == 0 then
        return nil
    end

    SetStorageFloat(cable_id, SEGMENT_COUNT_STORAGE, segment_count)
    return CreateRope(cable_id, anchor_x, anchor_y + segment_count * SEGMENT_LENGTH, segment_count)
end

---Removes the sprites of a rope and forgets it; the cable entity is left as it is.
---@param rope CableRope
---@return nil
local function DropRope(rope)
    for _, segment_id in ipairs(rope.segment_ids) do
        EntityKill(segment_id)
    end
    ropes[rope.cable_id] = nil
    if carried == rope then
        carried = nil
    end
end

---Finds where a carried cable ends: at the lamp in hand or in the world, at its holder while it is in the
---inventory, as the transform of an item in the inventory is not kept up to date.
---@param lamp_id number Lamp entity ID.
---@return number x
---@return number y
local function GetCarriedEnd(lamp_id)
    local root_id = EntityGetRootEntity(lamp_id)
    if root_id ~= lamp_id and GetHeldItem(root_id) ~= lamp_id then
        return EntityGetTransform(root_id)
    end

    return EntityGetTransform(lamp_id)
end

---Snaps the carried cable off the lamp with a burst of harmless sparks: the lamp loses its power, and the cable
---keeps hanging from the ceiling.
---@return nil
local function SnapCarriedCable()
    if carried == nil then
        return
    end

    local last = carried.points[#carried.points]
    GameCreateCosmeticParticle("spark_electric", last.x, last.y, BREAK_SPARK_COUNT, 0, 0)
    if EntityGetIsAlive(carried.lamp_id) and CutLanternPower(carried.lamp_id) then
        RefreshLanternIllumination(carried.lamp_id)
    end
    carried.lamp_id = nil
    SetStorageFloat(carried.cable_id, AGE_STORAGE, 0)
    carried = nil
end

---Starts a carried cable from the ceiling anchor to a lamp the player took down. The lamp keeps its power while
---the cable holds. Its joint is removed, so the lamp no longer counts as hanging once it is back in the world.
---@param lamp_id number Lamp entity ID.
---@param anchor_x number World X coordinate of the anchor.
---@param anchor_y number World Y coordinate of the anchor.
---@return boolean started Whether the cable is attached; false if it snapped right away.
local function StartCarriedCable(lamp_id, anchor_x, anchor_y)
    SnapCarriedCable()

    local lamp_x, lamp_y = GetCarriedEnd(lamp_id)
    local distance = math.sqrt((lamp_x - anchor_x) ^ 2 + (lamp_y - anchor_y) ^ 2)
    SetRandomSeed(anchor_x + GameGetFrameNum(), anchor_y)
    local max_segments = Random(MIN_SEGMENTS, MAX_SEGMENTS)
    local segment_count = math.max(1, math.ceil(distance / SEGMENT_LENGTH))
    if segment_count > max_segments then
        -- The lamp is already too far, e.g. picked up in a hurry from a high ceiling.
        SpawnHangingCable(anchor_x, anchor_y, max_segments)
        GameCreateCosmeticParticle("spark_electric", lamp_x, lamp_y, BREAK_SPARK_COUNT, 0, 0)
        return false
    end

    local cable_id = EntityLoad(CABLE_ENTITY_PATH, anchor_x, anchor_y)
    if cable_id == nil or cable_id == 0 then
        return false
    end
    SetStorageFloat(cable_id, SEGMENT_COUNT_STORAGE, segment_count)

    for _, joint_comp in ipairs(EntityGetComponentIncludingDisabled(lamp_id, "PhysicsJointComponent") or {}) do
        EntityRemoveComponent(lamp_id, joint_comp)
    end

    carried = CreateRope(cable_id, lamp_x, lamp_y, segment_count)
    carried.lamp_id = lamp_id
    carried.max_segments = max_segments
    return true
end

---Pays out one more segment of a carried cable from the ceiling: a new point appears next to the anchor.
---@param rope CableRope
---@return nil
local function PayOutSegment(rope)
    local anchor = rope.points[1]
    local next_point = rope.points[2]
    local x = (anchor.x + next_point.x) / 2
    local y = (anchor.y + next_point.y) / 2
    table.insert(rope.points, 2, { x = x, y = y, prev_x = x, prev_y = y, })
    table.insert(rope.segment_ids, SpawnSegment(x, y))
    SetStorageFloat(rope.cable_id, SEGMENT_COUNT_STORAGE, #rope.segment_ids)
end

---Moves the free rope points with verlet integration, stops them at surfaces, then pulls stretched segments back
---to their length. The first point is held by the ceiling, and the last one by the lamp while it is carried.
---Slack segments are left as they are.
---@param rope CableRope
---@return nil
local function SimulateRope(rope)
    local points = rope.points
    local last_free = rope.lamp_id == nil and #points or #points - 1
    for index = 2, last_free do
        local point = points[index]
        local vel_x = (point.x - point.prev_x) * DAMPING
        local vel_y = (point.y - point.prev_y) * DAMPING
        local x = point.x + vel_x
        local y = point.y + vel_y + GRAVITY
        point.prev_x, point.prev_y = point.x, point.y
        if not RaytraceSurfaces(point.x, point.y, x, y) then
            point.x, point.y = x, y
        end
    end

    for _ = 1, CONSTRAINT_ITERATIONS do
        for index = 1, #points - 1 do
            local a, b = points[index], points[index + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > SEGMENT_LENGTH then
                local correction = (distance - SEGMENT_LENGTH) / distance
                local a_free = index > 1
                local b_free = index + 1 <= last_free
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
---@param rope CableRope
---@return nil
local function RenderRope(rope)
    local points = rope.points
    for index, segment_id in ipairs(rope.segment_ids) do
        local a, b = points[index], points[index + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local length = math.sqrt(dx * dx + dy * dy)
        -- The sprite points down; the rotation turns (0, 1) into the segment direction.
        EntitySetTransform(segment_id, a.x, a.y, math.atan2(-dx, dy), 1, length / SEGMENT_LENGTH)
    end
end

---Pulls a lamp in the world back towards the anchor when it is farther than the full cable.
---@param lamp_id number Lamp entity ID.
---@param dx number Offset of the lamp from the anchor, X.
---@param dy number Offset of the lamp from the anchor, Y.
---@param distance number Distance of the lamp from the anchor.
---@param excess number How much farther the lamp is than the full cable.
---@return nil
local function PullLampBack(lamp_id, dx, dy, distance, excess)
    local force = math.min(LEASH_MAX_FORCE, excess * LEASH_FORCE_PER_PIXEL)
    PhysicsApplyForce(lamp_id, -dx / distance * force, -dy / distance * force)
end

---Moves a carried cable after its lamp, pays out segments and snaps the cable once it is too long. The player
---snaps it by walking away with the lamp; a lamp in the world is held back like by a leash, and snaps it only when
---flung far beyond its length.
---@param rope CableRope
---@return nil
local function UpdateCarriedCable(rope)
    if not EntityGetIsAlive(rope.lamp_id) then
        SnapCarriedCable()
        return
    end

    local lamp_x, lamp_y = GetCarriedEnd(rope.lamp_id)
    local last = rope.points[#rope.points]
    last.x, last.y = lamp_x, lamp_y

    local anchor = rope.points[1]
    local dx, dy = lamp_x - anchor.x, lamp_y - anchor.y
    local distance = math.sqrt(dx * dx + dy * dy)
    while distance > #rope.segment_ids * SEGMENT_LENGTH and #rope.segment_ids < rope.max_segments do
        PayOutSegment(rope)
    end

    local full_length = rope.max_segments * SEGMENT_LENGTH
    if EntityGetRootEntity(rope.lamp_id) ~= rope.lamp_id then
        if distance > full_length * BREAK_STRETCH then
            SnapCarriedCable()
        end
    elseif distance > full_length * WORLD_BREAK_STRETCH then
        SnapCarriedCable()
    elseif distance > full_length then
        PullLampBack(rope.lamp_id, dx, dy, distance, distance - full_length)
    end
end

---Shocks the creatures around a point of a live cable, unless a wall is in between: electrocution as from touching
---a live wire, a little electric damage, and an arc of sparks from the cable to each of them.
---@param x number World X coordinate of the end of the cable.
---@param y number World Y coordinate of the end of the cable.
---@return nil
local function InduceCurrent(x, y)
    for _, tag in ipairs(INDUCTION_TAGS) do
        for _, target_id in ipairs(EntityGetInRadiusWithTag(x, y, INDUCTION_RADIUS, tag) or {}) do
            local target_x, target_y = EntityGetTransform(target_id)
            if not RaytraceSurfaces(x, y, target_x, target_y) then
                LoadGameEffectEntityTo(target_id, ELECTROCUTION_EFFECT_PATH)
                EntityInflictDamage(target_id, INDUCTION_DAMAGE, "DAMAGE_ELECTRICITY", "$damage_tube_lamp_cable",
                    "NONE", 0, 0)
                for step = 1, INDUCTION_ARC_PARTICLES do
                    local t = step / INDUCTION_ARC_PARTICLES
                    GameCreateCosmeticParticle("spark_electric", x + (target_x - x) * t, y + (target_y - y) * t, 1, 0, 0)
                end
            end
        end
    end
end

---Sparks from the end of a torn cable while it is live, shocking creatures around it.
---@param rope CableRope
---@return nil
local function SparkTornCable(rope)
    local age = GetStorageFloat(rope.cable_id, AGE_STORAGE) + 1
    if age > LIVE_FRAMES then
        return
    end
    SetStorageFloat(rope.cable_id, AGE_STORAGE, age)

    if age >= SPARK_DELAY_FRAMES and age % SPARK_INTERVAL_FRAMES == 0 then
        local last = rope.points[#rope.points]
        EntityLoad(SPARK_ENTITY_PATH, last.x, last.y)
        GameCreateCosmeticParticle("spark_electric", last.x, last.y, SPARK_PARTICLE_COUNT, 0, 0)
        InduceCurrent(last.x, last.y)
    end
end

---Matches ropes to the loaded cable entities: cables loaded from a save or streamed in get a rope hanging straight
---down, and ropes of unloaded cables are dropped. Segment sprites of no known rope, left from an earlier session,
---are removed.
---@return nil
local function SyncRopes()
    local loaded = {}
    for _, cable_id in ipairs(EntityGetWithTag(CABLE_TAG) or {}) do
        loaded[cable_id] = true
        if ropes[cable_id] == nil then
            local anchor_x, anchor_y = EntityGetTransform(cable_id)
            local segment_count = math.max(1, math.floor(GetStorageFloat(cable_id, SEGMENT_COUNT_STORAGE)))
            CreateRope(cable_id, anchor_x, anchor_y + segment_count * SEGMENT_LENGTH, segment_count)
        end
    end

    local known_segments = {}
    for cable_id, rope in pairs(ropes) do
        if loaded[cable_id] then
            for _, segment_id in ipairs(rope.segment_ids) do
                known_segments[segment_id] = true
            end
        else
            DropRope(rope)
        end
    end
    for _, segment_id in ipairs(EntityGetWithTag(SEGMENT_TAG) or {}) do
        if not known_segments[segment_id] then
            EntityKill(segment_id)
        end
    end
end

---Watches powered tube lamps. A hanging lamp keeps its anchor up to date. When it leaves the ceiling, a lamp taken
---by the player gets a carried cable and stays powered; a lamp kicked down leaves a hanging cable and goes dark,
---and so does a lamp whose ceiling was destroyed, or one off the ceiling without a cable, e.g. after a reload.
---@return nil
local function UpdatePoweredLamps()
    for _, lamp_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local _, lantern_type = GetLanternType(lamp_id)
        local is_carried = carried ~= nil and carried.lamp_id == lamp_id
        if lantern_type.needs_power and not is_carried and GetLanternPowerFactor(lamp_id) > 0 then
            if IsLanternHanging(lamp_id) then
                local x, y = EntityGetTransform(lamp_id)
                SetStorageFloat(lamp_id, ANCHOR_X_STORAGE, x)
                SetStorageFloat(lamp_id, ANCHOR_Y_STORAGE, y)
                SetStorageFloat(lamp_id, HANGING_STORAGE, 1)
            else
                local was_hanging = GetStorageFloat(lamp_id, HANGING_STORAGE) > 0
                SetStorageFloat(lamp_id, HANGING_STORAGE, 0)
                local anchor_x = GetStorageFloat(lamp_id, ANCHOR_X_STORAGE)
                local anchor_y = GetStorageFloat(lamp_id, ANCHOR_Y_STORAGE)
                local is_picked_up = EntityGetRootEntity(lamp_id) ~= lamp_id
                if not (was_hanging and is_picked_up and StartCarriedCable(lamp_id, anchor_x, anchor_y)) then
                    CutLanternPower(lamp_id)
                    RefreshLanternIllumination(lamp_id)
                    local has_ceiling = RaytraceSurfaces(anchor_x, anchor_y, anchor_x, anchor_y - CEILING_CHECK_DISTANCE)
                    if was_hanging and not is_picked_up and has_ceiling then
                        SetRandomSeed(anchor_x + GameGetFrameNum(), anchor_y)
                        SpawnHangingCable(anchor_x, anchor_y, Random(KICKED_MIN_SEGMENTS, KICKED_MAX_SEGMENTS))
                    end
                end
            end
        end
    end
end

---Updates tube lamp cables. Runs every frame in OnWorldPostUpdate, after physics, so a carried cable follows its
---lamp in the same frame before rendering.
---@return nil
function UpdateTubeLampCables()
    SyncRopes()
    UpdatePoweredLamps()

    for _, rope in pairs(ropes) do
        if rope == carried then
            UpdateCarriedCable(rope)
        else
            SparkTornCable(rope)
        end
        SimulateRope(rope)
        RenderRope(rope)
    end
end
