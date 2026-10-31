# Version 0.3 - Variety and World Interactions

Tracking document for features, implementation progress, and known issues for **Version 0.3**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.2.md](version-0.2.md).

## Visual Polish and UI

- [ ] Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Extended Light Fixture Support

- [x] Support hanging chain torches (`chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml`) and their duplicates: hang on a short chain, burn with an open fire in hand and on the belt, go out in liquids and light again from fire. Details: [lantern-entities.md](../dev/lantern-entities.md#chain-torches).
- [x] Support mining lamps (`physics_mining_lamp.xml`).
- [x] Support temple lanterns (`temple_lantern.xml`): hang on a chain that swings and breaks under projectiles. Details: [lantern-entities.md](../dev/lantern-entities.md#lantern-chains).
- [x] Support fluorescent tube lamps (`physics_tubelamp.xml`): shine only while powered by a cable that follows the lamp, snaps and keeps sparking. Details: [tube-lamp-electricity.md](../rnd/tube-lamp-electricity.md).
- [x] Hiisi Base fixtures: the tube lamp is the only lamp of the Hiisi Base itself, see [requirements.md](../requirements.md#light-fixture-catalog).
- Research results and open issues: [extended-light-fixtures.md](../rnd/extended-light-fixtures.md).

## Open-Flame Variants

- [ ] Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
- [ ] Immediate extinguishing upon liquid contact (without a delay).

## Strategic World Incentives

- [x] Hang a held lantern on the ceiling above the player (up to 16 px) with LMB, then take the first wand (or the first item) from the Quick Inventory in hand; without a ceiling the lantern stays in hand. RMB keeps the vanilla throw. Details: [throwing-mechanics-and-controls.md](../rnd/throwing-mechanics-and-controls.md).

## Rogue Mode

- [ ] A Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
- [ ] Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).

## Enemy Study

- [x] Study conditions: while an enemy is within the study radius, in the player's line of sight (raycast) and lit by a lantern in the world or in hand (not on the belt) or by a projectile with the Light spell modifier (`LIGHT`), the player's damage against it grows from 0% to the configured bonus. The bonus is kept after the enemy leaves the light or sight. Details: [enemy-study.md](../rnd/enemy-study.md).
- [x] Knowledge: each enemy type has a counter equal to the sum of the study progress (0 to 1) of its enemies, so five fully studied enemies give 5. Other variants of the same enemy (e.g. a weak and a normal zombie) share half of their knowledge, the rest of its herd (`herd_id`, e.g. all Hiisi) a fifth.
- [x] Study time: the base study time at knowledge 0, shrinking linearly to 0.5 seconds at knowledge 10. Bosses take 120 seconds and neither give nor get knowledge.
- [x] Study indicator: a small semi-transparent dot above the head of an enemy whose study has begun: yellow while studied, red while paused (out of light or sight), green once fully studied.
- [x] Settings: a separate `Enemy Study` category in Mod Settings, not affected by presets, with an `Enemy study` option (off by default), the bonus of a fully studied enemy (10%, 25%, 50%, 100%) and the base study time (3, 5, 10, 30 seconds; 10 by default).
- [x] Bug: projectile spells with the Light modifier (`LIGHT`) do not light enemies for study progress. The modifier adds `data/entities/misc/light.xml` (a `LightComponent` with radius 200) to the projectile, but the study only counted light from entities with the `lantern` tag. Fixed: light sources for study are marked with the `pul_light_source` tag, and `light.xml` is patched at init.

## Mod Compatibility

- [x] Bug (Steam Workshop): with Apotheosis loaded first, the vision shader patch fails, because Apotheosis inserts its uniforms between the two context lines of `01_uniforms.patch.txt`. Fixed: the hunk is anchored on the single line `varying vec2 tex_coord_fogofwar;`, checked in game in both load orders.

## Lantern Modifiers

- [x] Cracked glass modifier: a lantern that takes damage without breaking (e.g., a fall or a projectile hit) has a 33% chance to crack. A cracked lantern has a 50% chance every 20 frames to emit 2 particles of gaseous fire (`fire`), both in the world and in hand, so it can set the player on fire. Does not appear when lantern progression is disabled. Described by a sentence in the item description.
- [x] Keep the configuration of all lantern modifiers (IDs, description keys, roll chances and behaviour parameters) in a single file.
- [x] Allow a lantern to carry several modifiers at once; the modifier configuration defines how modifiers interact with each other (e.g., which ones are incompatible, replace or combine with each other).

## Settings Presets

- [x] Add a `Preset` option as the first entry in Mod Settings that sets all other options at once: Light Touch (default, minimal changes: vanilla vision, lantern progression off), Atmospheric (Dark 50% vision), Survival (Minimal 10% vision, 25% belt light) and Pitch Black (0% vision, 25% belt light). Lantern progression is on in every preset except Light Touch.
- [x] Changing any option by hand switches the preset to `Custom`; new-game options of a preset take effect in the next run.

## Fire Enemies Lighting Rework

- [x] Make fire-related enemies glow noticeably brighter than other enemies so they stand out in darkness. Always on, no Mod Settings option. Fire enemies around the camera get an extra `LightComponent` at runtime, checked once per enemy, and dispel fog of war around themselves (unless `Illuminate the darkness` is off). Details: [fire-enemies.md](../rnd/fire-enemies.md).
- [x] Cover vanilla fire enemies with tuned light radius and colour: Fire Mage (Stendari, `firemage_weak`), Hellfire Mage (Eldari, `firemage`, blue), Fire Spirit (Liekkiö, `fireskull`), Hell Gazer (Helvetinkatse, `gazer`), fire bugs (`firebug`, `bigfirebug`), the flamethrower robot (`flamer`), the Molotov Hiisi (`miner_fire`) and the Dragon (`boss_dragon`). Hell Spitter (Helvetin sylkijä, `spitmonster`) is left out: nothing in its data is fire-related.
- [x] Implement a procedural patch that automatically detects similar fire-related enemies added by other mods and applies the same lighting enhancements. Done at runtime by a score of fire signs (fire herd, name, attack, blood, particles). An offline run over vanilla files marks no non-fire enemy. The light radius grows with the score: 100 + 50 × score.
- [x] Lit lanterns in the world (hanging, thrown or lying) attract fire-related enemies that see them within 1.5 times the light radius: the enemies gather around the lantern and do not attack it. Lanterns in hand, in the inventory or on the belt do not attract. Details: [fire-enemies.md](../rnd/fire-enemies.md#attraction-to-lanterns).
- [x] Attracted enemies are in a trance: they notice the player only within 48 px and wake up once they find prey (the player came close or hurt them).
- [x] Enemies take and leave a lantern at random, so they come and go.
- [x] Walking enemies are lured only by a lantern on their own level, and walk to it with a longer path search.
- [x] `Lanterns attract fire enemies` option in the `Gameplay` category, on by default and not affected by presets.

## Natural Fear Mode

- [x] Mod settings toggle that changes how enemy categories (`herd_id`) react to lantern light: zombies and monsters avoid it and keep their distance from the player, while Hiisi prefer lit areas.
- [x] `Natural Fear` option in the `Gameplay` category, off by default and not affected by presets.
- [x] Hiisi (with their tanks and turrets) and insects are attracted to lanterns, as fire enemies are. Details: [fire-enemies.md](../rnd/fire-enemies.md#attraction-to-lanterns).
- [x] Creatures that lanterns do not attract (zombies, slime creatures such as Limanuljaska, other monsters) panic in lantern light, as if it burned them. Details: [natural-fear.md](../rnd/natural-fear.md).
- [x] Lanterns in the world and in hand scare them, vanilla hanging lanterns too; the light of the player, the belt lantern and lanterns in the inventory do not.
- [x] Fear beats hunting: they stay in the dark while fighting the player.
- [x] Now and then a scared creature flies into a rage (Markov process) and attacks the lantern, or the player who holds it.
- [x] They go back to their usual behaviour once the light is gone.
