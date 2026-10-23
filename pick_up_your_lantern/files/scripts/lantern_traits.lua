--- Lantern progression: quality tiers and modifiers rolled once when a lantern appears in the world.
--- Better tiers become more likely in deeper biomes. Traits are kept in VariableStorageComponents,
--- so they survive moving the lantern between the world, inventory and hand, and saving the game.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local PROGRESSION_SETTING_ID = MOD_ID .. ".lantern_progression"
local TIER_STORAGE = "lantern_tier"
local MODIFIER_STORAGE = "lantern_modifier"
local BURN_FRAMES_STORAGE = "lantern_burn_frames"
local EXTINGUISHED_STORAGE = "lantern_extinguished"
local MODIFIER_SCRIPT = "mods/" .. MOD_ID .. "/files/scripts/lantern_modifier.lua"

LANTERN_MODIFIER_NONE = 0
LANTERN_MODIFIER_FLICKERING = 1
LANTERN_MODIFIER_SHORT_LIVED = 2

---Illumination multipliers of quality tiers, from the dimmest to the brightest.
local TIER_MULTIPLIERS = {
    0.75,
    1.0,
    1.5,
    2.0,
}

---Tier weights by world depth. Bands end at the Holy Mountains between biomes.
---@type table<number, {max_y: number, weights: number[]}>
local TIER_WEIGHTS_BY_DEPTH = {
    { max_y = 1300,      weights = { 50, 45, 5, 0, }, },  -- Mines
    { max_y = 2850,      weights = { 35, 50, 14, 1, }, }, -- Coal Pits
    { max_y = 4900,      weights = { 20, 50, 25, 5, }, }, -- Snowy Depths
    { max_y = 6400,      weights = { 10, 45, 35, 10, }, }, -- Hiisi Base
    { max_y = 8450,      weights = { 5, 35, 42, 18, }, },  -- Underground Jungle
    { max_y = 10500,     weights = { 0, 25, 50, 25, }, },  -- The Vault
    { max_y = math.huge, weights = { 0, 15, 50, 35, }, },  -- Temple of the Art and deeper
}

---Modifiers rolled independently of the tier. Chances are per mille; at most one modifier is applied.
---@type table<number, {id: number, letter: string, chance: number}>
local MODIFIERS = {
    { id = LANTERN_MODIFIER_FLICKERING,  letter = "F", chance = 70, },
    { id = LANTERN_MODIFIER_SHORT_LIVED, letter = "S", chance = 70, },
}

---Burn time range of short-lived lanterns, in frames while lit (60 frames per second).
local BURN_FRAMES_MIN = 3 * 60 * 60
local BURN_FRAMES_MAX = 8 * 60 * 60

local FLICKER_DEPTH = 0.45
local SPUTTER_FRAMES = 20 * 60
local SPUTTER_DEPTH = 0.6
local SPUTTER_MIN_FACTOR = 0.3

---Checks whether lantern progression is enabled in mod settings.
---@return boolean
function IsLanternProgressionEnabled()
    local is_enabled = ModSettingGet(PROGRESSION_SETTING_ID)
    if is_enabled == nil then
        is_enabled = ModSettingGetNextValue(PROGRESSION_SETTING_ID)
    end
    if is_enabled == nil then
        is_enabled = true
    end

    return is_enabled
end

---Returns the quality tier of a lantern, or 0 if it has not been rolled.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternTier(entity_id)
    return math.floor(GetStorageFloat(entity_id, TIER_STORAGE))
end

---Returns the illumination multiplier of the lantern quality tier.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternTierMultiplier(entity_id)
    return TIER_MULTIPLIERS[GetLanternTier(entity_id)] or 1.0
end

---Returns the modifier of a lantern.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternModifier(entity_id)
    return math.floor(GetStorageFloat(entity_id, MODIFIER_STORAGE))
end

---Returns the remaining burn time of a short-lived lantern, in frames.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternBurnFrames(entity_id)
    return GetStorageFloat(entity_id, BURN_FRAMES_STORAGE)
end

---Sets the remaining burn time of a short-lived lantern, in frames.
---@param entity_id number Lantern entity ID.
---@param frames number Remaining burn time.
---@return nil
function SetLanternBurnFrames(entity_id, frames)
    SetStorageFloat(entity_id, BURN_FRAMES_STORAGE, frames)
end

