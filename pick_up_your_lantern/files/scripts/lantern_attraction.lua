--- Lantern attraction for Pick Up Your Lantern mod.
--- Some enemies are drawn to lit lanterns in the world, like moths to a flame: the home of their AI moves to the
--- nearest lantern they have seen, and a short leash keeps them circling around it. They do not attack the lantern.
--- The light holds them in a trance: they notice the player only up close, and once they find prey (the player came
--- close or hit them) the trance breaks and they fight as usual. The original AI values are restored once the enemy
--- hunts, the lantern is gone, picked up, extinguished or out of range, or the option is turned off.
--- Two groups of enemies are attracted, each with its own option:
--- - fire-related enemies (`Lanterns attract fire enemies`), marked by the fire enemy glow;
--- - Hiisi and insects (`Natural Fear`), by their herd.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
local enemy_ai_home = dofile_once("mods/" .. MOD_ID .. "/files/scripts/enemy_ai_home.lua")

local FIRE_SETTING_ID = MOD_ID .. ".fire_enemy_attraction"
local NATURAL_FEAR_SETTING_ID = MOD_ID .. ".natural_fear"
local UPDATE_INTERVAL_FRAMES = 20
local LANTERN_TAG = "lantern"
local ENEMY_TAG = "enemy"
local ATTRACTED_TAG = "pul_lantern_attracted"
-- Lanterns attract enemies from farther than they light.
local ATTRACTION_RADIUS_FACTOR = 1.5
-- The line of sight stops this far before the lantern: the lantern body is solid cells in the world grid,
-- and a hanging lantern sits right under the ceiling, so a ray to its centre always hits something.
local SIGHT_MARGIN = 10
-- Walking enemies cannot reach a hanging lantern and stand still under it, so their home is the floor below
-- the lantern, found within this distance. Without a floor there, the home stays at the lantern.
local FLOOR_SEARCH_DISTANCE = 200
-- Height of the walking home above the floor surface.
local FLOOR_CLEARANCE = 4
-- Walking enemies stand still when their home is on another level, as they find no path to it. They are lured
-- only when the floor below the lantern is within this height of their feet.
local WALKING_LEVEL_TOLERANCE = 24
-- Lure as a Markov process, decided on every update: a free enemy that sees a lantern takes it as its home with
-- LURE_ENTER_CHANCE, and a lured enemy leaves it to wander with LURE_LEAVE_CHANCE. With updates every 20 frames,
-- an enemy takes a seen lantern in about 3 seconds on average and stays for about 11 seconds.
local LURE_ENTER_CHANCE = 0.1
local LURE_LEAVE_CHANCE = 0.03
-- Creature detection range of an entranced enemy on both axes: it notices the player only this close.
local TRANCE_DETECTION_RANGE = 48

---Gathers lit lanterns in the world: hanging, thrown or lying ones. Lanterns in hand or in the inventory are
---children of the player, and extinguished lanterns have no enabled light, so none of them attract.
---@return table[] lanterns Lanterns as `{ x, y, attraction_radius, lantern_id }`.
local function CollectLureLanterns()
    local lanterns = {}
    for _, lantern_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        if EntityGetRootEntity(lantern_id) == lantern_id then
            local light_comp = EntityGetFirstComponent(lantern_id, "LightComponent", LIGHT_SOURCE_TAG)
            if light_comp ~= nil then
                -- The current radius already includes the quality tier, liquid state and modifiers of lanterns.
                local radius = ComponentGetValue2(light_comp, "radius") * ATTRACTION_RADIUS_FACTOR
                local x, y = EntityGetTransform(lantern_id)
                if radius > 0 and x ~= nil then
                    table.insert(lanterns, { x, y, radius, lantern_id, })
                end
            end
        end
    end

    return lanterns
end

---Collects the enemies to evaluate: those near any lure lantern and those attracted earlier, without duplicates.
---@param lanterns table[] Lanterns from CollectLureLanterns.
---@return number[]
local function CollectCandidates(lanterns)
    local candidates = {}
    local seen = {}
    local function Add(enemy_id)
        if not seen[enemy_id] then
            seen[enemy_id] = true
            table.insert(candidates, enemy_id)
        end
    end

    for _, lantern in ipairs(lanterns) do
        for _, enemy_id in ipairs(EntityGetInRadiusWithTag(lantern[1], lantern[2], lantern[3], ENEMY_TAG) or {}) do
            if EntityGetParent(enemy_id) == 0 then
                Add(enemy_id)
            end
        end
    end
    -- Attracted enemies may have left the radius or lost their lantern, and must be released.
    for _, enemy_id in ipairs(EntityGetWithTag(ATTRACTED_TAG) or {}) do
        Add(enemy_id)
    end

    return candidates
