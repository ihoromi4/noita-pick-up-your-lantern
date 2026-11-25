# Creatures and Light

How enemies react to lantern light: lanterns lure some enemies, Natural Fear scares the others, and the mod exports a visibility API for other mods. For the player's view, see [Lanterns](../guides/lanterns.md#luring-fire-creatures). The bright glow of fire enemies is described in [Vision and Lighting](vision-and-lighting.md#fire-enemy-glow).

## Contents

- [Overview](#overview)
- [Settings](#settings)
- [Light Sources](#light-sources)
- [Visibility API](#visibility-api)
- [Luring Enemies to Lanterns](#luring-enemies-to-lanterns)
  - [Lured Enemies and Lure Lanterns](#lured-enemies-and-lure-lanterns)
  - [Home and Leash](#home-and-leash)
  - [Trance](#trance)
  - [Release](#release)
- [Natural Fear](#natural-fear)
  - [Fearful Enemies and Fear Lights](#fearful-enemies-and-fear-lights)
  - [Scorch](#scorch)
  - [Rage](#rage)
- [Files](#files)

## Overview

Both creature reaction mechanics run from `OnWorldPreUpdate` in `init.lua`:

| Function | Module | Interval | Setting |
| --- | --- | --- | --- |
| `UpdateLanternAttraction` | `lantern_attraction.lua` | 20 frames | `Lanterns attract fire enemies`, `Natural Fear` |
| `UpdateLanternFear` | `lantern_fear.lua` | 30 frames, 5 frames after the attraction | `Natural Fear` |

Each mechanic handles only root entities. A child entity with the `enemy` tag is a part of another entity, so it is skipped.

## Settings

All options of these mechanics are marked `preset_excluded = true` in `settings.lua`. `GetPresetSettings()` skips such options, so `ApplyPreset` does not reset them and `SyncPreset` does not compare them. Without the flag, picking a preset would turn the mechanics off, and turning one on would switch the preset to `Custom`.

- `fire_enemy_attraction` and `natural_fear` are in the `Gameplay` category.
- Both use the runtime scope and are read on every update, so a change applies immediately.

## Light Sources

A light that counts for these mechanics is marked with the `pul_light_source` tag twice:

- on the entity, so one `EntityGetWithTag` query finds every source;
- on its `LightComponent`, so the right light is read when an entity has several.

Lanterns declare both tags in their own XML files. `EntityGetFirstComponent` returns only enabled components, so a lantern in the inventory has no light to read. An extinguished lantern has no `LightComponent` at all. The belt lantern is a separate entity with the `pul_belt` tag and without `pul_light_source`.

The Light spell modifier (`LIGHT`) adds `data/entities/misc/light.xml` to a projectile through `extra_entities`. The engine merges an extra entity into the projectile, so a tag on the root of `light.xml` may not reach it. At startup, `PatchLightSources()` in `patch_light_sources.lua` tags the root and the `LightComponent` of `light.xml`. It also adds a `LuaComponent` with `light_source_tag.lua`, which tags the entity the components end up on and then removes itself. To add another light source, put its path into `LIGHT_SOURCE_PATHS`.

The radius of a source is the current `radius` of its tagged `LightComponent`. For a lantern, this radius already includes `Illuminated area size`, the quality tier, the liquid state and the modifiers. `LightComponent.radius` is the outer edge of a soft light, and the visibly lit area is smaller. So the visibility API and creature reactions take only a share of it, as described below.

## Visibility API

`files/scripts/visibility_api.lua` exports a module table for other mods (such as **In Game Wiki**) to check whether a point or an entity is illuminated by a light source:

- `IsPointVisible(x, y)` returns `true` when `(x, y)` lies within `LIT_RADIUS_FACTOR` (0.35) of the radius of any enabled `pul_light_source` light or an active belt lantern (`pul_belt`, which uses its own reduced `belt_light_scale` radius).
- `IsEntityVisible(entity_id)` resolves the entity's hitbox centre (falling back to its transform) and calls `IsPointVisible`.
- Lit areas are cached per frame (`GameGetFrameNum`), so multiple queries in the same frame scan light sources once.

## Luring Enemies to Lanterns

Lit lanterns in the world lure some enemies: the enemies gather around a lantern and do not attack it. Research and in-game findings are in [Fire Enemies](../rnd/creatures/fire-enemies.md#attraction-to-lanterns).

The engine has no call that sends an AI to a point. So the attraction moves the home of the AI (`AnimalAIComponent.mHomePosition`) to the lantern and sets a leash (`max_distance_to_move_from_home`). The AI then walks or flies there with its own path finding.

### Lured Enemies and Lure Lanterns

`UpdateLanternAttraction()` runs every 20 frames.

- An enemy is lured when `Lanterns attract fire enemies` is on and it has the `pul_fire_enemy` tag. The fire enemy glow adds this tag, see [Fire Enemy Glow](vision-and-lighting.md#fire-enemy-glow).
- An enemy is also lured when `Natural Fear` is on and `IsNaturalFearLured` in `enemy_ai_home.lua` accepts it. It accepts non-robot enemies whose herd is `orcs` (Hiisi), `healer` (support Hiisi and cowards), or `fly` (insects).
- Robots (`IsRobot` in `enemy_ai_home.lua`: entities with the `robot` tag or `robot` herd, such as Hiisi tanks, turrets, healer drones, and monks) are not lured by `Natural Fear`.
- Bosses, charmed enemies and a polymorphed player are never lured (`EXCLUDED_TAGS` in `enemy_ai_home.lua`).
- A lure lantern is an entity with the `lantern` tag that is its own root entity and has an enabled light with the `pul_light_source` tag. So a lantern in hand, in the inventory or on the belt does not lure. Vanilla hanging lanterns lure too.
- The attraction radius is 1.5 times the current light radius (`ATTRACTION_RADIUS_FACTOR`).
- A free enemy takes the nearest lantern it sees. The ray from the enemy stops 10 px before the lantern (`SIGHT_MARGIN`), because the lantern body is made of solid cells.
- An attracted enemy keeps its lantern while it stays within the radius, even if a ledge hides the lantern for a moment.
- A walking enemy is lured only while the floor below the lantern is within 24 px of its feet (`WALKING_LEVEL_TOLERANCE`). A walker sent to another level stands still in the `GoNearHome` state.
- Enemies come and go at random (a Markov process). On each update, a free enemy that sees a lantern takes it with a 10% chance (`LURE_ENTER_CHANCE`). An attracted enemy leaves it with a 3% chance (`LURE_LEAVE_CHANCE`).

### Home and Leash

The home is set on every update, because a thrown lantern keeps moving.

- A flying enemy (`can_fly` is 1) gets its home at the lantern and a leash of 40 px (`LEASH_DISTANCE`).
- A walking enemy gets its home on the floor below the lantern: up to 200 px down, 4 px above the floor. The leash is never shorter than the current distance from home plus 16 px (`WALKING_LEASH_MARGIN`). It only shrinks as the enemy comes closer, down to 40 px. A home outside the leash freezes a walker.
- An attracted enemy gets a path finding depth of 200 nodes (`pathfinding_max_depth_no_target`, 50 by default). With 50 nodes, walkers found no path to a distant home.

### Trance

An attracted enemy gets `creature_detection_range_x` and `creature_detection_range_y` of 48 px (`TRANCE_DETECTION_RANGE`), so it notices the player only up close.

An enemy that has living prey (`mGreatestPrey`) is not lured. So an enemy that already fights the player takes no lantern. An attracted enemy that finds prey is released on the next update and gets its detection range back. This happens when the player comes within 48 px or hits the enemy.

### Release

On the first attraction, the original AI values are saved in a `VariableStorageComponent` named `pul_original_ai`:

- the leash in `value_float`;
- `"home_x,home_y,range_x,range_y,depth"` in `value_string`;
- the entity ID of the lantern in `value_int`.

The enemy also gets the `pul_lantern_attracted` tag. When the enemy leaves by chance, finds prey, loses its lantern or is charmed, or when its option is turned off, the original values are restored and the storage is removed. The helpers for the original values, the home and the lured groups are in `enemy_ai_home.lua`, which the fear module shares.

## Natural Fear

With `Natural Fear` on, enemies that lanterns never lure fear lantern light. Research, the AI state table and the rejected options are in [Natural Fear](../rnd/creatures/natural-fear.md).

Setting an AI state from Lua does not start its path finding: such an enemy stands still. So the mod deals a tiny fire damage instead. The AI reacts to it as to burning, and runs with its own path finding.

### Fearful Enemies and Fear Lights

`UpdateLanternFear()` runs every 30 frames, 5 frames after the attraction updates (`UPDATE_FRAME_OFFSET`).

- A fearful enemy is a root entity with the `enemy` tag that the fire enemy glow has already checked (`pul_fire_glow_checked`). It has no `pul_fire_enemy` tag, and `IsNaturalFearLured`, `IsRobot`, `IsFireImmune`, and `IsExcluded` in `enemy_ai_home.lua` all return `false` for it. The glow check is needed, because otherwise a fire enemy far from the camera would be scared before the glow scan tags it.
- Fire-immune enemies (`damage_multipliers.fire <= 0`, missing `DamageModelComponent`, or `PROTECTION_FIRE` / `PROTECTION_ALL` effects), robots (`robot` tag or `robot` herd), bosses, charmed enemies and a polymorphed player are skipped. Enemies without an `AnimalAIComponent` are left alone.
- A fear light is an entity with the `lantern` tag and an enabled light with the `pul_light_source` tag. It is either its own root entity (in the world) or the held item of its root entity (in hand). A lantern in the inventory or on the belt does not scare.
- The fear radius is 0.36 of the light radius: the lit share `LIT_RADIUS_FACTOR` (0.6) times `FEAR_RADIUS_SCALE` (0.6).
- An enemy is lit only by a lantern it sees. The ray stops 10 px before the lantern (`SIGHT_MARGIN`), so light does not pass through walls.

### Scorch

On each update, a fearful enemy in a fear light is scorched:

- It takes `LIGHT_BURN_DAMAGE` (0.000001) of fire damage with no responsible entity, no ragdoll and no impulse. The AI switches to the `TakingFireDamage` state and runs, as a burning enemy does. A larger damage added up and killed weak enemies.
- It is pushed away from the light that lights it the most: `FEAR_PUSH_SPEED` (60) is added to `CharacterDataComponent.mVelocity`. Walking enemies are pushed only along X.
- It gets the `pul_lantern_scared` tag and the look of fear: a child entity `lantern_fear_effect.xml` (tag `pul_lantern_fear_effect`) with the particles of the Confusion status, without the Confusion effect. The look is removed once the enemy is out of the light.

Fear beats hunting, because the damage interrupts any job. Robots and fire-immune enemies are filtered out in `IsFearful` before reaching scorch or rage.

### Rage

On each update, an enemy in the light flies into a rage with a 5% chance (`RAGE_ENTER_CHANCE`) instead of being scorched. An enraged enemy calms down with a 10% chance (`RAGE_LEAVE_CHANCE`). On average, the rage starts after 10 seconds in the light and lasts 5 seconds.

- The target is the root entity of the light: the lantern in the world, or the player who holds it. It is kept in the `pul_lantern_rage_target` storage, and the enemy gets the `pul_lantern_enraged` tag.
- On every update, the target is set again as `mGreatestPrey`, because the AI may pick other prey on its own. An enraged enemy is not scorched.
- The rage has the look of the Berserk status: a child entity `lantern_rage_effect.xml` (tag `pul_lantern_rage_effect`) without the Berserk effect, so the enemy does not attack everyone around.
- The rage ends by chance, when the target is gone, when the enemy is charmed, or when the option is turned off. A lantern target stops being the prey. A player target stays, as the enemy would hunt the player anyway.
- Enraged and scared enemies are evaluated outside the light too, so they calm down and lose their look in time.

## Files

| File | Role |
| --- | --- |
| `files/scripts/visibility_api.lua` | Exported visibility API (`IsPointVisible`, `IsEntityVisible`) for other mods |
| `files/scripts/patches/patch_light_sources.lua`, `files/scripts/patches/light_source_tag.lua` | Mark the Light spell modifier as a light source |
| `files/scripts/creatures/lantern_attraction.lua` | Lure lanterns, lured enemies, home, leash and trance |
| `files/scripts/creatures/enemy_ai_home.lua` | Original AI values, home with leash, lured groups and exclusions, shared by the attraction and the fear |
| `files/scripts/creatures/lantern_fear.lua` | Fear lights, fearful enemies, scorch and rage |
| `files/entities/lantern_fear_effect.xml`, `files/entities/lantern_rage_effect.xml` | Looks of fear and rage |
| `files/scripts/creatures/fire_enemy_glow.lua` | Fire enemy glow and the `pul_fire_enemy` and `pul_fire_glow_checked` tags |
