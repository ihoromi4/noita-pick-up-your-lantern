--- Lantern progression: quality tiers and modifiers rolled once when a lantern appears in the world.
--- A lantern may carry several modifiers; some are acquired later instead of rolled (Cracked, from damage).
--- Better tiers become more likely in deeper biomes. Traits are kept in VariableStorageComponents,
--- so they survive moving the lantern between the world, inventory and hand, and saving the game.
--- Liquid states (oil-soaked, wet) are taken on later while the lantern is held, see lantern_liquid_state.lua.
--- Tiers, modifiers and states are configured in lantern_properties_config.lua.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_properties_config.lua")

local PROGRESSION_SETTING_ID = MOD_ID .. ".lantern_progression"
local TIER_STORAGE = "lantern_tier"
local MODIFIERS_STORAGE = "lantern_modifiers"
local BURN_FRAMES_STORAGE = "lantern_burn_frames"
local BURN_FRAMES_TOTAL_STORAGE = "lantern_burn_frames_total"
local EXTINGUISHED_STORAGE = "lantern_extinguished"
local BASE_DESCRIPTION_STORAGE = "lantern_base_description"
local LIQUID_STATE_STORAGE = "lantern_liquid_state"
local POWER_LOST_STORAGE = "lantern_power_lost"
local DOUSED_STORAGE = "lantern_doused"
local MODIFIER_SCRIPT = "mods/" .. MOD_ID .. "/files/scripts/lantern_modifier.lua"

-- Open fire of a torch carried by the player, as the vanilla torch emitters (data/entities/base_torch_particle.xml).
-- Visual particles are cosmetic ones that rise on a negative gravity, as fire does; GameCreateParticle with
-- just_visual makes particles that fall and still set the player alight.
local OPEN_FIRE_INTERVAL_MIN_FRAMES = 2
local OPEN_FIRE_INTERVAL_MAX_FRAMES = 6
local OPEN_FIRE_LIFETIME_MIN = 0.3
local OPEN_FIRE_LIFETIME_MAX = 0.5
local OPEN_FIRE_GRAVITY_Y = -30
-- Each particle starts at a random point over the coals and flies up at a random speed and angle.
local OPEN_FIRE_SPREAD_X = 2
local OPEN_FIRE_SPREAD_Y = 1
local OPEN_FIRE_VEL_X_MAX = 8
local OPEN_FIRE_VEL_Y_MIN = -25
local OPEN_FIRE_VEL_Y_MAX = -8
local OPEN_FIRE_SPARK_INTERVAL_FRAMES = 2

-- Type used when neither the filename nor the icon is known: the Small Lantern, the most common one.
local DEFAULT_LANTERN_TYPE_INDEX = 2

---Picks the entity file the lantern was loaded from, and its type.
---@param lantern_id number Lantern entity ID.
---@return string filename
---@return LanternType lantern_type
function GetLanternType(lantern_id)
    local filename = EntityGetFilename(lantern_id)
    for _, lantern_type in ipairs(LANTERN_TYPES) do
        for _, lantern_file in ipairs(lantern_type.files) do
            if filename == lantern_file then
                return lantern_file, lantern_type
            end
        end
    end

    -- The filename is unreliable once the lantern has passed through world streaming; the icon tells the type apart.
    local item_comp = EntityGetFirstComponentIncludingDisabled(lantern_id, "ItemComponent")
    local ui_sprite = item_comp ~= nil and ComponentGetValue2(item_comp, "ui_sprite") or ""
    for _, lantern_type in ipairs(LANTERN_TYPES) do
        if ui_sprite == lantern_type.ui_sprite or ui_sprite == lantern_type.unpowered_ui_sprite then
            return lantern_type.files[1], lantern_type
        end
    end

    local default_type = LANTERN_TYPES[DEFAULT_LANTERN_TYPE_INDEX]
    return default_type.files[1], default_type
end

---Returns the configuration of a modifier.
---@param modifier_id number
---@return LanternModifier|nil
function GetLanternModifierDefinition(modifier_id)
    for _, modifier in ipairs(LANTERN_MODIFIERS) do
        if modifier.id == modifier_id then
            return modifier
        end
    end

    return nil
