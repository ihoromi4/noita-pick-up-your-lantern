# R&D Notes

This document contains an index of research, Noita engine technical details, and open hypotheses gathered during the development of the **Pick Up Your Lantern** mod.

> [!WARNING]
> Items marked with **[Needs verification]** in articles contain assumptions or partially tested mechanics that require separate in-game verification.

## Planned Features

Features planned for the next versions are listed in the [Backlog](../backlog.md). These ideas still need research:

- Player can pick up open-flame oil lamps and braziers that ignite combustible materials and surrounding enemies, extinguish when submerged in liquid, and reignite near fire.
- "Rogue" mode, where the player is invisible to enemies while they stay far from light (possibly per enemy type: e.g., zombies see in the dark, Hiisi do not).

## Research Articles

### Entities and Fixtures

- [Vanilla Light Fixture Types](entities/vanilla-lantern-types.md) - list of main hanging lantern entities in vanilla Noita and their differences.
- [Extended Light Fixtures](entities/extended-light-fixtures.md) - results of making the mining lamp, tube lamp, temple lantern and chain torches pickable: engine findings, approaches tried and rejected, open issues.
- [Two Physics Systems of Noita](entities/physics-systems.md) - analysis of `PhysicsBody2Component` incompatibility with inventory and migration to `PhysicsBodyComponent`.
- [Sprite Geometry and Positioning](entities/sprite-geometry.md) - image geometry, `centered="0"`, axis offsets, and fixing ceiling clipping issues.
- [Ceiling Anchors, Kicking, and Support Destruction](entities/ceiling-anchors-and-kicking.md) - `PhysicsJointComponent` behavior, joint destruction on pickup, and hypotheses on detachment upon support destruction.
- [Native Physics Chain for Chain Torches](entities/native-chain-torch.md) - experiment with a real Box2D chain built with `PhysicsAddBodyImage` and `PhysicsAddJoint`, as the vanilla duplicate torches do: its links cannot be shot through, so chain torches stay on the Lua chain.
- [Tube Lamp and Electricity](entities/tube-lamp-electricity.md) - a tube lamp shines only while wired to the ceiling or hit by electricity: power state, cable of segments while carrying, sparking dangling cable, implementation stages.

### Mechanics, Holding, and Throwing

- [Item Lifecycle in World, Inventory, and Hands](mechanics/item-lifecycle.md) - component state management via system tags `enabled_in_world`, `enabled_in_hand`, `enabled_in_inventory`.
- [Visual Rendering and In-Hand Animation](mechanics/visuals-and-animation.md) - sprite rendering, frame-by-frame flame animation, flipping, and swaying algorithm.
- [Belt Attachment and Passive Illumination](mechanics/belt-attachment.md) - technical options for attaching a lantern to the player character and configuring lighting (reference: "Extra Backpack").
- [Throwing and Impact Physics](mechanics/throwing-and-impact-physics.md) - Box2D parameters (`gridworld_box2d`, `is_bullet`), speed thresholds for shattering and explosions.
- [Lantern Throwing Mechanics and Controls](mechanics/throwing-mechanics-and-controls.md) - research on throwing exclusively with RMB, LMB blocking, evaluation of tested configurations, and engine limitations.

### Progression and States

- [Lantern Progression: Quality Tiers and Modifiers](progression/lantern-progression.md) - depth-based quality tiers, rare modifiers (flickering, frail), current implementation, and future ideas.
- [Lantern Properties and Dynamic States](progression/lantern-properties-and-states.md) - lantern quality tiers, depth progression, and lighting changes depending on liquids (oil, water, etc.).

### Vision and Lighting

- [Fog of War Line-of-Sight and Shaders](lighting/line-of-sight-and-shaders.md) - analysis of vanilla fog/lighting system, 2D screen-space raymarching in `post_final.frag`, and technical limitations.
- [Limited Player Vision and Darkness](lighting/player-vision-and-darkness.md) - architecture for overcoming vanilla 35% ambient light, patching `post_final.frag` shader, ECS interaction, and support for absolute Pitch Black.
- [All-Seeing Eye Projectile Lifetime](lighting/all-seeing-eye-lifetime.md) - how spell modifiers change the `lifetime` of the All-Seeing Eye projectile, why the projectile disappears after about 64 frames, and how the reveal timer is computed.
- [Player Polymorph and Lighting System](lighting/polymorph-and-lighting.md) - engine polymorph mechanics, `polytools` library, bug with darkness loss after transformation, and fix options.

### Creatures and AI

- [Fire Enemies](creatures/fire-enemies.md) - brighter light of fire-related enemies: vanilla list, runtime light, detection heuristic for enemies of other mods, and attraction of fire enemies to lanterns in the world through the AI home position.
- [Natural Fear](creatures/natural-fear.md) - creatures that lanterns do not attract run from lantern light through the native Escaping AI state; vanilla burning and the AI state table.

### Tooling and Infrastructure

- [Diff Patch](tooling/diff-patch.md) - single-file library for applying unified diff patches to VFS files and shaders with variable replacement.
- [Spawning Fixtures for In-Game Tests](tooling/test-spawning.md) - a temporary debug spawner for rare light fixtures, spawn rules, finding biomes and ceiling points in pixel scenes, tested points in the mountain hall at the entrance to the Mines.
- [YAML Localization](tooling/yaml-localization.md) - postponed idea of storing translations in YAML (`.yaml.txt`) and converting them to CSV at startup via `tinyyaml`; limitations, pros and cons.
