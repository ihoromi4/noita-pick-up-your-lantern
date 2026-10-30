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
--- A cable is a slack rope of hanging_rope.lua: a physics chain built at runtime gets no bodies when spawned by
--- the mod, and could not grow anyway. A cable entity at the ceiling anchor keeps the segment count and age in
--- storages, so cables are rebuilt after a save and reload. Which lamp a cable holds is not saved: after a reload
--- the lamp falls off and goes dark.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/hanging_rope.lua")

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
-- Length of the tube: the lamp is taken as a thin rod.
local TUBE_LENGTH = 19

---@type RopeKind
local CABLE_KIND = {
    segment_length = SEGMENT_LENGTH,
    segment_entity_path = SEGMENT_ENTITY_PATH,
    anchor_tag = CABLE_TAG,
    segment_tag = SEGMENT_TAG,
    segment_count_storage = SEGMENT_COUNT_STORAGE,
    rigid = false,
}

---A cable; its anchor entity is the cable entity at the ceiling.
---@class CableRope : HangingRope
---@field lamp_id number|nil Lamp the cable holds and powers, nil once it snapped.
---@field max_segments number Number of segments paid out before the cable snaps.
---@field attach_side number 1 or -1: which end of the tube the cable holds while the lamp is in the world.

---Cables simulated this session, by cable entity ID.
---@type table<number, CableRope>
local ropes = {}

---Cables that hold a lamp, by lamp entity ID.
---@type table<number, CableRope>
local lamp_ropes = {}

---Creates the rope of a cable from the anchor to the end of the cable.
---@param cable_id number Cable entity ID.
---@param end_x number World X coordinate of the end of the cable.
---@param end_y number World Y coordinate of the end of the cable.
---@param segment_count number Number of segments.
---@return CableRope
local function CreateRope(cable_id, end_x, end_y, segment_count)
    local anchor_x, anchor_y = EntityGetTransform(cable_id)
    local rope = CreateHangingRope(CABLE_KIND, cable_id, anchor_x, anchor_y, end_x, end_y, segment_count)
    ---@cast rope CableRope
    rope.lamp_id = nil
    rope.max_segments = segment_count
    rope.attach_side = 1
    ropes[cable_id] = rope

    return rope
end

---Spawns a cable entity at the anchor.
---@param anchor_x number World X coordinate of the anchor, right under the ceiling.
---@param anchor_y number World Y coordinate of the anchor.
---@param segment_count number Number of segments.
---@return number|nil cable_id
local function SpawnCableEntity(anchor_x, anchor_y, segment_count)
    return SpawnHangingRopeAnchor(CABLE_ENTITY_PATH, CABLE_KIND, anchor_x, anchor_y, segment_count)
end

---Forgets the lamp of a cable whose rope was dropped.
---@param rope HangingRope
---@return nil
local function OnRopeDropped(rope)
    ---@cast rope CableRope
    if rope.lamp_id ~= nil then
        lamp_ropes[rope.lamp_id] = nil
    end
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
        return OffsetToWorld(x, y, rotation, ATTACH_OFFSET_X * attach_side, ATTACH_OFFSET_Y)
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
    SetStorageFloat(rope.anchor_id, AGE_STORAGE, 0)
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

---Holds a lamp in the world at the length of its cable by the point the cable is attached to: moves its physics
---body so that the point is back on the circle around the anchor, and takes away the speed of the point away from
---the anchor as an impulse at the point would, which also turns the lamp, so it swings on the cable.
---The lamp is taken as a thin rod: the ratio of mass to moment of inertia is 12 / length^2.
---@param lamp_id number Lamp entity ID.
---@param attach_x number World X coordinate of the attachment point.
---@param attach_y number World Y coordinate of the attachment point.
---@param dir_x number Direction from the anchor to the attachment point, X.
---@param dir_y number Direction from the anchor to the attachment point, Y.
---@param shift number How far the attachment point has to move towards the anchor.
---@return nil
local function HoldLampOnCable(lamp_id, attach_x, attach_y, dir_x, dir_y, shift)
    HoldBodyOnHangingRope(lamp_id, attach_x, attach_y, dir_x, dir_y, shift, 12 / (TUBE_LENGTH * TUBE_LENGTH))
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
        PayOutHangingRopeSegment(rope)
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
    local age = GetStorageFloat(rope.anchor_id, AGE_STORAGE) + 1
    if age > LIVE_FRAMES then
        return
    end
    SetStorageFloat(rope.anchor_id, AGE_STORAGE, age)

    if age >= SPARK_DELAY_FRAMES and age % SPARK_INTERVAL_FRAMES == 0 then
        local last = rope.points[#rope.points]
        EntityLoad(SPARK_ENTITY_PATH, last.x, last.y)
        GameCreateCosmeticParticle("spark_electric", last.x, last.y, SPARK_PARTICLE_COUNT, 0, 0)
        InduceCurrent(last.x, last.y)
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
    SyncHangingRopes(CABLE_KIND, ropes, OnRopeDropped)
    UpdatePoweredLamps()

    for _, rope in pairs(ropes) do
        if rope.lamp_id ~= nil then
            UpdateLampCable(rope)
        else
            SparkTornCable(rope)
        end
        SimulateHangingRope(rope, rope.lamp_id ~= nil)
        RenderHangingRope(rope)
    end
end
