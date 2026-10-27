--- Fire enemy glow for Pick Up Your Lantern mod.
--- Fire-related enemies get a bright light of their own and dispel fog of war around themselves,
--- so they stand out in darkness.
--- Vanilla fire enemies use tuned light parameters; enemies of other mods are detected by their components.
--- Each enemy is checked once: the check tag is saved with the entity, so the light is never added twice.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

---@class FireGlow
---@field radius number Light radius in world pixels.
---@field r number Red, 0-255.
---@field g number Green, 0-255.
---@field b number Blue, 0-255.

local SCAN_INTERVAL_FRAMES = 30
-- Covers the screen with a margin, so enemies get their light before they come into view.
local SCAN_RADIUS = 512
local CHECKED_TAG = "pul_fire_glow_checked"
local GLOW_TAG = "pul_fire_glow"
-- The light fades out after the enemy dies, as the light of a burning entity does.
local GLOW_FADE_OUT_SECONDS = 1.0

-- The fog of war hole follows the `Illuminate the darkness` setting, as the holes of lanterns and other light sources do.
local ILLUMINATE_SETTING_ID = MOD_ID .. ".illuminate_the_darkness"
local FOG_HOLE_IMAGE = "data/particles/fog_of_war_hole_64.xml"
local FOG_HOLE_ALPHA = 0.55
-- A lantern with a 280 px light has a hole of scale 1.2; fire enemies keep the same proportion.
local FOG_HOLE_SCALE_PER_LIGHT_RADIUS = 1.2 / 280

-- Several bosses have no `enemy` tag, and the Dragon has neither `enemy` nor `boss`.
local ENEMY_TAGS = {
    "enemy",
    "boss",
    "boss_dragon",
}

local VANILLA_ANIMALS_PATTERN = "^data/entities/animals/.-([^/]+)%.xml$"
-- Light of vanilla fire enemies by file name; biome variants (e.g. `vault/firemage.xml`) share it.
---@type table<string, FireGlow>
local VANILLA_GLOWS = {
    -- Stendari: orange fireballs.
    firemage_weak = { radius = 150, r = 255, g = 130, b = 40, },
    -- Eldari: blue hellfire.
    firemage = { radius = 170, r = 90, g = 150, b = 255, },
    -- Liekkiö.
    fireskull = { radius = 130, r = 255, g = 170, b = 60, },
    fireskull_weak = { radius = 100, r = 255, g = 170, b = 60, },
    -- Helvetinkatse: lava blood and lava shots.
    gazer = { radius = 160, r = 255, g = 90, b = 30, },
    firebug = { radius = 100, r = 255, g = 150, b = 50, },
    bigfirebug = { radius = 150, r = 255, g = 150, b = 50, },
    flamer = { radius = 130, r = 255, g = 120, b = 40, },
    miner_fire = { radius = 110, r = 255, g = 140, b = 50, },
    boss_dragon = { radius = 260, r = 255, g = 130, b = 30, },
}
-- Colour of fire enemies detected by their components.
local DETECTED_GLOW_COLOR = { r = 255, g = 130, b = 40, }
-- Light radius of a detected fire enemy grows with its fire score: GLOW_BASE_RADIUS + GLOW_RADIUS_PER_SCORE * score.
local GLOW_BASE_RADIUS = 100
local GLOW_RADIUS_PER_SCORE = 50

-- Fire detection: each sign gives a point, the fire herd gives two. Fire immunity is not a sign:
-- dozens of vanilla enemies have it. Torch particles and burning blood alone are not enough either:
-- mages carry torches, and Hell Hiisi bleed liquid fire.
local FIRE_SCORE_THRESHOLD = 2
local FIRE_HERD = "fire"
local FIRE_HERD_SCORE = 2
local FIRE_MATERIALS = {
    fire = true,
    flame = true,
    fire_blue = true,
    lava = true,
    liquid_fire = true,
    liquid_fire_weak = true,
    burning_powder = true,
}
-- Looked for in the file name (without folders, which may hold a mod name), the entity name and the attack file name.
local FIRE_KEYWORDS = {
    "fire",
    "flame",
    "lava",
    "magma",
    "inferno",
    "pyro",
    "blaze",
    "ember",
    "burn",
    "liekki",
    "tuli",
}