end

local FLICKERING = GetLanternModifierDefinition(LANTERN_MODIFIER_FLICKERING) --[[@as LanternModifierFlickering]]
local SHORT_LIVED = GetLanternModifierDefinition(LANTERN_MODIFIER_SHORT_LIVED) --[[@as LanternModifierShortLived]]
local CRACKED = GetLanternModifierDefinition(LANTERN_MODIFIER_CRACKED) --[[@as LanternModifierCracked]]

---Checks whether lantern progression is enabled in mod settings.
---@return boolean
function IsLanternProgressionEnabled()
    local is_enabled = ModSettingGet(PROGRESSION_SETTING_ID)
    if is_enabled == nil then
        is_enabled = ModSettingGetNextValue(PROGRESSION_SETTING_ID)
    end
    if is_enabled == nil then
        is_enabled = false
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
    local tier = LANTERN_TIERS[GetLanternTier(entity_id)]
    return tier ~= nil and tier.multiplier or 1.0
end

---Returns the bit of a modifier in a modifier mask.
---@param modifier_id number
---@return number
local function GetModifierBit(modifier_id)
    return 2 ^ (modifier_id - 1)
end

---Checks whether a modifier mask contains a modifier.
---@param mask number Modifier mask.
---@param modifier_id number
---@return boolean
local function MaskHasModifier(mask, modifier_id)
    return math.floor(mask / GetModifierBit(modifier_id)) % 2 == 1
end

---Checks whether a modifier is listed in a list of modifier IDs.
---@param modifier_ids number[]|nil
---@param modifier_id number
---@return boolean
local function ListHasModifier(modifier_ids, modifier_id)
    for _, listed_id in ipairs(modifier_ids or {}) do
        if listed_id == modifier_id then
            return true
        end
    end

    return false
end

---Adds a modifier to a modifier mask according to the modifier interactions: the modifier is skipped if it is
---already present or incompatible with a present one, and the modifiers it replaces are removed.
---@param mask number Modifier mask.
---@param modifier_id number
---@return number mask New modifier mask.
---@return boolean added Whether the modifier was added.
local function AddModifierToMask(mask, modifier_id)
    local modifier = GetLanternModifierDefinition(modifier_id)
    if modifier == nil or MaskHasModifier(mask, modifier_id) then
        return mask, false
    end

    for _, other in ipairs(LANTERN_MODIFIERS) do
        if MaskHasModifier(mask, other.id) and not ListHasModifier(modifier.replaces, other.id)
            and (ListHasModifier(modifier.incompatible, other.id) or ListHasModifier(other.incompatible, modifier_id)) then
            return mask, false
        end
    end

    for _, replaced_id in ipairs(modifier.replaces or {}) do
        if MaskHasModifier(mask, replaced_id) then
            mask = mask - GetModifierBit(replaced_id)
        end
    end

    return mask + GetModifierBit(modifier_id), true
end

---Returns the modifier mask of a lantern: bit `2^(id - 1)` is set for each modifier it carries.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternModifiers(entity_id)
    return math.floor(GetStorageFloat(entity_id, MODIFIERS_STORAGE))
end

---Checks whether a lantern carries a modifier.
---@param entity_id number Lantern entity ID.
---@param modifier_id number
---@return boolean
function HasLanternModifier(entity_id, modifier_id)
    return MaskHasModifier(GetLanternModifiers(entity_id), modifier_id)
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

---Checks whether an open fire lantern has been doused in a liquid, see chain_torch_fire.lua.
---@param entity_id number Lantern entity ID.
---@return boolean
function IsLanternDoused(entity_id)
    return GetStorageFloat(entity_id, DOUSED_STORAGE) > 0
end

