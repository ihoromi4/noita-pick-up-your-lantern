--- Enemy AI helpers for Pick Up Your Lantern mod.
--- Shared by the lantern attraction and the lantern fear: settings, the lured groups and the excluded enemies.
--- The attraction also steers enemies by their AI home: `AnimalAIComponent.mHomePosition` with
--- `max_distance_to_move_from_home` as a leash. The original AI values are kept in a VariableStorageComponent and
--- restored when the enemy is released.
--- Loaded as a module: `local enemy_ai_home = dofile_once(".../enemy_ai_home.lua")`.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

-- Original AI values of a steered enemy: the leash distance in value_float, and the home position, creature
-- detection range and path finding depth as "home_x,home_y,range_x,range_y,depth" in value_string.
-- value_int is free for the caller (the attraction keeps its lantern there).
local ORIGINAL_AI_STORAGE = "pul_original_ai"
-- Distance from the home within which steered enemies wander.
local LEASH_DISTANCE = 40
-- A walking enemy outside its leash stands still instead of walking home, so its leash is never shorter than its
-- current distance from home plus this margin. The leash only shrinks as the enemy wanders closer, down to
-- LEASH_DISTANCE, and the enemy drifts towards the home.
local WALKING_LEASH_MARGIN = 16
-- Path finding depth of a steered enemy without prey. The default of 50 nodes is too short for a home far away:
-- walking enemies stood still in the going home state even with the home on their own level.
local HOME_PATHFINDING_DEPTH = 200

-- Herds attracted in the Natural Fear mode: Hiisi (with their tanks and turrets) and insects.
local NATURAL_FEAR_LURED_HERDS = {
    orcs = true,
    fly = true,
}

-- Bosses keep their own behaviour, and a polymorphed player is controlled by the player.
local EXCLUDED_TAGS = {
    "boss",
    "boss_dragon",
    "polymorphed_player",
    "polymorphed_cessation",
}

local enemy_ai_home = {}

---Reads a boolean mod setting, falling back to the pending value and then to the default.
---@param setting_id string
---@param default_value boolean
---@return boolean
function enemy_ai_home.GetBoolSetting(setting_id, default_value)
    local value = ModSettingGet(setting_id)
    if value == nil then
        value = ModSettingGetNextValue(setting_id)
    end
    if value == nil then
        return default_value
    end

    return value == true
end

---Returns the centre of the entity hitbox, or its position if it has no hitbox.
---@param entity_id number Entity ID.
---@return number x, number y
function enemy_ai_home.GetEntityCenter(entity_id)
    local x, y = EntityGetFirstHitboxCenter(entity_id)
    if x == nil then
        x, y = EntityGetTransform(entity_id)
    end

    return x, y
end

---Returns all AnimalAIComponents of an enemy, including disabled ones.
---@param enemy_id number Enemy entity ID.
---@return number[]
function enemy_ai_home.GetAIComponents(enemy_id)
    return EntityGetComponentIncludingDisabled(enemy_id, "AnimalAIComponent") or {}
end

---Checks whether an enemy is fire-related, as marked by the fire enemy glow.
---@param enemy_id number Enemy entity ID.
---@return boolean
function enemy_ai_home.IsFireEnemy(enemy_id)
    return EntityHasTag(enemy_id, FIRE_ENEMY_TAG)
end

---Checks whether an enemy belongs to a herd that the Natural Fear mode attracts to lanterns.
---@param enemy_id number Enemy entity ID.
---@return boolean
function enemy_ai_home.IsNaturalFearLuredHerd(enemy_id)
    local genome_comp = EntityGetFirstComponentIncludingDisabled(enemy_id, "GenomeDataComponent")
    if genome_comp == nil then
        return false
    end

    return NATURAL_FEAR_LURED_HERDS[HerdIdToString(ComponentGetValue2(genome_comp, "herd_id"))] == true
end

---Checks whether an enemy keeps its own AI home: bosses, a polymorphed player and charmed enemies.
---@param enemy_id number Enemy entity ID.
---@return boolean
function enemy_ai_home.IsExcluded(enemy_id)
    for _, tag in ipairs(EXCLUDED_TAGS) do
        if EntityHasTag(enemy_id, tag) then
            return true
        end
    end

    return GameGetGameEffectCount(enemy_id, "CHARM") > 0
end