end

---Checks whether an enemy is lured by lanterns under the enabled options and is not hunting.
---@param enemy_id number Enemy entity ID.
---@param ai_comp number AnimalAIComponent of the enemy.
---@param is_fire_enabled boolean Whether fire enemies are attracted.
---@param is_natural_fear_enabled boolean Whether the Natural Fear herds are attracted.
---@return boolean
local function IsLured(enemy_id, ai_comp, is_fire_enabled, is_natural_fear_enabled)
    -- Most enemies near lanterns belong to no lured group, so this check goes first.
    local is_in_lured_group = (is_fire_enabled and enemy_ai_home.IsFireEnemy(enemy_id))
        or (is_natural_fear_enabled and enemy_ai_home.IsNaturalFearLuredHerd(enemy_id))
    if not is_in_lured_group or enemy_ai_home.IsExcluded(enemy_id) then
        return false
    end

    -- A hunting enemy is not lured, and an entranced one that finds prey wakes up.
    local prey_id = ComponentGetValue2(ai_comp, "mGreatestPrey")
    return prey_id == 0 or not EntityGetIsAlive(prey_id)
end

---Checks whether a lantern is in line of sight from a point, ignoring the last SIGHT_MARGIN pixels before it.
---@param x number World X coordinate of the viewer.
---@param y number World Y coordinate of the viewer.
---@param lantern_x number Lantern world X coordinate.
---@param lantern_y number Lantern world Y coordinate.
---@param dist number Distance between them.
---@return boolean
local function CanSeeLantern(x, y, lantern_x, lantern_y, dist)
    if dist <= SIGHT_MARGIN then
        return true
    end

    local factor = (dist - SIGHT_MARGIN) / dist
    return not RaytraceSurfaces(x, y, x + (lantern_x - x) * factor, y + (lantern_y - y) * factor)
end

---Returns the point on the floor below a lantern, found once per update and kept in the lantern table.
---The ray starts SIGHT_MARGIN below the lantern, so it does not hit the lantern body.
---@param lantern table Lantern from CollectLureLanterns.
---@return number x, number y
local function GetFloorBelow(lantern)
    if lantern.floor_x == nil then
        local start_y = lantern[2] + SIGHT_MARGIN
        local did_hit, hit_x, hit_y = RaytraceSurfaces(lantern[1], start_y, lantern[1], start_y + FLOOR_SEARCH_DISTANCE)
        if did_hit then
            lantern.floor_x, lantern.floor_y = hit_x, hit_y - FLOOR_CLEARANCE
        else
            lantern.floor_x, lantern.floor_y = lantern[1], lantern[2]
        end
    end

    return lantern.floor_x, lantern.floor_y
end

---Checks whether a lantern can attract an enemy from a distance: within the attraction radius and, for a walking
---enemy, with the floor below the lantern on the level of its feet (see WALKING_LEVEL_TOLERANCE).
---@param lantern table Lantern from CollectLureLanterns.
---@param dist number Distance from the enemy to the lantern.
---@param feet_y number|nil World Y coordinate of the feet of a walking enemy, nil for a flying one.
---@return boolean
local function CanAttract(lantern, dist, feet_y)
    if dist > lantern[3] then
        return false
    end
    if feet_y == nil then
        return true
    end

    local _, floor_y = GetFloorBelow(lantern)
    return math.abs(floor_y - feet_y) <= WALKING_LEVEL_TOLERANCE
end

---Finds the lure lantern that attracts an enemy. An attracted enemy keeps the lantern it took while that lantern
---can attract it, with no line of sight needed, so it does not flip between the lantern and its own home whenever
---a ledge hides the lantern. A free enemy takes the nearest lantern that can attract it and is in line of sight.
---@param enemy_id number Enemy entity ID.
---@param ai_comp number AnimalAIComponent of the enemy.
---@param is_attracted boolean Whether the enemy is attracted already.
---@param lanterns table[] Lanterns from CollectLureLanterns.
---@return table|nil lantern Lantern from CollectLureLanterns, or nil if none attracts the enemy.
local function FindLureLantern(enemy_id, ai_comp, is_attracted, lanterns)
    local feet_y = nil
    if not ComponentGetValue2(ai_comp, "can_fly") then
        feet_y = select(2, EntityGetTransform(enemy_id))
    end
    local x, y = enemy_ai_home.GetEntityCenter(enemy_id)
    local function GetDistance(lantern)
        return math.sqrt((lantern[1] - x) ^ 2 + (lantern[2] - y) ^ 2)
    end

    if is_attracted then
        local storage = enemy_ai_home.FindOriginalStorage(enemy_id)
        local lantern_id = storage and ComponentGetValue2(storage, "value_int")
        for _, lantern in ipairs(lanterns) do
            if lantern[4] == lantern_id then
                return CanAttract(lantern, GetDistance(lantern), feet_y) and lantern or nil
            end
        end
        return nil
    end

    local nearest = nil
    local nearest_dist = math.huge
    for _, lantern in ipairs(lanterns) do
        local dist = GetDistance(lantern)
        -- The raytrace is the most expensive check, so it goes last.
        if dist < nearest_dist and CanAttract(lantern, dist, feet_y)
            and CanSeeLantern(x, y, lantern[1], lantern[2], dist) then
            nearest = lantern
            nearest_dist = dist
        end
    end

    return nearest
