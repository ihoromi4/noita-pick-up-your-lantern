--- Enemy study for Pick Up Your Lantern mod.
--- An enemy watched by the player in lantern light is studied: the player's damage against it grows up to
--- the configured bonus. Every bit of study adds to the knowledge of the enemy type, of its family (variants
--- of the same enemy, e.g. a weak and a normal zombie) and of its herd (e.g. all Hiisi). The better the player
--- knows a type and its relatives, the faster its enemies are studied. Bosses neither give nor get knowledge.
--- A dot above the enemy shows its study state: yellow while it is being studied, red while its study is paused
--- (out of light or sight), green once it is fully studied.
--- Also loaded by the enemy damage hook, so the top level only defines constants and functions.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local ENABLED_SETTING_ID = MOD_ID .. ".enemy_study"
local BONUS_SETTING_ID = MOD_ID .. ".enemy_study_damage_bonus"
local DEFAULT_BONUS = 0.25
local DURATION_SETTING_ID = MOD_ID .. ".enemy_study_duration"
-- Study time of an unknown type in seconds, shrinking linearly to KNOWN_TYPE_STUDY_FRAMES for a fully known one.
local DEFAULT_STUDY_SECONDS = 10
local FRAMES_PER_SECOND = 60

local PLAYER_TAGS = {
    "player_unit",
    "polymorphed_player",
}
-- Several bosses have no `enemy` tag, and the Dragon has neither `enemy` nor `boss`.
local ENEMY_TAGS = {
    "enemy",
    "boss",
    "boss_dragon",
}
local BOSS_TAGS = {
    "boss",
    "boss_dragon",
}

local MARKER_PATH = "mods/" .. MOD_ID .. "/files/entities/study_marker.xml"
local MARKER_TAG = "pul_study_marker"
local MARKER_IN_PROGRESS_TAG = "pul_study_in_progress"
local MARKER_PAUSED_TAG = "pul_study_paused"
local MARKER_DONE_TAG = "pul_study_done"
-- Half of the dot image size, so the dot is centred on its position.
local MARKER_SPRITE_CENTER = 2
-- The 4 px dot image is drawn at half of its size.
local MARKER_SCALE = 1 / 2
-- Gap between the top of the enemy hitbox and the dot.
local MARKER_MARGIN = 3
-- Height of the dot above enemies without a hitbox.
local DEFAULT_MARKER_HEIGHT = 10

local DAMAGE_SCRIPT = "mods/" .. MOD_ID .. "/files/scripts/enemy_study_damage.lua"
-- Study progress of an enemy, from 0 to 1.
local PROGRESS_STORAGE = "pul_study_progress"
local DONE_STORAGE = "pul_study_done"
-- Knowledge of an enemy type, family and herd: the sum of the study progress of all their enemies.
local TYPE_KNOWLEDGE_GLOBAL_PREFIX = "pul_study_knowledge_"
local FAMILY_KNOWLEDGE_GLOBAL_PREFIX = "pul_study_family_knowledge_"
local HERD_KNOWLEDGE_GLOBAL_PREFIX = "pul_study_herd_knowledge_"
-- Share of the knowledge of other variants of the same enemy, and of the rest of its herd.
local FAMILY_KNOWLEDGE_WEIGHT = 0.5
local HERD_KNOWLEDGE_WEIGHT = 0.2
-- Suffixes of enemy file names that mark a variant of the same enemy, stripped to get the family key.
local VARIANT_SUFFIXES = {
    "_weak",
    "_big",
    "_small",
    "_tiny",
    "_giga",
    "_large",
    "_super",
    "_hell",
    "_fire",
    "_chef",
    "_santa",
    "_a",
    "_b",
}
-- Herd of charmed enemies and the player's allies, which says nothing about the enemy itself.
local PLAYER_HERD = "player"

local SCAN_INTERVAL_FRAMES = 10
local STUDY_RADIUS = 400
-- Share of the lantern light radius that looks lit: the soft outer edge of the light does not count.
local LIT_RADIUS_FACTOR = 0.6
local KNOWN_TYPE_STUDY_FRAMES = 30
-- Knowledge at which enemies take KNOWN_TYPE_STUDY_FRAMES to study.
local FULL_TYPE_KNOWLEDGE = 10
local BOSS_STUDY_FRAMES = 7200

