--- All-Seeing Eye support for Pick Up Your Lantern mod.
--- Passes areas revealed by the All-Seeing Eye spell (X_RAY) and perk (REMOVE_FOG_OF_WAR)
--- to the post_final shader, so the limited vision does not darken them again.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")

local XRAY_PROJECTILE_PATH = "data/entities/projectiles/deck/xray.xml"
local XRAY_TAG = "pul_xray"
local REMOVE_FOG_EFFECT = "REMOVE_FOG_OF_WAR"

-- MagicXRayComponent radius="512" from xray.xml, expanding 3 times slower than steps_per_frame="8".
local XRAY_MAX_RADIUS = 512
local XRAY_GROWTH_PER_FRAME = 8 / 3
-- 1 second for the strength to rise from 0 to full after a cast.
local XRAY_RISE_FRAMES = 60
-- 10 seconds of full strength for a cast without lifetime modifiers.
local XRAY_BASE_REVEAL_FRAMES = 600
-- Each frame of projectile lifetime added by modifiers adds this many frames of full strength.
local XRAY_LIFETIME_MULTIPLIER = 5
-- The circle always reaches full strength, even when modifiers shorten the lifetime a lot.
local XRAY_MIN_REVEAL_FRAMES = XRAY_RISE_FRAMES
-- 10 seconds of fading after the reveal timer runs out.
local XRAY_FADE_FRAMES = 600
-- The reveal timer waits while the player stays within this distance from the cast point.
local XRAY_HOLD_DISTANCE = 64

---The single active reveal circle. A new cast replaces it, inheriting its radius and strength.
---The circle outlives its projectile, which MagicXRayComponent removes after about 64 frames.
---`reveal_frames` is the reveal timer: the frames left before the circle starts to fade.
---`is_released` turns on once the player first leaves the hold distance and never turns off.
---@type {x: number, y: number, radius: number, strength: number, reveal_frames: number, is_released: boolean, is_fading: boolean}?
local xray_reveal = nil
---All-Seeing Eye projectiles that have already been cast, keyed by entity id.
---@type table<number, boolean>
local known_projectiles = {}
local last_update_frame = nil

---Patches the All-Seeing Eye projectile with a tag used to find it at runtime.
---@return nil
function PatchXRayProjectile()
    local content = ModTextFileGetContent(XRAY_PROJECTILE_PATH)
    if content == nil or content == "" then
        print(string.format("[%s] ERROR: Failed to read %s", MOD_ID, XRAY_PROJECTILE_PATH))
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        print(string.format("[%s] ERROR: Failed to parse %s", MOD_ID, XRAY_PROJECTILE_PATH))
        return
    end

    local tags = xml.attr.tags or ""
    for tag in tags:gmatch("[^,]+") do
        if tag == XRAY_TAG then
            return
        end
    end
    xml.attr.tags = tags == "" and XRAY_TAG or tags .. "," .. XRAY_TAG

    ModTextFileSetContent(XRAY_PROJECTILE_PATH, nxml.tostring(xml))
end

---Returns the reveal timer for a new All-Seeing Eye projectile.
---Spell modifiers add `c.lifetime_add` to the `lifetime` field, while `mStartingLifetime` keeps
---the value from the XML. The field counts down every frame, and the script first sees
---the projectile one frame after the cast, hence the `+ 1`.
---@param entity_id number All-Seeing Eye projectile.
---@return number frames Frames of full strength before the circle starts to fade.
local function GetRevealFrames(entity_id)
    local projectile = EntityGetFirstComponentIncludingDisabled(entity_id, "ProjectileComponent")
    if projectile == nil then
        return XRAY_BASE_REVEAL_FRAMES
    end

    local lifetime = ComponentGetValue2(projectile, "lifetime")
    local starting_lifetime = ComponentGetValue2(projectile, "mStartingLifetime")
    if lifetime == nil or starting_lifetime == nil or lifetime < 0 or starting_lifetime < 0 then
        return XRAY_BASE_REVEAL_FRAMES
    end

    local lifetime_add = lifetime + 1 - starting_lifetime
    return math.max(XRAY_MIN_REVEAL_FRAMES, XRAY_BASE_REVEAL_FRAMES + lifetime_add * XRAY_LIFETIME_MULTIPLIER)
end