---Checks whether the lantern has burned out.
---@param entity_id number Lantern entity ID.
---@return boolean
function IsLanternExtinguished(entity_id)
    return GetStorageFloat(entity_id, EXTINGUISHED_STORAGE) > 0
end

---Calculates a smooth pseudo-random flicker factor from layered sine waves with rare deep dips.
---@param frame number Current game frame.
---@param phase number Per-lantern phase offset.
---@param depth number Maximum relative brightness drop.
---@return number factor Light multiplier in the range [1 - depth, 1].
local function GetFlickerFactor(frame, phase, depth)
    local wave = math.sin(frame * 0.11 + phase) * 0.5
        + math.sin(frame * 0.27 + phase * 2.3) * 0.3
        + math.sin(frame * 0.63 + phase * 1.1) * 0.2
    local dip = math.max(0, math.sin(frame * 0.031 + phase)) ^ 12
    local amount = math.min(1, 0.35 * (0.5 + 0.5 * wave) + 0.65 * dip)

    return 1 - depth * amount
end

---Burns one frame of fuel of a short-lived lantern. Lanterns without the modifier burn forever.
---@param entity_id number Lantern entity ID.
---@return boolean has_fuel Whether the lantern still has fuel left.
function ConsumeLanternFuel(entity_id)
    if GetLanternModifier(entity_id) ~= LANTERN_MODIFIER_SHORT_LIVED then
        return true
    end

    local burn_frames = GetLanternBurnFrames(entity_id) - 1
    if burn_frames <= 0 then
        SetLanternBurnFrames(entity_id, 0)
        return false
    end
    SetLanternBurnFrames(entity_id, burn_frames)

    return true
end

---Calculates the light multiplier of the lantern modifier for the current frame:
---Flickering wavers constantly, Short-lived sputters near the end of its burn time.
---@param entity_id number Lantern entity ID.
---@return number factor Light multiplier in the range (0, 1].
function GetLanternModifierFactor(entity_id)
    local frame = GameGetFrameNum()
    local phase = entity_id * 1.7
    local modifier_id = GetLanternModifier(entity_id)

    if modifier_id == LANTERN_MODIFIER_FLICKERING then
        return GetFlickerFactor(frame, phase, FLICKER_DEPTH)
    elseif modifier_id == LANTERN_MODIFIER_SHORT_LIVED then
        local burn_frames = GetLanternBurnFrames(entity_id)
        if burn_frames < SPUTTER_FRAMES then
            local fuel = math.max(0, burn_frames) / SPUTTER_FRAMES
            return (SPUTTER_MIN_FACTOR + (1 - SPUTTER_MIN_FACTOR) * fuel) * GetFlickerFactor(frame, phase, SPUTTER_DEPTH)
        end
    end

    return 1.0
end

---Picks a tier according to the weights of the depth band.
---@param y number World Y coordinate.
---@return number
local function RollTier(y)
    local weights = TIER_WEIGHTS_BY_DEPTH[#TIER_WEIGHTS_BY_DEPTH].weights
    for _, band in ipairs(TIER_WEIGHTS_BY_DEPTH) do
        if y < band.max_y then
            weights = band.weights
            break
        end
    end

    local total = 0
    for _, weight in ipairs(weights) do
        total = total + weight
    end

    local roll = Random(1, total)
    for tier, weight in ipairs(weights) do
        roll = roll - weight
        if roll <= 0 then
            return tier
        end
    end

    return 2
end

---Picks a modifier, or LANTERN_MODIFIER_NONE.
---@return number
local function RollModifier()
    local roll = Random(1, 1000)
    for _, modifier in ipairs(MODIFIERS) do
        roll = roll - modifier.chance
        if roll <= 0 then
            return modifier.id
        end
    end

    return LANTERN_MODIFIER_NONE
end

---Returns the letter shown in the item name for a modifier.
---@param modifier_id number
---@return string
local function GetModifierLetter(modifier_id)
    for _, modifier in ipairs(MODIFIERS) do
        if modifier.id == modifier_id then
            return modifier.letter
        end
    end

    return ""
end

---Appends the tier and modifier to the item name, e.g. "Lantern 3F".
---@param entity_id number Lantern entity ID.
---@param tier number
---@param modifier_id number
---@return nil
local function UpdateLanternName(entity_id, tier, modifier_id)
    local item_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if item_comp == nil then
        return
    end

    local base_name = ComponentGetValue2(item_comp, "item_name")
    if base_name:sub(1, 1) == "$" then
        base_name = GameTextGet(base_name)
    end
    local name = base_name .. " " .. tier .. GetModifierLetter(modifier_id)

    ComponentSetValue2(item_comp, "item_name", name)
    local ui_info_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "UIInfoComponent")
    if ui_info_comp ~= nil then
        ComponentSetValue2(ui_info_comp, "name", name)
    end
    local ability_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "AbilityComponent")
    if ability_comp ~= nil then
        ComponentSetValue2(ability_comp, "ui_name", name)
    end
