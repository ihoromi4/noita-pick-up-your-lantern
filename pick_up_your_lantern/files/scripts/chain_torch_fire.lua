--- Dousing and lighting again of a chain torch, in the world and in hand.
--- Runs every frame to drive the hissing AudioLoopComponent while submerged; liquid checks and timer ticks run
--- every 10 frames.
--- - The fire itself comes from the particle emitters of the torch in the world. In hand the engine turns and
---   mirrors the emitters with the aim of the player, so lantern_in_hand.lua makes the fire at the coals of the
---   swinging sprite instead, and lantern_belt.lua on the belt (EmitOpenFire()).
--- - A torch whose coals stay submerged in a liquid for 1 second (60 frames) is doused: while the timer runs,
---   it emits real fire cells so the liquid reacts natively with fire (e.g. water evaporates into steam, oil
---   ignites) and plays a hissing loop via AudioLoopComponent. Leaving the liquid resets the timer and stops
---   the loop immediately. Lava and liquid_fire never douse the torch and can relight a doused one.
--- - Solid materials do not douse it. Doused, it lights again from fire: in the world when it catches fire
---   itself, in hand when its holder burns, or when dipped into lava or liquid_fire.
--- A torch that has burned out for good (Short-lived) is handled by ExtinguishLantern() and skipped here.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/hanging_rope.lua")

-- Coals below the top of the bail, which is the torch origin, in the world and in hand, where the sprite is drawn
-- at 60% of its size.
local COALS_OFFSET_Y = 6
local HAND_COALS_OFFSET_Y = 3.6
-- Ignition probability of the DamageModelComponent of a doused torch, so it can catch fire in the world.
local DOUSED_IGNITION_PROBABILITY = 1
-- Interval between liquid raychecks and submersion timer ticks, in frames.
local CHECK_INTERVAL_FRAMES = 10
-- Submersion duration before the torch goes out: 1 second at 60 FPS.
local SUBMERSION_DOUSE_FRAMES = 60
-- Maximum gap between consecutive ticks before assuming the torch left the world/hand (e.g. stowed in inventory).
local SUBMERSION_MAX_TICK_GAP = CHECK_INTERVAL_FRAMES * 2
-- How recently MaterialAreaCheckerComponent must have seen lava or liquid_fire to count as a hot liquid.
local HOT_LIQUID_GRACE_FRAMES = CHECK_INTERVAL_FRAMES * 2
-- Real fire particles emitted per tick while submerged to drive native material reactions with fire.
local SUBMERSION_FIRE_COUNT = 15
local SUBMERSION_FIRE_SPREAD_X = 3
local SUBMERSION_FIRE_SPREAD_Y = 1.5
local SUBMERSION_FIRE_VEL_X_MAX = 10
local SUBMERSION_FIRE_VEL_Y_MIN = -24
local SUBMERSION_FIRE_VEL_Y_MAX = -10

local SUBMERSION_FRAMES_STORAGE = "lantern_submersion_frames"
local SUBMERSION_LAST_FRAME_STORAGE = "lantern_submersion_last_frame"
local HOT_LIQUID_FRAME_STORAGE = "lantern_hot_liquid_frame"

local HISS_AUDIO_TAG = "pul_hiss_sound"
local HISS_AUDIO_INTENSITY = 1.0
local MISC_BANK = "data/audio/Desktop/misc.bank"
local EXTINGUISH_EVENT = "game_effect/on_fire/game_effect_end"
local IGNITE_EVENT = "game_effect/on_fire/create"

local entity_id = GetUpdatedEntityID()
if IsLanternExtinguished(entity_id) then
    return
end

local frame = GameGetFrameNum()

-- Drive the hissing loop every frame while the submersion timer is active. Stopping the call fades the loop out.
if GetStorageFloat(entity_id, SUBMERSION_FRAMES_STORAGE) > 0 then
    GameEntityPlaySoundLoop(entity_id, HISS_AUDIO_TAG, HISS_AUDIO_INTENSITY)
end

if frame % CHECK_INTERVAL_FRAMES ~= 0 then
    return
end

local x, y, rotation = EntityGetTransform(entity_id)
local root_id = EntityGetRootEntity(entity_id)
local in_hand = root_id ~= entity_id
local coals_x, coals_y
if in_hand then
    -- The sprite hangs down from the hand, turned by the swing of lantern_in_hand.lua. The rotation of the entity
    -- may still follow the aim of the player here, when this script runs before the swing is applied.
    coals_x, coals_y = OffsetToWorld(x, y, GetStorageFloat(entity_id, "lantern_swing_angle"), 0, HAND_COALS_OFFSET_Y)
else
    coals_x, coals_y = OffsetToWorld(x, y, rotation, 0, COALS_OFFSET_Y)
end

---Checks whether a short vertical ray at a point stops at a liquid cell and not at a solid one.
---@param px number World X coordinate.
---@param py number World Y coordinate.
---@return boolean
local function IsPointInLiquid(px, py)
    local hit_liquid = RaytraceSurfacesAndLiquiform(px, py - 1, px, py + 1)
    return hit_liquid and not RaytraceSurfaces(px, py - 1, px, py + 1)
end

