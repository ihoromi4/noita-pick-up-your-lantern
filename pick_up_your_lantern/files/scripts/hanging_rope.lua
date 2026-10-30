--- Ropes hanging from the ceiling for Pick Up Your Lantern mod: tube lamp cables and lantern chains.
--- A rope is a chain of verlet points simulated in Lua, one sprite entity per segment: a physics chain built at
--- runtime gets no bodies when spawned by the mod. An anchor entity at the ceiling keeps the segment count in
--- a storage, so ropes are rebuilt, hanging straight down, after a save and reload or when a chunk streams in.
--- Each kind of rope sets its segment length and sprite; a rigid rope (a chain of metal links) keeps every segment
--- at its length, while a slack one (a cable) only stops its segments from stretching.

---@diagnostic disable: undefined-global
dofile_once("mods/pick_up_your_lantern/files/scripts/utils.lua")

local GRAVITY = 0.2
local DAMPING = 0.95
local CONSTRAINT_ITERATIONS = 8

---@class RopeKind
---@field segment_length number Length of a segment, in pixels: the height of its sprite.
---@field segment_entity_path string Sprite entity of a segment, with its origin at the upper end.
---@field top_segment_entity_path string|nil Sprite entity of the segment at the anchor; the usual one if nil.
---@field anchor_tag string Tag of the anchor entities at the ceiling.
---@field segment_tag string Tag of the segment sprite entities.
---@field segment_count_storage string Storage of the anchor entity with the number of segments.
---@field rigid boolean Whether segments keep their length both ways and their sprites are never stretched.

---@class RopePoint
---@field x number
---@field y number
---@field prev_x number
---@field prev_y number

---@class HangingRope
---@field kind RopeKind
---@field anchor_id number|nil Anchor entity ID at the ceiling; nil for a loose piece that fell off.
---@field points RopePoint[] Rope points from the ceiling to the end of the rope.
---@field segment_ids number[] Segment sprite entity IDs, one per pair of neighbour points.

---Creates a rope: points on a straight line from the start to the end, one segment sprite between each two.
---@param kind RopeKind
---@param anchor_id number|nil Anchor entity ID, or nil for a loose piece.
---@param start_x number World X coordinate of the first point.
---@param start_y number World Y coordinate of the first point.
---@param end_x number World X coordinate of the last point.
---@param end_y number World Y coordinate of the last point.
---@param segment_count number Number of segments.
---@return HangingRope
function CreateHangingRope(kind, anchor_id, start_x, start_y, end_x, end_y, segment_count)
    local rope = {
        kind = kind,
        anchor_id = anchor_id,
        points = {},
        segment_ids = {},
    }
    for index = 0, segment_count do
        local t = index / segment_count
        local x = start_x + (end_x - start_x) * t
        local y = start_y + (end_y - start_y) * t
        table.insert(rope.points, { x = x, y = y, prev_x = x, prev_y = y, })
        if index < segment_count then
            local entity_path = kind.segment_entity_path
            if index == 0 and kind.top_segment_entity_path ~= nil then
                entity_path = kind.top_segment_entity_path
            end
            table.insert(rope.segment_ids, EntityLoad(entity_path, x, y))
        end
    end

    return rope
end

---Spawns an anchor entity at the ceiling and keeps the number of segments in it.
---@param anchor_entity_path string Anchor entity file.
---@param kind RopeKind
---@param x number World X coordinate of the anchor, right under the ceiling.
---@param y number World Y coordinate of the anchor.
---@param segment_count number Number of segments.
---@return number|nil anchor_id
function SpawnHangingRopeAnchor(anchor_entity_path, kind, x, y, segment_count)
    local anchor_id = EntityLoad(anchor_entity_path, x, y)
    if anchor_id == nil or anchor_id == 0 then
        return nil
    end

    SetStorageFloat(anchor_id, kind.segment_count_storage, segment_count)
    return anchor_id
end

---Removes the segment sprites of a rope; the anchor entity is left as it is.
---@param rope HangingRope
---@return nil
function RemoveHangingRopeSprites(rope)
    for _, segment_id in ipairs(rope.segment_ids) do
        EntityKill(segment_id)
    end
    rope.segment_ids = {}
end

