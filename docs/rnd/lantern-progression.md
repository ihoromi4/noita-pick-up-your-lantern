# Lantern Progression: Quality Tiers and Modifiers

[← Back to R&D Index](../rnd.md)

Internal gameplay progression: each lantern spawned in the world receives a quality tier and occasionally a modifier. The deeper the player descends, the better lanterns they find, providing a reason to search for and compare lanterns rather than just taking the first one encountered.

General context for differences between lanterns and environmental dynamic states is covered in [Lantern Properties and Dynamic States](lantern-properties-and-states.md).

## Current Implementation

The first iteration is implemented and tested in-game (commit `a25be6b`).

### Terminology

- **Trait** — umbrella term for everything a lantern rolls once on its first appearance: the quality tier and the modifier (`RollLanternTraits`, `EnsureLanternTraits`). Traits do not change afterwards.
- **Tier** — a trait every lantern gets while progression is on; only a light multiplier, without its own behaviour.
- **Modifier** — a rare trait with its own per-frame behaviour (Flickering, Short-lived); configured in `LANTERN_MODIFIERS`, executed by `lantern_modifier.lua`.
- Not traits: the liquid state (taken on later in hand, see [Environmental Dynamic States](lantern-properties-and-states.md#environmental-dynamic-states)) and the extinguished state (the end of a Short-lived lantern, not a separate modifier).
- `lantern_traits.lua` is broader than its name: it also holds liquid states, the description and extinguishing.

### Files

- `files/scripts/lantern_modifier_config.lua` — configuration of all modifiers: IDs, description keys, roll chances and behaviour parameters.
- `files/scripts/lantern_traits.lua` — tier definitions, tier and modifier roll, oil consumption, description, extinguishing.
- `files/scripts/lantern_modifier.lua` — modifier behaviors (flickering, burn timer).
- `files/scripts/lantern_illumination.lua` — applying the tier multiplier to light and fog of war hole.
- `files/props_gfx/lantern_in_hand_out.xml`, `lantern_small_in_hand_out.xml` — sprites for an extinguished lantern in hand.

### Tier and Modifier Roll

- A lantern without a tier receives one during the periodic `UpdateLanternIllumination` scan (once every 30 frames).
- Seed — lantern position (`SetRandomSeed(x, y)`); for a lantern in inventory — owner's position.
- Tier, modifier, and state are stored in `VariableStorageComponent`: `lantern_tier`, `lantern_modifier`, `lantern_burn_frames`, `lantern_burn_frames_total`, `lantern_extinguished`, `lantern_base_description`. Dynamic liquid state is stored in `lantern_liquid_state` (see [Environmental Dynamic States](lantern-properties-and-states.md#environmental-dynamic-states)).
- After rolling, the cached illumination scale is reset so the new radius applies immediately without a smooth transition.

### Tiers

| Tier | Light and Fog Hole Multiplier |
|------|-------------------------------|
| 1    | ×0.75                         |
| 2    | ×1.0                          |
| 3    | ×1.5                          |
| 4    | ×2.0                          |

Weights for tiers 1 / 2 / 3 / 4 depending on depth `y` (boundaries correspond to Holy Mountains):

| Depth                 | Weights           |
|-----------------------|-------------------|
| Mines (< 1300)        | 50 / 45 / 5 / 0   |
| Coal Pits (< 2850)    | 35 / 50 / 14 / 1  |
| Snowy Depths (< 4900) | 20 / 50 / 25 / 5  |
| Hiisi Base (< 6400)   | 10 / 45 / 35 / 10 |
| Jungle (< 8450)       | 5 / 35 / 42 / 18  |
| Vault (< 10500)       | 0 / 25 / 50 / 25  |
| Deeper                | 0 / 15 / 50 / 35  |

Final light radius: `base type radius × tier multiplier × illumination_scale`, where base radius is defined in the lantern XML (see [Declaring Parameters in XML](lantern-properties-and-states.md#declaring-parameters-in-xml)). The fog of war hole scales similarly from its base `special_scale_x`.

### Modifiers

At most one per lantern, 7% chance each.

All modifiers are configured in the `LANTERN_MODIFIERS` table in `lantern_modifier_config.lua`: ID, description key, roll chance (per mille) and behaviour parameters (field names in parentheses below). The table is an array: modifiers are rolled in its order, so the order is part of the configuration. `GetLanternModifierDefinition(modifier_id)` in `lantern_traits.lua` returns the configuration of a modifier.

- **Flickering.** Light radius is 20% larger (`radius_bonus`), but fluctuates (sum of sine waves with occasional deep drops) down to −45% (`flicker_depth`).
- **Short-lived.** Burns for 3–8 minutes (`burn_frames_min`, `burn_frames_max`); time only ticks down while the lantern emits light in the world, in hand, or on the belt. Total burn time is stored in `lantern_burn_frames_total`.
  - Every 5 seconds of burning (`oil_drip_interval_frames`), the lantern drips 1 droplet of oil (`GameCreateParticle("oil", ...)`, without fire); on the belt — at the player's position.
  - Light radius decreases linearly from 100% to 20% (`fade_low_factor`) until the last 30 seconds (`fade_end_frames`), and during those 30 seconds — from 20% to zero with flickering (`sputter_depth`), after which the lantern extinguishes permanently:
  - `LightComponent` and the fog hole are removed;
  - in-world flame switches to the empty vanilla `out` animation;
  - in-hand sprite is replaced with `*_in_hand_out.xml` (body without flame).

Modifier behavior is handled by a `LuaComponent` with tags `enabled_in_world,enabled_in_hand`, which is added only to lit lanterns (otherwise it would run in the inventory until the next state change).

### Item Description

The lantern name remains unchanged and uses the vanilla translation key from XML. Tier, modifier, and dynamic liquid state are described by atmospheric sentences in `ItemComponent.ui_description`: base lantern description, followed by one sentence per property on a new line.

| Property     | Translation Key                               |
|--------------|-----------------------------------------------|
| Tier 1–4     | `item_description_lantern_tier_1` … `_tier_4` |
| Flickering   | `item_description_lantern_flickering`         |
| Short-lived  | `item_description_lantern_short_lived`        |
| Extinguished | `item_description_lantern_extinguished`       |
| Oil-soaked   | `item_description_lantern_oil_soaked`         |
| Wet          | `item_description_lantern_wet`                |

- The extinguished sentence replaces the short-lived sentence; an extinguished lantern does not show liquid state sentences.
- `GetLanternPropertyDescriptions` collects sentence keys based on the lantern's current state; new states append their keys there.
- `UpdateLanternDescription` is called during each scan (`EnsureLanternTraits`) and upon extinguishing; it only writes to the field when the text changes. Thus, the description tracks the lantern's state and the game language.
- The original description key from XML is saved in `lantern_base_description`, since the field itself is overwritten.

### Save Compatibility

Compatibility with saves from older mod versions is not maintained: a new game is assumed after updating the mod. Storage keys, modifier IDs and their order may change between versions without migration.

### Settings

`Lantern progression` in the Gameplay category, enabled by default, `MOD_SETTING_SCOPE_NEW_GAME`. Disabling stops rolling in new games; lanterns without a tier have a 1.0 multiplier and no modifiers.

### Needs Verification

- **[Needs verification]** Does the lantern description update in inventory after `ui_description` is modified.
- **[Needs verification]** Does writing to a disabled `ItemComponent` enable it for a lantern in inventory.
- **[Needs verification]** Does the engine properly disable a runtime-added `LuaComponent` when the lantern is moved into inventory.
- Balance of weights and modifier chances — needs a longer playthrough.

## Future Ideas

### Visuals

- Visual distinction of tiers: flame tint or light color (`r`, `g`, `b` in `LightComponent`), custom icon in inventory.

### New Tier Properties

- Durability of the casing (`DamageModelComponent.hp`) and shattering threshold.
- Explosion strength and oil amount upon shattering.
- Light color and temperature (cool white for high tiers).

### New Modifiers

- Positive modifiers for balance (e.g. "Sturdy" — does not shatter from falling, "Pure Flame" — wider fog of war hole).
- Risk/reward modifiers: "Unstable" — stronger explosion when shattered.
- Reigniting a short-lived lantern with fire or by submerging in oil (synergy with [dynamic states](lantern-properties-and-states.md#environmental-dynamic-states)).

### Lantern Sources

- Special guaranteed high-tier lanterns in the Holy Mountain or secret locations.
- Lanterns in Holy Mountain shops with tier-dependent prices.

## Open Questions

- Should the tier only affect light, or also other properties (durability, explosion)?
- Should multiple modifiers be allowed on a single lantern (the description system already supports multiple sentences)?
- The planned Cracked glass modifier is acquired from damage, not on spawn. A modifier then stops meaning "rolled on spawn", and the trait/modifier terminology (and possibly the name of `lantern_traits.lua`) needs to be revisited.
- Is a modifier frequency setting needed, or an option to disable modifiers independently without disabling tiers?