---Returns the file name of a path without folders and extension.
---@param path string File path.
---@return string
local function GetFileStem(path)
    local stem = (path:match("([^/]+)$") or path):gsub("%.xml$", "")
    return stem
end

---Checks whether a text contains any fire keyword.
---@param text string|nil Text to check.
---@return boolean
local function HasFireKeyword(text)
    if text == nil or text == "" then
        return false
    end

    text = text:lower()
    for _, keyword in ipairs(FIRE_KEYWORDS) do
        if text:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

---Checks whether an entity emits fire particles.
---@param entity_id number Entity ID.
---@return boolean
local function EmitsFireParticles(entity_id)
    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "ParticleEmitterComponent") or {}) do
        if FIRE_MATERIALS[ComponentGetValue2(comp, "emitted_material_name")] then
            return true
        end
    end

    return false
end

---Checks whether an enemy or its body parts emit fire particles, e.g. the burning hands of a fire mage.
---Status effects (such as being on fire) and carried items are skipped, as they say nothing about the enemy.
---@param enemy_id number Enemy entity ID.
---@return boolean
local function HasFireParticles(enemy_id)
    if EmitsFireParticles(enemy_id) then
        return true
    end

    for _, child_id in ipairs(EntityGetAllChildren(enemy_id) or {}) do
        if EntityGetFirstComponentIncludingDisabled(child_id, "GameEffectComponent") == nil
            and EntityGetFirstComponentIncludingDisabled(child_id, "ItemComponent") == nil
            and EmitsFireParticles(child_id) then
            return true
        end
    end

    return false
end

---Checks whether an enemy bleeds a fire material.
---@param enemy_id number Enemy entity ID.
---@return boolean
local function HasFireBlood(enemy_id)
    local damage_comp = EntityGetFirstComponentIncludingDisabled(enemy_id, "DamageModelComponent")
    if damage_comp == nil then
        return false
    end

    return FIRE_MATERIALS[ComponentGetValue2(damage_comp, "blood_material")] == true
        or FIRE_MATERIALS[ComponentGetValue2(damage_comp, "blood_spray_material")] == true
end

---Checks whether an enemy has a fire ranged attack, by the name of its projectile file.
---@param enemy_id number Enemy entity ID.
---@return boolean
local function HasFireAttack(enemy_id)
    for _, ai_comp in ipairs(EntityGetComponentIncludingDisabled(enemy_id, "AnimalAIComponent") or {}) do
        if HasFireKeyword(GetFileStem(ComponentGetValue2(ai_comp, "attack_ranged_entity_file") or "")) then
            return true
        end
    end

    return false
end

---Checks whether an enemy belongs to the fire herd.
---@param enemy_id number Enemy entity ID.
---@return boolean
local function IsInFireHerd(enemy_id)
    local genome_comp = EntityGetFirstComponentIncludingDisabled(enemy_id, "GenomeDataComponent")
    if genome_comp == nil then
        return false
    end

    return HerdIdToString(ComponentGetValue2(genome_comp, "herd_id")) == FIRE_HERD
end

---Scores the fire signs of an enemy.
---@param enemy_id number Enemy entity ID.
---@param file string Enemy file path.
---@return number
local function GetFireScore(enemy_id, file)
    local score = 0
    if IsInFireHerd(enemy_id) then
        score = score + FIRE_HERD_SCORE
    end
    if HasFireKeyword(GetFileStem(file)) or HasFireKeyword(EntityGetName(enemy_id)) then
        score = score + 1
    end
    if HasFireAttack(enemy_id) then
        score = score + 1
    end
    if HasFireBlood(enemy_id) then
        score = score + 1
    end
    if HasFireParticles(enemy_id) then
        score = score + 1
    end

    return score
end

