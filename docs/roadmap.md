# Development Roadmap

Development roadmap and release milestones for the **Pick Up Your Lantern** mod for Noita. Detailed functional specifications for each feature are documented in [requirements.md](requirements.md).

## Version 0.1 - MVP and Core Lifecycle

Version 0.1 delivers a fully functional, stable core gameplay loop for standard hanging oil lanterns: world physics and ceiling anchors, pickup into `Quick Inventory`, holding in hand with swaying light, throwing with shattering and oil fires, and configurable limited player vision. Features and implementation details: [version-0.1.md](versions/version-0.1.md).

## Version 0.1.1 - Item Radar Fix

Version 0.1.1 is a patch release that hides lanterns from the Item Radar perk, with a Mod Settings toggle to show them. Details: [version-0.1.1.md](versions/version-0.1.1.md).

## Version 0.2 - Passive Carrying and Atmosphere

Version 0.2 focuses on passive utility and atmospheric carrying mechanics: a lantern on the belt that lights the way while hands are busy, distinct lantern properties with quality tiers and rare modifiers, oil-soaked and wet states, and vision fixes for polymorph, chain torches and All-Seeing Eye. Details: [version-0.2.md](versions/version-0.2.md).

## Version 0.3 - Variety and World Interactions

Version 0.3 expands the scope to other environmental light fixtures, danger mechanics, world incentives, and visual polish.

- **Visual Polish and UI**:
  - Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.
- **Extended Light Fixture Support**:
  - Support hanging chain torches (`chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml`).
  - Support mining lamps (`physics_mining_lamp.xml`) and temple lanterns (`temple_lantern.xml`).
  - Support fluorescent tube lamps (`physics_tubelamp.xml`) and Hiisi Base fixtures.
- **Open-Flame Variants**:
  - Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
  - Immediate extinguishing upon liquid contact (without a delay).
- **Strategic World Incentives**:
  - Rogue mode: a Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
  - Rogue mode: investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).
  - Enemy study: while an enemy is within the study radius, in direct line of sight of the player (raycast) and within the light radius of a lantern in the world or in hand (not on the belt) or of a projectile with the Light spell modifier (`LIGHT`), the player's damage against this enemy grows from 0% to the configured bonus. Each enemy type has a knowledge counter: the sum of the study progress (0 to 1) of all its enemies, so five fully studied enemies give 5. Related enemies share part of their knowledge: other variants of the same enemy (e.g. a weak and a normal zombie) give half of theirs, the rest of its herd (`herd_id`, e.g. all Hiisi) a fifth. The study takes the base study time at knowledge 0 and shrinks linearly to 0.5 seconds at knowledge 10. Bosses take 120 seconds and neither give nor get knowledge. An enemy whose study has begun has a small semi-transparent dot above its head: yellow while it is being studied, red while its study is paused (out of light or sight), green once it is fully studied. The accumulated bonus is kept after the enemy leaves the light or the line of sight.
  - Enemy study settings: a separate `Enemy Study` category in Mod Settings, not affected by presets, with an `Enemy study` option (off by default), the bonus of a fully studied enemy (10%, 25%, 50%, 100%) and the base study time (3, 5, 10, 30 seconds; 10 by default).
  - Hang a held lantern on the ceiling above the player with the Left Mouse Button (LMB); without a ceiling within reach the lantern stays in hand. The Right Mouse Button (RMB) keeps the vanilla throw.
- **Lantern Modifiers**:
  - Cracked glass modifier: a lantern that takes damage without breaking (e.g., a fall or a projectile hit) has a 33% chance to crack. A cracked lantern has a 50% chance every 30 frames to emit a particle of gaseous fire (`fire`), both in the world and in hand, so it can set the player on fire. Does not appear when lantern progression is disabled. Described by a sentence in the item description.
  - Keep the configuration of all lantern modifiers (IDs, description keys, roll chances and behaviour parameters) in a single file.
  - Allow a lantern to carry several modifiers at once; the modifier configuration defines how modifiers interact with each other (e.g., which ones are incompatible, replace or combine with each other).
- **Settings Presets**:
  - Add a `Preset` option as the first entry in Mod Settings that sets all other options at once: Light Touch (default, minimal changes: vanilla vision, lantern progression off), Atmospheric (Dark 50% vision), Survival (Minimal 10% vision, 25% belt light) and Pitch Black (0% vision, 25% belt light). Lantern progression is on in every preset except Light Touch.
  - Changing any option by hand switches the preset to `Custom`; new-game options of a preset take effect in the next run.
- **Fire Enemies Lighting Rework**:
  - Make fire-related enemies glow noticeably brighter than other enemies so they stand out in darkness.
  - Cover vanilla fire enemies: Fire Mage (Stendari), Hellfire Mage (Eldari), Fire Spirit (Liekkiö), Hell Gazer (Helvetinkatse), fire bugs, the flamethrower robot, the Molotov Hiisi and the Dragon.
  - Implement a procedural patch that automatically detects similar fire-related enemies added by other mods and applies the same lighting enhancements.
  - Lanterns attract fire-related enemies.
- **Natural Fear Mode**:
  - Mod settings toggle that changes how enemy categories (`herd_id`) react to lantern light: zombies and monsters avoid it and keep their distance from the player, while Hiisi prefer lit areas.

## Version 0.4

Version 0.4 adds modifiers specific to the new light fixtures.

- **Temple Lantern Modifiers**:
  - Magic liquid modifier: with a small chance, a temple lantern is filled with a magic liquid instead of plasma. It gives no light, and when it breaks it spills one of the magic liquids: Concentrated Mana (`magic_liquid_mana_regeneration`), Flummoxium (`material_confusion`) or Unstable Teleportatium (`magic_liquid_unstable_teleportation`).

## Version 1.0 - Polished State Simulation

Version 1.0 delivers complete physical and chemical state transitions, edge case handling, and release stability.

- **Extinguishing and Submersion**:
  - Implement a 2-second submersion timer: lanterns submerged in water or non-flammable liquids extinguish and cease emitting light.
  - Dynamic state tracking: switch inventory icon to an unlit flask when extinguished.
  - Update in-hand and belt sprites to render unlit containers without flame animations.
  - Magical and hermetic lanterns remain lit underwater.
- **Additional Liquid Interactions**:
  - React to other liquids besides oil and water (e.g., alcohol flicker, toxic sludge tint, blood dimming).
- **Reignition Mechanics**:
  - Reignite unlit lanterns when exposed to open fire, burning materials, or high environmental heat.
- **Full Playthrough Guarantee in Darkness**:
  - Verify that the game can be fully completed with the mod enabled at the darkest vision presets (Minimal 10% and Pitch Black 0%).
  - Guarantee that every biome, including the main path, side biomes, parallel worlds, and boss arenas, offers at least one reliable way to get sufficient illumination (e.g., spawned lanterns, light fixtures, glowing materials, or light sources the player can bring along).
  - Close any biome where no light source can be obtained, by adding guaranteed lantern spawns or other light sources.
- **Full Release Polish**:
  - Finalized balance, performance optimization, and compatibility verification.