---Douses an open fire lantern or lights it again: keeps the state and switches the in-hand sprite between its lit
---(`*_in_hand.xml`) and dark (`*_in_hand_out.xml`) variants. The light goes to 0 through GetLanternPowerFactor().
---@param entity_id number Lantern entity ID.
---@param is_doused boolean
---@return nil
function SetLanternDoused(entity_id, is_doused)
    SetStorageFloat(entity_id, DOUSED_STORAGE, is_doused and 1 or 0)
    local from, to = "_in_hand%.xml$", "_in_hand_out.xml"
    if not is_doused then
        from, to = "_in_hand_out%.xml$", "_in_hand.xml"
    end
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if image_file:find(from) then
            ComponentSetValue2(sprite_comp, "image_file", (image_file:gsub(from, to)))
            if ComponentGetIsEnabled(sprite_comp) then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        end
    end
end

---Makes the open fire of a torch carried by the player, in hand or on the belt, where the particle emitters of the
---torch do not work: sparks of its type and fire, of which only a share is real fire cells that set burning
---materials around alight, and the rest only visual. Called every frame.
---@param open_fire LanternOpenFire Open fire config of the lantern type.
---@param x number World X coordinate of the coals.
---@param y number World Y coordinate of the coals.
---@param real_fire_chance number Share of the fire particles that are real fire cells, 0 to 1.
---@return nil
function EmitOpenFire(open_fire, x, y, real_fire_chance)
    ---Creates particles of a material one by one, each at its own point and with its own velocity.
    ---@param material string
    ---@param count number
    ---@param is_real boolean Whether the particles are real cells, not cosmetic ones.
    local function Emit(material, count, is_real)
        for _ = 1, count do
            local px = x + (math.random() * 2 - 1) * OPEN_FIRE_SPREAD_X
            local py = y + (math.random() * 2 - 1) * OPEN_FIRE_SPREAD_Y
            local vel_x = (math.random() * 2 - 1) * OPEN_FIRE_VEL_X_MAX
            local vel_y = OPEN_FIRE_VEL_Y_MIN + math.random() * (OPEN_FIRE_VEL_Y_MAX - OPEN_FIRE_VEL_Y_MIN)
            if is_real then
                GameCreateParticle(material, px, py, 1, vel_x, vel_y, false, false, false)
            else
                GameCreateCosmeticParticle(material, px, py, 1, vel_x, vel_y, 0, OPEN_FIRE_LIFETIME_MIN,
                    OPEN_FIRE_LIFETIME_MAX, true, false, false, false, 0, OPEN_FIRE_GRAVITY_Y)
            end
        end
    end

    local frame = GameGetFrameNum()
    if frame % OPEN_FIRE_SPARK_INTERVAL_FRAMES == 0 then
        Emit(open_fire.spark_material, math.random(1, 3), false)
    end
    if frame % math.random(OPEN_FIRE_INTERVAL_MIN_FRAMES, OPEN_FIRE_INTERVAL_MAX_FRAMES) == 0 then
        Emit("fire", math.random(1, 2), math.random() < real_fire_chance)
    end
end

---Returns the light multiplier of the lamp power: 0 for a lamp that needs power and has lost it, or for a doused
---open fire lantern, 1 otherwise.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternPowerFactor(entity_id)
    local _, lantern_type = GetLanternType(entity_id)
    if lantern_type.open_fire ~= nil and IsLanternDoused(entity_id) then
        return 0
    end
    if lantern_type.needs_power and GetStorageFloat(entity_id, POWER_LOST_STORAGE) > 0 then
        return 0
    end

    return 1
end

---Checks whether a lantern hangs on the ceiling: it is a root entity, not in an inventory, and keeps its joint,
---which lantern_anchor.lua removes when the lantern is detached.
---@param entity_id number Lantern entity ID.
---@return boolean
function IsLanternHanging(entity_id)
    return EntityGetRootEntity(entity_id) == entity_id
        and EntityGetFirstComponentIncludingDisabled(entity_id, "PhysicsJointComponent") ~= nil
end

---Switches the in-hand sprite of a lantern to its dark variant (`*_in_hand.xml` to `*_in_hand_out.xml`).
---@param entity_id number Lantern entity ID.
---@return nil
local function ShowDarkHandSprite(entity_id)
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if image_file:find("_in_hand%.xml$") then
            ComponentSetValue2(sprite_comp, "image_file", (image_file:gsub("_in_hand%.xml$", "_in_hand_out.xml")))
            if ComponentGetIsEnabled(sprite_comp) then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        end
    end