---Retrieves a raw mod setting value, falling back to the pending value.
---@param setting_id string
---@return any
local function GetSettingValue(setting_id)
    local val = ModSettingGet(setting_id)
    if val == nil then
        val = ModSettingGetNextValue(setting_id)
    end

    return val
end

---Checks whether the Enemy Study option is on.
---@return boolean
function IsEnemyStudyEnabled()
    return GetSettingValue(ENABLED_SETTING_ID) == true
end

---Retrieves the damage bonus of a fully studied enemy from mod settings.
---@return number
local function GetFullStudyBonus()
    local bonus = tonumber(GetSettingValue(BONUS_SETTING_ID))
    if bonus == nil or bonus < 0 then
        return DEFAULT_BONUS
    end

    return bonus
end

---Retrieves the study duration of an enemy of an unknown type from mod settings.
---@return number frames
local function GetBaseStudyFrames()
    local seconds = tonumber(GetSettingValue(DURATION_SETTING_ID))
    if seconds == nil or seconds <= 0 then
        seconds = DEFAULT_STUDY_SECONDS
    end

    return seconds * FRAMES_PER_SECOND
end

---Reads a float study value of an enemy without adding storage to enemies that were never studied.
---@param enemy_id number Enemy entity ID.
---@param name string Variable storage name.
---@return number|nil value Stored value, or nil if the enemy has no such storage.
local function FindStudyValue(enemy_id, name)
    local comp = FindVariableStorage(enemy_id, name)
    if comp == nil then
        return nil
    end

    return ComponentGetValue2(comp, "value_float")
end

---Returns the player's damage bonus against an enemy for its accumulated study.
---@param enemy_id number Enemy entity ID.
---@return number bonus Damage bonus, from 0 to the bonus of a fully studied enemy.
function GetEnemyStudyBonus(enemy_id)
    local progress = FindStudyValue(enemy_id, PROGRESS_STORAGE) or 0
    return GetFullStudyBonus() * math.min(1, progress)
end

---Checks whether an entity is the player, including a polymorphed player.
---@param entity_id number|nil Entity ID.
---@return boolean
function IsPlayerEntity(entity_id)
    if entity_id == nil or entity_id == 0 then
        return false
    end

    for _, tag in ipairs(PLAYER_TAGS) do
        if EntityHasTag(entity_id, tag) then
            return true
        end
    end

    return false
end

---Finds the entity currently controlled by the player.
---@return number player_id Player entity ID, or 0 if not found.
local function FindStudyingPlayer()
    for _, tag in ipairs(PLAYER_TAGS) do
        local players = EntityGetWithTag(tag) or {}
        if players[1] ~= nil then
            return players[1]
        end
    end

    return 0
end

---Checks whether an entity has any of the tags.
---@param entity_id number Entity ID.
---@param tags string[] Tags to look for.
---@return boolean
local function HasAnyTag(entity_id, tags)
    for _, tag in ipairs(tags) do
        if EntityHasTag(entity_id, tag) then
            return true
        end
    end

    return false
end

---Returns the type key of an enemy: the file it was loaded from, or its name.
---@param enemy_id number Enemy entity ID.
---@return string
local function GetEnemyTypeKey(enemy_id)
    local file = EntityGetFilename(enemy_id)
    if file ~= nil and file ~= "" then
        return file
    end

    return EntityGetName(enemy_id) or ""
end