---Picks the light of an enemy: tuned for vanilla fire enemies, growing with the fire score for detected ones.
---@param enemy_id number Enemy entity ID.
---@return FireGlow|nil glow Light parameters, or nil if the enemy is not fire-related.
local function GetFireGlow(enemy_id)
    local file = EntityGetFilename(enemy_id) or ""
    local vanilla_name = file:match(VANILLA_ANIMALS_PATTERN)
    if vanilla_name ~= nil and VANILLA_GLOWS[vanilla_name] ~= nil then
        return VANILLA_GLOWS[vanilla_name]
    end

    local score = GetFireScore(enemy_id, file)
    if score >= FIRE_SCORE_THRESHOLD then
        return {
            radius = GLOW_BASE_RADIUS + GLOW_RADIUS_PER_SCORE * score,
            r = DETECTED_GLOW_COLOR.r,
            g = DETECTED_GLOW_COLOR.g,
            b = DETECTED_GLOW_COLOR.b,
        }
    end

    return nil
end

---Checks whether light sources dispel fog of war, as set in mod settings.
---@return boolean
local function IsIlluminationEnabled()
    local is_enabled = ModSettingGet(ILLUMINATE_SETTING_ID)
    if is_enabled == nil then
        is_enabled = ModSettingGetNextValue(ILLUMINATE_SETTING_ID)
    end

    -- On by default.
    return is_enabled ~= false
end

---Adds the fire light and the fog of war hole to an enemy, centred on its hitbox.
---Without `update_properties`, a light added at runtime keeps the default zero radius and stays invisible.
---@param enemy_id number Enemy entity ID.
---@param glow FireGlow Light parameters.
---@return nil
local function AddGlow(enemy_id, glow)
    local x, y = EntityGetTransform(enemy_id)
    local cx, cy = EntityGetFirstHitboxCenter(enemy_id)
    local offset_x = cx ~= nil and cx - x or 0
    local offset_y = cy ~= nil and cy - y or 0
    EntityAddComponent2(enemy_id, "LightComponent", {
        _tags = GLOW_TAG,
        update_properties = true,
        radius = glow.radius,
        r = glow.r,
        g = glow.g,
        b = glow.b,
        offset_x = offset_x,
        offset_y = offset_y,
        fade_out_time = GLOW_FADE_OUT_SECONDS,
    })

    if not IsIlluminationEnabled() then
        return
    end

    local fog_hole_scale = glow.radius * FOG_HOLE_SCALE_PER_LIGHT_RADIUS * GetIlluminationScale()
    local sprite_comp = EntityAddComponent2(enemy_id, "SpriteComponent", {
        _tags = GLOW_TAG,
        alpha = FOG_HOLE_ALPHA,
        image_file = FOG_HOLE_IMAGE,
        smooth_filtering = true,
        fog_of_war_hole = true,
        has_special_scale = true,
        special_scale_x = fog_hole_scale,
        special_scale_y = fog_hole_scale,
    })
    ComponentSetValue2(sprite_comp, "transform_offset", offset_x, offset_y)
end

---Checks enemies around the camera that have not been checked yet, lights the fire-related ones
---and marks them with FIRE_ENEMY_TAG for the lantern attraction.
---Runs every SCAN_INTERVAL_FRAMES frames from OnWorldPreUpdate.
---@return nil
function UpdateFireEnemyGlow()
    if GameGetFrameNum() % SCAN_INTERVAL_FRAMES ~= 0 then
        return
    end

    local x, y = GameGetCameraPos()
    for _, tag in ipairs(ENEMY_TAGS) do
        for _, enemy_id in ipairs(EntityGetInRadiusWithTag(x, y, SCAN_RADIUS, tag) or {}) do
            if not EntityHasTag(enemy_id, CHECKED_TAG) and EntityGetParent(enemy_id) == 0 then
                EntityAddTag(enemy_id, CHECKED_TAG)
                local glow = GetFireGlow(enemy_id)
                if glow ~= nil then
                    EntityAddTag(enemy_id, FIRE_ENEMY_TAG)
                    AddGlow(enemy_id, glow)
                end
            end
        end
    end
end
