--- Lantern fear for Pick Up Your Lantern mod.
--- In the Natural Fear mode, creatures that lanterns do not attract fear their light: lantern light (in the world or
--- in the player's hands) scorches them. A tiny fire damage triggers the native reaction to burning, the
--- TakingFireDamage AI state, so they panic by their own path finding; a push away from the light gives the panic a
--- direction, and the particles of Confusion show it. Fear beats hunting: a hunting enemy panics too.
--- Fear and rage form a Markov process: now and then a scorched enemy flies into a rage instead (the look of Berserk) and
--- attacks the lantern it feared, or the player who holds it; the rage passes by chance or once the target is gone.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
local enemy_ai_home = dofile_once("mods/" .. MOD_ID .. "/files/scripts/enemy_ai_home.lua")

local NATURAL_FEAR_SETTING_ID = MOD_ID .. ".natural_fear"
-- How often lantern light burns an enemy in it.
local UPDATE_INTERVAL_FRAMES = 30
-- Runs between the updates of the lantern attraction, to spread the load.
local UPDATE_FRAME_OFFSET = 5
local LANTERN_TAG = "lantern"
local ENEMY_TAG = "enemy"
-- Share of the lantern light radius that looks lit, as for enemy study: the soft outer edge of the light does not
-- scare. With the full radius, one lantern scared enemies over 330 px.
local LIT_RADIUS_FACTOR = 0.6
-- Scale of the lit area that scares, tuned by feel: enemies come closer to a lantern before they fear it.
local FEAR_RADIUS_SCALE = 0.6
-- The line of sight stops this far before the lantern: the lantern body is solid cells in the world grid,
-- and a hanging lantern sits right under the ceiling, so a ray to its centre always hits something.
local SIGHT_MARGIN = 10
-- Fire damage of lantern light per update, in game units (1 is 25 HP): enough for the AI to react, too little to
-- matter for the health of the enemy. The damage adds up: 0.001 killed weak zombies (0.2) in a few minutes.
local LIGHT_BURN_DAMAGE = 0.000001
-- Speed of the push away from the light per update, added to the enemy velocity. Walking enemies are pushed only
-- along X, so they are not lifted off their floor.
local FEAR_PUSH_SPEED = 60
-- Rage as a Markov process, decided on every update: an enemy in the light flies into a rage with RAGE_ENTER_CHANCE
-- instead of being scorched, and an enraged enemy calms down with RAGE_LEAVE_CHANCE. With updates every 30 frames,
-- an enemy in the light flies into a rage in about 10 seconds on average and stays enraged for about 5 seconds.
local RAGE_ENTER_CHANCE = 0.05
local RAGE_LEAVE_CHANCE = 0.1
local ENRAGED_TAG = "pul_lantern_enraged"
-- Target of an enraged enemy in value_int: the lantern in the world, or the carrier of the lantern in hand.
local RAGE_TARGET_STORAGE = "pul_lantern_rage_target"
-- Look of the rage, a child entity of the enraged enemy: the particles of the Berserk status effect.
local RAGE_EFFECT_PATH = "mods/" .. MOD_ID .. "/files/entities/lantern_rage_effect.xml"
local RAGE_EFFECT_TAG = "pul_lantern_rage_effect"
-- Scorched enemies have this tag and the look of fear, a child entity with the particles of the Confusion status
-- effect, while they are in the light.
local SCARED_TAG = "pul_lantern_scared"
local FEAR_EFFECT_PATH = "mods/" .. MOD_ID .. "/files/entities/lantern_fear_effect.xml"
local FEAR_EFFECT_TAG = "pul_lantern_fear_effect"

---Checks whether a lantern scares: it lies or hangs in the world, or its carrier holds it in hand. A carried lantern
---that is not in hand (in the inventory, shown on the belt) does not scare, and neither do the light of the player
---and the belt lantern, which have no lantern tag.
---@param lantern_id number Lantern entity ID.
---@return boolean
local function IsFearLantern(lantern_id)
    local root_id = EntityGetRootEntity(lantern_id)
    return root_id == lantern_id or GetHeldItem(root_id) == lantern_id
end

---Gathers lit lanterns in the world and in hand. Extinguished lanterns have no enabled light.
---@return table[] lights Feared circles as `{ x, y, radius, lantern_id }`.
local function CollectFearLights()
    local lights = {}
    for _, lantern_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        local light_comp = EntityGetFirstComponent(lantern_id, "LightComponent", LIGHT_SOURCE_TAG)
        if light_comp ~= nil and IsFearLantern(lantern_id) then
            -- The current radius already includes the quality tier, liquid state and modifiers of lanterns.
            local radius = ComponentGetValue2(light_comp, "radius") * LIT_RADIUS_FACTOR * FEAR_RADIUS_SCALE
            local x, y = EntityGetTransform(lantern_id)
            if radius > 0 and x ~= nil then
                table.insert(lights, { x, y, radius, lantern_id, })
            end
        end
    end

    return lights
end

---Collects the root enemies in feared lights and the scared and enraged enemies, without duplicates.
---@param lights table[] Lights from CollectFearLights.
---@return number[]
local function CollectCandidates(lights)
    local candidates = {}
    local seen = {}
    local function Add(enemy_id)
        if not seen[enemy_id] then
            seen[enemy_id] = true
            table.insert(candidates, enemy_id)
        end
    end

    for _, light in ipairs(lights) do
        for _, enemy_id in ipairs(EntityGetInRadiusWithTag(light[1], light[2], light[3], ENEMY_TAG) or {}) do
            if EntityGetParent(enemy_id) == 0 then
                Add(enemy_id)
            end
        end
    end
    -- Scared and enraged enemies may have left the light, and must lose their look and calm down in time.
    for _, tag in ipairs({ SCARED_TAG, ENRAGED_TAG, }) do
        for _, enemy_id in ipairs(EntityGetWithTag(tag) or {}) do
            Add(enemy_id)
        end
    end

    return candidates
end

---Checks whether an enemy fears lantern light: any enemy that lanterns do not attract, whatever the options.
---Only enemies checked by the fire enemy glow count, as an unchecked fire enemy has no fire tag yet.
---@param enemy_id number Enemy entity ID.
---@return boolean
local function IsFearful(enemy_id)
    return EntityHasTag(enemy_id, FIRE_GLOW_CHECKED_TAG)
        and not enemy_ai_home.IsFireEnemy(enemy_id)
        and not enemy_ai_home.IsNaturalFearLuredHerd(enemy_id)
        and not enemy_ai_home.IsExcluded(enemy_id)
end

---Checks whether a lantern is in line of sight from a point, ignoring the last SIGHT_MARGIN pixels before it.
---Light does not pass through walls: without this check, lanterns in nearby caves scared enemies through the rock.
---@param x number World X coordinate of the viewer.
---@param y number World Y coordinate of the viewer.
---@param light table Light from CollectFearLights.
---@param dist number Distance between them.
---@return boolean
local function CanSeeLight(x, y, light, dist)
    if dist <= SIGHT_MARGIN then
        return true
    end

    local factor = (dist - SIGHT_MARGIN) / dist
    return not RaytraceSurfaces(x, y, x + (light[1] - x) * factor, y + (light[2] - y) * factor)
end

---Returns the light that lights a point the most: the one in line of sight whose edge is the farthest from the point.
---@param x number World X coordinate.
---@param y number World Y coordinate.
---@param lights table[] Lights from CollectFearLights.
---@return table|nil light Light from CollectFearLights, or nil if the point is dark.
local function FindLightAt(x, y, lights)
    local brightest = nil
    local brightest_depth = 0
    for _, light in ipairs(lights) do
        local dist = math.sqrt((x - light[1]) ^ 2 + (y - light[2]) ^ 2)
        local depth = light[3] - dist
        -- The raytrace is the most expensive check, so it goes last.
        if depth >= brightest_depth and CanSeeLight(x, y, light, dist) then
            brightest = light
            brightest_depth = depth
        end
    end

    return brightest
end

---Scorches an enemy in the light: a tiny fire damage for the panic and a push away from the light.
---@param enemy_id number Enemy entity ID.
---@param ai_comp number AnimalAIComponent of the enemy.
---@param x number World X coordinate of the enemy centre.
---@param y number World Y coordinate of the enemy centre.
---@param light table Light from CollectFearLights that lights the enemy.
---@return nil
local function Scorch(enemy_id, ai_comp, x, y, light)
    EntityInflictDamage(enemy_id, LIGHT_BURN_DAMAGE, "DAMAGE_FIRE", "$damage_fire", "NONE", 0, 0)

    local character_comp = EntityGetFirstComponent(enemy_id, "CharacterDataComponent")
    if character_comp == nil then
        return
    end
    local dx, dy = x - light[1], y - light[2]
    if not ComponentGetValue2(ai_comp, "can_fly") then
        dy = 0
    end
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then
        return
    end

    local vel_x, vel_y = ComponentGetValue2(character_comp, "mVelocity")
    ComponentSetValue2(character_comp, "mVelocity",
        vel_x + dx / dist * FEAR_PUSH_SPEED, vel_y + dy / dist * FEAR_PUSH_SPEED)
end

---Attaches a look effect to an enemy as a child entity.
---@param enemy_id number Enemy entity ID.
---@param path string Effect entity file.
---@param x number World X coordinate of the enemy centre.
---@param y number World Y coordinate of the enemy centre.
---@return nil
local function AttachEffect(enemy_id, path, x, y)
    local effect_id = EntityLoad(path, x, y)
    if effect_id ~= nil and effect_id ~= 0 then
        EntityAddChild(enemy_id, effect_id)
    end
end

---Removes the look effects with a tag from an enemy.
---@param enemy_id number Enemy entity ID.
---@param effect_tag string Tag of the effect entities.
---@return nil
local function RemoveEffect(enemy_id, effect_tag)
    for _, child_id in ipairs(EntityGetAllChildren(enemy_id) or {}) do
        if EntityHasTag(child_id, effect_tag) then
            EntityKill(child_id)
        end
    end
end

---Shows or hides the look of fear of an enemy.
---@param enemy_id number Enemy entity ID.
---@param is_scared boolean Whether the enemy is scorched by the light.
---@param x number World X coordinate of the enemy centre.
---@param y number World Y coordinate of the enemy centre.
---@return nil
local function SetScared(enemy_id, is_scared, x, y)
    if is_scared == EntityHasTag(enemy_id, SCARED_TAG) then
        return
    end

    if is_scared then
        EntityAddTag(enemy_id, SCARED_TAG)
        AttachEffect(enemy_id, FEAR_EFFECT_PATH, x, y)
    else
        EntityRemoveTag(enemy_id, SCARED_TAG)
        RemoveEffect(enemy_id, FEAR_EFFECT_TAG)
    end
end

---Makes an enemy in the light fly into a rage: the lantern (or the player who holds it) becomes its prey.
---@param enemy_id number Enemy entity ID.
---@param x number World X coordinate of the enemy centre.
---@param y number World Y coordinate of the enemy centre.
---@param light table Light from CollectFearLights that lights the enemy.
---@return nil
local function Enrage(enemy_id, x, y, light)
    EntityAddTag(enemy_id, ENRAGED_TAG)
    local storage = GetOrCreateVariableStorage(enemy_id, RAGE_TARGET_STORAGE)
    ComponentSetValue2(storage, "value_int", EntityGetRootEntity(light[4]))
    AttachEffect(enemy_id, RAGE_EFFECT_PATH, x, y)
end

---Returns the target of an enraged enemy, or 0 if it is gone.
---@param enemy_id number Enemy entity ID.
---@return number target_id
local function GetRageTarget(enemy_id)
    local storage = FindVariableStorage(enemy_id, RAGE_TARGET_STORAGE)
    local target_id = storage and ComponentGetValue2(storage, "value_int") or 0
    if target_id == 0 or not EntityGetIsAlive(target_id) then
        return 0
    end

    return target_id
end

---Calms an enraged enemy. A lantern stops being its prey; a player stays, as the enemy would hunt them anyway.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy.
---@return nil
local function Pacify(enemy_id, ai_comps)
    local target_id = GetRageTarget(enemy_id)
    if target_id ~= 0 and EntityHasTag(target_id, LANTERN_TAG) then
        for _, ai_comp in ipairs(ai_comps) do
            if ComponentGetValue2(ai_comp, "mGreatestPrey") == target_id then
                ComponentSetValue2(ai_comp, "mGreatestPrey", 0)
            end
        end
    end

    EntityRemoveTag(enemy_id, ENRAGED_TAG)
    local storage = FindVariableStorage(enemy_id, RAGE_TARGET_STORAGE)
    if storage ~= nil then
        EntityRemoveComponent(enemy_id, storage)
    end
    RemoveEffect(enemy_id, RAGE_EFFECT_TAG)
end

---Keeps the target of an enraged enemy as its prey: the AI may pick other prey on its own between updates.
---@param ai_comps number[] AnimalAIComponents of the enemy.
---@param target_id number Target from GetRageTarget.
---@return nil
local function Rage(ai_comps, target_id)
    for _, ai_comp in ipairs(ai_comps) do
        ComponentSetValue2(ai_comp, "mGreatestPrey", target_id)
    end
end

---Updates the fear or rage of one fearful enemy and its look.
---An enraged enemy keeps attacking its target until it calms down by chance or the target is gone.
---An enemy in the light flies into a rage by chance, or is scorched.
---@param enemy_id number Enemy entity ID.
---@param ai_comps number[] AnimalAIComponents of the enemy, at least one.
---@param lights table[] Lights from CollectFearLights.
---@return nil
local function UpdateEnemyFear(enemy_id, ai_comps, lights)
    if EntityHasTag(enemy_id, ENRAGED_TAG) then
        local target_id = GetRageTarget(enemy_id)
        if target_id ~= 0 and math.random() >= RAGE_LEAVE_CHANCE then
            Rage(ai_comps, target_id)
            return
        end
        Pacify(enemy_id, ai_comps)
    end

    local x, y = enemy_ai_home.GetEntityCenter(enemy_id)
    local light = FindLightAt(x, y, lights)
    local is_scared = false
    if light ~= nil then
        if math.random() < RAGE_ENTER_CHANCE then
            Enrage(enemy_id, x, y, light)
            Rage(ai_comps, GetRageTarget(enemy_id))
        else
            Scorch(enemy_id, ai_comps[1], x, y, light)
            is_scared = true
        end
    end
    SetScared(enemy_id, is_scared, x, y)
end

---Scorches fearful enemies in lantern light, so they panic as when they are on fire and back away from the light,
---and now and then makes one fly into a rage and attack the lantern.
---Runs every UPDATE_INTERVAL_FRAMES frames from OnWorldPreUpdate.
---@return nil
function UpdateLanternFear()
    if GameGetFrameNum() % UPDATE_INTERVAL_FRAMES ~= UPDATE_FRAME_OFFSET then
        return
    end
    if not enemy_ai_home.GetBoolSetting(NATURAL_FEAR_SETTING_ID, false) then
        for _, enemy_id in ipairs(EntityGetWithTag(ENRAGED_TAG) or {}) do
            Pacify(enemy_id, enemy_ai_home.GetAIComponents(enemy_id))
        end
        for _, enemy_id in ipairs(EntityGetWithTag(SCARED_TAG) or {}) do
            SetScared(enemy_id, false, 0, 0)
        end
        return
    end

    local lights = CollectFearLights()
    for _, enemy_id in ipairs(CollectCandidates(lights)) do
        -- The panic and the rage are reactions of the AnimalAIComponent: enemies without one are left alone.
        local ai_comps = enemy_ai_home.GetAIComponents(enemy_id)
        if #ai_comps > 0 and IsFearful(enemy_id) then
            UpdateEnemyFear(enemy_id, ai_comps, lights)
        else
            -- Charmed since it was scared or flew into a rage.
            if EntityHasTag(enemy_id, ENRAGED_TAG) then
                Pacify(enemy_id, ai_comps)
            end
            SetScared(enemy_id, false, 0, 0)
        end
    end
end
