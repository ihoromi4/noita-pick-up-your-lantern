--[[
    Mathematical Model: Damped Spring-Damper Pendulum for In-Hand Lantern Sway

    Simulates realistic handheld lantern secondary motion using a damped harmonic oscillator
    (semi-implicit Euler integration) driven by player velocity.

    1. Coordinate System & Inertial Lag:
        - Noita uses a 2D coordinate system where positive Y points downwards.
        - Positive rotation turns clockwise, deflecting the bottom of the lantern to the left.
        - Moving right (vx > 0) sets a positive target tilt, lagging the lantern to the left (backward).
        - Moving left (vx < 0) sets a negative target tilt, lagging the lantern to the right (backward).

    2. Walking Gait & Footstep Sway:
        - While moving (|vx| > VELOCITY_THRESHOLD), a walk phase accumulator is stepped:
            step_phase = (step_phase + |vx| * STEP_FREQ) % (2 * pi)
        - A harmonic footstep oscillation is added to the target angle:
            sway = sin(step_phase) * SWAY_AMOUNT * sgn(vx)
        This guarantees that the initial swing from a rest state always deflects backward against
        the direction of movement.

    3. Spring-Damper Dynamics:
        - Spring restoring force towards target angle:
            spring_force = (target_angle - angle) * SPRING_K
        - Semi-implicit Euler integration with velocity damping:
            angle_vel = (angle_vel + spring_force) * DAMPING
            angle = angle + angle_vel

    4. State Reset within Tolerance:
        - When the player stops (|vx|, |vy| <= VELOCITY_THRESHOLD), the pendulum freely settles.
        - Once |angle| < TOLERANCE_ANGLE and |angle_vel| < TOLERANCE_VEL, all state variables
            (angle, angle_vel, step_phase) snap to zero.
        - This prevents floating-point drift and guarantees that any subsequent movement begins
            deterministically from rest.
]]

local MOD_ID = "pick_up_your_lantern"
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")

-- Spring-damper pendulum tuning constants
local SPRING_K = 0.05
local DAMPING = 0.9
local TILT_FACTOR = 0.3
local SWAY_AMOUNT = 0.3
local STEP_FREQ = 0.12

local TOLERANCE_ANGLE = 0.008
local TOLERANCE_VEL = 0.004

local MAX_TARGET_ANGLE = 0.6
local MAX_ANGLE = 0.7
local VELOCITY_THRESHOLD = 0.05

-- Open fire in hand: coals below the hand at the scale of the in-hand sprite (6 px at 60%), and the share of the
-- fire particles that are real fire cells; the others are only visual, so the holder does not catch fire at once.
local OPEN_FIRE_COALS_OFFSET_Y = 3.6
local OPEN_FIRE_REAL_CHANCE = 0.1

---Open fire config of each held lantern by entity ID, false for lanterns without one. Lantern scripts share one
---Lua state per script file, so the type is looked up once per lantern.
---@type table<number, LanternOpenFire|false>
open_fire_by_lantern = open_fire_by_lantern or {}

local entity_id = GetUpdatedEntityID()
local x, y, _, scale_x, scale_y = EntityGetTransform(entity_id)
local root_id = EntityGetRootEntity(entity_id)

local vx, vy = GameGetVelocityCompVelocity(root_id)
vx = vx or 0
vy = vy or 0

if vx == 0 and vy == 0 then
    local char_data = EntityGetFirstComponentIncludingDisabled(root_id, "CharacterDataComponent")
    if char_data ~= nil then
        local cvx, cvy = ComponentGetValue2(char_data, "mVelocity")
        vx = (cvx or 0) / 60.0
        vy = (cvy or 0) / 60.0
    end
end

local angle = GetStorageFloat(entity_id, "lantern_swing_angle")
local angle_vel = GetStorageFloat(entity_id, "lantern_swing_vel")
local step_phase = GetStorageFloat(entity_id, "lantern_swing_phase")

local target_angle = vx * TILT_FACTOR

if math.abs(vx) > VELOCITY_THRESHOLD then
    step_phase = (step_phase + math.abs(vx) * STEP_FREQ) % (math.pi * 2.0)
    local move_dir = (vx > 0) and 1.0 or -1.0
    target_angle = target_angle + math.sin(step_phase) * SWAY_AMOUNT * move_dir
end

target_angle = clamp(target_angle, -MAX_TARGET_ANGLE, MAX_TARGET_ANGLE)

local spring_force = (target_angle - angle) * SPRING_K
angle_vel = (angle_vel + spring_force) * DAMPING
angle = angle + angle_vel

angle = clamp(angle, -MAX_ANGLE, MAX_ANGLE)

local is_moving = (math.abs(vx) > VELOCITY_THRESHOLD) or (math.abs(vy) > VELOCITY_THRESHOLD)
if not is_moving then
    if math.abs(angle) < TOLERANCE_ANGLE and math.abs(angle_vel) < TOLERANCE_VEL then
        angle = 0.0
        angle_vel = 0.0
        step_phase = 0.0
    end
end

SetStorageFloat(entity_id, "lantern_swing_angle", angle)
SetStorageFloat(entity_id, "lantern_swing_vel", angle_vel)
SetStorageFloat(entity_id, "lantern_swing_phase", step_phase)

EntitySetTransform(entity_id, x, y, angle, scale_x or 1, scale_y or 1)

-- The fire hangs below the hand at the coals of the sprite, turned by the swing like the sprite.
local open_fire = open_fire_by_lantern[entity_id]
if open_fire == nil then
    local _, lantern_type = GetLanternType(entity_id)
    open_fire = lantern_type.open_fire or false
    open_fire_by_lantern[entity_id] = open_fire
end
if open_fire and not IsLanternExtinguished(entity_id) and not IsLanternDoused(entity_id) then
    local coals_x = x - math.sin(angle) * OPEN_FIRE_COALS_OFFSET_Y
    local coals_y = y + math.cos(angle) * OPEN_FIRE_COALS_OFFSET_Y
    EmitOpenFire(open_fire, coals_x, coals_y, OPEN_FIRE_REAL_CHANCE)
end