---Finds the storage with the original AI values of a steered enemy.
---@param enemy_id number Enemy entity ID.
---@return number|nil storage VariableStorageComponent, or nil if the enemy is not steered.
function enemy_ai_home.FindOriginalStorage(enemy_id)
    return FindVariableStorage(enemy_id, ORIGINAL_AI_STORAGE)
end

---Saves the original AI values of an enemy before it is steered.
---@param enemy_id number Enemy entity ID.
---@param ai_comp number First AnimalAIComponent of the enemy.
---@return number storage VariableStorageComponent with the saved values.
function enemy_ai_home.SaveOriginal(enemy_id, ai_comp)
    local home_x, home_y = ComponentGetValue2(ai_comp, "mHomePosition")
    local storage = GetOrCreateVariableStorage(enemy_id, ORIGINAL_AI_STORAGE)
    ComponentSetValue2(storage, "value_float", ComponentGetValue2(ai_comp, "max_distance_to_move_from_home"))
    ComponentSetValue2(storage, "value_string", string.format("%f,%f,%f,%f,%d", home_x, home_y,
        ComponentGetValue2(ai_comp, "creature_detection_range_x"),
        ComponentGetValue2(ai_comp, "creature_detection_range_y"),
        ComponentGetValue2(ai_comp, "pathfinding_max_depth_no_target")))

    return storage
end

---Reads the saved original values from a storage.
---@param storage number VariableStorageComponent from SaveOriginal.
---@return number|nil home_x, number|nil home_y, number|nil range_x, number|nil range_y, number|nil depth
local function ReadOriginal(storage)
    local home_x, home_y, range_x, range_y, depth = (ComponentGetValue2(storage, "value_string") or "")
        :match("^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")

    return tonumber(home_x), tonumber(home_y), tonumber(range_x), tonumber(range_y), tonumber(depth)
end

---Restores the original AI home, leash, detection range and path finding depth of a steered enemy and removes the
---storage.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy.
---@return nil
function enemy_ai_home.RestoreOriginal(enemy_id, ai_comps)
    local storage = enemy_ai_home.FindOriginalStorage(enemy_id)
    if storage == nil then
        return
    end

    local leash = ComponentGetValue2(storage, "value_float")
    local home_x, home_y, range_x, range_y, depth = ReadOriginal(storage)
    for _, ai_comp in ipairs(ai_comps) do
        ComponentSetValue2(ai_comp, "max_distance_to_move_from_home", leash)
        if depth ~= nil then
            ComponentSetValue2(ai_comp, "mHomePosition", home_x, home_y)
            ComponentSetValue2(ai_comp, "creature_detection_range_x", range_x)
            ComponentSetValue2(ai_comp, "creature_detection_range_y", range_y)
            ComponentSetValue2(ai_comp, "pathfinding_max_depth_no_target", depth)
        end
    end
    EntityRemoveComponent(enemy_id, storage)
end

---Moves the AI home of a steered enemy and leashes it there, with a longer path finding. Flying enemies get a short
---leash; walking ones get a leash that only shrinks as they come closer (see WALKING_LEASH_MARGIN).
---Set on every update: the home may move, and the engine may reset it after loading.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy, at least one.
---@param is_steered boolean Whether the enemy was steered on the previous update, so its leash is ours.
---@param x number Home world X coordinate.
---@param y number Home world Y coordinate.
---@return nil
function enemy_ai_home.SetHome(enemy_id, ai_comps, is_steered, x, y)
    local leash = LEASH_DISTANCE
    if not ComponentGetValue2(ai_comps[1], "can_fly") then
        local enemy_x, enemy_y = enemy_ai_home.GetEntityCenter(enemy_id)
        local dist = math.sqrt((x - enemy_x) ^ 2 + (y - enemy_y) ^ 2)
        local current_leash = math.huge
        if is_steered then
            current_leash = ComponentGetValue2(ai_comps[1], "max_distance_to_move_from_home")
        end
        leash = math.max(LEASH_DISTANCE, math.min(current_leash, dist + WALKING_LEASH_MARGIN))
    end

    for _, ai_comp in ipairs(ai_comps) do
        ComponentSetValue2(ai_comp, "mHomePosition", x, y)
        ComponentSetValue2(ai_comp, "max_distance_to_move_from_home", leash)
        ComponentSetValue2(ai_comp, "pathfinding_max_depth_no_target", HOME_PATHFINDING_DEPTH)
    end
end

return enemy_ai_home
