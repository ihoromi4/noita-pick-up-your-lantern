# Lantern Properties and Dynamic States

[← Back to R&D Index](../rnd.md)

Internal progression concept: lanterns differ from each other in properties and alter them depending on environmental conditions affecting the player or the lantern itself. The goal is to give the player a reason to search for a "better" lantern and intentionally interact with liquids in the world.

## Current State

- Each lantern type (see [Vanilla Light Fixture Types](vanilla-lantern-types.md)) has its own base light radius, color, fog of war hole size, and durability defined in its XML.
- On top of this base, quality tiers, modifiers, and the global `illumination_scale` setting are applied (see [Lantern Progression](lantern-progression.md)).

| File | `radius` | Fog Hole | `r`, `g`, `b` | `hp` |
| --- | --- | --- | --- | --- |
| `physics_lantern.xml` (large) | 280 | 1.2 | 255, 225, 180 | 0.5 |
| `physics_lantern_small.xml` | 220 | 0.9 | 255, 205, 150 | 0.15 |
| `physics/lantern_small.xml` | 220 | 0.9 | 255, 205, 150 | 0.15 |

## Declaring Parameters in XML

### Implemented Approach: Native Component Attributes

Type parameters are declared using standard component fields in `pick_up_your_lantern/data/entities/props/`, so lantern properties are immediately visible when inspecting the XML:

- `LightComponent` — `radius`, `r`, `g`, `b`.
- `SpriteComponent` with `fog_of_war_hole="1"` — `special_scale_x` / `special_scale_y`. The component is declared directly in the lantern XML; `patch_lighting.lua` does not add it, only removes it if `Illuminate the darkness` is disabled.
- `DamageModelComponent` — `hp`.

The mod modifies `radius` and `special_scale_x/y` directly on the entity (setting × tier × modifier), and these altered values persist into saves. Therefore, XML values serve only as the baseline: `EnsureLanternBaseIllumination` in `lantern_illumination.lua` reads them once upon the lantern's initial spawn and stores them in `VariableStorageComponent` (`lantern_base_light_radius`, `lantern_base_fog_hole_scale`). The belt lantern copies the light color of the lantern held by the player.

### Alternative: Custom XML Tag

For parameters without native fields (modifier chances, burn duration, liquid effect intensity), everything could be grouped into a single custom tag, for example:

```xml
<LanternProperties light_radius="280" fog_hole_scale="1.2" burn_time="300" />
```

- During initialization, `init.lua` reads the tag from the lantern XML via `nxml`, removes it, and adds a `VariableStorageComponent` for each parameter instead. The engine never sees the custom tag.
- Advantages: all parameters in one place, ability to add parameters that do not exist in vanilla components.
- Drawbacks: XML in-game differs from the file on disk; the file is invalid without the mod.
- **[Needs verification]** How the engine reacts to unknown tags in an entity (a warning in the log or a fatal load failure) determines how critical it is for the patch to always succeed.
- Another compromise: a single `VariableStorageComponent` with `value_string="light_radius=280;fog_hole_scale=1.2"` parsed at runtime: valid for the engine, but less readable.

## Varied Lantern Properties

### Parameters That Can Vary

- Light radius (`LightComponent.radius`).
- Fog of war hole size (`special_scale_x` / `special_scale_y` in `SpriteComponent` with `fog_of_war_hole`).
- Light color and brightness (`r`, `g`, `b`, `fade_out_time`) — for example, cool white light for "masterwork" lanterns.
- Casing durability (`DamageModelComponent.hp`) and explosion radius upon shattering (`explosion_radius`).
- **[Needs verification]** Oil volume released upon shattering.

### Implementation Options