---Pays out one more segment from the ceiling: a new point appears next to the anchor.
---@param rope HangingRope
---@return nil
function PayOutHangingRopeSegment(rope)
    local anchor = rope.points[1]
    local next_point = rope.points[2]
    local x = (anchor.x + next_point.x) / 2
    local y = (anchor.y + next_point.y) / 2
    table.insert(rope.points, 2, { x = x, y = y, prev_x = x, prev_y = y, })
    table.insert(rope.segment_ids, EntityLoad(rope.kind.segment_entity_path, x, y))
    if rope.anchor_id ~= nil then
        SetStorageFloat(rope.anchor_id, rope.kind.segment_count_storage, #rope.segment_ids)
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
function OffsetToWorld(x, y, rotation, offset_x, offset_y)
    local cos, sin = math.cos(rotation), math.sin(rotation)
    return x + offset_x * cos - offset_y * sin, y + offset_x * sin + offset_y * cos
end

---Holds a body in the world at the length of its rope by the point the rope is attached to: moves its physics
---body so that the point is back on the circle around the anchor, and takes away the speed of the point away from
---the anchor as an impulse at the point would, which also turns the body, so it swings on the rope.
---The impulse needs only the ratio of mass to moment of inertia of the body, not the mass itself.
---@param entity_id number Entity ID of the body.
---@param attach_x number World X coordinate of the attachment point.
---@param attach_y number World Y coordinate of the attachment point.
---@param center_x number World X coordinate of the centre of mass.
---@param center_y number World Y coordinate of the centre of mass.
---@param dir_x number Direction from the anchor to the attachment point, X.
---@param dir_y number Direction from the anchor to the attachment point, Y.
---@param shift number How far the attachment point has to move towards the anchor.
---@param mass_over_inertia number Ratio of the mass to the moment of inertia around the centre, per square pixel.
---@return nil
function HoldBodyOnHangingRope(entity_id, attach_x, attach_y, center_x, center_y, dir_x, dir_y, shift,
                               mass_over_inertia)
    local arm_x, arm_y = attach_x - center_x, attach_y - center_y
    -- Box2D may count y and the angle the other way around than the game.
    local _, physics_down = GameVecToPhysicsVec(0, 1)
    local angle_sign = physics_down < 0 and -1 or 1

    for _, body_id in ipairs(PhysicsBodyIDGetFromEntity(entity_id) or {}) do
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

---Moves the free rope points with verlet integration, stops them at surfaces, then pulls the segments back to their
---length: stretched ones only, or every one for a rigid rope. The first point is held by the ceiling unless the
---rope is a loose piece, and the last one by what hangs on the rope, if anything.
---@param rope HangingRope
---@param is_end_held boolean Whether the last point is held by a body hanging on the rope.
---@return nil
function SimulateHangingRope(rope, is_end_held)
    local points = rope.points
    local first_free = rope.anchor_id ~= nil and 2 or 1
    local last_free = is_end_held and #points - 1 or #points
    for index = first_free, last_free do
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

    local segment_length = rope.kind.segment_length
    local is_rigid = rope.kind.rigid
    for iteration = 1, CONSTRAINT_ITERATIONS do
        -- A rigid rope alternates the direction of the passes, so the remaining error is not gathered in the last
        -- segment, which would bend there.
        local first, last, step = 1, #points - 1, 1
        if is_rigid and iteration % 2 == 0 then
            first, last, step = #points - 1, 1, -1
        end
        for index = first, last, step do
            local a, b = points[index], points[index + 1]
            local dx, dy = b.x - a.x, b.y - a.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > segment_length or (is_rigid and distance > 0) then
                local correction = (distance - segment_length) / distance
                local a_free = index >= first_free
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

---Lays a rope pulled taut between its ends on the straight line between them, at rest: a taut rigid rope is
---straight, which the step-by-step simulation only reaches slowly, bending at the held end meanwhile.
---@param rope HangingRope
---@return nil
function StraightenHangingRope(rope)
    local points = rope.points
    local first, last = points[1], points[#points]
    local count = #points - 1
    for index = 2, count do
        local t = (index - 1) / count
        local point = points[index]
        point.x = first.x + (last.x - first.x) * t
        point.y = first.y + (last.y - first.y) * t
        point.prev_x, point.prev_y = point.x, point.y
    end
end

---Places each segment sprite at the upper of its two rope points, turned along the segment. A slack rope stretches
---its sprites to the segment length; a rigid one keeps them at their own length.
---@param rope HangingRope
---@return nil
function RenderHangingRope(rope)
    local points = rope.points
    local segment_length = rope.kind.segment_length
    for index, segment_id in ipairs(rope.segment_ids) do
        local a, b = points[index], points[index + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local scale_y = 1
        if not rope.kind.rigid then
            scale_y = math.sqrt(dx * dx + dy * dy) / segment_length
        end
        -- The sprite points down; the rotation turns (0, 1) into the segment direction.
        EntitySetTransform(segment_id, a.x, a.y, math.atan2(-dx, dy), 1, scale_y)
    end
end

---Matches ropes to the loaded anchor entities of a kind: anchors loaded from a save or streamed in get a rope
---hanging straight down, and ropes of unloaded anchors are dropped. Segment sprites of no known rope, left from
---an earlier session, are removed.
---@param kind RopeKind
---@param ropes table<number, HangingRope> Ropes of this kind by anchor entity ID; updated in place.
---@param on_drop fun(rope: HangingRope)|nil Called for each dropped rope, after its sprites are removed.
---@param loose_ropes HangingRope[]|nil Loose pieces of this kind, whose sprites are kept as well.
---@return nil
function SyncHangingRopes(kind, ropes, on_drop, loose_ropes)
    local loaded = {}
    for _, anchor_id in ipairs(EntityGetWithTag(kind.anchor_tag) or {}) do
        loaded[anchor_id] = true
        if ropes[anchor_id] == nil then
            local x, y = EntityGetTransform(anchor_id)
            local segment_count = math.max(1, math.floor(GetStorageFloat(anchor_id, kind.segment_count_storage)))
            ropes[anchor_id] = CreateHangingRope(kind, anchor_id, x, y, x, y + segment_count * kind.segment_length,
                segment_count)
        end
    end

    local known_segments = {}
    for anchor_id, rope in pairs(ropes) do
        if loaded[anchor_id] then
            for _, segment_id in ipairs(rope.segment_ids) do
                known_segments[segment_id] = true
            end
        else
            RemoveHangingRopeSprites(rope)
            ropes[anchor_id] = nil
            if on_drop ~= nil then
                on_drop(rope)
            end
        end
    end
    for _, rope in ipairs(loose_ropes or {}) do
        for _, segment_id in ipairs(rope.segment_ids) do
            known_segments[segment_id] = true
        end
    end
    for _, segment_id in ipairs(EntityGetWithTag(kind.segment_tag) or {}) do
        if not known_segments[segment_id] then
            EntityKill(segment_id)
        end
    end
end
