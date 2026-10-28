--- Configuration of all lantern properties: quality tiers, modifiers and states.
--- - Traits are rolled once when a lantern first appears and never change: the quality tier and the modifiers.
---   Some modifiers are never rolled and are acquired later instead (Cracked, from damage).
--- - States are taken on later and can change: liquid states and the extinguished state.
--- Lantern types are listed in LANTERN_TYPES. Base values of each type (light radius and colour, fog of war hole,
--- hp, ceiling check distance) are declared in its XML files.

-- Lantern types

---@class LanternType
---@field files string[] Entity files of the type; the first one is loaded to hang a held lantern.
---@field ui_sprite string Inventory icon; tells the type apart once the entity filename is lost.
---@field hang_offset_y number|nil Origin of a hung lantern below the ceiling, in pixels: the joint ends up just under
---the surface, and lantern_anchor.lua still finds the ceiling within its check distance. Types without it are not
---hung with the left mouse button.
---@field needs_power boolean|nil Whether the lamp shines only while it is wired to the ceiling: it loses power for good
---once it is picked up or detached.
---@field unpowered_image_file string|nil Physics image of a lamp without power, used for its next physics body.
---@field unpowered_ui_sprite string|nil Inventory icon of a lamp without power; also tells the type apart.

---Pickable light fixtures. Each file is a full override in `data/entities/props/` of the mod.
---@type LanternType[]
LANTERN_TYPES = {
    -- Lantern
    {
        files = { "data/entities/props/physics_lantern.xml", },
        ui_sprite = "mods/pick_up_your_lantern/files/props_gfx/ui_lantern.png",
        hang_offset_y = 4,
    },
    -- Small Lantern
    {
        files = {
            "data/entities/props/physics/lantern_small.xml",
            "data/entities/props/physics_lantern_small.xml",
        },
        ui_sprite = "mods/pick_up_your_lantern/files/props_gfx/ui_lantern_small.png",
        hang_offset_y = 4,
    },
    -- Mining Lamp
    {
        files = { "data/entities/props/physics_mining_lamp.xml", },
        ui_sprite = "mods/pick_up_your_lantern/files/props_gfx/ui_mining_lamp.png",
        hang_offset_y = 7,
    },
    -- Tube Lamp: needs a power cable, so it is not hung back.
    {
        files = { "data/entities/props/physics_tubelamp.xml", },
        ui_sprite = "mods/pick_up_your_lantern/files/props_gfx/ui_tube_lamp.png",
        needs_power = true,
        unpowered_image_file = "mods/pick_up_your_lantern/files/props_gfx/tube_lamp_unlit.png",
        unpowered_ui_sprite = "mods/pick_up_your_lantern/files/props_gfx/ui_tube_lamp_unlit.png",
    },
}

-- Quality tiers

---@class LanternTier
---@field multiplier number Light radius and fog of war hole multiplier.
---@field description string Translation key of the description sentence.

---Quality tiers, from the dimmest to the brightest. The index is the tier kept in the `lantern_tier` storage.
---@type LanternTier[]
LANTERN_TIERS = {
    { multiplier = 0.75, description = "$item_description_lantern_tier_1", },
    { multiplier = 1.0,  description = "$item_description_lantern_tier_2", },
    { multiplier = 1.5,  description = "$item_description_lantern_tier_3", },
    { multiplier = 2.0,  description = "$item_description_lantern_tier_4", },
}

---Tier weights by world depth, in the order of LANTERN_TIERS. Bands end at the Holy Mountains between biomes.
---@type {max_y: number, weights: number[]}[]
LANTERN_TIER_WEIGHTS_BY_DEPTH = {
    { max_y = 1300,      weights = { 50, 45, 5, 0, }, },   -- Mines
    { max_y = 2850,      weights = { 35, 50, 14, 1, }, },  -- Coal Pits
    { max_y = 4900,      weights = { 20, 50, 25, 5, }, },  -- Snowy Depths
    { max_y = 6400,      weights = { 10, 45, 35, 10, }, }, -- Hiisi Base
    { max_y = 8450,      weights = { 5, 35, 42, 18, }, },  -- Underground Jungle
    { max_y = 10500,     weights = { 0, 25, 50, 25, }, },  -- The Vault
    { max_y = math.huge, weights = { 0, 15, 50, 35, }, },  -- Temple of the Art and deeper
}

-- Modifiers

