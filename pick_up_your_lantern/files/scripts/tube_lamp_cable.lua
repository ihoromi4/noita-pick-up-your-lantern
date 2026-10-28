--- Power cables of tube lamps for Pick Up Your Lantern mod.
--- A tube lamp hangs on its power cable. When it leaves the ceiling, the cable stays attached and keeps it powered:
--- - taken by the player, a cable of separate segments runs from the ceiling to the lamp; a segment is paid out from
---   the ceiling whenever the cable gets too short, up to a random limit, and past the limit the cable snaps with
---   a burst of sparks and the lamp goes dark;
--- - knocked off by a shot or a kick, the lamp dangles on a short cable and blinks, like a damaged vanilla tube lamp;
--- - a lamp in the world is held by its cable like by a leash, and snaps it only when flung far beyond its length;
---   the cable holds it by one end of the tube, where a vanilla wire is attached, so the lamp swings on it.
--- The ceiling part of a snapped cable keeps hanging, and after SPARK_DELAY_FRAMES its end shocks creatures around
--- it for LIVE_FRAMES. A lamp whose ceiling is destroyed falls and goes dark.
--- A cable is a rope of verlet points simulated in Lua, one sprite entity per segment: a physics chain built at
--- runtime gets no bodies when spawned by the mod, and could not grow anyway. A cable entity at the ceiling anchor
--- keeps the segment count and age in storages, so cables are rebuilt after a save and reload. Which lamp a cable
--- holds is not saved: after a reload the lamp falls off and goes dark.

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
-- Number of segments a cable pays out for the player before it snaps: 40 to 160 px.
local CARRIED_MIN_SEGMENTS = 8
local CARRIED_MAX_SEGMENTS = 32
-- Number of segments a lamp knocked off the ceiling dangles on: 10 to 30 px.
local DANGLING_MIN_SEGMENTS = 2
local DANGLING_MAX_SEGMENTS = 6
-- Light blinking of a lamp knocked off the ceiling, as the vanilla damaged tube lamp.
local DANGLING_BLINKING_FREQ = 0.9
-- How far above the anchor the ceiling is searched for, to tell a knocked-off lamp from a destroyed ceiling.
local CEILING_CHECK_DISTANCE = 8
-- How much a fully paid-out cable stretches before it snaps when the player pulls the lamp.
local BREAK_STRETCH = 1.1
-- A lamp in the world is held at the length of its cable, and snaps it only when flung this much farther in a frame.
local WORLD_BREAK_STRETCH = 2
local BREAK_SPARK_COUNT = 12
-- The first spark comes 2 seconds after the cable snapped, so the player who broke it is not shocked right away.
local SPARK_DELAY_FRAMES = 2 * 60
local SPARK_INTERVAL_FRAMES = 60
local SPARK_PARTICLE_COUNT = 6
-- A torn cable is live for 3 minutes, then it keeps hanging without sparks.
local LIVE_FRAMES = 3 * 60 * 60
-- Each spark shocks creatures around the end of the cable, unless a wall is in between.
local INDUCTION_RADIUS = 20
local INDUCTION_DAMAGE = 0.08
local INDUCTION_TAGS = { "enemy", "player_unit", }
local INDUCTION_ARC_PARTICLES = 6
-- A lamp in the world hangs by the upper end of one of its wires, relative to the lamp origin (tube_lamp.png).
local ATTACH_OFFSET_X = 5
local ATTACH_OFFSET_Y = -0.5
-- Middle of the tube relative to the lamp origin, and its length: the lamp is taken as a thin rod.
local TUBE_CENTER_OFFSET_Y = 2.5
local TUBE_LENGTH = 19
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
---@field lamp_id number|nil Lamp the cable holds and powers, nil once it snapped.
---@field max_segments number Number of segments paid out before the cable snaps.
---@field attach_side number 1 or -1: which end of the tube the cable holds while the lamp is in the world.

---Cables simulated this session, by cable entity ID.
---@type table<number, CableRope>
local ropes = {}

---Cables that hold a lamp, by lamp entity ID.
---@type table<number, CableRope>
local lamp_ropes = {}

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
    local rope = {
        cable_id = cable_id,
        points = {},
        segment_ids = {},
        lamp_id = nil,
        max_segments = segment_count,
        attach_side = 1,
    }
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

---Spawns a cable entity at the anchor.
---@param anchor_x number World X coordinate of the anchor, right under the ceiling.
---@param anchor_y number World Y coordinate of the anchor.
---@param segment_count number Number of segments.
---@return number|nil cable_id
local function SpawnCableEntity(anchor_x, anchor_y, segment_count)
    local cable_id = EntityLoad(CABLE_ENTITY_PATH, anchor_x, anchor_y)
    if cable_id == nil or cable_id == 0 then
        return nil
    end

    SetStorageFloat(cable_id, SEGMENT_COUNT_STORAGE, segment_count)
    return cable_id