end

---Moves the AI home of an enemy to a lantern, leashes it there and puts it in a trance, saving the original AI values
---on the first call. Flying enemies get the lantern itself as their home, walking ones the floor below it.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy, at least one.
---@param is_attracted boolean Whether the enemy is attracted already.
---@param lantern table Lantern from CollectLureLanterns.
---@return nil
local function Attract(enemy_id, ai_comps, is_attracted, lantern)
    local x, y = lantern[1], lantern[2]
    if not ComponentGetValue2(ai_comps[1], "can_fly") then
        x, y = GetFloorBelow(lantern)
    end

    if not is_attracted then
        local storage = enemy_ai_home.SaveOriginal(enemy_id, ai_comps[1])
        ComponentSetValue2(storage, "value_int", lantern[4])
        EntityAddTag(enemy_id, ATTRACTED_TAG)
    end

    -- Set on every update: a thrown lantern keeps moving.
    enemy_ai_home.SetHome(enemy_id, ai_comps, is_attracted, x, y)
    for _, ai_comp in ipairs(ai_comps) do
        ComponentSetValue2(ai_comp, "creature_detection_range_x", TRANCE_DETECTION_RANGE)
        ComponentSetValue2(ai_comp, "creature_detection_range_y", TRANCE_DETECTION_RANGE)
    end
end

---Restores the original AI values of an attracted enemy.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy.
---@return nil
local function Release(enemy_id, ai_comps)
    EntityRemoveTag(enemy_id, ATTRACTED_TAG)
    enemy_ai_home.RestoreOriginal(enemy_id, ai_comps)
end

---Attracts lured enemies to the nearest lure lanterns and releases the ones no lantern attracts any more.
---Taking and leaving a lantern are random (LURE_ENTER_CHANCE, LURE_LEAVE_CHANCE), so enemies come and go.
---Runs every UPDATE_INTERVAL_FRAMES frames from OnWorldPreUpdate.
---@return nil
function UpdateLanternAttraction()
    if GameGetFrameNum() % UPDATE_INTERVAL_FRAMES ~= 0 then
        return
    end

    local is_fire_enabled = enemy_ai_home.GetBoolSetting(FIRE_SETTING_ID, true)
    local is_natural_fear_enabled = enemy_ai_home.GetBoolSetting(NATURAL_FEAR_SETTING_ID, false)
    if not is_fire_enabled and not is_natural_fear_enabled then
        for _, enemy_id in ipairs(EntityGetWithTag(ATTRACTED_TAG) or {}) do
            Release(enemy_id, enemy_ai_home.GetAIComponents(enemy_id))
        end
        return
    end

    local lanterns = CollectLureLanterns()
    for _, enemy_id in ipairs(CollectCandidates(lanterns)) do
        local ai_comps = enemy_ai_home.GetAIComponents(enemy_id)
        local is_attracted = EntityHasTag(enemy_id, ATTRACTED_TAG)
        local lantern = nil
        -- The enter chance is rolled before the search, which spares the raytraces of most free enemies.
        local is_rolled = is_attracted or math.random() < LURE_ENTER_CHANCE
        if is_rolled and #ai_comps > 0
            and IsLured(enemy_id, ai_comps[1], is_fire_enabled, is_natural_fear_enabled) then
            lantern = FindLureLantern(enemy_id, ai_comps[1], is_attracted, lanterns)
        end
        if is_attracted and math.random() < LURE_LEAVE_CHANCE then
            lantern = nil
        end

        if lantern ~= nil then
            Attract(enemy_id, ai_comps, is_attracted, lantern)
        elseif is_attracted then
            Release(enemy_id, ai_comps)
        end
    end
end