---Returns the family key of an enemy type: its file path without variant suffixes,
---so `zombie_weak.xml` and `zombie.xml` share the family `data/entities/animals/zombie`.
---@param type_key string Enemy type key.
---@return string
local function GetEnemyFamilyKey(type_key)
    local family_key = type_key:gsub("%.xml$", "")
    local is_stripped = true
    while is_stripped do
        is_stripped = false
        for _, suffix in ipairs(VARIANT_SUFFIXES) do
            local stem = family_key:sub(1, -#suffix - 1)
            if #stem > 0 and family_key:sub(-#suffix) == suffix and not stem:find("/$") then
                family_key = stem
                is_stripped = true
                break
            end
        end
    end

    return family_key
end

---Returns the herd of an enemy from its GenomeDataComponent.
---@param enemy_id number Enemy entity ID.
---@return string|nil herd_key Herd name, or nil if the enemy has no herd or belongs to the player's herd.
local function GetEnemyHerdKey(enemy_id)
    local genome_comp = EntityGetFirstComponentIncludingDisabled(enemy_id, "GenomeDataComponent")
    if genome_comp == nil then
        return nil
    end

    local herd_key = HerdIdToString(ComponentGetValue2(genome_comp, "herd_id"))
    if herd_key == nil or herd_key == "" or herd_key == PLAYER_HERD then
        return nil
    end

    return herd_key
end

---Collects the run globals that hold the knowledge of an enemy: its type, family and herd.
---@param enemy_id number Enemy entity ID.
---@return table globals Global names as `{ type, family, herd }`, `herd` is nil for enemies without a herd.
local function GetKnowledgeGlobals(enemy_id)
    local type_key = GetEnemyTypeKey(enemy_id)
    local herd_key = GetEnemyHerdKey(enemy_id)
    return {
        type = TYPE_KNOWLEDGE_GLOBAL_PREFIX .. type_key,
        family = FAMILY_KNOWLEDGE_GLOBAL_PREFIX .. GetEnemyFamilyKey(type_key),
        herd = herd_key and HERD_KNOWLEDGE_GLOBAL_PREFIX .. herd_key or nil,
    }
end

---Reads a knowledge value gathered in this run: the sum of the study progress of the enemies it covers,
---so five fully studied enemies give 5.
---@param global_name string|nil Knowledge global name.
---@return number
local function GetKnowledge(global_name)
    if global_name == nil then
        return 0
    end

    return tonumber(GlobalsGetValue(global_name, "0")) or 0
end

---Adds study progress to the knowledge of an enemy type, its family and its herd.
---@param globals table Knowledge globals from GetKnowledgeGlobals.
---@param progress number Gained study progress.
---@return nil
local function AddKnowledge(globals, progress)
    for _, global_name in pairs(globals) do
        GlobalsSetValue(global_name, tostring(GetKnowledge(global_name) + progress))
    end
end

---Calculates how well the player knows an enemy: its own type in full, other variants of its family and the rest
---of its herd in part. Each level excludes the level below, so the type is not counted twice.
---@param globals table Knowledge globals from GetKnowledgeGlobals.
---@return number
local function GetEffectiveKnowledge(globals)
    local type_knowledge = GetKnowledge(globals.type)
    local family_knowledge = GetKnowledge(globals.family)
    local herd_knowledge = GetKnowledge(globals.herd)
    -- A family may span several herds, so the rest of the herd is kept non-negative.
    return type_knowledge
        + FAMILY_KNOWLEDGE_WEIGHT * math.max(0, family_knowledge - type_knowledge)
        + HERD_KNOWLEDGE_WEIGHT * math.max(0, herd_knowledge - family_knowledge)
end

---Calculates the study duration of an enemy from the player's current knowledge of it.
---@param globals table Knowledge globals from GetKnowledgeGlobals.
---@return number frames Study duration in frames.
local function GetStudyDuration(globals)
    local knowledge = math.min(1, GetEffectiveKnowledge(globals) / FULL_TYPE_KNOWLEDGE)
    local base_frames = GetBaseStudyFrames()
    return base_frames - (base_frames - KNOWN_TYPE_STUDY_FRAMES) * knowledge
end

---Gathers the areas lit by light sources: lanterns in the world and in the player's hands, and projectiles with
---the Light spell modifier. Lanterns in the inventory have their light disabled, extinguished lanterns have none,
---and the belt lantern is a separate entity without the light source tag, so none of them count.
---Only the tagged LightComponent is read, as a projectile may also carry its own light.
---@return table[] areas Lit circles as `{ x, y, radius_sq }`.
local function CollectLitAreas()
    local areas = {}
    for _, source_id in ipairs(EntityGetWithTag(LIGHT_SOURCE_TAG) or {}) do
        local light_comp = EntityGetFirstComponent(source_id, "LightComponent", LIGHT_SOURCE_TAG)
        if light_comp ~= nil then
            -- The current radius already includes the quality tier, liquid state and modifiers of lanterns.
            local radius = ComponentGetValue2(light_comp, "radius") * LIT_RADIUS_FACTOR
            local x, y = EntityGetTransform(source_id)
            if radius > 0 and x ~= nil then
                table.insert(areas, { x, y, radius * radius, })
            end
        end
    end

    return areas
end

---Checks whether a point is inside any lit area.
---@param x number World X coordinate.
---@param y number World Y coordinate.
---@param areas table[] Lit circles from CollectLitAreas.
---@return boolean
local function IsPointLit(x, y, areas)
    for _, area in ipairs(areas) do
        local dx = x - area[1]
        local dy = y - area[2]
        if dx * dx + dy * dy <= area[3] then
            return true
        end
    end

    return false
end

---Returns the centre of the entity hitbox, or its position if it has no hitbox.
---@param entity_id number Entity ID.
---@return number x, number y
local function GetEntityCenter(entity_id)
    local x, y = EntityGetFirstHitboxCenter(entity_id)
    if x == nil then
        x, y = EntityGetTransform(entity_id)
    end

    return x, y
end

---Collects living root enemies and bosses around a point, without duplicates.
---@param x number World X coordinate.
---@param y number World Y coordinate.
---@param player_id number Player entity ID, excluded from the result.
---@return number[]
local function CollectNearbyEnemies(x, y, player_id)
    local enemies = {}
    local seen = {}
    for _, tag in ipairs(ENEMY_TAGS) do
        for _, enemy_id in ipairs(EntityGetInRadiusWithTag(x, y, STUDY_RADIUS, tag) or {}) do
            if not seen[enemy_id] and enemy_id ~= player_id and EntityGetIsAlive(enemy_id)
                and EntityGetParent(enemy_id) == 0 then
                seen[enemy_id] = true
                table.insert(enemies, enemy_id)
            end
        end
    end

    return enemies
end

---Finds the study marker attached to an enemy.
---@param enemy_id number Enemy entity ID.
---@return number marker_id Marker entity ID, or 0 if the enemy has none.
local function FindMarker(enemy_id)
    for _, child_id in ipairs(EntityGetAllChildren(enemy_id) or {}) do
        if EntityHasTag(child_id, MARKER_TAG) then
            return child_id
        end
    end

    return 0
end

---Calculates how high above the enemy position the marker is drawn: just over the top of its hitboxes.
---@param enemy_id number Enemy entity ID.
---@return number
local function GetMarkerHeight(enemy_id)
    local top = nil
    for _, hitbox_comp in ipairs(EntityGetComponent(enemy_id, "HitboxComponent") or {}) do
        local min_y = ComponentGetValue2(hitbox_comp, "aabb_min_y")
        if top == nil or min_y < top then
            top = min_y
        end
    end
    if top == nil then
        return DEFAULT_MARKER_HEIGHT
    end

    return -top + MARKER_MARGIN
end

---Attaches a study marker above an enemy, unless it already has one.
---@param enemy_id number Enemy entity ID.
---@return nil
local function AttachMarker(enemy_id)
    if FindMarker(enemy_id) ~= 0 then
        return
    end

    local x, y = EntityGetTransform(enemy_id)
    local marker_id = EntityLoad(MARKER_PATH, x, y)
    -- The offset is in image pixels, so it is scaled together with the dot.
    local offset_y = MARKER_SPRITE_CENTER + GetMarkerHeight(enemy_id) / MARKER_SCALE
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(marker_id, "SpriteComponent") or {}) do
        ComponentSetValue2(sprite_comp, "has_special_scale", true)
        ComponentSetValue2(sprite_comp, "special_scale_x", MARKER_SCALE)
        ComponentSetValue2(sprite_comp, "special_scale_y", MARKER_SCALE)
        ComponentSetValue2(sprite_comp, "offset_y", offset_y)
        if ComponentGetIsEnabled(sprite_comp) then
            EntityRefreshSprite(marker_id, sprite_comp)
        end
    end
    EntityAddChild(enemy_id, marker_id)