end

---Cuts the power of a lamp that needs it, for good: its light and fog of war hole go to 0 once the illumination
---is applied again, its in-hand sprite and inventory icon turn dark, and the physics image is switched to the
---unpowered one, which the engine uses for the next physics body, after the lamp is thrown or dropped. Called by tube_lamp_cable.lua
---when the lamp leaves the ceiling without its cable, or when the cable snaps.
---@param entity_id number Lantern entity ID.
---@return boolean cut Whether the power was cut during this call.
function CutLanternPower(entity_id)
    local _, lantern_type = GetLanternType(entity_id)
    if not lantern_type.needs_power or GetStorageFloat(entity_id, POWER_LOST_STORAGE) > 0 then
        return false
    end

    SetStorageFloat(entity_id, POWER_LOST_STORAGE, 1)
    ShowDarkHandSprite(entity_id)
    local item_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if item_comp ~= nil and lantern_type.unpowered_ui_sprite ~= nil then
        ComponentSetValue2(item_comp, "ui_sprite", lantern_type.unpowered_ui_sprite)
    end
    if lantern_type.unpowered_image_file ~= nil then
        for _, shape_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "PhysicsImageShapeComponent") or {}) do
            ComponentSetValue2(shape_comp, "image_file", lantern_type.unpowered_image_file)
        end
    end

    return true
end

---Returns the liquid state of a lantern.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternLiquidState(entity_id)
    return math.floor(GetStorageFloat(entity_id, LIQUID_STATE_STORAGE))
end

---Sets the liquid state of a lantern.
---@param entity_id number Lantern entity ID.
---@param state_id number Liquid state.
---@return nil
function SetLanternLiquidState(entity_id, state_id)
    SetStorageFloat(entity_id, LIQUID_STATE_STORAGE, state_id)
end

---Returns the liquid state a lantern takes on in the given material.
---@param material_name string Material name.
---@return number state_id Liquid state, or LANTERN_LIQUID_STATE_NONE if the material has no effect.
function GetLiquidStateByMaterial(material_name)
    for _, state in ipairs(LANTERN_LIQUID_STATES) do
        if state.materials[material_name] then
            return state.id
        end
    end

    return LANTERN_LIQUID_STATE_NONE
end

---Returns the definition of a liquid state.
---@param state_id number
---@return LanternLiquidState|nil
local function GetLiquidStateDefinition(state_id)
    for _, state in ipairs(LANTERN_LIQUID_STATES) do
        if state.id == state_id then
            return state
        end
    end

    return nil
end

---Returns the illumination multiplier of the lantern liquid state.
---@param entity_id number Lantern entity ID.
---@return number
function GetLanternLiquidStateMultiplier(entity_id)
    local state = GetLiquidStateDefinition(GetLanternLiquidState(entity_id))
    return state ~= nil and state.multiplier or 1.0
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
---@param entity_id number Lantern entity ID.
---@return number
local function GetLanternBurnFramesTotal(entity_id)
    return GetStorageFloat(entity_id, BURN_FRAMES_TOTAL_STORAGE)
end

---Burns one frame of fuel of a short-lived lantern and leaks a drop of oil at the given position
---at the configured interval. Lanterns without the modifier burn forever.
---@param entity_id number Lantern entity ID.
---@param x number World X coordinate of the oil drop.
---@param y number World Y coordinate of the lantern; the drop appears slightly below it.
---@return boolean has_fuel Whether the lantern still has fuel left.
function ConsumeLanternFuel(entity_id, x, y)
    if not HasLanternModifier(entity_id, LANTERN_MODIFIER_SHORT_LIVED) then
        return true
    end

    local burn_frames = GetLanternBurnFrames(entity_id) - 1
    if burn_frames <= 0 then
        SetLanternBurnFrames(entity_id, 0)
        return false
    end
    SetLanternBurnFrames(entity_id, burn_frames)

    if math.floor(burn_frames) % SHORT_LIVED.oil_drip_interval_frames == 0 then
        GameCreateParticle("oil", x, y + SHORT_LIVED.oil_drip_offset_y, 1, 0, 0, false, false)
    end

    return true
