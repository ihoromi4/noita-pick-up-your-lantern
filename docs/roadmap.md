# Development Roadmap

Development roadmap and release milestones for the **Pick Up Your Lantern** mod for Noita. Detailed functional specifications for each feature are documented in [requirements.md](requirements.md).

## Version 0.1 - MVP and Core Lifecycle

The primary goal of version 0.1 is to deliver a fully functional, stable core gameplay loop for standard hanging oil lanterns (`lantern_small.xml`, `physics_lantern.xml`, `physics_lantern_small.xml`).

- **World Physics and Anchors**:
  - Migrate vanilla lanterns from `PhysicsBody2Component` to `PhysicsBodyComponent` to ensure full inventory compatibility.
  - Establish proper ceiling attachment without clipping into solid pixels (`centered="0"`, custom offsets).
  - Enable realistic kick (`kick`) reactions and detachment via Box2D joint physics.
  - Support ceiling destruction detection: when the ceiling block is destroyed, the lantern detaches and falls.
  - World persistence: ensure detached or picked-up lanterns do not respawn upon chunk reload or returning to the area.
- **Pickup and Inventory Lifecycle**:
  - Proximity pickup via the interaction key (`E`) within immediate melee reach.
  - Integrate with standard `Quick Inventory` item slots (4 slots shared with flasks and stones; wands excluded).
  - Strictly enforce non-stackable behavior (1 slot per lantern) and silent failure when inventory is full.
  - Prevent consuming lantern contents (`drinkable="0"`).
  - Add custom inventory UI icon with illuminated flask.
- **Holding in Hand**:
  - Render lantern sprite (flask container + animated flame) in the player's hand when selected as the active item.
  - Provide 360-degree illumination and clear fog of war around the player.
  - Implement smooth velocity-based swaying during walking and flying (`lantern_in_hand.lua`).
  - Handle horizontal character flipping properly without sprite scale distortion.
  - Guarantee player and environmental safety for closed lanterns in hand (no accidental fires or self-damage).
  - Prevent lantern durability loss or breakage while held in hand.
- **Throwing and Combat**:
  - Support throwing via Right Mouse Button (RMB).
  - Apply physics impact damage to enemies upon collision prior to shattering.
  - Shatter on hard collisions, spilling oil and igniting it into a fire hazard.
  - Preserve fixture intactness on soft landings, allowing re-pickup and kicking.
- **True Dynamic Lighting**:
  - Research and integrate true dynamic lighting options based on the "Light-Up Lanterns" mod (workshop ID: `2316356772`).
  - Provide a toggle in Mod Settings for enhanced lighting shaders/raycasts.
- **Player Vision and Limited Visibility**:
  - Configurable player vision presets in Mod Settings (Vanilla 100%, Dim 75%, Dark 50%, Very Dark 25%, Minimal 10%, Pitch Black 0%).
  - Dual-system vision scaling: proportional reduction of personal illumination and persistent map fog reveal radius.
  - Runtime settings synchronization without game restart.
  - Material illumination and burning entity lighting enhancements cutting through darkness.

## Version 0.1.1 - Item Radar Fix

Version 0.1.1 is a patch release that improves compatibility with vanilla perks.

- **Item Radar Compatibility**:
  - Hide lanterns from the Item Radar perk by default, with a Mod Settings toggle to show them.

## Version 0.2 - Passive Carrying and Atmosphere

Version 0.2 focuses on passive utility and atmospheric carrying mechanics.

- **Belt Attachment and Passive Illumination**:
  - Automatically display the first available lantern from `Quick Inventory` on the character's belt/waist when hands are holding wands, flasks, or items (reference: "Extra Backpack", Steam ID: `3807317449`).
  - Emit moderate passive ambient light from the belt (dimmer than active hand holding, but brighter than unlit player vision).
  - `Belt lantern light` option in Mod Settings to scale the belt light relative to the lantern in hand (0-100%, 50% by default).
  - Hide the belt lantern (sprite and light) whenever any lantern is the active held item, even if other lanterns remain in the inventory.
  - Synchronize belt lantern movement with player locomotion.
- **Lantern Properties and Dynamic States**:
  - Distinct properties per lantern: light radius, fog of war hole size, light color, and durability differ between lantern types and are declared in the lantern XML files.
  - Lantern quality tiers rolled on spawn, with better tiers becoming more likely in deeper biomes; tier is described by an atmospheric sentence in the item description.
  - Rare lantern modifiers rolled independently of the tier, each described by a sentence in the item description: Flickering (20% wider but unstable light) and Short-lived (leaks a drop of oil every 5 seconds, fades over its limited burn time and goes out).
  - `Lantern progression` option in Mod Settings to turn tiers and modifiers off (enabled by default).
  - Oil-soaked state: diving into oil with a lantern in hand makes its light and fog of war hole 30% wider until it is submerged in water. The state is described by a sentence in the item description.
  - Wet state: diving under water with a lantern in hand makes its light and fog of war hole 20% narrower until it is submerged in oil. The state is described by a sentence in the item description.
- **Vision Fixes and Compatibility**:
  - Restore limited vision after returning from polymorph, with a separate `Polymorphed vision` option in Mod Settings for the polymorphed form (`Same as player` by default).
  - Dispel fog of war with duplicate chain torch variants spawned in some biomes (e.g., ghostly torches in Coal Pits).
  - All-Seeing Eye spell (`X_RAY`) compatibility: reveal a slowly expanding circle around the cast point at vanilla brightness, then fade back to the previous lighting.
  - All-Seeing Eye perk (`REMOVE_FOG_OF_WAR`) compatibility: reveal the whole level as in vanilla; holding Sunseed or Sunstone has the same effect.
  - Fix flame sprite desync after throwing a held lantern while facing left.

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
  - Enemy study: while an enemy is within the study radius, in direct line of sight of the player (raycast) and within the light radius of a lantern in the world or in hand (not on the belt), the player's damage against this enemy grows from 0% to the configured bonus. Each enemy type has a knowledge counter: the sum of the study progress (0 to 1) of all its enemies, so five fully studied enemies give 5. Related enemies share part of their knowledge: other variants of the same enemy (e.g. a weak and a normal zombie) give half of theirs, the rest of its herd (`herd_id`, e.g. all Hiisi) a fifth. The study takes the base study time at knowledge 0 and shrinks linearly to 0.5 seconds at knowledge 10. Bosses take 120 seconds and neither give nor get knowledge. An enemy whose study has begun has a small semi-transparent dot above its head: yellow while it is being studied, red while its study is paused (out of light or sight), green once it is fully studied. The accumulated bonus is kept after the enemy leaves the light or the line of sight.
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
  - Cover vanilla fire enemies: Fire Mage (Stendari), Fire Spirit (Liekkiö), Hell Spitter (Helvetin sylkijä), Hell Gazer (Helvetinkatse), Hellfire Mage (Eldari), perhaps some others.
  - Implement a procedural patch that automatically detects similar fire-related enemies added by other mods and applies the same lighting enhancements.
- **Natural Fear Mode**:
  - Mod settings toggle where wild beast and animal enemy categories (`herd_id`) actively avoid lantern light and maintain distance from the player.

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
- **Full Release Polish**:
  - Finalized balance, performance optimization, and compatibility verification.
