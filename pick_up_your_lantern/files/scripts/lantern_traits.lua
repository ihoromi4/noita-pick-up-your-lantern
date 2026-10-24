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
local BURN_FRAMES_TOTAL_STORAGE = "lantern_burn_frames_total"
local EXTINGUISHED_STORAGE = "lantern_extinguished"
local BASE_DESCRIPTION_STORAGE = "lantern_base_description"
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

---Description sentences of quality tiers, in the same order as TIER_MULTIPLIERS.
local TIER_DESCRIPTIONS = {
    "$item_description_lantern_tier_1",
    "$item_description_lantern_tier_2",
    "$item_description_lantern_tier_3",
    "$item_description_lantern_tier_4",
}

local EXTINGUISHED_DESCRIPTION = "$item_description_lantern_extinguished"

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
---@type table<number, {id: number, description: string, chance: number}>
local MODIFIERS = {
    { id = LANTERN_MODIFIER_FLICKERING,  description = "$item_description_lantern_flickering",  chance = 70, },
    { id = LANTERN_MODIFIER_SHORT_LIVED, description = "$item_description_lantern_short_lived", chance = 70, },
}

---Burn time range of short-lived lanterns, in frames while lit (60 frames per second).
local BURN_FRAMES_MIN = 3 * 60 * 60
local BURN_FRAMES_MAX = 8 * 60 * 60

local FLICKER_DEPTH = 0.45
local FLICKERING_RADIUS_BONUS = 1.2

-- Short-lived lanterns fade slowly to FADE_LOW_FACTOR, then go dark over the last FADE_END_FRAMES while sputtering.
local FADE_LOW_FACTOR = 0.2
local FADE_END_FRAMES = 30 * 60
local SPUTTER_DEPTH = 0.6

-- Short-lived lanterns leak a drop of oil every OIL_DRIP_INTERVAL_FRAMES while burning.
local OIL_DRIP_INTERVAL_FRAMES = 5 * 60
local OIL_DRIP_OFFSET_Y = 4

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

---Returns the full burn time of a short-lived lantern, in frames.
---Lanterns from older saves lack it and take their remaining burn time, so they fade from full brightness.
---@param entity_id number Lantern entity ID.
---@return number
local function GetLanternBurnFramesTotal(entity_id)
    local total = GetStorageFloat(entity_id, BURN_FRAMES_TOTAL_STORAGE)
    if total <= 0 then
        total = GetLanternBurnFrames(entity_id)
        SetStorageFloat(entity_id, BURN_FRAMES_TOTAL_STORAGE, total)
    end

    return total
end

---Burns one frame of fuel of a short-lived lantern and leaks a drop of oil at the given position
---every OIL_DRIP_INTERVAL_FRAMES. Lanterns without the modifier burn forever.
---@param entity_id number Lantern entity ID.
---@param x number World X coordinate of the oil drop.
---@param y number World Y coordinate of the lantern; the drop appears slightly below it.
---@return boolean has_fuel Whether the lantern still has fuel left.
function ConsumeLanternFuel(entity_id, x, y)
    if GetLanternModifier(entity_id) ~= LANTERN_MODIFIER_SHORT_LIVED then
        return true
    end

    local burn_frames = GetLanternBurnFrames(entity_id) - 1
    if burn_frames <= 0 then
        SetLanternBurnFrames(entity_id, 0)
        return false
    end
    SetLanternBurnFrames(entity_id, burn_frames)

    if math.floor(burn_frames) % OIL_DRIP_INTERVAL_FRAMES == 0 then
        GameCreateParticle("oil", x, y + OIL_DRIP_OFFSET_Y, 1, 0, 0, false, false)
    end

    return true
end

---Calculates how much light a short-lived lantern has left: it fades linearly from full brightness
---to FADE_LOW_FACTOR, then to darkness over the last FADE_END_FRAMES of its burn time.
---@param entity_id number Lantern entity ID.
---@return number factor Light multiplier in the range [0, 1].
local function GetFuelFactor(entity_id)
    local burn_frames = math.max(0, GetLanternBurnFrames(entity_id))
    if burn_frames <= FADE_END_FRAMES then
        return FADE_LOW_FACTOR * burn_frames / FADE_END_FRAMES
    end

    local fade_frames = GetLanternBurnFramesTotal(entity_id) - FADE_END_FRAMES
    if fade_frames <= 0 then
        return 1.0
    end

    local fuel = math.min(1, (burn_frames - FADE_END_FRAMES) / fade_frames)
    return FADE_LOW_FACTOR + (1 - FADE_LOW_FACTOR) * fuel