---Starts a new reveal circle at the cast point of a new All-Seeing Eye projectile.
---The circle inherits the radius and strength of the previous one, so nothing disappears abruptly.
---The reveal timer comes from the new projectile, so the latest cast decides when the fading starts.
---The new circle is not released, so its timer waits again until the player leaves the cast point.
---@param x number Cast point x.
---@param y number Cast point y.
---@param reveal_frames number Frames of full strength before the circle starts to fade.
---@return nil
local function StartXRayReveal(x, y, reveal_frames)
    local radius, strength = 0.0, 1.0
    if xray_reveal ~= nil then
        radius, strength = xray_reveal.radius, xray_reveal.strength
    end

    xray_reveal = {
        x = x,
        y = y,
        radius = radius,
        strength = strength,
        reveal_frames = reveal_frames,
        is_released = false,
        is_fading = false,
    }
end

---Starts a reveal circle for each All-Seeing Eye projectile cast since the last frame.
---@return nil
local function RegisterXRayProjectiles()
    local alive = {}
    for _, entity_id in ipairs(EntityGetWithTag(XRAY_TAG) or {}) do
        alive[entity_id] = true
        if not known_projectiles[entity_id] then
            local x, y = EntityGetTransform(entity_id)
            if x ~= nil and y ~= nil then
                StartXRayReveal(x, y, GetRevealFrames(entity_id))
            end
        end
    end

    known_projectiles = alive
end

---Checks whether the reveal timer of the circle waits for the player to leave the cast point.
---The circle is released once the player first moves farther than XRAY_HOLD_DISTANCE.
---Without a player, the timer does not wait, but the circle is not released either.
---@param reveal table The active reveal circle.
---@param player_x number? Player x, nil without a player entity.
---@param player_y number? Player y, nil without a player entity.
---@return boolean
local function IsXRayRevealHeld(reveal, player_x, player_y)
    if reveal.is_released or player_x == nil or player_y == nil then
        return false
    end

    local dx, dy = player_x - reveal.x, player_y - reveal.y
    if dx * dx + dy * dy > XRAY_HOLD_DISTANCE * XRAY_HOLD_DISTANCE then
        reveal.is_released = true
        return false
    end

    return true
end

---Advances the reveal circle by the given number of frames.
---The circle expands while its strength rises to full. The reveal timer counts down
---once the player has left the cast point. When it runs out, the circle fades out over XRAY_FADE_FRAMES.
---@param frames number Frames passed since the last update.
---@param player_x number? Player x, nil without a player entity.
---@param player_y number? Player y, nil without a player entity.
---@return nil
local function AdvanceXRayReveal(frames, player_x, player_y)
    local reveal = xray_reveal
    if reveal == nil then
        return
    end

    reveal.radius = math.min(XRAY_MAX_RADIUS, reveal.radius + frames * XRAY_GROWTH_PER_FRAME)

    if not reveal.is_fading then
        reveal.strength = math.min(1.0, reveal.strength + frames / XRAY_RISE_FRAMES)
        if not IsXRayRevealHeld(reveal, player_x, player_y) then
            reveal.reveal_frames = reveal.reveal_frames - frames
        end
        if reveal.reveal_frames <= 0 then
            reveal.is_fading = true
        end
        return
    end

    reveal.strength = reveal.strength - frames / XRAY_FADE_FRAMES
    if reveal.strength <= 0.0 then
        xray_reveal = nil
    end
end

---Passes the All-Seeing Eye spell circle to the shader.
---@param player_x number? Player x, nil without a player entity.
---@param player_y number? Player y, nil without a player entity.
---@return nil
local function UpdateXRayReveal(player_x, player_y)
    local frame = GameGetFrameNum()
    local frames = last_update_frame ~= nil and math.max(0, frame - last_update_frame) or 0
    last_update_frame = frame

    AdvanceXRayReveal(frames, player_x, player_y)
    RegisterXRayProjectiles()

    local reveal = xray_reveal
    if reveal == nil then
        GameSetPostFxParameter("pul_xray", 0.0, 0.0, 0.0, 0.0)
        return
    end

    GameSetPostFxParameter("pul_xray", reveal.x, reveal.y, reveal.radius, reveal.strength)
end

---Updates All-Seeing Eye reveals every frame.
---The perk reveals the whole level, the spell reveals a circle around its cast point.
---The spell circle waits while the player stays near the cast point.
---Without a player entity, the circle keeps going and its timer counts down as usual.
---@param player_entity number? Entity currently controlled by the player, nil when dead.
---@return nil
function UpdateAllSeeingEye(player_entity)
    local perk_reveal = 0.0
    if player_entity ~= nil and GameGetGameEffectCount(player_entity, REMOVE_FOG_EFFECT) > 0 then
        perk_reveal = 1.0
    end
    GameSetPostFxParameter("pul_reveal", perk_reveal, 0.0, 0.0, 0.0)

    local player_x, player_y = nil, nil
    if player_entity ~= nil then
        player_x, player_y = EntityGetTransform(player_entity)
    end
    UpdateXRayReveal(player_x, player_y)
end
