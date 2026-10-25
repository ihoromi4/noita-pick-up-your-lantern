--- Configuration of lantern modifiers: IDs, description sentences, roll chances and behaviour parameters.
--- Modifiers are rolled in table order, so the order is part of the configuration: changing it changes
--- which modifier a lantern at a given position gets.

LANTERN_MODIFIER_NONE = 0
LANTERN_MODIFIER_FLICKERING = 1
LANTERN_MODIFIER_SHORT_LIVED = 2

---@class LanternModifier
---@field id number Modifier ID, kept in the `lantern_modifier` storage.
---@field description string Translation key of the description sentence.
---@field chance number Roll chance, per mille.

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

---At most one modifier is applied to a lantern.
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
}