end

---Checks whether the modifier script is attached to the lantern.
---@param entity_id number Lantern entity ID.
---@return boolean
local function HasModifierScript(entity_id)
    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LuaComponent") or {}) do
        if ComponentGetValue2(comp, "script_source_file") == MODIFIER_SCRIPT then
            return true
        end
    end

    return false
end

---Rolls tier and modifier of a lantern that has none yet, using the position as the random seed.
---Lanterns stored in the inventory are rolled by the position of their holder.
---@param entity_id number Lantern entity ID.
---@return nil
local function RollLanternTraits(entity_id)
    local x, y = EntityGetTransform(EntityGetRootEntity(entity_id))
    SetRandomSeed(math.floor(x), math.floor(y))

    local tier = RollTier(y)
    local modifier_id = RollModifier()

    SetStorageFloat(entity_id, TIER_STORAGE, tier)
    SetStorageFloat(entity_id, MODIFIER_STORAGE, modifier_id)
    if modifier_id == LANTERN_MODIFIER_SHORT_LIVED then
        SetLanternBurnFrames(entity_id, Random(BURN_FRAMES_MIN, BURN_FRAMES_MAX))
    end
    UpdateLanternName(entity_id, tier, modifier_id)
end

---Rolls lantern traits if needed and attaches the modifier script to lit lanterns.
---The script is attached only while the light is enabled: a component added to a lantern in the
---inventory would run there until the engine toggles components on the next state change.
---@param entity_id number Lantern entity ID.
---@return boolean rolled Whether traits were rolled during this call.
function EnsureLanternTraits(entity_id)
    if not IsLanternProgressionEnabled() then
        return false
    end

    local rolled = false
    if GetLanternTier(entity_id) == 0 then
        RollLanternTraits(entity_id)
        rolled = true
    end

    if GetLanternModifier(entity_id) ~= LANTERN_MODIFIER_NONE and not IsLanternExtinguished(entity_id) then
        local light_comp = EntityGetFirstComponent(entity_id, "LightComponent")
        if light_comp ~= nil and not HasModifierScript(entity_id) then
            EntityAddComponent2(entity_id, "LuaComponent", {
                _tags = "enabled_in_world,enabled_in_hand",
                execute_every_n_frame = 1,
                script_source_file = MODIFIER_SCRIPT,
            })
        end
    end

    return rolled
end

---Permanently puts out a lantern: removes its light and fog of war hole and hides the flame.
---@param entity_id number Lantern entity ID.
---@return nil
function ExtinguishLantern(entity_id)
    SetStorageFloat(entity_id, EXTINGUISHED_STORAGE, 1)

    for _, light_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LightComponent") or {}) do
        EntityRemoveComponent(entity_id, light_comp)
    end

    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        local is_enabled = ComponentGetIsEnabled(sprite_comp)
        if ComponentGetValue2(sprite_comp, "fog_of_war_hole") then
            EntityRemoveComponent(entity_id, sprite_comp)
        elseif image_file:find("_flame%.xml$") then
            -- The vanilla flame sprite has an empty "out" animation.
            ComponentSetValue2(sprite_comp, "rect_animation", "out")
            ComponentSetValue2(sprite_comp, "next_rect_animation", "out")
            if is_enabled then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        elseif image_file:find("_in_hand%.xml$") then
            ComponentSetValue2(sprite_comp, "image_file", (image_file:gsub("_in_hand%.xml$", "_in_hand_out.xml")))
            if is_enabled then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        end
    end

    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LuaComponent") or {}) do
        if ComponentGetValue2(comp, "script_source_file") == MODIFIER_SCRIPT then
            EntityRemoveComponent(entity_id, comp)
        end
    end
end