end

---Removes the sprites of a rope and forgets it; the cable entity is left as it is.
---@param rope CableRope
---@return nil
local function DropRope(rope)
    for _, segment_id in ipairs(rope.segment_ids) do
        EntityKill(segment_id)
    end
    ropes[rope.cable_id] = nil
    if rope.lamp_id ~= nil then
        lamp_ropes[rope.lamp_id] = nil
    end
end

---Turns a point given relative to an entity origin by the entity rotation and moves it to the entity position.
---@param x number Entity X coordinate.
---@param y number Entity Y coordinate.
---@param rotation number Entity rotation, in radians.
---@param offset_x number Offset from the origin before the rotation, X.
---@param offset_y number Offset from the origin before the rotation, Y.
---@return number x
---@return number y
local function ToWorld(x, y, rotation, offset_x, offset_y)
    local cos, sin = math.cos(rotation), math.sin(rotation)
    return x + offset_x * cos - offset_y * sin, y + offset_x * sin + offset_y * cos
end

---Finds where a cable holding a lamp ends: at one end of the tube while the lamp is in the world, at the lamp in
---hand, and at its holder while it is in the inventory, as the transform of an item in the inventory is not kept up
---to date.
---@param lamp_id number Lamp entity ID.
---@param attach_side number 1 or -1: which end of the tube the cable holds.
---@return number x
---@return number y
local function GetLampEnd(lamp_id, attach_side)
    local root_id = EntityGetRootEntity(lamp_id)
    if root_id == lamp_id then
        local x, y, rotation = EntityGetTransform(lamp_id)
        return ToWorld(x, y, rotation, ATTACH_OFFSET_X * attach_side, ATTACH_OFFSET_Y)
    elseif GetHeldItem(root_id) ~= lamp_id then
        return EntityGetTransform(root_id)
    end

    return EntityGetTransform(lamp_id)
end