---Checks whether the coals are in a liquid, sampling the center and nearby points so rising steam or gas
---bubbles from the fire reaction do not falsely break submersion.
---@return boolean
local function AreCoalsInLiquid()
    return IsPointInLiquid(coals_x, coals_y)
        or IsPointInLiquid(coals_x - 4, coals_y + 1)
        or IsPointInLiquid(coals_x + 4, coals_y + 1)
        or IsPointInLiquid(coals_x, coals_y + 3)
end

---Checks whether lava or liquid_fire was recently detected around the torch by MaterialAreaCheckerComponent.
---@return boolean
local function IsInHotLiquid()
    local hot_frame = GetStorageFloat(entity_id, HOT_LIQUID_FRAME_STORAGE)
    return hot_frame > 0 and (frame - hot_frame) <= HOT_LIQUID_GRACE_FRAMES
end

---Checks whether fire reaches the torch: the torch itself burns in the world, its holder in hand.
---@return boolean
local function IsTouchedByFire()
    local damage_model = EntityGetFirstComponent(in_hand and root_id or entity_id, "DamageModelComponent")
    return damage_model ~= nil and ComponentGetValue2(damage_model, "is_on_fire")
end

---Resets the submersion countdown timer when the torch is no longer submerged in a dousing liquid.
---@return nil
local function ResetSubmersionTimer()
    if GetStorageFloat(entity_id, SUBMERSION_FRAMES_STORAGE) > 0 then
        SetStorageFloat(entity_id, SUBMERSION_FRAMES_STORAGE, 0)
    end
end

---Emits real fire cells at the coals so Noita's cellular simulation runs the native fire reaction for
---whatever liquid surrounds the torch.
---@return nil
local function EmitSubmersionReactionFire()
    SetRandomSeed(frame, entity_id)
    for _ = 1, SUBMERSION_FIRE_COUNT do
        local px = coals_x + (Random() * 2 - 1) * SUBMERSION_FIRE_SPREAD_X
        local py = coals_y + (Random() * 2 - 1) * SUBMERSION_FIRE_SPREAD_Y
        local vel_x = (Random() * 2 - 1) * SUBMERSION_FIRE_VEL_X_MAX
        local vel_y = SUBMERSION_FIRE_VEL_Y_MIN + Random() * (SUBMERSION_FIRE_VEL_Y_MAX - SUBMERSION_FIRE_VEL_Y_MIN)
        GameCreateParticle("fire", px, py, 1, vel_x, vel_y, false, false, false)
    end
end

---Switches the emitters of the torch on or off, and lets it catch fire in the world while doused.
---@param is_doused boolean
---@return nil
local function ApplyDousedComponents(is_doused)
    for _, emitter_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "ParticleEmitterComponent") or {}) do
        ComponentSetValue2(emitter_comp, "is_emitting", not is_doused)
    end

    local damage_model = EntityGetFirstComponentIncludingDisabled(entity_id, "DamageModelComponent")
    if damage_model ~= nil then
        ComponentSetValue2(damage_model, "fire_probability_of_ignition", is_doused and DOUSED_IGNITION_PROBABILITY or 0)
        ComponentSetValue2(damage_model, "is_on_fire", false)
    end
end

---Puts the torch out or lights it again: switches its emitters, light, fog of war hole, sprites and sound.
---@param is_doused boolean
---@return nil
local function SetDoused(is_doused)
    ResetSubmersionTimer()
    SetLanternDoused(entity_id, is_doused)
    ApplyDousedComponents(is_doused)
    if is_doused then
        GameCreateCosmeticParticle("smoke", coals_x, coals_y, 6, 0, -20)
        GamePlaySound(MISC_BANK, EXTINGUISH_EVENT, coals_x, coals_y)
    else
        GamePlaySound(MISC_BANK, IGNITE_EVENT, coals_x, coals_y)
    end
    RefreshLanternIllumination(entity_id)
end

local in_hot_liquid = IsInHotLiquid()

if IsLanternDoused(entity_id) then
    if in_hot_liquid or (IsTouchedByFire() and not AreCoalsInLiquid()) then
        SetDoused(false)
    else
        -- A torch hung with the left mouse button is a new entity that copied only the doused state.
        ApplyDousedComponents(true)
    end
elseif not in_hot_liquid and AreCoalsInLiquid() then
    local last_frame = GetStorageFloat(entity_id, SUBMERSION_LAST_FRAME_STORAGE)
    local submersion_frames = GetStorageFloat(entity_id, SUBMERSION_FRAMES_STORAGE)
    if last_frame == 0 or (frame - last_frame) > SUBMERSION_MAX_TICK_GAP then
        submersion_frames = 0
    end
    submersion_frames = submersion_frames + CHECK_INTERVAL_FRAMES
    SetStorageFloat(entity_id, SUBMERSION_LAST_FRAME_STORAGE, frame)

    if submersion_frames >= SUBMERSION_DOUSE_FRAMES then
        SetDoused(true)
    else
        SetStorageFloat(entity_id, SUBMERSION_FRAMES_STORAGE, submersion_frames)
        GameEntityPlaySoundLoop(entity_id, HISS_AUDIO_TAG, HISS_AUDIO_INTENSITY)
        EmitSubmersionReactionFire()
    end
else
    ResetSubmersionTimer()
end
