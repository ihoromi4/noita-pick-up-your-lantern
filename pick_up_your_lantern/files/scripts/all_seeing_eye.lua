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
-- 10 seconds of fading after the circle has covered the screen.
local XRAY_FADE_FRAMES = 600
-- Fallback screen size from VIRTUAL_RESOLUTION_X/Y in data/magic_numbers.xml.
local SCREEN_WIDTH = 427
local SCREEN_HEIGHT = 242

---The single active reveal circle. A new cast replaces it, inheriting its radius and strength.
---The circle outlives its projectile until it fully fades out.
---@type {x: number, y: number, radius: number, strength: number, is_fading: boolean}?
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

---Returns the camera rectangle in world coordinates.
---@return number x, number y, number width, number height
local function GetScreenBounds()
    if GameGetCameraBounds ~= nil then
        return GameGetCameraBounds()
    end

    local cx, cy = GameGetCameraPos()
    return cx - SCREEN_WIDTH / 2, cy - SCREEN_HEIGHT / 2, SCREEN_WIDTH, SCREEN_HEIGHT
end

---Checks whether a circle covers the whole screen.
---@param x number Circle center x.
---@param y number Circle center y.
---@param radius number
---@return boolean
local function IsScreenCovered(x, y, radius)
    local sx, sy, sw, sh = GetScreenBounds()
    local dx = math.max(math.abs(sx - x), math.abs(sx + sw - x))
    local dy = math.max(math.abs(sy - y), math.abs(sy + sh - y))
    return dx * dx + dy * dy <= radius * radius
end

---Starts a new reveal circle at the cast point of a new All-Seeing Eye projectile.
---The circle inherits the radius and strength of the previous one, so nothing disappears abruptly.
---@param x number Cast point x.
---@param y number Cast point y.
---@return nil
local function StartXRayReveal(x, y)
    local radius, strength = 0.0, 1.0
    if xray_reveal ~= nil then
        radius, strength = xray_reveal.radius, xray_reveal.strength
    end

    xray_reveal = {
        x = x,
        y = y,
        radius = radius,
        strength = strength,
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
                StartXRayReveal(x, y)
            end
        end
    end

    known_projectiles = alive
end

---Advances the reveal circle by the given number of frames.
---The circle expands while its strength rises to full. Once it is at full strength
---and covers the screen or reaches its maximum radius, it fades out over XRAY_FADE_FRAMES.
---@param frames number Frames passed since the last update.
---@return nil
local function AdvanceXRayReveal(frames)
    local reveal = xray_reveal
    if reveal == nil then
        return
    end

    reveal.radius = math.min(XRAY_MAX_RADIUS, reveal.radius + frames * XRAY_GROWTH_PER_FRAME)

    if not reveal.is_fading then
        reveal.strength = math.min(1.0, reveal.strength + frames / XRAY_RISE_FRAMES)
        if reveal.strength >= 1.0
            and (reveal.radius >= XRAY_MAX_RADIUS or IsScreenCovered(reveal.x, reveal.y, reveal.radius)) then
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
---@return nil
local function UpdateXRayReveal()
    local frame = GameGetFrameNum()
    local frames = last_update_frame ~= nil and math.max(0, frame - last_update_frame) or 0
    last_update_frame = frame

    AdvanceXRayReveal(frames)
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
---The spell circle does not depend on the player, so it keeps going while the player entity is missing.
---@param player_entity number? Entity currently controlled by the player, nil when dead.
---@return nil
function UpdateAllSeeingEye(player_entity)
    local perk_reveal = 0.0
    if player_entity ~= nil and GameGetGameEffectCount(player_entity, REMOVE_FOG_EFFECT) > 0 then
        perk_reveal = 1.0
    end
    GameSetPostFxParameter("pul_reveal", perk_reveal, 0.0, 0.0, 0.0)

    UpdateXRayReveal()
end