end

---Calculates how much light a short-lived lantern has left: it fades linearly from full brightness
---to `fade_low_factor`, then to darkness over the last `fade_end_frames` of its burn time.
---@param entity_id number Lantern entity ID.
---@return number factor Light multiplier in the range [0, 1].
local function GetFuelFactor(entity_id)
    local fade_low_factor = SHORT_LIVED.fade_low_factor
    local fade_end_frames = SHORT_LIVED.fade_end_frames
    local burn_frames = math.max(0, GetLanternBurnFrames(entity_id))
    if burn_frames <= fade_end_frames then
        return fade_low_factor * burn_frames / fade_end_frames
    end

    local fade_frames = GetLanternBurnFramesTotal(entity_id) - fade_end_frames
    if fade_frames <= 0 then
        return 1.0
    end

    local fuel = math.min(1, (burn_frames - fade_end_frames) / fade_frames)
    return fade_low_factor + (1 - fade_low_factor) * fuel
end

---Calculates the light multiplier of the lantern modifiers for the current frame, multiplying the factors of
---all modifiers: Flickering shines wider but wavers constantly, Short-lived fades as its oil burns and sputters
---at the end. Cracked does not change the light.
---@param entity_id number Lantern entity ID.
---@return number factor Light multiplier, above 1 for the brightest moments of Flickering lanterns.
function GetLanternModifierFactor(entity_id)
    local frame = GameGetFrameNum()
    local phase = entity_id * 1.7
    local factor = 1.0

    if HasLanternModifier(entity_id, LANTERN_MODIFIER_FLICKERING) then
        factor = factor * FLICKERING.radius_bonus * GetFlickerFactor(frame, phase, FLICKERING.flicker_depth)
    end
    if HasLanternModifier(entity_id, LANTERN_MODIFIER_SHORT_LIVED) then
        factor = factor * GetFuelFactor(entity_id)
        if GetLanternBurnFrames(entity_id) < SHORT_LIVED.fade_end_frames then
            factor = factor * GetFlickerFactor(frame, phase, SHORT_LIVED.sputter_depth)
        end
    end

    return factor
end

---Leaks particles of fire from a cracked lantern at the given position: every `fire_interval_frames`
---frames with a `fire_chance` chance. Lanterns without the modifier never leak fire.
---@param entity_id number Lantern entity ID.
---@param x number World X coordinate of the fire particles.
---@param y number World Y coordinate of the fire particles.
---@return nil
function EmitCrackedFire(entity_id, x, y)
    local frame = GameGetFrameNum()
    if not HasLanternModifier(entity_id, LANTERN_MODIFIER_CRACKED) or frame % CRACKED.fire_interval_frames ~= 0 then
        return
    end

    SetRandomSeed(frame, entity_id)
    if Random(1, 1000) <= CRACKED.fire_chance then
        GameCreateParticle("fire", x, y, CRACKED.fire_particle_count, 0, 0, false, false)
    end
end

