# Fire Enemies: Glow and Attraction to Lanterns

[← Back to R&D Index](../rnd.md)

Research on the "Fire Enemies Lighting Rework" planned for version 0.3 (see [version-0.3.md](../versions/version-0.3.md#fire-enemies-lighting-rework)): fire-related enemies glow brighter than other enemies so they stand out in darkness, enemies of other mods are detected automatically, and lanterns attract fire enemies.

- [Requirements](#requirements)
- [Vanilla Fire Enemies](#vanilla-fire-enemies)
- [Approach: Runtime Light Instead of XML Patches](#approach-runtime-light-instead-of-xml-patches)
- [Fire Detection Heuristic](#fire-detection-heuristic)
- [Light Parameters](#light-parameters)
- [Attraction to Lanterns](#attraction-to-lanterns)
  - [Design](#design)
  - [In-Game Findings](#in-game-findings)
  - [Current Status and Next Steps](#current-status-and-next-steps)
  - [Open Questions](#open-questions)
- [Edge Cases](#edge-cases)
- [Relevant Game Files](#relevant-game-files)
- [Implementation](#implementation)

## Requirements

- Fire-related enemies glow noticeably brighter than other enemies, so they stand out in darkness.
- Fire-related enemies dispel fog of war around themselves, as lanterns and other light sources do.
- The glow is always on, with no Mod Settings option: like the light of burning entities, it is a lighting fix rather than a mode.
- Vanilla fire enemies have tuned light: Stendari, Eldari, Liekkiö, Helvetinkatse, the fire bugs, the flamethrower robot, the Molotov Hiisi and the Dragon.
- Fire-related enemies of other mods are detected automatically and get the same kind of light.
- Lit lanterns in the world (hanging, thrown or lying) attract fire-related enemies: they gather around the lantern like moths to a flame and do not attack it. The light holds them in a trance: they notice the player only up close and fight as usual once they find prey, so the lantern gives a tactical advantage (sneak past, strike first, fight one by one). Lanterns in hand, in the inventory or on the belt do not attract. A Mod Settings option, on by default and not affected by presets, turns the attraction off (see [Attraction to Lanterns](#attraction-to-lanterns)).

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

The engine has no Lua call that sends an `AnimalAIComponent` to a point, and no vanilla script changes AI targets. The tools found in the component documentation, vanilla files and other mods:

| Tool | How it works | Verdict |
| --- | --- | --- |
| `AnimalAIComponent.mHomePosition` + `max_distance_to_move_from_home` | The AI stays within the distance from its home. Vanilla leashes `firebug.xml` and `bigfirebug.xml` to their spawn point (256 px). Spellbound Bundle (workshop 1976795806, `set_home_on_player.lua`) moves the home of its drone to the player every 40 frames with a 60 px leash, and the drone follows the player | **Chosen**: native movement and pathfinding, nothing to fight |
| `AnimalAIComponent.mGreatestPrey` | Writable from Lua (Goki's Things, `hero_mode_ai.lua`, sets it to the player). The AI hunts the entity | Rejected: the enemy would attack the lantern and break it |
| Velocity steering (`CharacterDataComponent.mVelocity`, `VelocityComponent`) | The mod pushes the enemy towards the lantern every few frames | Rejected: fights the AI and looks unnatural |
| `WormAttractorComponent` | Attracts or repels worms | Rejected: worms only |

`max_distance_to_move_from_home` is 0 (no leash) for most enemies, so moving the home alone does nothing: the leash has to be set too.

### Design

`files/scripts/lantern_attraction.lua`, every 20 frames. The same mechanism serves the [Natural Fear](../versions/version-0.3.md#natural-fear-mode) mode, which attracts Hiisi and insects.

- **Lured enemies**: root entities with the `enemy` tag within the attraction radius of a lure lantern, plus the enemies attracted earlier (to release them). An enemy is lured when:
  - `Lanterns attract fire enemies` is on and it has the `pul_fire_enemy` tag, which the glow scan adds to every enemy it lights;
  - or `Natural Fear` is on and its herd is `orcs` (Hiisi, with their tanks, turrets and `friend.xml`) or `fly` (insects).

  Bosses, charmed enemies, a polymorphed player and hunting enemies (see Trance) are skipped.
- **Lure lanterns**: entities with the `lantern` tag that are their own root entity (not held, not in the inventory) and have an enabled `LightComponent` with the `pul_light_source` tag (lit). Vanilla hanging lanterns count too. The attraction radius is 1.5 times the current light radius, which already includes the quality tier, liquid state and modifiers (about 420 px for a large lantern).
- **Line of sight to start, radius to stay.** A free enemy takes the nearest lantern it sees (`RaytraceSurfaces`). The ray stops 10 px before the lantern (`SIGHT_MARGIN`): the lantern body is solid cells in the world grid, and a hanging lantern sits right under the ceiling, so a ray to its centre always hit something and no enemy was ever attracted. An attracted enemy keeps the lantern it took (its entity ID is kept in the storage, see Release) and needs only the radius to stay: otherwise it flipped between the lantern and its own home whenever a ledge hid the lantern while it moved. It does not switch to a nearer lantern, which it may not even see (see [In-Game Findings](#in-game-findings)).
- **Walking enemies only on the lantern level.** A walking enemy is lured only while the floor below the lantern is within `WALKING_LEVEL_TOLERANCE` (24 px) of its feet (`EntityGetTransform`). A walker whose home is on another level stands still (see [In-Game Findings](#in-game-findings)).
- **Markov process.** On every update, a free enemy that sees a lantern takes it as its home with `LURE_ENTER_CHANCE` (10%, about 3 seconds on average), and a lured enemy leaves it to wander with `LURE_LEAVE_CHANCE` (3%, about 11 seconds). Enemies come and go instead of sticking to a lantern for good. The idea came from the user. The enter chance of a free enemy is rolled before the lantern search, so 90% of free enemies skip the line of sight raytraces on an update.
- **Cost.** Per update, the AI components of each candidate are read once and passed on, and the lure group (fire tag or herd) is checked before the other exclusions, as most enemies near lanterns belong to no lured group. The floor below a lantern is found once per update.
- **Home and leash.**
  - Flying enemies (`AnimalAIComponent.can_fly` is 1): home at the lantern, leash `LEASH_DISTANCE` (40 px).
  - Walking enemies: home on the floor below the lantern (a ray down from 10 px below the lantern, up to 200 px, 4 px above the hit; the lantern itself if there is no floor), found once per lantern per update. The leash is never shorter than the current distance from home plus `WALKING_LEASH_MARGIN` (16 px) and only shrinks as the enemy comes closer, down to 40 px (see [In-Game Findings](#in-game-findings)).
  - The home is set on every update, as a thrown lantern keeps moving.
- **Path finding.** An attracted enemy gets `pathfinding_max_depth_no_target` 200 (`LURED_PATHFINDING_DEPTH`, default 50, no vanilla Hiisi override it): with 50 nodes, walkers found no path to a distant home (see [In-Game Findings](#in-game-findings)).
- **Trance.** Before it, attraction gave no tactical advantage: lured enemies only stood elsewhere and still attacked the player (third test). An attracted enemy gets `creature_detection_range_x` and `_y` 48 (`TRANCE_DETECTION_RANGE`; vanilla Hiisi have 180–300 px), so it notices the player only up close. An enemy whose `mGreatestPrey` is a living entity is not lured: an enemy that is already fighting takes no lantern, and an attracted one that finds prey (the player came within 48 px, or hit it, as the AI counter-attacks with `attack_if_damaged_probability`) is released on the next update and gets its detection range back. The player can sneak past lured enemies, strike first and fight them one by one. The idea of the user, chosen from: trance, luring away (lower leave chance), clustering for area damage.
- **Release.** The original AI values are saved in a `VariableStorageComponent` named `pul_lantern_attraction` on the first attraction: the leash in `value_float`, `"home_x,home_y,range_x,range_y,depth"` in `value_string` and the lantern entity ID in `value_int`, and the enemy gets the `pul_lantern_attracted` tag. When the enemy leaves by chance, hunts, no lantern attracts it (picked up, extinguished, out of range), it is charmed, or its option is off, the original values are restored and the storage is removed.

### In-Game Findings

From `logger.txt` with the diagnostic output (see [Current Status and Next Steps](#current-status-and-next-steps)).

Fourth test, 2026-10-27 (with the trance and the longer path finding): the user found the attraction works better now. Limanuljaska (`slimeshooter.xml`, `slimeshooter_weak.xml`, `slimeshooter_nontoxic.xml`, herd `slimes`) did not react to lanterns at all, as designed: its herd is not lured. The user decided that slime creatures and other monsters will fear the light in the Natural Fear mode, later.

Third test, 2026-10-27 (`Natural Fear` on, with the lantern level check and sticky lanterns, no cheats). The user's verdict: luring gives no noticeable tactical advantage.

- **Walkers still froze on their own level.** `shotgunner_weak` 454 stood at 150,381 in state 21 for minutes with its home at 329,381 (the same height, 179 px away, leash 195 px); `miner_weak` 793 (68 px from home), 795, 392 and 379 too. So the level was not the only cause. Hypothesis: `pathfinding_max_depth_no_target` (50 nodes by default, used while the AI has no prey) is too short for a distant home. The walkers that moved had their home close: `miner_weak` 631 and `shotgunner_weak` 629 reached it (from 151 and 369 px to 1–7 px), `firemage_weak` 809 from 179 to 10 px.
- **Sticky lanterns work**: most walkers kept one lantern ID while attracted.
- **No tactical value**: lured enemies still attacked the player as soon as they saw them, so a lantern changed only where they stood. Hence the trance (see [Design](#design)).
- `fireskull` 807 (flying) followed lanterns, as before.

Second test, 2026-10-27 (`Natural Fear` on, with the shrinking leash; at times the player was ignored by enemies, so enemies moved less). In the game, flying enemies clearly went to lanterns, while walking ones looked as if they ignored them. The log shows why:

- **Walkers do go to a lantern on their own level.** `miner_weak` 483 (home 1 px above its centre) walked from 250 to 314–386 px around a home at 338 and stayed there with a 40 px leash. `alchemist` 479 went from 556 to a home at 709, then to the next lanterns at 979 and 1137. `shotgunner_weak` 412 and `miner` 1904 also reached the home and wandered around it in state 1. The shrinking leash works: 105 → 79 → 40 px as the enemy comes closer.
- **Walkers freeze when the home is on another level**, even well inside the leash: `shotgunner_weak` 771 stood at the same pixel for 62 samples (about 2 minutes) in state 21 with the home 120 px above it (distance 126 px, leash 142 px). The same with `miner` 2136 (home 59 px below), 1896 and 1900 (160 px below), 2999 and 3005 (90–115 px below), `goblin_bomb` 3011 (45 px below), and `miner` 1904 on a ledge 28 px under its home. So state 21 does not mean "outside the leash": it is the job of going home, and a walker stands still in it when its path finding finds no way there. This is why walkers looked as if they ignored lanterns: of 13 lured walkers, about a third moved.
- **An attracted enemy switched to a lantern it did not see.** `shotgunner_weak` 771 took a lantern on its own level (home 939,831), and on the next update the nearest lantern in range (home 1079,640, on the level above) took over, as an attracted enemy skipped the sight check. `miner` 3005 did the same (1680,2460 → 1580,2514). Fixed: an attracted enemy keeps its own lantern.
- **The Markov process works**, but with a 3% chance to leave and 10% to come back, a walker often returns towards its spawn before it reaches the lantern, which also looks like no reaction.
- `scavenger_mine` 2011 (flying) followed lanterns from 1830 to 1649 px high.
- Up to 36 lure lanterns were found at once.

First test, 2026-10-26:

- **Flying enemies work.** `firebug`, `bigfirebug` and `fireskull` fly to the lantern and stay within 15–30 px of it (Liekkiö: from 107 px to 11 px on average). They get their original home and leash back once the lantern is picked up. A few stay where they are when no path leads to the lantern.
- **Walking enemies froze.** A walking enemy (Stendari `firemage_weak`, Hiisi `miner_weak`, `shotgunner_weak`, `miner_fire`) whose home is moved outside its leash switches to AI state 21 and stands still for good, wherever the home is: at a hanging lantern 40 px above the floor, or on the floor 60 px aside. Before the move, the same enemy walked around in state 1. Flying enemies in state 21 fly home. A frozen enemy no longer wanders or hunts, so a plain home move is a bug for walkers. The shrinking leash is the attempted fix.
- **Line of sight to the lantern centre was always blocked** before `SIGHT_MARGIN` (see [Design](#design)).
- **The home follows a thrown lantern** while it flies, as long as the enemy stays within the radius.
- `PathFindingComponent` has no public target field: the path and goal are private and driven by the AI, so there is no other native way to send a walking enemy to a point.
- AI states seen: 1 (walking around), 5, 18 (idle, before the camera comes close), 21 (going home; walkers stand still in it when they find no path home, see the second test).

### Current Status and Next Steps

Work state at the end of 2026-10-27:

- **Committed** (`ced8873`): fire enemy glow and fog of war hole.
- **Ready to commit**: the whole attraction (`lantern_attraction.lua`, `FIRE_ENEMY_TAG`, the `pul_fire_enemy` tag in `fire_enemy_glow.lua`, the `fire_enemy_attraction` and `natural_fear` options, translations, docs). The temporary diagnostics (`DEBUG`, `PrintDebug()` with `[pul_attract]` lines in `logger.txt`) are removed; to debug again, print the enemy position, `ai_state`, `mHomePosition`, `max_distance_to_move_from_home`, `mGreatestPrey` and `creature_detection_range_x` every 120 frames.
- Commit message: `feat: make lanterns attract fire enemies, Hiisi and insects`.

Next steps:

1. Tune `LURE_ENTER_CHANCE`, `LURE_LEAVE_CHANCE`, `LEASH_DISTANCE`, `ATTRACTION_RADIUS_FACTOR` and `TRANCE_DETECTION_RANGE` by feel.
2. Slime creatures and other monsters avoid lantern light in the [Natural Fear](../versions/version-0.3.md#natural-fear-mode) mode instead of being attracted (see [In-Game Findings](#in-game-findings)).

### Open Questions

- Walkers move better with the longer path finding (`pathfinding_max_depth_no_target` 200) by the fourth test. **[Needs verification]** whether it costs too much with many attracted enemies.
- **[Needs verification]** Whether `mGreatestPrey` returns to 0 after a fight. If it keeps a lost or distant prey for long, a once alerted enemy is not lured again for that time; a dead prey is already ignored (`EntityGetIsAlive`).
- **[Needs verification]** Whether 48 px is a good trance range: small enough to sneak past, yet not so small that an enemy ignores the player right next to it. Ranged enemies detect along X farther than along Y in vanilla, so the two axes may need different values.
- A hanging lantern above a pit or high in a large cave lures no walkers at all: the floor below it is too far from their level.
- **[Needs verification]** Whether the leash moves an enemy that still idles: `JobDefault` idles until the camera has once been within `max_distance_to_cam_to_start_hunting` (300 px).
- **[Needs verification]** Whether `mHomePosition`, a private field, survives saving and loading. If not, the next update sets it again, and the original values are kept in the storage.
- Vanilla hanging lanterns are lure lanterns too, so lured enemies spawned near them gather there from the start. If this is unwanted, only lanterns the player has touched could lure.

## Edge Cases

- **New enemies between scans**: an enemy gets its light up to 30 frames after it appears. Enemies usually spawn off screen, and the scan radius is larger than the screen.
- **Polymorph**: a polymorphed enemy is a new entity and is checked again. A player polymorphed into a fire enemy glows too.
- **Charmed enemies**: keep their light.
- **Enemy parts**: child entities with an enemy tag are skipped, only root entities are checked.
- **Mod enemies that change their components at runtime**: the check runs once, on the first scan that sees the enemy.
- **Enemies attracted before a save**: the attraction is evaluated again after loading, and the original home and leash stay in the storage until the enemy is released.

## Relevant Game Files

- `data/entities/animals/firemage.xml`, `firemage_weak.xml`, `fireskull.xml`, `gazer.xml`, `firebug.xml`, `bigfirebug.xml`, `flamer.xml`, `miner_fire.xml`, `boss_dragon.xml` — vanilla fire enemies.
- `data/entities/base_torch_particle.xml` — torch flame particles used by mages and other enemies.
- `data/entities/projectiles/fireball_ghostly.xml` — blue fireball of Eldari.
- `data/entities/misc/effect_on_fire.xml` — burning status effect, a child entity of the burning creature.

## Implementation

| File | Role |
| --- | --- |
| `files/scripts/fire_enemy_glow.lua` | Vanilla light table, fire detection heuristic, light and fog of war hole components, `pul_fire_enemy` tag. `UpdateFireEnemyGlow()` is called from `OnWorldPreUpdate` |
| `files/scripts/lantern_attraction.lua` | Lure lanterns, lured enemies (fire enemies and the Natural Fear herds), AI home, leash, path finding depth and trance (detection range) of attracted enemies. `UpdateLanternAttraction()` is called from `OnWorldPreUpdate` |
| `files/scripts/utils.lua` | `FIRE_ENEMY_TAG` |
| `settings.lua`, `files/translations.csv` | `fire_enemy_attraction` and `natural_fear` options in the `Gameplay` category, marked `preset_excluded = true` |

- Confirmed in-game: fire enemies glow and dispel the fog of war around them.
- Confirmed in-game: flying enemies are attracted to lanterns; walking enemies and the trance work better after the third test fixes (fourth test, user's verdict).
- Still worth checking during play: light brightness and colours, the hitbox offset on large enemies and the Dragon, no light on non-fire enemies, no second light after loading a save.
