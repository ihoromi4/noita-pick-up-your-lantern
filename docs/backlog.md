# Backlog

This document lists planned tasks that are not done yet. Released versions and completed work live in [Versions](versions/README.md). Current implemented behavior is documented in [Player Guides](guides/README.md) and [Developer Documentation](dev/README.md).

## Rules

- Keep open tasks only in this document. Group them by topic.
- Describe small features directly inside their backlog entry. For complex features or engine questions, write a design or research note in [R&D Notes](rnd/README.md) and link it from the backlog entry.
- A finished task leaves the backlog. It moves to the notes of its release in the [Versions](versions/README.md) folder.
- When a task changes how the mod works, update [Player Guides](guides/README.md) and [Developer Documentation](dev/README.md). Those two sections are the source of truth for implemented behavior.

## Natural Fear Mode

- The Giant Laser-Drone (Jättilaser-lennokki, `drone_lasership`) fears lantern light in the Natural Fear mode, but it should not. The drone is a robot, and robots are immune to fire. The guides say that creatures immune to fire do not fear the light.
  - Cause: the immunity is never checked in code. `IsFearful` in `files/scripts/lantern_fear.lua` filters only by fire enemies, lured herds, and excluded enemies. The drone has the `robot` herd, so it counts as fearful.
  - The design assumed that fire immunity alone stops the reaction. In fact, immunity only cancels the `LIGHT_BURN_DAMAGE` fire damage and the panic that it starts. `Scorch` still adds `FEAR_PUSH_SPEED` to the velocity of the drone, and `SetScared` still gives it the look of fear. The rage branch also works, because it does not use damage at all.
  - The drone inherits the `fire="0.0"` damage multiplier from `data/entities/base_enemy_robot.xml`. The drone is light (mass 0.8) and flies, so the push moves it along both axes and is easy to notice.
  - The same bug likely affects every creature immune to fire: other robots, ghosts, and others. The fix should skip enemies whose fire damage multiplier is 0 in `IsFearful`.
- The Hiisi Healer (Parantajahiisi, `scavenger_heal`) fears lantern light in the Natural Fear mode, but it should not. It is a Hiisi, and lanterns should attract Hiisi.
  - Cause: the Natural Fear mode recognizes Hiisi only by the `orcs` herd. The list is `NATURAL_FEAR_LURED_HERDS` in `files/scripts/enemy_ai_home.lua`. In vanilla data, the Hiisi Healer has the `healer` herd instead of `orcs`.
  - As a result, `IsNaturalFearLuredHerd` returns false for the Hiisi Healer. `IsFearful` then counts it as a fearful enemy, so the light scorches it.
  - Two other Hiisi have the `healer` herd too: the invisibility Hiisi (`scavenger_invis`) and the shield Hiisi (`scavenger_shield`). They likely have the same bug. The `healer` herd also has the coward (`coward`) and the healer drone (`healerdrone_physics`), which need a check.
  - A whole `healer` herd in the lured list would also attract the healer drone, which is a robot. The fix may need to recognize these Hiisi by their file names instead of the herd.

## Temple Lantern Modifiers

- Magic liquid modifier for the temple lantern (`physics/temple_lantern.xml`): with a small chance, a temple lantern is filled with a magic liquid instead of plasma.
- A lantern with this modifier gives no light.
- When it breaks, it spills one of the magic liquids instead of `plasma_fading`:
  - Concentrated Mana (`magic_liquid_mana_regeneration`);
  - Flummoxium (`material_confusion`);
  - Unstable Teleportatium (`magic_liquid_unstable_teleportation`).

## Visual Polish and UI

- Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Open-Flame Variants

- Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
- Immediate extinguishing upon liquid contact (without a delay).

## Rogue Mode

- A Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
- Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).

## Extinguishing and Submersion

- Implement a 2-second submersion timer: lanterns submerged in water or non-flammable liquids extinguish and cease emitting light.
- Dynamic state tracking: switch inventory icon to an unlit flask when extinguished.
- Update in-hand and belt sprites to render unlit containers without flame animations.
- Magical and hermetic lanterns remain lit underwater.

## Additional Liquid Interactions

- React to other liquids besides oil and water (e.g., alcohol flicker, toxic sludge tint, blood dimming).

## Reignition Mechanics

- Reignite unlit lanterns when exposed to open fire, burning materials, or high environmental heat.

## Full Playthrough Guarantee in Darkness

- Verify that the game can be fully completed with the mod enabled at the darkest vision presets (Minimal 10% and Pitch Black 0%).
- Guarantee that every biome, including the main path, side biomes, parallel worlds, and boss arenas, offers at least one reliable way to get sufficient illumination (e.g., spawned lanterns, light fixtures, glowing materials, or light sources the player can bring along).
- Close any biome where no light source can be obtained, by adding guaranteed lantern spawns or other light sources.

## Full Release Polish

- Finalized balance, performance optimization, and compatibility verification.