end

---Calculates the light multiplier of the lantern modifier for the current frame:
---Flickering shines wider but wavers constantly, Short-lived fades as its oil burns and sputters at the end.
---@param entity_id number Lantern entity ID.
---@return number factor Light multiplier, above 1 for the brightest moments of Flickering lanterns.
function GetLanternModifierFactor(entity_id)
    local frame = GameGetFrameNum()
    local phase = entity_id * 1.7
    local modifier_id = GetLanternModifier(entity_id)

    if modifier_id == LANTERN_MODIFIER_FLICKERING then
        return FLICKERING_RADIUS_BONUS * GetFlickerFactor(frame, phase, FLICKER_DEPTH)
    elseif modifier_id == LANTERN_MODIFIER_SHORT_LIVED then
        local factor = GetFuelFactor(entity_id)
        if GetLanternBurnFrames(entity_id) < FADE_END_FRAMES then
            factor = factor * GetFlickerFactor(frame, phase, SPUTTER_DEPTH)
        end
        return factor
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

---Returns the description sentence of a modifier.
---@param modifier_id number
---@return string|nil description Translation key, or nil for LANTERN_MODIFIER_NONE.
local function GetModifierDescription(modifier_id)
    for _, modifier in ipairs(MODIFIERS) do
        if modifier.id == modifier_id then
            return modifier.description
        end
    end

    return nil
end

---Lists the description sentences of the current lantern properties: quality tier, then modifier.
---@param entity_id number Lantern entity ID.
---@return string[] descriptions Translation keys.
local function GetLanternPropertyDescriptions(entity_id)
    local descriptions = {}

    local tier_description = TIER_DESCRIPTIONS[GetLanternTier(entity_id)]
    if tier_description ~= nil then
        table.insert(descriptions, tier_description)
    end

    local modifier_description = GetModifierDescription(GetLanternModifier(entity_id))
    if IsLanternExtinguished(entity_id) then
        modifier_description = EXTINGUISHED_DESCRIPTION
    end
    if modifier_description ~= nil then
        table.insert(descriptions, modifier_description)
    end

    -- Dynamic states from the environment (e.g. oil-soaked) add their sentences here.

    return descriptions
end

---Translates a text if it is a translation key.
---@param text string Plain text or a translation key starting with "$".
---@return string
local function TranslateText(text)
    if text:sub(1, 1) == "$" then
        return GameTextGet(text)
    end

    return text
end

---Rebuilds the item description from the base description and a sentence per lantern property.
---Rebuilt on every scan, so it follows state changes and the game language.
---@param entity_id number Lantern entity ID.
---@return nil
function UpdateLanternDescription(entity_id)
    local item_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if item_comp == nil then
        return
    end

    -- The original description is kept aside, as the field itself gets overwritten.
    local base_description = GetStorageString(entity_id, BASE_DESCRIPTION_STORAGE)
    if base_description == "" then
        base_description = ComponentGetValue2(item_comp, "ui_description")
        SetStorageString(entity_id, BASE_DESCRIPTION_STORAGE, base_description)
    end

    local description = TranslateText(base_description)
    for _, property_description in ipairs(GetLanternPropertyDescriptions(entity_id)) do
        description = description .. "\n" .. TranslateText(property_description)
    end

    if ComponentGetValue2(item_comp, "ui_description") ~= description then
        ComponentSetValue2(item_comp, "ui_description", description)
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
        local burn_frames = Random(BURN_FRAMES_MIN, BURN_FRAMES_MAX)
        SetLanternBurnFrames(entity_id, burn_frames)
        SetStorageFloat(entity_id, BURN_FRAMES_TOTAL_STORAGE, burn_frames)
    end
end

---Rolls lantern traits if needed, updates the description and attaches the modifier script to lit lanterns.
---The script is attached only while the light is enabled: a component added to a lantern in the
---inventory would run there until the engine toggles components on the next state change.
---@param entity_id number Lantern entity ID.
---@return boolean rolled Whether traits were rolled during this call.
function EnsureLanternTraits(entity_id)
    local rolled = false
    if IsLanternProgressionEnabled() and GetLanternTier(entity_id) == 0 then
        RollLanternTraits(entity_id)
        rolled = true
    end
    UpdateLanternDescription(entity_id)

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
    UpdateLanternDescription(entity_id)

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
