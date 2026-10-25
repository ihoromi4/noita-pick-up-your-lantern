# Lantern Properties and Progression

How each lantern gets its light: the base values of its type, the quality tier, the modifiers and the liquid state.

## Contents

- [Terminology](#terminology)
- [Light Formula](#light-formula)
- [Base Properties per Type](#base-properties-per-type)
- [Quality Tiers](#quality-tiers)
- [Modifiers](#modifiers)
- [Liquid States](#liquid-states)
- [Item Description](#item-description)
- [Stored State](#stored-state)
- [Files](#files)

## Terminology

| Term | Meaning | When it is set | Code |
| --- | --- | --- | --- |
| Trait | Umbrella term for everything rolled once when a lantern first appears: the quality tier and the modifiers. Rolled traits do not change afterwards. | On spawn, by `RollLanternTraits` | `EnsureLanternTraits`, `RollLanternTraits` |
| Tier | Trait every lantern gets while progression is on. Only a light multiplier, no own behaviour. | On spawn | `LANTERN_TIERS`, `GetLanternTier` |
| Modifier | Rare trait with its own per-frame behaviour (Flickering, Short-lived, Cracked). Most lanterns have none; a lantern may carry several. | On spawn; Cracked when damaged | `LANTERN_MODIFIERS`, `lantern_modifier.lua` |
| Liquid state | Not a trait: taken on later in hand and replaced by another dive. | While held | `LANTERN_LIQUID_STATES`, `lantern_liquid_state.lua` |
| Extinguished | Not a modifier: the final state of a burnt-out Short-lived lantern. | When fuel runs out | `ExtinguishLantern` |

All tiers, modifiers and states are configured in one file, `lantern_properties_config.lua`, in that order. Base values of each lantern type stay in its XML file, see [Base Properties per Type](#base-properties-per-type).

`lantern_traits.lua` holds more than traits: it also covers liquid states, the item description and burn-out.

## Light Formula

```text
light radius   = type base radius   × tier × liquid state × Illuminated area size × modifier
fog hole scale = type base hole     × tier × liquid state × Illuminated area size
```

- The setting and the liquid state are combined into one smoothly changing illumination scale (`lantern_illumination_scale`), so their changes fade in instead of jumping. The tier multiplies that scale. Right after the tier is rolled, the scale snaps to the new value instead of easing from the old radius.
- The modifier factor (flicker or burn-out fade) is applied on top, every frame.
- The belt lantern multiplies the same values by `Belt lantern light`. See [Belt Lantern](holding-and-belt.md#belt-lantern).

## Base Properties per Type

Each lantern type declares its base values in the native component fields of its XML file in `pick_up_your_lantern/data/entities/props/`:

| File | `radius` | Fog of war hole | `r`, `g`, `b` | `hp` |
| --- | --- | --- | --- | --- |
| `physics_lantern.xml` (large) | 280 | 1.2 | 255, 225, 180 | 0.5 |
| `physics_lantern_small.xml` | 220 | 0.9 | 255, 205, 150 | 0.15 |
| `physics/lantern_small.xml` | 220 | 0.9 | 255, 205, 150 | 0.15 |

- `LightComponent`: `radius`, `r`, `g`, `b`.
- `SpriteComponent` with `fog_of_war_hole="1"`: `special_scale_x`, `special_scale_y`. The component is declared in the lantern XML. `patch_lighting.lua` only removes it when `Illuminate the darkness` is off.
- `DamageModelComponent`: `hp`.

The mod writes the scaled `radius` and `special_scale_x/y` back to the entity, and these values end up in save files. So the XML values are only a base: `EnsureLanternBaseIllumination` in `lantern_illumination.lua` reads them once, when the lantern first appears, and stores them as `lantern_base_light_radius` and `lantern_base_fog_hole_scale`.

## Quality Tiers

Every lantern gets a tier when it first appears.

- The tier is rolled during the periodic `UpdateLanternIllumination` scan (every 30 frames).
- The random seed is the lantern position (`SetRandomSeed(x, y)`). For a lantern already in an inventory, the owner's position is used.

| Tier | Light and fog hole multiplier | Description key |
| --- | --- | --- |
| 1 | ×0.75 | `item_description_lantern_tier_1` |
| 2 | ×1.0 | `item_description_lantern_tier_2` |
| 3 | ×1.5 | `item_description_lantern_tier_3` |
| 4 | ×2.0 | `item_description_lantern_tier_4` |

Tier weights (1 / 2 / 3 / 4) depend on the depth `y`. Bands end at the Holy Mountains:

| Depth | Weights |
| --- | --- |
| Mines (< 1300) | 50 / 45 / 5 / 0 |
| Coal Pits (< 2850) | 35 / 50 / 14 / 1 |
| Snowy Depths (< 4900) | 20 / 50 / 25 / 5 |
| Hiisi Base (< 6400) | 10 / 45 / 35 / 10 |
| Underground Jungle (< 8450) | 5 / 35 / 42 / 18 |
| The Vault (< 10500) | 0 / 25 / 50 / 25 |
| Deeper | 0 / 15 / 50 / 35 |

`Lantern progression` (Gameplay category, off by default, `MOD_SETTING_SCOPE_NEW_GAME`) turns rolling off in new games. It is off in the default Light Touch preset and on in all other presets. A lantern without a tier has a multiplier of 1.0 and no modifier.

## Modifiers

Modifiers are rolled independently of the tier and of each other: Flickering and Short-lived have a 7% chance each (`chance`, per mille). Cracked has `chance = 0`: it is never rolled and is acquired from damage instead. A lantern may carry several modifiers.

All modifier configuration (IDs, description keys, roll chances per mille, interactions and behaviour parameters) lives in the `LANTERN_MODIFIERS` table in `lantern_properties_config.lua`. Modifiers are rolled in table order, so reordering them changes which modifiers a lantern at a given position gets. The table order is also the order of the description sentences. The field names are given in parentheses below.

How modifiers interact is set per modifier:

- `incompatible`: IDs of modifiers it cannot be combined with. The check runs in both directions: a modifier is not added if either side lists the other.
- `replaces`: IDs of modifiers removed from the lantern when it is added.
- Modifiers without these fields combine, and their light factors multiply. Flickering, Short-lived and Cracked all combine.

The rules apply both to rolling (`RollModifiers`) and to modifiers acquired later (`AddLanternModifier`).

- **Flickering**: the light radius is 20% larger (`radius_bonus`) but wavers: a sum of sine waves with rare deep dips, down to −45% (`flicker_depth`).
- **Short-lived**: burns for 3–8 minutes (`burn_frames_min`, `burn_frames_max`). Time counts only while the lantern is lit in the world, in hand or on the belt.
  - Every 5 seconds of burning (`oil_drip_interval_frames`), one drop of oil leaks out (`GameCreateParticle("oil", ...)`, without fire). On the belt, the drop falls at the player position.
  - The light radius drops linearly from 100% to 20% (`fade_low_factor`) until the last 30 seconds (`fade_end_frames`). Over those 30 seconds it sputters down to zero (`sputter_depth`), and the lantern goes out for good:
    - `LightComponent` and the fog of war hole are removed;
    - the world flame switches to the empty vanilla `out` animation;
    - the in-hand sprite switches to `*_in_hand_out.xml`.
- **Cracked**: a lantern that takes damage without breaking (a hard fall or throw, a weak projectile hit) cracks with a 33% chance (`crack_chance`).
  - Detected by `damage_received` in `lantern_damage.lua` (`script_damage_received` in the lantern XMLs). Damage is dealt by `PhysicsBodyCollisionDamageComponent` on impacts and by projectiles; `falling_damages` stays off.
  - Lanterns do not crack while `Lantern progression` is off, once burnt out, or when already cracked.
  - Every 20 frames (`fire_interval_frames`), a lit cracked lantern has a 50% chance (`fire_chance`) to leak two particles (`fire_particle_count`) of gaseous fire (`GameCreateParticle("fire", ...)`) in the world or in hand, so it can set the player on fire.

Modifier behavior runs in `lantern_modifier.lua` through a `LuaComponent` tagged `enabled_in_world,enabled_in_hand`. It is added only to a lit lantern with modifiers, on spawn or when a modifier is acquired. Otherwise it would keep running in the inventory until the next state change.

## Liquid States

| State | Liquid materials | Light and fog hole multiplier |
| --- | --- | --- |
| Oil-soaked | `oil` | ×1.3 |
| Wet | `water`, `water_salt`, `water_ice`, `water_fading`, `swamp` | ×0.8 |

- Only the held lantern takes on a state, when the player is fully submerged with it.
- The states exclude each other: a state lasts until the player dives with the lantern into the opposite liquid.
- A burnt-out lantern takes no state, and its description shows no state sentence.
- The state is stored on the lantern (`lantern_liquid_state`), so it survives the inventory, the belt, throws and saves. It does not depend on vanilla stains on the player.
- The states work regardless of `Lantern progression`.

Detection is in `UpdateLanternLiquidState` (`lantern_liquid_state.lua`), called from `OnWorldPostUpdate` every 10 frames:

- the held lantern is the player's `Inventory2Component.mActiveItem` with the `lantern` tag (`FindPlayer`, `GetHeldItem` in `utils.lua`);
- submersion is `DamageModelComponent.mAirAreWeInWater`, the same check the game uses for drowning;
- the liquid is `CellFactory_GetName(mLiquidMaterialWeAreIn)`.

## Item Description

The lantern name never changes; it stays the translation key from the XML. Properties are described by atmospheric sentences in `ItemComponent.ui_description`: the base description first, then one sentence per property on a new line.

| Property | Translation key |
| --- | --- |
| Tier 1–4 | `item_description_lantern_tier_1` … `_tier_4` |
| Flickering | `item_description_lantern_flickering` |
| Short-lived | `item_description_lantern_short_lived` |
| Cracked | `item_description_lantern_cracked` |
| Burnt out | `item_description_lantern_extinguished` |
| Oil-soaked | `item_description_lantern_oil_soaked` |
| Wet | `item_description_lantern_wet` |

- The burnt-out sentence replaces all modifier sentences.
- `GetLanternPropertyDescriptions` in `lantern_traits.lua` collects the sentence keys for the current lantern state. New states add their keys there.
- `UpdateLanternDescription` runs on every scan (`EnsureLanternTraits`), on burn-out and on liquid state changes. It writes the field only when the text changes, so the description follows both the lantern state and the game language.
- The original description key is kept in `lantern_base_description`, because the field itself is overwritten.

## Stored State

All per-lantern state lives in `VariableStorageComponent` tagged for the world, hand and inventory:

| Name | Meaning |
| --- | --- |
| `lantern_tier` | Quality tier, 1–4. |
| `lantern_modifiers` | Bitmask of modifiers: bit `2^(id - 1)` per modifier, `1` Flickering, `2` Short-lived, `4` Cracked. |
| `lantern_burn_frames`, `lantern_burn_frames_total` | Remaining and total burn time of a Short-lived lantern. |
| `lantern_extinguished` | The lantern has burnt out. |
| `lantern_liquid_state` | `0` none, `1` Oil-soaked, `2` Wet. |
| `lantern_base_description` | Original description key. |
| `lantern_base_light_radius`, `lantern_base_fog_hole_scale` | Base light of the lantern type. |
| `lantern_illumination_scale` | Currently applied illumination scale. |

## Files

- `files/scripts/lantern_traits.lua`: tiers, modifiers, liquid states, rolling, fuel, descriptions, burn-out.
- `files/scripts/lantern_properties_config.lua`: configuration of all tiers, modifiers and states.
- `files/scripts/lantern_modifier.lua`: per-frame modifier behavior.
- `files/scripts/lantern_damage.lua`: cracking on damage.
- `files/scripts/lantern_illumination.lua`: base values and applying the illumination scale.
- `files/scripts/lantern_liquid_state.lua`: liquid state detection.
- `files/props_gfx/lantern_in_hand_out.xml`, `lantern_small_in_hand_out.xml`: burnt-out in-hand sprites.