- **Difference between types.** The large lantern (`physics_lantern.xml`) shines brighter than smaller ones. The simplest approach without RNG — strictly XML edits.
- **Quality tiers.** When a lantern spawns in the world, an initialization script determines its tier (e.g., "Dim", "Common", "Bright", "Masterwork") and applies a multiplier to parameters. The tier is stored in `VariableStorageComponent` to persist through world → inventory → hand transitions.
- **Depth dependency.** Higher tier chances increase with biome depth (`y` coordinate or biome name from `BiomeMapGetName`). This constitutes progression: the deeper you go, the better lanterns you find.
- **Special lanterns.** Rare unique specimens in the Holy Mountain or secret locations (see also "magical and hermetic lanterns" from version 1.0 in the [roadmap](../roadmap.md)).

### Player Presentation

- Tier and modifier are described by atmospheric sentences in the item description (`ItemComponent.ui_description`), while the item name remains vanilla. Details: [Lantern Progression](lantern-progression.md#item-description).
- Flame sprite tint or a dedicated inventory icon for higher tiers.

## Implementation

Quality tiers and modifiers are implemented and detailed in a separate note: [Lantern Progression: Quality Tiers and Modifiers](lantern-progression.md).

## Environmental Dynamic States

### Implemented States: Oil and Water

| State | Liquids (Materials) | Light and Fog Hole Multiplier |
| --- | --- | --- |
| Oil-soaked | `oil` | ×1.3 |
| Wet | `water`, `water_salt`, `water_ice`, `water_fading`, `swamp` | ×0.8 |

- Only a held lantern receives a state: the player completely submerges in liquid while holding the lantern in hand.
- States are mutually exclusive: a state persists until the player submerges with the lantern into the opposite liquid.
- An extinguished lantern does not receive a state, and state sentences are omitted from its description.
- State is stored directly on the lantern in `VariableStorageComponent` (`lantern_liquid_state`), persisting through inventory, belt, world dropping, and saving. It does not depend on vanilla stains on the player.
- States do not depend on the `Lantern progression` setting.

### Submersion Detection

- `files/scripts/lantern_liquid_state.lua`, `UpdateLanternLiquidState` is called from `OnWorldPostUpdate` and checks once every 10 frames.
- Held lantern — `Inventory2Component.mActiveItem` of the player with the `lantern` tag (`FindPlayer`, `GetHeldItem` in `utils.lua`).
- Submersion — `DamageModelComponent.mAirAreWeInWater` of the player (same check used for drowning), liquid material — `CellFactory_GetName(mLiquidMaterialWeAreIn)`.
- **[Needs verification]** Whether `mAirAreWeInWater` and `mLiquidMaterialWeAreIn` reliably update for the player; fallback option is sampling material at the player's head position.

### Applying Changes

- Liquid states (materials, multipliers, description keys) are configured in `LANTERN_LIQUID_STATES` in `lantern_properties_config.lua`.
- The state multiplier is factored into the smoothly interpolated illumination scale (`lantern_illumination_scale` = setting × state), so changing state transitions light and fog hole smoothly, identical to tweaking the `Illuminated area size` setting.
- Tier and state combine multiplicatively, so the "oil-soaked" state on a "masterwork" lantern is noticeably stronger than on a "dim" one. Modifiers (flickering, fading) apply on top.
- The belt lantern multiplies its light by the state of the lantern currently held by the player.
- The active state is described by a separate atmospheric sentence in the item description (`item_description_lantern_oil_soaked`, `item_description_lantern_wet`): added by `GetLanternPropertyDescriptions` (`lantern_traits.lua`), while `UpdateLanternDescription` updates the description immediately upon state change.

### Other Possible Interactions

- **Fire / player burning** — short-term "overcharge" with maximum brightness.
- **Water as extinguishing** — eventually, submersion extinguishes the lantern (see "Extinguishing and Submersion" in version 1.0).

## Open Questions

- How should tiers interact with the global `illumination_scale` setting — as a multiplier on top, or as a distinct "Lantern progression" toggle?
- Should the "oil-soaked" state increase risk: for example, causing a larger explosion if an oil-soaked lantern shatters?