---Picks a tier according to the weights of the depth band.
---@param y number World Y coordinate.
---@return number
local function RollTier(y)
    local weights = LANTERN_TIER_WEIGHTS_BY_DEPTH[#LANTERN_TIER_WEIGHTS_BY_DEPTH].weights
    for _, band in ipairs(LANTERN_TIER_WEIGHTS_BY_DEPTH) do
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

---Rolls each modifier independently in table order, applying the modifier interactions.
---@return number mask Modifier mask, 0 for none.
local function RollModifiers()
    local mask = 0
    for _, modifier in ipairs(LANTERN_MODIFIERS) do
        if modifier.chance > 0 and Random(1, 1000) <= modifier.chance then
            mask = AddModifierToMask(mask, modifier.id)
        end
    end

    return mask
end

---Lists the description sentences of the current lantern properties: quality tier, modifiers, then liquid state.
---@param entity_id number Lantern entity ID.
---@return string[] descriptions Translation keys.
local function GetLanternPropertyDescriptions(entity_id)
    local descriptions = {}

    local tier = LANTERN_TIERS[GetLanternTier(entity_id)]
    if tier ~= nil then
        table.insert(descriptions, tier.description)
    end

    if IsLanternExtinguished(entity_id) then
        table.insert(descriptions, LANTERN_EXTINGUISHED_DESCRIPTION)
    else
        for _, modifier in ipairs(LANTERN_MODIFIERS) do
            if HasLanternModifier(entity_id, modifier.id) then
                table.insert(descriptions, modifier.description)
            end
        end
    end

    local liquid_state = GetLiquidStateDefinition(GetLanternLiquidState(entity_id))
    if liquid_state ~= nil and not IsLanternExtinguished(entity_id) then
        table.insert(descriptions, liquid_state.description)
    end

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
    local modifiers = RollModifiers()

    SetStorageFloat(entity_id, TIER_STORAGE, tier)
    SetStorageFloat(entity_id, MODIFIERS_STORAGE, modifiers)
    if HasLanternModifier(entity_id, LANTERN_MODIFIER_SHORT_LIVED) then
        local burn_frames = Random(SHORT_LIVED.burn_frames_min, SHORT_LIVED.burn_frames_max)
        SetLanternBurnFrames(entity_id, burn_frames)
        SetStorageFloat(entity_id, BURN_FRAMES_TOTAL_STORAGE, burn_frames)
    end
end

---Attaches the modifier script to a lit lantern with modifiers.
---The script is attached only while the light is enabled: a component added to a lantern in the
---inventory would run there until the engine toggles components on the next state change.
---@param entity_id number Lantern entity ID.
---@return nil
local function AttachModifierScript(entity_id)
    if GetLanternModifiers(entity_id) == 0 or IsLanternExtinguished(entity_id) then
        return
    end

    local light_comp = EntityGetFirstComponent(entity_id, "LightComponent")
    if light_comp ~= nil and not HasModifierScript(entity_id) then
        EntityAddComponent2(entity_id, "LuaComponent", {
            _tags = "enabled_in_world,enabled_in_hand",
            execute_every_n_frame = 1,
            script_source_file = MODIFIER_SCRIPT,
        })
    end
end

---Rolls lantern traits if needed, updates the description and attaches the modifier script to lit lanterns.
---@param entity_id number Lantern entity ID.
---@return boolean rolled Whether traits were rolled during this call.
function EnsureLanternTraits(entity_id)
    local rolled = false
    if IsLanternProgressionEnabled() and GetLanternTier(entity_id) == 0 then
        RollLanternTraits(entity_id)
        rolled = true
    end
    UpdateLanternDescription(entity_id)
    AttachModifierScript(entity_id)

    return rolled
end

---Adds a modifier acquired after the lantern appeared, according to the modifier interactions,
---then updates the description and attaches the modifier script.
---@param entity_id number Lantern entity ID.
---@param modifier_id number
---@return boolean added Whether the modifier was added.
function AddLanternModifier(entity_id, modifier_id)
    local mask, added = AddModifierToMask(GetLanternModifiers(entity_id), modifier_id)
    if not added then
        return false
    end

    SetStorageFloat(entity_id, MODIFIERS_STORAGE, mask)
    UpdateLanternDescription(entity_id)
    AttachModifierScript(entity_id)

    return true
end

---Permanently puts out a lantern: removes its light, fog of war hole and glow particles, and hides the flame.
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
        end
    end
    ShowDarkHandSprite(entity_id)

    for _, component_type in ipairs({ "ParticleEmitterComponent", "SpriteParticleEmitterComponent", }) do
        for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, component_type) or {}) do
            EntityRemoveComponent(entity_id, comp)
        end
    end

    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LuaComponent") or {}) do
        if ComponentGetValue2(comp, "script_source_file") == MODIFIER_SCRIPT then
            EntityRemoveComponent(entity_id, comp)
        end
    end
end
