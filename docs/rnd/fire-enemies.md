# Fire Enemies: Glow and Attraction to Lanterns

[← Back to R&D Index](../rnd.md)

Research on the "Fire Enemies Lighting Rework" planned for version 0.3 (see [version-0.3.md](../versions/version-0.3.md#fire-enemies-lighting-rework)): fire-related enemies glow brighter than other enemies so they stand out in darkness, enemies of other mods are detected automatically, and lanterns attract fire enemies.

- [Requirements](#requirements)
- [Vanilla Fire Enemies](#vanilla-fire-enemies)
- [Approach: Runtime Light Instead of XML Patches](#approach-runtime-light-instead-of-xml-patches)
- [Fire Detection Heuristic](#fire-detection-heuristic)
- [Light Parameters](#light-parameters)
- [Attraction to Lanterns](#attraction-to-lanterns)
- [Edge Cases](#edge-cases)
- [Relevant Game Files](#relevant-game-files)
- [Implementation](#implementation)

## Requirements

- Fire-related enemies glow noticeably brighter than other enemies, so they stand out in darkness.
- Fire-related enemies dispel fog of war around themselves, as lanterns and other light sources do.
- The glow is always on, with no Mod Settings option: like the light of burning entities, it is a lighting fix rather than a mode.
- Vanilla fire enemies have tuned light: Stendari, Eldari, Liekkiö, Helvetinkatse, the fire bugs, the flamethrower robot, the Molotov Hiisi and the Dragon.
- Fire-related enemies of other mods are detected automatically and get the same kind of light.
- Lanterns attract fire-related enemies (see [Attraction to Lanterns](#attraction-to-lanterns), not implemented yet).

## Vanilla Fire Enemies

Light and fire signs of the candidates in `data/entities/animals/`. Weak variants inherit the main file through `<Base>`, and biome variants (`vault/`, `rainforest/`, `the_end/`, `drunk/`) inherit the main file of the same name.

| Enemy | File | Vanilla light | Fire signs | Glow |
| --- | --- | --- | --- | --- |
| Stendari | `firemage_weak.xml` | 100 px, default warm colour (inherited) | burning hands, `fireball`, lava blood | yes |
| Eldari | `firemage.xml`, `vault/firemage.xml` | 100 px, default warm colour | blue burning hands (`fire_blue`), `fireball_ghostly` (blue), lava blood | yes |
| Liekkiö | `fireskull.xml`, `fireskull_weak.xml` | 50 px, pale yellow | `herd_id="fire"`, `fire` particles | yes |
| Helvetinkatse | `gazer.xml`, `the_end/gazer.xml` | none | lava blood, `lavashot`, 200 lava inside | yes |
| Fire bugs | `firebug.xml`, `bigfirebug.xml` | 48 px, dim green | `flame` particles, fireballs, lava blood | yes |
| Flamethrower robot | `flamer.xml`, `vault/flamer.xml`, `rainforest/flamer.xml` | 50 px | `flamethrower` attack | yes |
| Molotov Hiisi | `miner_fire.xml`, `drunk/miner_fire.xml` | 50 px | `cocktail` attack | yes |
| Dragon (Suomuhauki) | `boss_dragon.xml` | 100 px, orange | none in data: green orbs (`orb_green_boss_dragon`); a fiery look and the orange vanilla light | yes |
| Helvetin sylkijä | `spitmonster.xml` | none | none: pink orbs, `endslime_blood`; only hell-themed | no |

Other vanilla enemies with some fire sign, which are **not** fire-related:

- Fire immunity (`fire="0"` damage multiplier) is shared by about 60 enemies: ghosts, worms, robots, Hell Hiisi, bosses.
- Torch particles (`data/entities/base_torch_particle.xml`, `fire` and `fire_blue`) are also carried by other mages and spirits, e.g. `thundermage_big.xml` and `wraith_glowing.xml`.
- Hell Hiisi (`shotgunner_hell`, `sniper_hell`, `miner_hell`) and `boss_robot` bleed `liquid_fire`; `worm_end` bleeds lava.
- `skullfly`, `bigzombie` and `wizard_returner` shoot fireballs or dark flame.

Most enemies already have a weak light: standard Hiisi have a 50 px light of the default `LightComponent` colour (255, 178, 118).

## Approach: Runtime Light Instead of XML Patches

Two options were considered:

- **XML patches at init.** Add a `LightComponent` to each vanilla file with `ModTextFileSetContent`. Free at runtime, but a mod enemy can only be found by its file, and the virtual file system cannot be listed. Spawn lists in biome scripts could be parsed, but mods spawn enemies in many other ways.
- **Runtime light (chosen).** Every 30 frames, enemies within 512 px of the camera that have not been checked are checked once and tagged with `pul_fire_glow_checked`. Fire-related ones get a new `LightComponent` and a fog of war hole `SpriteComponent`, both with the `pul_fire_glow` tag. Vanilla and mod enemies go through the same code, and the components can be read as they are, after `<Base>` merging and any changes by other mods.

The vanilla light is left alone, and the new one is added next to it. The vanilla lights have `update_properties="0"`, so changing them at runtime would have no effect anyway (see [Vision and Lighting](../dev/vision-and-lighting.md#why-vanilla-components-are-not-enough)).

Both the tag and the component are saved with the entity, so after loading a save the light is not added a second time.

## Fire Detection Heuristic

Enemies whose file name (without folders) is in the vanilla table get their tuned light. Any other enemy is scored, and a score of 2 or more makes it fire-related:

| Sign | Points | Read from |
| --- | --- | --- |
| Fire herd | 2 | `GenomeDataComponent.herd_id` is `fire` |
| Fire keyword in the name | 1 | file name without folders, or the entity name (`$animal_…`) |
| Fire ranged attack | 1 | fire keyword in the file name of `AnimalAIComponent.attack_ranged_entity_file` |
| Fire blood | 1 | `DamageModelComponent.blood_material` or `blood_spray_material` is a fire material |
| Fire particles | 1 | `ParticleEmitterComponent.emitted_material_name` of the enemy or its body parts is a fire material |

- Fire materials: `fire`, `flame`, `fire_blue`, `lava`, `liquid_fire`, `liquid_fire_weak`, `burning_powder`.
- Fire keywords: `fire`, `flame`, `lava`, `magma`, `inferno`, `pyro`, `blaze`, `ember`, `burn`, `liekki`, `tuli`.
- Folders are left out of the file name, so a mod named e.g. `fire_mod` does not make all its enemies fire-related.
- Child entities with a `GameEffectComponent` (status effects, including being on fire) or an `ItemComponent` (carried items) are skipped in the particle check, so a burning enemy is not mistaken for a fire enemy.
- Fire immunity gives no points.

An offline run of the same rules over all vanilla files (with `<Base>` merging) marks exactly the vanilla glow list above, except `miner_fire` (score 1) and `boss_dragon` (score 0), which are covered by the table. It also marks `boss_centipede/orb_mat_lava.xml` (lava blood and name), but that is a projectile without an enemy tag, so the scan never reaches it.

## Light Parameters

| Enemy | Radius | Colour (R, G, B) |
| --- | --- | --- |
| Stendari (`firemage_weak`) | 150 | 255, 130, 40 |
| Eldari (`firemage`) | 170 | 90, 150, 255 |
| Liekkiö (`fireskull`) | 130 | 255, 170, 60 |
| Weak Liekkiö (`fireskull_weak`) | 100 | 255, 170, 60 |
| Helvetinkatse (`gazer`) | 160 | 255, 90, 30 |
| Fire bug (`firebug`) | 100 | 255, 150, 50 |
| Big fire bug (`bigfirebug`) | 150 | 255, 150, 50 |
| Flamethrower robot (`flamer`) | 130 | 255, 120, 40 |
| Molotov Hiisi (`miner_fire`) | 110 | 255, 140, 50 |
| Dragon (`boss_dragon`) | 260 | 255, 130, 30 |
| Detected mod enemy | 100 + 50 × score (200 to 400) | 255, 130, 40 |

- The light is centred on the hitbox (`offset_x`, `offset_y` from `EntityGetFirstHitboxCenter`), as the position of walking enemies is at their feet.
- `update_properties="1"`: without it, a light added at runtime with `EntityAddComponent2` stayed invisible in game (a Stendari had no glow). The engine seems to create the light sprite with the default zero radius before the passed values are set. Vanilla scripts also set `update_properties` whenever they change a light at runtime (`data/scripts/gun/procedural/*.lua`). Confirmed in-game: with it, the light is visible.
- `fade_out_time="1.0"`: the light fades out after the enemy dies, as the light of a burning entity does (see [Burning Entity Light](../dev/vision-and-lighting.md#burning-entity-light)).
- The light is steady. `blinking_freq` below 1 makes the light blink at random every frame, which looks like a strobe. A smooth flicker would need a radius update every frame for each fire enemy, as the flickering lantern modifier does in `lantern_traits.lua`. **[Needs verification]** whether a flicker is worth that cost.
- Fog of war hole: the `LightComponent` only lifts the darkness added by the mod shader (see [Darkness Around the Player](../dev/vision-and-lighting.md#darkness-around-the-player)). The vanilla fog of war of unexplored areas stays, so an enemy far in a new cave was hidden in it. Each fire enemy also gets a `SpriteComponent` with `fog_of_war_hole="1"` (`data/particles/fog_of_war_hole_64.xml`, alpha 0.55, centred on the hitbox), as lanterns have. Vanilla does the same for `wraith_glowing.xml`. The hole scale keeps the lantern proportion (1.2 for a 280 px light): `radius * 1.2 / 280`, multiplied by the `Illuminated area size` setting. It follows the `Illuminate the darkness` setting: when that is off, fire enemies get only the light.
- The glow does not carry the `pul_light_source` tag, so it does not light enemies for [Enemy Study](enemy-study.md).

Ideas not used:

- `SpriteComponent.emissive="1"` would draw the enemy sprite on the emissive render target, so the body itself shines. It would change the look of the sprite a lot. **[Needs verification]** how it combines with the darkness shader.

## Attraction to Lanterns

Not implemented. The engine has no Lua call that sends an `AnimalAIComponent` to a point, so the options need in-game tests:

- **Home position.** `AnimalAIComponent` has private fields used by the idle and return-home jobs. **[Needs verification]** whether writing a home or target position (e.g. `mHomePosition`) makes an idle enemy walk or fly to a lantern, and whether the engine overwrites it.
- **Lantern as prey.** Give a lantern in the world a `GenomeDataComponent` with a herd that the fire herds hunt, so the AI targets it. Fire enemies would then attack the lantern, and could break it. **[Needs verification]** whether the AI targets entities without a `DamageModelComponent`, and how herd relations can be changed (`data/genome_relations.csv` is loaded by the engine).
- **Steering.** Every few frames, nudge the velocity of idle fire enemies (`CharacterDataComponent.mVelocity`, or `VelocityComponent` for flyers) towards the nearest lantern within a radius. Fully under mod control, but it may fight the AI and look unnatural.

Open questions: the attraction radius, whether lanterns in hand and on the belt attract too, and what a fire enemy does once it reaches a lantern.

## Edge Cases

- **New enemies between scans**: an enemy gets its light up to 30 frames after it appears. Enemies usually spawn off screen, and the scan radius is larger than the screen.
- **Polymorph**: a polymorphed enemy is a new entity and is checked again. A player polymorphed into a fire enemy glows too.
- **Charmed enemies**: keep their light.
- **Enemy parts**: child entities with an enemy tag are skipped, only root entities are checked.
- **Mod enemies that change their components at runtime**: the check runs once, on the first scan that sees the enemy.

## Relevant Game Files

- `data/entities/animals/firemage.xml`, `firemage_weak.xml`, `fireskull.xml`, `gazer.xml`, `firebug.xml`, `bigfirebug.xml`, `flamer.xml`, `miner_fire.xml`, `boss_dragon.xml` — vanilla fire enemies.
- `data/entities/base_torch_particle.xml` — torch flame particles used by mages and other enemies.
- `data/entities/projectiles/fireball_ghostly.xml` — blue fireball of Eldari.
- `data/entities/misc/effect_on_fire.xml` — burning status effect, a child entity of the burning creature.

## Implementation

| File | Role |
| --- | --- |
| `files/scripts/fire_enemy_glow.lua` | Vanilla light table, fire detection heuristic, light and fog of war hole components. `UpdateFireEnemyGlow()` is called from `OnWorldPreUpdate` |

- Confirmed in-game: fire enemies glow and dispel the fog of war around them.
- Still worth checking during play: light brightness and colours, the hitbox offset on large enemies and the Dragon, no light on non-fire enemies, no second light after loading a save.
