# R&D Notes

This document contains an index of research, Noita engine technical details, and open hypotheses gathered during the development of the **Pick Up Your Lantern** mod.

> [!WARNING]
> Items marked with **[Needs verification]** in articles contain assumptions or partially tested mechanics that require separate in-game verification.

## Current Implementation Issues

- Lanterns do not detach when the support above them is destroyed.
- The lantern icon in the inventory is dark, almost black.
- The lantern in the player's hands sways too violently. When the player starts moving forward, the lantern also moves forward, although physically it should swing backward.

## Planned Features

- "Limited Visibility" game mode, making handheld lanterns significantly more useful.
- "Natural Fear" mode, where zombies and monsters fear lantern light and keep their distance from the player, while Hiisi prefer lit areas.
- Player can pick up open-flame oil lamps and braziers that ignite combustible materials and surrounding enemies, extinguish when submerged in liquid, and reignite near fire.
- "Rogue" mode, where the player is invisible to enemies while they stay far from light (possibly per enemy type: e.g., zombies see in the dark, Hiisi do not).
- Enemy study: an enemy watched in lantern light raises the player's damage against it; the more the player has studied enemies of a type and its relatives (variants of the same enemy, its herd), the faster the next ones of that type are studied.
- Lanterns attract fire-related enemies.
- Displaying the first lantern from the inventory on the player's belt and passive base illumination when the lantern is not equipped as the active item in hands (reference: "Extra Backpack" mod, Steam ID: 3807317449).
- Varied lantern properties (light radius, illuminated area size, quality tiers based on depth) as internal progression.
- Dynamic lantern states influenced by the environment: for example, after the player dips in oil, the lantern shines brighter until the player dives into water.

## Research Articles

- [Vanilla Light Fixture Types](rnd/vanilla-lantern-types.md) - list of main hanging lantern entities in vanilla Noita and their differences.
- [Two Physics Systems of Noita](rnd/physics-systems.md) - analysis of `PhysicsBody2Component` incompatibility with inventory and migration to `PhysicsBodyComponent`.
- [Item Lifecycle in World, Inventory, and Hands](rnd/item-lifecycle.md) - component state management via system tags `enabled_in_world`, `enabled_in_hand`, `enabled_in_inventory`.
- [Visual Rendering and In-Hand Animation](rnd/visuals-and-animation.md) - sprite rendering, frame-by-frame flame animation, flipping, and swaying algorithm.
- [Belt Attachment and Passive Illumination](rnd/belt-attachment.md) - technical options for attaching a lantern to the player character and configuring lighting (reference: "Extra Backpack").
- [Sprite Geometry and Positioning](rnd/sprite-geometry.md) - image geometry, `centered="0"`, axis offsets, and fixing ceiling clipping issues.
- [Ceiling Anchors, Kicking, and Support Destruction](rnd/ceiling-anchors-and-kicking.md) - `PhysicsJointComponent` behavior, joint destruction on pickup, and hypotheses on detachment upon support destruction.
- [Throwing and Impact Physics](rnd/throwing-and-impact-physics.md) - Box2D parameters (`gridworld_box2d`, `is_bullet`), speed thresholds for shattering and explosions.
- [Lantern Throwing Mechanics and Controls](rnd/throwing-mechanics-and-controls.md) - research on throwing exclusively with RMB, LMB blocking, evaluation of tested configurations, and engine limitations.
- [Fog of War Line-of-Sight and Shaders](rnd/line-of-sight-and-shaders.md) - analysis of vanilla fog/lighting system, 2D screen-space raymarching in `post_final.frag`, and technical limitations.
- [Limited Player Vision and Darkness](rnd/player-vision-and-darkness.md) - architecture for overcoming vanilla 35% ambient light, patching `post_final.frag` shader, ECS interaction, and support for absolute Pitch Black.
- [Diff Patch](rnd/diff-patch.md) - single-file library for applying unified diff patches to VFS files and shaders with variable replacement.
- [Player Polymorph and Lighting System](rnd/polymorph-and-lighting.md) - engine polymorph mechanics, `polytools` library, bug with darkness loss after transformation, and fix options.
- [Lantern Progression: Quality Tiers and Modifiers](rnd/lantern-progression.md) - depth-based quality tiers, rare modifiers (flickering, frail), current implementation, and future ideas.
- [Lantern Properties and Dynamic States](rnd/lantern-properties-and-states.md) - lantern quality tiers, depth progression, and lighting changes depending on liquids (oil, water, etc.).
- [Enemy Study](rnd/enemy-study.md) - damage bonus against enemies watched in the light: line of sight and lit area checks, per-enemy bonus storage, damage hooks, and study markers above enemies.
- [Natural Fear](rnd/natural-fear.md) - creatures that lanterns do not attract run from lantern light through the native Escaping AI state; vanilla burning and the AI state table.
- [Fire Enemies](rnd/fire-enemies.md) - brighter light of fire-related enemies: vanilla list, runtime light, detection heuristic for enemies of other mods, and attraction of fire enemies to lanterns in the world through the AI home position.
- [Spawning Fixtures for In-Game Tests](rnd/test-spawning.md) - debug spawner for rare light fixtures, spawn rules, finding biomes and ceiling points in pixel scenes, tested points in the mountain hall at the entrance to the Mines.
- [Extended Light Fixture Support: Progress](rnd/extended-light-fixtures-progress.md) - where the version 0.3 fixture work stopped: done fixtures, remaining temple lantern and chain torches, open issues, steps before merging.
- [Tube Lamp and Electricity](rnd/tube-lamp-electricity.md) - a tube lamp shines only while wired to the ceiling or hit by electricity: power state, cable of segments while carrying, sparking dangling cable, implementation stages.
- [YAML Localization](rnd/yaml-localization.md) - postponed idea of storing translations in YAML (`.yaml.txt`) and converting them to CSV at startup via `tinyyaml`; limitations, pros and cons.