LANTERN_MODIFIER_FLICKERING = 1
LANTERN_MODIFIER_SHORT_LIVED = 2
LANTERN_MODIFIER_CRACKED = 3

---@class LanternModifier
---@field id number Modifier ID; bit `2^(id - 1)` of the `lantern_modifiers` storage.
---@field description string Translation key of the description sentence.
---@field chance number Roll chance when a lantern appears, per mille. 0 for modifiers that are never rolled.
---@field incompatible number[]|nil IDs of modifiers this one cannot be combined with, checked in both directions.
---@field replaces number[]|nil IDs of modifiers removed from the lantern when this one is added.

---@class LanternModifierFlickering : LanternModifier
---@field radius_bonus number Light radius multiplier.
---@field flicker_depth number Maximum relative brightness drop of the flicker.

---@class LanternModifierShortLived : LanternModifier
---@field burn_frames_min number Minimum burn time, in frames while lit (60 frames per second).
---@field burn_frames_max number Maximum burn time, in frames while lit.
---@field fade_low_factor number Light multiplier the lantern slowly fades to before the end.
---@field fade_end_frames number Last frames of burn time over which the lantern sputters down to darkness.
---@field sputter_depth number Maximum relative brightness drop while sputtering.
---@field oil_drip_interval_frames number Interval between leaked oil drops, in frames.
---@field oil_drip_offset_y number Vertical offset of an oil drop below the lantern, in pixels.

---@class LanternModifierCracked : LanternModifier
---@field crack_chance number Chance to crack when the lantern takes damage without breaking, per mille.
---@field fire_interval_frames number Interval between fire leak rolls, in frames.
---@field fire_chance number Chance to leak fire on each roll, per mille.
---@field fire_particle_count number Number of fire particles leaked at once.

---Modifiers, rolled independently in table order: changing the order changes which modifiers a lantern at a given
---position gets. A lantern may carry several modifiers; modifiers without `incompatible` or `replaces` combine,
---and their light factors multiply. The order also sets the order of the description sentences.
---@type LanternModifier[]
LANTERN_MODIFIERS = {
    ---@type LanternModifierFlickering
    {
        id = LANTERN_MODIFIER_FLICKERING,
        description = "$item_description_lantern_flickering",
        chance = 70,
        radius_bonus = 1.2,
        flicker_depth = 0.45,
    },
    ---@type LanternModifierShortLived
    {
        id = LANTERN_MODIFIER_SHORT_LIVED,
        description = "$item_description_lantern_short_lived",
        chance = 70,
        burn_frames_min = 3 * 60 * 60,
        burn_frames_max = 8 * 60 * 60,
        fade_low_factor = 0.2,
        fade_end_frames = 30 * 60,
        sputter_depth = 0.6,
        oil_drip_interval_frames = 5 * 60,
        oil_drip_offset_y = 4,
    },
    ---@type LanternModifierCracked
    {
        id = LANTERN_MODIFIER_CRACKED,
        description = "$item_description_lantern_cracked",
        chance = 0,
        crack_chance = 330,
        fire_interval_frames = 20,
        fire_chance = 500,
        fire_particle_count = 2,
    },
}

-- States

LANTERN_LIQUID_STATE_NONE = 0
LANTERN_LIQUID_STATE_OIL_SOAKED = 1
LANTERN_LIQUID_STATE_WET = 2

---@class LanternLiquidState
---@field id number Liquid state ID, kept in the `lantern_liquid_state` storage.
---@field materials table<string, boolean> Names of the liquid materials that cause the state.
---@field multiplier number Light radius and fog of war hole multiplier.
---@field description string Translation key of the description sentence.

---Liquid states a held lantern takes on when the player dives into a liquid. A state lasts until another one
---replaces it and multiplies the light radius and fog of war hole of the lantern.
---@type LanternLiquidState[]
LANTERN_LIQUID_STATES = {
    {
        id = LANTERN_LIQUID_STATE_OIL_SOAKED,
        materials = { oil = true, },
        multiplier = 1.3,
        description = "$item_description_lantern_oil_soaked",
    },
    {
        id = LANTERN_LIQUID_STATE_WET,
        materials = { water = true, water_salt = true, water_ice = true, water_fading = true, swamp = true, },
        multiplier = 0.8,
        description = "$item_description_lantern_wet",
    },
}

---Description sentence of a burnt-out lantern. It replaces the modifier sentences and hides the liquid state.
LANTERN_EXTINGUISHED_DESCRIPTION = "$item_description_lantern_extinguished"
