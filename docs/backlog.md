# Backlog

This document lists planned tasks that are not done yet. Released versions and completed work live in [Versions](versions/README.md). Current implemented behavior is documented in [Player Guides](guides/README.md) and [Developer Documentation](dev/README.md).

## Rules

- Keep open tasks only in this document. Group them by topic.
- Describe small features directly inside their backlog entry. For complex features or engine questions, write a design or research note in [R&D Notes](rnd/README.md) and link it from the backlog entry.
- Never delete a finished task from this file alone. In the same edit, record it in the current release file in `docs/versions/` and update its summary in [Versions](versions/README.md).
- When a task changes how the mod works, update [Player Guides](guides/README.md) and [Developer Documentation](dev/README.md). Those two sections are the source of truth for implemented behavior.

## Visual Polish and UI

- Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Rogue Mode

- A Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
- Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).

## Extinguishing and Submersion

- Switch the inventory icon of an extinguished or doused lantern to an unlit variant. Currently, only unpowered tube lamps change their inventory icon.

## Additional Liquid Interactions

- React to other liquids besides oil and water (e.g., alcohol flicker, toxic sludge tint, blood dimming).

## Full Playthrough Guarantee in Darkness

- Verify that the game can be fully completed with the mod enabled at the darkest vision presets (Minimal 10% and Pitch Black 0%).
- Guarantee that every biome, including the main path, side biomes, parallel worlds, and boss arenas, offers at least one reliable way to get sufficient illumination (e.g., spawned lanterns, light fixtures, glowing materials, or light sources the player can bring along).
- Close any biome where no light source can be obtained, by adding guaranteed lantern spawns or other light sources.

## Full Release Polish

- Finalized balance, performance optimization, and compatibility verification.