---Snaps a cable off its lamp with a burst of harmless sparks: the lamp loses its power, and the cable keeps
---hanging from the ceiling.
---@param rope CableRope
---@return nil
local function SnapCable(rope)
    local lamp_id = rope.lamp_id
    if lamp_id == nil then
        return
    end

    local last = rope.points[#rope.points]
    GameCreateCosmeticParticle("spark_electric", last.x, last.y, BREAK_SPARK_COUNT, 0, 0)
    if EntityGetIsAlive(lamp_id) and CutLanternPower(lamp_id) then
        RefreshLanternIllumination(lamp_id)
    end
    lamp_ropes[lamp_id] = nil
    rope.lamp_id = nil
    SetStorageFloat(rope.cable_id, AGE_STORAGE, 0)
end

---Rolls the number of segments a cable pays out before it snaps.
---@param anchor_x number World X coordinate of the anchor, part of the random seed.
---@param anchor_y number World Y coordinate of the anchor, part of the random seed.
---@param min_segments number
---@param max_segments number
---@return number
local function RollMaxSegments(anchor_x, anchor_y, min_segments, max_segments)
    SetRandomSeed(anchor_x + GameGetFrameNum(), anchor_y)
    return Random(min_segments, max_segments)
end

---Attaches a cable from the ceiling anchor to a lamp that left the ceiling, by a random end of the tube. The lamp keeps its power while the
---cable holds. Its joint is removed, so the lamp no longer counts as hanging once it is back in the world.
---@param lamp_id number Lamp entity ID.
---@param anchor_x number World X coordinate of the anchor.
---@param anchor_y number World Y coordinate of the anchor.
---@param max_segments number Number of segments paid out before the cable snaps.
---@return boolean attached Whether the cable is attached; false if the lamp is already too far and it snapped.
local function AttachCable(lamp_id, anchor_x, anchor_y, max_segments)
    local attach_side = Random(0, 1) == 0 and -1 or 1
    local lamp_x, lamp_y = GetLampEnd(lamp_id, attach_side)
    local distance = math.sqrt((lamp_x - anchor_x) ^ 2 + (lamp_y - anchor_y) ^ 2)
    local segment_count = math.max(1, math.ceil(distance / SEGMENT_LENGTH))
    if segment_count > max_segments then
        -- The lamp is already too far, e.g. picked up in a hurry from a high ceiling.
        local cable_id = SpawnCableEntity(anchor_x, anchor_y, max_segments)
        if cable_id ~= nil then
            CreateRope(cable_id, anchor_x, anchor_y + max_segments * SEGMENT_LENGTH, max_segments)
        end
        GameCreateCosmeticParticle("spark_electric", lamp_x, lamp_y, BREAK_SPARK_COUNT, 0, 0)
        return false
    end

    local cable_id = SpawnCableEntity(anchor_x, anchor_y, segment_count)
    if cable_id == nil then
        return false
    end

    for _, joint_comp in ipairs(EntityGetComponentIncludingDisabled(lamp_id, "PhysicsJointComponent") or {}) do
        EntityRemoveComponent(lamp_id, joint_comp)
    end

    local rope = CreateRope(cable_id, lamp_x, lamp_y, segment_count)
    rope.lamp_id = lamp_id
    rope.max_segments = max_segments
    rope.attach_side = attach_side
    lamp_ropes[lamp_id] = rope
    return true
end

---Makes the light of a lamp knocked off the ceiling blink, as the vanilla damaged tube lamp does.
---@param lamp_id number Lamp entity ID.
---@return nil
local function MakeLampBlink(lamp_id)
    for _, light_comp in ipairs(EntityGetComponentIncludingDisabled(lamp_id, "LightComponent") or {}) do
        ComponentSetValue2(light_comp, "blinking_freq", DANGLING_BLINKING_FREQ)
    end
end

---Pays out one more segment of a cable from the ceiling: a new point appears next to the anchor.
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

---Holds a lamp in the world at the length of its cable by the point the cable is attached to: moves its physics
---body so that the point is back on the circle around the anchor, and takes away the speed of the point away from
---the anchor as an impulse at the point would, which also turns the lamp, so it swings on the cable.
---The lamp is taken as a thin rod: the impulse needs only the ratio of mass to moment of inertia, 12 / length^2.
---@param lamp_id number Lamp entity ID.
---@param attach_x number World X coordinate of the attachment point.
---@param attach_y number World Y coordinate of the attachment point.
---@param dir_x number Direction from the anchor to the attachment point, X.
---@param dir_y number Direction from the anchor to the attachment point, Y.
---@param shift number How far the attachment point has to move towards the anchor.
---@return nil
local function HoldLampOnCable(lamp_id, attach_x, attach_y, dir_x, dir_y, shift)
    local x, y, rotation = EntityGetTransform(lamp_id)
    local center_x, center_y = ToWorld(x, y, rotation, 0, TUBE_CENTER_OFFSET_Y)
    local arm_x, arm_y = attach_x - center_x, attach_y - center_y
    local mass_over_inertia = 12 / (TUBE_LENGTH * TUBE_LENGTH)
    -- Box2D may count y and the angle the other way around than the game.
    local _, physics_down = GameVecToPhysicsVec(0, 1)
    local angle_sign = physics_down < 0 and -1 or 1

    for _, body_id in ipairs(PhysicsBodyIDGetFromEntity(lamp_id) or {}) do
        local body_x, body_y, angle, vel_x, vel_y, angular_vel = PhysicsBodyIDGetTransform(body_id)
        if body_x ~= nil then
            local game_x, game_y = PhysicsPosToGamePos(body_x, body_y)
            body_x, body_y = GamePosToPhysicsPos(game_x - dir_x * shift, game_y - dir_y * shift)

            local game_vel_x, game_vel_y = PhysicsVecToGameVec(vel_x, vel_y)
            local spin = angular_vel * angle_sign
            -- Velocity of the attachment point: of the centre plus the spin around it.
            local point_vel_x, point_vel_y = game_vel_x - spin * arm_y, game_vel_y + spin * arm_x
            local outward = point_vel_x * dir_x + point_vel_y * dir_y
            if outward > 0 then
                local arm_cross_dir = arm_x * dir_y - arm_y * dir_x
                local impulse = outward / (1 + arm_cross_dir * arm_cross_dir * mass_over_inertia)
                game_vel_x, game_vel_y = game_vel_x - dir_x * impulse, game_vel_y - dir_y * impulse
                spin = spin - impulse * arm_cross_dir * mass_over_inertia
            end

            vel_x, vel_y = GameVecToPhysicsVec(game_vel_x, game_vel_y)
            PhysicsBodyIDSetTransform(body_id, body_x, body_y, angle, vel_x, vel_y, spin * angle_sign)
        end
    end
end

---Moves a cable after its lamp, pays out segments and snaps the cable once it is too long. The player snaps it by
---walking away with the lamp; a lamp in the world is held at the length of its cable, and snaps it only when flung
---far beyond it in a single frame.
---@param rope CableRope
---@return nil
local function UpdateLampCable(rope)
    local lamp_id = rope.lamp_id --[[@as number]]
    if not EntityGetIsAlive(lamp_id) then
        SnapCable(rope)
        return
    end

    local lamp_x, lamp_y = GetLampEnd(lamp_id, rope.attach_side)
    local is_carried = EntityGetRootEntity(lamp_id) ~= lamp_id
    if is_carried and rope.max_segments < CARRIED_MIN_SEGMENTS then
        -- The player tugs a dangling lamp off its short cable, and more of the cable comes off the ceiling.
        local anchor = rope.points[1]
        rope.max_segments = RollMaxSegments(anchor.x, anchor.y, CARRIED_MIN_SEGMENTS, CARRIED_MAX_SEGMENTS)
    end

    local anchor = rope.points[1]
    local dx, dy = lamp_x - anchor.x, lamp_y - anchor.y
    local distance = math.sqrt(dx * dx + dy * dy)
    while distance > #rope.segment_ids * SEGMENT_LENGTH and #rope.segment_ids < rope.max_segments do
        PayOutSegment(rope)
    end

    local length = rope.max_segments * SEGMENT_LENGTH
    if is_carried then
        if distance > length * BREAK_STRETCH then
            SnapCable(rope)
            return
        end
    elseif distance > length * WORLD_BREAK_STRETCH then
        SnapCable(rope)
        return
    elseif distance > length then
        HoldLampOnCable(lamp_id, lamp_x, lamp_y, dx / distance, dy / distance, distance - length)
        lamp_x, lamp_y = anchor.x + dx / distance * length, anchor.y + dy / distance * length
    end

    local last = rope.points[#rope.points]
    last.x, last.y = lamp_x, lamp_y
end

---Moves the free rope points with verlet integration, stops them at surfaces, then pulls stretched segments back
---to their length. The first point is held by the ceiling, and the last one by the lamp while the cable holds one.
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

---Handles a powered lamp that has just left the ceiling: a lamp taken by the player gets a long cable, a lamp
---knocked off dangles on a short one and blinks. Without a ceiling at the anchor, or when the cable snaps right
---away, the lamp goes dark.
---@param lamp_id number Lamp entity ID.
---@return nil
local function HandleLampLeftCeiling(lamp_id)
    local anchor_x = GetStorageFloat(lamp_id, ANCHOR_X_STORAGE)
    local anchor_y = GetStorageFloat(lamp_id, ANCHOR_Y_STORAGE)
    local has_ceiling = RaytraceSurfaces(anchor_x, anchor_y, anchor_x, anchor_y - CEILING_CHECK_DISTANCE)
    if has_ceiling then
        local is_picked_up = EntityGetRootEntity(lamp_id) ~= lamp_id
        local min_segments = is_picked_up and CARRIED_MIN_SEGMENTS or DANGLING_MIN_SEGMENTS
        local max_segments = is_picked_up and CARRIED_MAX_SEGMENTS or DANGLING_MAX_SEGMENTS
        local cable_length = RollMaxSegments(anchor_x, anchor_y, min_segments, max_segments)
        if AttachCable(lamp_id, anchor_x, anchor_y, cable_length) then
            if not is_picked_up then
                MakeLampBlink(lamp_id)
            end
            return
        end
    end

    CutLanternPower(lamp_id)
    RefreshLanternIllumination(lamp_id)
end

---Watches powered tube lamps. A hanging lamp keeps its anchor up to date; a lamp that leaves the ceiling gets its
---cable. A powered lamp off the ceiling without a cable, e.g. after a reload, goes dark.
---@return nil
local function UpdatePoweredLamps()
    for _, lamp_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local _, lantern_type = GetLanternType(lamp_id)
        if lantern_type.needs_power and lamp_ropes[lamp_id] == nil and GetLanternPowerFactor(lamp_id) > 0 then
            if IsLanternHanging(lamp_id) then
                local x, y = EntityGetTransform(lamp_id)
                SetStorageFloat(lamp_id, ANCHOR_X_STORAGE, x)
                SetStorageFloat(lamp_id, ANCHOR_Y_STORAGE, y)
                SetStorageFloat(lamp_id, HANGING_STORAGE, 1)
            elseif GetStorageFloat(lamp_id, HANGING_STORAGE) > 0 then
                SetStorageFloat(lamp_id, HANGING_STORAGE, 0)
                HandleLampLeftCeiling(lamp_id)
            else
                CutLanternPower(lamp_id)
                RefreshLanternIllumination(lamp_id)
            end
        end
    end
end

---Updates tube lamp cables. Runs every frame in OnWorldPostUpdate, after physics, so a cable follows its lamp in
---the same frame before rendering.
---@return nil
function UpdateTubeLampCables()
    SyncRopes()
    UpdatePoweredLamps()

    for _, rope in pairs(ropes) do
        if rope.lamp_id ~= nil then
            UpdateLampCable(rope)
        else
            SparkTornCable(rope)
        end
        SimulateRope(rope)
        RenderRope(rope)
    end
end
