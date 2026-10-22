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
  - Support throwing via Right Mouse Button (RMB) aim or dropping from inventory.
  - Apply physics impact damage to enemies upon collision prior to shattering.
  - Shatter on hard collisions, spilling oil and igniting it into a fire hazard (including high-velocity impacts in water).
  - Preserve fixture intactness on soft landings, allowing re-pickup and kicking.
- **True Dynamic Lighting**:
  - Research and integrate true dynamic lighting options based on the "Light-Up Lanterns" mod (workshop ID: `2316356772`).
  - Provide a toggle in Mod Settings for enhanced lighting shaders/raycasts.

## Version 0.1.1 - Item Radar Fix

Version 0.1.1 is a patch release that improves compatibility with vanilla perks.

- **Item Radar Compatibility**:
  - Hide lanterns from the Item Radar perk by default, with a Mod Settings toggle to show them.

## Version 0.2 - Passive Carrying and Atmosphere

Version 0.2 focuses on visual polish, passive utility, and atmospheric difficulty enhancement.

- **Belt Attachment and Passive Illumination**:
  - Automatically display the first available lantern from `Quick Inventory` on the character's belt/waist when hands are holding wands, flasks, or items (reference: "Extra Backpack", Steam ID: `3807317449`).
  - Emit moderate passive ambient light from the belt (dimmer than active hand holding, but brighter than unlit player vision).
  - Hide belt lantern sprite when a lantern is selected as the active held item.
  - Synchronize belt lantern movement with player locomotion.
- **Limited Visibility Mode**:
  - Mod settings toggle reducing the player's innate vision radius in dark biomes.
  - Enhances survival atmosphere and makes handheld and belt-mounted lanterns critical for navigation.

## Version 0.3 - Variety and World Interactions

Version 0.3 expands the scope to other environmental light fixtures, danger mechanics, and world incentives.

- **Extended Light Fixture Support**:
  - Support hanging chain torches (`chain_torch.xml`, `chain_torch_blue.xml`, `chain_torch_ghostly.xml`).
  - Support mining lamps (`physics_mining_lamp.xml`) and temple lanterns (`temple_lantern.xml`).
  - Support fluorescent tube lamps (`physics_tubelamp.xml`) and Hiisi Base fixtures.
- **Open-Flame Variants**:
  - Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
  - Immediate extinguishing upon liquid contact (without a delay).
- **Strategic World Incentives**:
  - Implement gameplay incentives for leaving light fixtures hanging in the world (e.g., safe illumination zones, stations to reignite unlit lanterns, enemy debuff zones, or fog of war landmarks).
  - Counteract the tendency to treat lanterns purely as disposable weapons.
- **Natural Fear Mode**:
  - Mod settings toggle where wild beast and animal enemy categories (`herd_id`) actively avoid lantern light and maintain distance from the player.

## Version 1.0 - Polished State Simulation

Version 1.0 delivers complete physical and chemical state transitions, edge case handling, and release stability.

- **Extinguishing and Submersion**:
  - Implement a 2-second submersion timer: lanterns submerged in water or non-flammable liquids extinguish and cease emitting light.
  - Dynamic state tracking: switch inventory icon to an unlit flask when extinguished.
  - Update in-hand and belt sprites to render unlit containers without flame animations.
  - Magical and hermetic lanterns remain lit underwater.
- **Reignition Mechanics**:
  - Reignite unlit lanterns when exposed to open fire, burning materials, or high environmental heat.
- **Full Release Polish**:
  - Finalized balance, performance optimization, and compatibility verification.
