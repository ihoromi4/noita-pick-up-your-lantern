# Creatures and Light

How enemies react to lantern light: the player studies enemies in the light, lanterns lure some enemies, and Natural Fear scares the others. For the player's view, see [Lanterns](../guides/lanterns.md#luring-fire-creatures). The bright glow of fire enemies is described in [Vision and Lighting](vision-and-lighting.md#fire-enemy-glow).

## Contents

- [Overview](#overview)
- [Settings](#settings)
- [Light Sources](#light-sources)
- [Enemy Study](#enemy-study)
  - [Scan](#scan)
  - [Knowledge and Study Time](#knowledge-and-study-time)
  - [Damage Bonus](#damage-bonus)
  - [Study Markers](#study-markers)
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

All three mechanics run from `OnWorldPreUpdate` in `init.lua`:

| Function | Module | Interval | Setting |
| --- | --- | --- | --- |
| `UpdateEnemyStudy` | `enemy_study.lua` | 10 frames | `Enemy study` |
| `UpdateLanternAttraction` | `lantern_attraction.lua` | 20 frames | `Lanterns attract fire enemies`, `Natural Fear` |
| `UpdateLanternFear` | `lantern_fear.lua` | 30 frames, 5 frames after the attraction | `Natural Fear` |

Each mechanic handles only root entities. A child entity with the `enemy` tag is a part of another entity, so it is skipped.

## Settings

All options of these mechanics are marked `preset_excluded = true` in `settings.lua`. `GetPresetSettings()` skips such options, so `ApplyPreset` does not reset them and `SyncPreset` does not compare them. Without the flag, picking a preset would turn the mechanics off, and turning one on would switch the preset to `Custom`.

- `fire_enemy_attraction` and `natural_fear` are in the `Gameplay` category.
- `enemy_study`, `enemy_study_damage_bonus` and `enemy_study_duration` are in their own `Enemy Study` category.
- All of them use the runtime scope and are read on every update, so a change applies immediately.

## Light Sources

A light that counts for these mechanics is marked with the `pul_light_source` tag twice:

- on the entity, so one `EntityGetWithTag` query finds every source;
- on its `LightComponent`, so the right light is read when an entity has several.

Lanterns declare both tags in their own XML files. `EntityGetFirstComponent` returns only enabled components, so a lantern in the inventory has no light to read. An extinguished lantern has no `LightComponent` at all. The belt lantern is a separate entity with the `pul_belt` tag and without `pul_light_source`.

The Light spell modifier (`LIGHT`) adds `data/entities/misc/light.xml` to a projectile through `extra_entities`. The engine merges an extra entity into the projectile, so a tag on the root of `light.xml` may not reach it. At startup, `PatchLightSources()` in `patch_light_sources.lua` tags the root and the `LightComponent` of `light.xml`. It also adds a `LuaComponent` with `light_source_tag.lua`, which tags the entity the components end up on and then removes itself. To add another light source, put its path into `LIGHT_SOURCE_PATHS`.

The radius of a source is the current `radius` of its tagged `LightComponent`. For a lantern, this radius already includes `Illuminated area size`, the quality tier, the liquid state and the modifiers. `LightComponent.radius` is the outer edge of a soft light, and the visibly lit area is smaller. So all three mechanics take only a share of it, as described below.

## Enemy Study

The player's damage against an enemy grows while the enemy is watched in lantern light. Research and the rejected options are in [Enemy Study](../rnd/enemy-study.md).

### Scan

`UpdateEnemyStudy()` runs every 10 frames (`SCAN_INTERVAL_FRAMES`) while `Enemy study` is on.

- Candidates are root entities with the `enemy` or `boss` tag within 400 px of the player (`STUDY_RADIUS`). The Dragon has only the `boss_dragon` tag, so it is listed separately. The target point is the hitbox centre (`EntityGetFirstHitboxCenter`).
- An enemy is lit when its hitbox centre is within `LIT_RADIUS_FACTOR` (0.6) of the radius of a light source. Light sources are collected once per scan. No rays are cast from the light, so a lantern behind a thin wall still lights an enemy.
- An enemy is in sight when `RaytraceSurfaces` from the player's hitbox centre to the enemy hits no solid cells. Liquids and gases do not block the line. The ray is cast only for lit enemies, because the light check is cheaper.
- A fully studied enemy (`pul_study_done` storage) is skipped.

### Knowledge and Study Time

The study progress of an enemy grows from 0 to 1. It is kept in the `pul_study_progress` storage on the enemy and saved with it. The progress never decreases: an enemy out of light or sight only stops gaining it.

The player studies enemy types, not single enemies. Every gain of progress is added to three run globals:

| Level | Global | Key | Weight |
| --- | --- | --- | --- |
| Type | `pul_study_knowledge_<type>` | File path from `EntityGetFilename`, or the entity name as a fallback | 1 |
| Family | `pul_study_family_knowledge_<family>` | File path without variant suffixes such as `_weak` or `_big` (`VARIANT_SUFFIXES`) | 0.5 |
| Herd | `pul_study_herd_knowledge_<herd>` | `herd_id` of `GenomeDataComponent` | 0.2 |

- The effective knowledge is `T + 0.5 × max(0, F − T) + 0.2 × max(0, H − F)`, where `T`, `F` and `H` are the type, family and herd knowledge. Each level excludes the level below it, so the enemy's own type is not counted twice.
- The study time shrinks linearly from the `Base study time` at knowledge 0 to 30 frames (0.5 s) at knowledge 10 (`FULL_TYPE_KNOWLEDGE`). It is computed again on every scan.
- The `player` herd is ignored: charmed enemies say nothing about their kind.
- Bosses always take 7200 frames (120 s). They neither add to nor use any knowledge.
- Run globals are used instead of a storage on the player, because polymorph replaces the player entity. They are saved with the run and reset in a new game.

### Damage Bonus

When the study of an enemy begins, it gets a `LuaComponent` with `enemy_study_damage.lua` in `script_damage_about_to_be_received`. The hook multiplies the damage by `1 + bonus × progress` when the responsible entity is the current player. Wand projectiles report the shooter, so spells and explosions get the bonus. The values returned by the hook replace the incoming damage, so damage numbers show the raised damage.

With `Enemy study` off, the hook returns the damage unchanged. The bonus setting is read at hit time, so a change applies to enemies studied earlier too.

### Study Markers

A studied enemy gets a child entity `study_marker.xml` (tag `pul_study_marker`) above its head:

- It has three dot sprites: yellow (`pul_study_in_progress`), red (`pul_study_paused`) and green (`pul_study_done`). The images are in `files/ui_gfx/`.
- `InheritTransformComponent` with `only_position="1"` keeps the dot upright when the enemy turns.
- The height is the top of the enemy's hitboxes plus a small margin, so it also fits large enemies.
- At the end of each scan, every loaded marker shows one sprite and hides the other two: green for a fully studied enemy, yellow for an enemy studied in this scan, and red for all others. With `Enemy study` off, all markers are hidden.
- The marker is found among the children of the enemy by its tag, so a reload never attaches a second one. It is removed together with the enemy.

## Luring Enemies to Lanterns

Lit lanterns in the world lure some enemies: the enemies gather around a lantern and do not attack it. Research and in-game findings are in [Fire Enemies](../rnd/fire-enemies.md#attraction-to-lanterns).

The engine has no call that sends an AI to a point. So the attraction moves the home of the AI (`AnimalAIComponent.mHomePosition`) to the lantern and sets a leash (`max_distance_to_move_from_home`). The AI then walks or flies there with its own path finding.

### Lured Enemies and Lure Lanterns

`UpdateLanternAttraction()` runs every 20 frames.

- An enemy is lured when `Lanterns attract fire enemies` is on and it has the `pul_fire_enemy` tag. The fire enemy glow adds this tag, see [Fire Enemy Glow](vision-and-lighting.md#fire-enemy-glow).
- An enemy is also lured when `Natural Fear` is on and its herd is `orcs` (Hiisi with their tanks and turrets) or `fly` (insects).
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

With `Natural Fear` on, enemies that lanterns never lure fear lantern light. Research, the AI state table and the rejected options are in [Natural Fear](../rnd/natural-fear.md).

Setting an AI state from Lua does not start its path finding: such an enemy stands still. So the mod deals a tiny fire damage instead. The AI reacts to it as to burning, and runs with its own path finding.

### Fearful Enemies and Fear Lights

`UpdateLanternFear()` runs every 30 frames, 5 frames after the attraction updates (`UPDATE_FRAME_OFFSET`).

- A fearful enemy is a root entity with the `enemy` tag that the fire enemy glow has already checked (`pul_fire_glow_checked`). It has no `pul_fire_enemy` tag, and its herd is neither `orcs` nor `fly`. The glow check is needed, because otherwise a fire enemy far from the camera would be scared before the glow scan tags it.
- Bosses, charmed enemies and a polymorphed player are skipped. Enemies without an `AnimalAIComponent` are left alone.
- A fear light is an entity with the `lantern` tag and an enabled light with the `pul_light_source` tag. It is either its own root entity (in the world) or the held item of its root entity (in hand). A lantern in the inventory or on the belt does not scare.
- The fear radius is 0.36 of the light radius: the lit share `LIT_RADIUS_FACTOR` (0.6) times `FEAR_RADIUS_SCALE` (0.6).
- An enemy is lit only by a lantern it sees. The ray stops 10 px before the lantern (`SIGHT_MARGIN`), so light does not pass through walls.

### Scorch

On each update, a fearful enemy in a fear light is scorched:

- It takes `LIGHT_BURN_DAMAGE` (0.000001) of fire damage with no responsible entity, no ragdoll and no impulse. The AI switches to the `TakingFireDamage` state and runs, as a burning enemy does. A larger damage added up and killed weak enemies.
- It is pushed away from the light that lights it the most: `FEAR_PUSH_SPEED` (60) is added to `CharacterDataComponent.mVelocity`. Walking enemies are pushed only along X.
- It gets the `pul_lantern_scared` tag and the look of fear: a child entity `lantern_fear_effect.xml` (tag `pul_lantern_fear_effect`) with the particles of the Confusion status, without the Confusion effect. The look is removed once the enemy is out of the light.

Enemies immune to fire, such as ghosts and robots, take no damage and do not react. Fear beats hunting, because the damage interrupts any job.

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
| `files/scripts/enemy_study.lua` | Study scan, light and sight checks, progress, knowledge, markers |
| `files/scripts/enemy_study_damage.lua` | Damage hook of a studied enemy |
| `files/entities/study_marker.xml`, `files/ui_gfx/study_dot_*.png` | Study marker entity and its dot images |
| `files/scripts/patch_light_sources.lua`, `files/scripts/light_source_tag.lua` | Mark the Light spell modifier as a light source |
| `files/scripts/lantern_attraction.lua` | Lure lanterns, lured enemies, home, leash and trance |
| `files/scripts/enemy_ai_home.lua` | Original AI values, home with leash, lured groups and exclusions, shared by the attraction and the fear |
| `files/scripts/lantern_fear.lua` | Fear lights, fearful enemies, scorch and rage |
| `files/entities/lantern_fear_effect.xml`, `files/entities/lantern_rage_effect.xml` | Looks of fear and rage |
| `files/scripts/fire_enemy_glow.lua` | Fire enemy glow and the `pul_fire_enemy` and `pul_fire_glow_checked` tags |