end

---Starts studying an enemy: adds its progress storage, the damage hook and the marker.
---@param enemy_id number Enemy entity ID.
---@return nil
local function BeginStudy(enemy_id)
    SetStorageFloat(enemy_id, PROGRESS_STORAGE, 0)
    SetStorageFloat(enemy_id, DONE_STORAGE, 0)
    EntityAddComponent2(enemy_id, "LuaComponent", {
        script_damage_about_to_be_received = DAMAGE_SCRIPT,
        execute_every_n_frame = -1,
    })
    AttachMarker(enemy_id)
end

---Advances the study of an enemy by one scan. The duration is recalculated every scan, so the study speeds up
---as the knowledge grows. The gained progress is added to the knowledge of the type, family and herd.
---Bosses always take BOSS_STUDY_FRAMES and neither give nor get knowledge.
---@param enemy_id number Enemy entity ID.
---@return nil
local function AdvanceStudy(enemy_id)
    local progress = FindStudyValue(enemy_id, PROGRESS_STORAGE)
    if progress == nil then
        BeginStudy(enemy_id)
        progress = 0
    end

    local is_boss = HasAnyTag(enemy_id, BOSS_TAGS)
    local globals = not is_boss and GetKnowledgeGlobals(enemy_id) or nil
    local duration = globals and GetStudyDuration(globals) or BOSS_STUDY_FRAMES
    local next_progress = math.min(1, progress + SCAN_INTERVAL_FRAMES / duration)
    SetStorageFloat(enemy_id, PROGRESS_STORAGE, next_progress)
    if globals ~= nil then
        AddKnowledge(globals, next_progress - progress)
    end
    if next_progress >= 1 then
        SetStorageFloat(enemy_id, DONE_STORAGE, 1)
    end
