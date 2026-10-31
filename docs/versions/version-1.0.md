# Version 1.0 - Polished State Simulation

Tracking document for features, implementation progress, and known issues for **Version 1.0**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.4.md](version-0.4.md).

## Extinguishing and Submersion

- [ ] Implement a 2-second submersion timer: lanterns submerged in water or non-flammable liquids extinguish and cease emitting light.
- [ ] Dynamic state tracking: switch inventory icon to an unlit flask when extinguished.
- [ ] Update in-hand and belt sprites to render unlit containers without flame animations.
- [ ] Magical and hermetic lanterns remain lit underwater.

## Additional Liquid Interactions

- [ ] React to other liquids besides oil and water (e.g., alcohol flicker, toxic sludge tint, blood dimming).

## Reignition Mechanics

- [ ] Reignite unlit lanterns when exposed to open fire, burning materials, or high environmental heat.

## Full Playthrough Guarantee in Darkness

- [ ] Verify that the game can be fully completed with the mod enabled at the darkest vision presets (Minimal 10% and Pitch Black 0%).
- [ ] Guarantee that every biome, including the main path, side biomes, parallel worlds, and boss arenas, offers at least one reliable way to get sufficient illumination (e.g., spawned lanterns, light fixtures, glowing materials, or light sources the player can bring along).
- [ ] Close any biome where no light source can be obtained, by adding guaranteed lantern spawns or other light sources.

## Full Release Polish

- [ ] Finalized balance, performance optimization, and compatibility verification.