end

---Enables or disables a marker sprite, if it is not in that state already.
---@param marker_id number Marker entity ID.
---@param tag string Sprite tag.
---@param is_enabled boolean Whether the sprite should be shown.
---@return nil
local function SetMarkerSpriteEnabled(marker_id, tag, is_enabled)
    local sprite_comp = EntityGetFirstComponentIncludingDisabled(marker_id, "SpriteComponent", tag)
    if sprite_comp ~= nil and ComponentGetIsEnabled(sprite_comp) ~= is_enabled then
        EntitySetComponentIsEnabled(marker_id, sprite_comp, is_enabled)
    end
end

---Shows the colour of every loaded marker from the study state of its enemy, or hides all markers
---while Enemy Study is off.
---@param is_enabled boolean Whether Enemy Study is on.
---@param studied_enemies table<number, boolean> Enemies studied in this scan.
---@return nil
local function SyncMarkers(is_enabled, studied_enemies)
    for _, marker_id in ipairs(EntityGetWithTag(MARKER_TAG) or {}) do
        local enemy_id = EntityGetParent(marker_id)
        local is_done = enemy_id ~= 0 and (FindStudyValue(enemy_id, DONE_STORAGE) or 0) > 0
        local is_studied = not is_done and studied_enemies[enemy_id] == true
        SetMarkerSpriteEnabled(marker_id, MARKER_IN_PROGRESS_TAG, is_enabled and is_studied)
        SetMarkerSpriteEnabled(marker_id, MARKER_PAUSED_TAG, is_enabled and not is_done and not is_studied)
        SetMarkerSpriteEnabled(marker_id, MARKER_DONE_TAG, is_enabled and is_done)
    end
end

---Studies enemies around the player that stand in lantern light and in the player's line of sight.
---@return table<number, boolean> studied_enemies Enemies studied in this scan.
local function StudyNearbyEnemies()
    local studied_enemies = {}
    local player_id = FindStudyingPlayer()
    if player_id == 0 then
        return studied_enemies
    end

    local areas = CollectLitAreas()
    if #areas == 0 then
        return studied_enemies
    end

    local px, py = GetEntityCenter(player_id)
    if px == nil then
        return studied_enemies
    end

    for _, enemy_id in ipairs(CollectNearbyEnemies(px, py, player_id)) do
        if (FindStudyValue(enemy_id, DONE_STORAGE) or 0) <= 0
            and GameGetGameEffectCount(enemy_id, "INVISIBILITY") == 0 then
            local x, y = GetEntityCenter(enemy_id)
            -- The lit check is cheaper than a raytrace, so it goes first.
            if IsPointLit(x, y, areas) and not RaytraceSurfaces(px, py, x, y) then
                AdvanceStudy(enemy_id)
                studied_enemies[enemy_id] = true
            end
        end
    end

    return studied_enemies
end

---Advances enemy study and refreshes the study markers.
---Runs every SCAN_INTERVAL_FRAMES frames from OnWorldPreUpdate.
---@return nil
function UpdateEnemyStudy()
    if GameGetFrameNum() % SCAN_INTERVAL_FRAMES ~= 0 then
        return
    end

    local is_enabled = IsEnemyStudyEnabled()
    SyncMarkers(is_enabled, is_enabled and StudyNearbyEnemies() or {})
end
