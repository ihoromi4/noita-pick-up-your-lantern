# Functional Requirements

Functional requirements for the **Pick Up Your Lantern** mod for Noita.

## Development Roadmap

The release schedule, milestones, and phased breakdown of features across versions (v0.1, v0.1.1, v0.2, v0.3, v0.3.1, v0.4 and v1.0) are maintained in the [Development Roadmap](roadmap.md).

## Light Fixture Catalog

List of light fixtures in the game. Both small lanterns, the large lantern, the temple lantern, the mining lamp, the tube lamp and the three chain torches are pickable items. Torch stands and the burning barrel serve as environmental lights or potential future targets:

- Small Hanging Lantern (Small Lantern): In-game file `data/entities/props/physics/lantern_small.xml`. The most common lantern on a chain, found in Mines, Coalmine, Hiisi Base, and other biomes. Uses `PhysicsBody2Component` + `PhysicsJoint2Component`. Primary target for pickup, holding, and throwing.
- Large Glass Lantern (Physics Lantern): In-game file `data/entities/props/physics_lantern.xml`. Lantern using legacy physics (`PhysicsBodyComponent` + `PhysicsJointComponent`). Found in Town biomes, liquid caves, and others. Fully pickable.
- Alternative Small Lantern: In-game file `data/entities/props/physics_lantern_small.xml`. Legacy physics variant found in Snow Cave, Sand Cave, Meat, etc. Fully pickable.
- Temple Lantern: In-game file `data/entities/props/physics/temple_lantern.xml`. Found in Holy Mountain biomes and temple altars.
- Mining Lamp: In-game file `data/entities/props/physics_mining_lamp.xml`. Found in Hills, mine entrances, and near the lake.
- Fluorescent Tube Lamp (Tubelamp): In-game file `data/entities/props/physics_tubelamp.xml`. Found in The Vault, Snowcastle, and Robobase. Non-oil, electric behavior: it shines only while powered by its cable.
- Hanging Chain Torch: In-game files `data/entities/props/physics/chain_torch.xml` and `data/entities/props/physics_chain_torch.xml`. Found in Dungeons, Crypt, and Wizard Cave.
- Blue Hanging Chain Torch: In-game files `data/entities/props/physics/chain_torch_blue.xml` and `data/entities/props/physics_chain_torch_blue.xml`. Found in Pyramid.
- Ghostly Green Chain Torch: In-game files `data/entities/props/physics/chain_torch_ghostly.xml` and `data/entities/props/physics_chain_torch_ghostly.xml`. Found in Fungi Cave, Coalmines, and temple entrances.
- Torch Stand: In-game file `data/entities/props/physics_torch_stand.xml`. Found in Rainforest, Dragon Cave, and Crypt.
- Blue Torch Stand: In-game file `data/entities/props/physics_torch_stand_blue.xml`. Found in Pyramid and Dark Rainforest.
- Burning Barrel: In-game file `data/entities/props/physics_barrel_burning.xml`. Found in Snowy Depths and Meat biome. Heavy environmental object (non-pickable into inventory).
- Hiisi Base lamps: the Tube Lamp is the only lamp of the Hiisi Base itself (`snowcastle`). The biome also spawns Ghostly Green Chain Torches, Small Lanterns (`snowcastle_cavern`) and a Temple Lantern (`snowcastle_hourglass_chamber`). Candles there give no light, and the forcefield generator lights up only while shielding.

> [!NOTE]
> Initial technical testing begins with light sources found in the first biome (Mines): Small Lantern (most frequent) and Ghostly Chain Torch.

## Modifications to Light Fixtures

- Light fixtures reveal and clear fog of war around themselves (similar to the "Light-Up Lanterns" mod).
- Pickable light fixtures (such as small and large glass lanterns) can be picked up into the inventory, held in hand for illumination, and thrown.

## In-World State and Physics

- Light fixtures spawn at their standard positions in biomes, anchored to the ceiling at the correct height.
- In-world fixtures behave as physical objects according to their material properties (metal for most lanterns).
- Sinking and submersion:
  - Lanterns are denser than water and sink to the bottom of liquid pools.
  - When submerged in liquid (e.g., water), an unsealed lantern extinguishes after a 2-second delay and ceases to emit light.
  - High-velocity impacts even within liquids shatter the lantern, spilling oil that floats to the surface and ignites (matching vanilla physics behavior).
  - An extinguished lantern can be reignited by bringing it into contact with fire or high heat.
  - Hermetic or magical lanterns do not extinguish under liquids.
- The fixture emits light and has an animated flame inside the container.
- Physical reactions:
  - Sways from impacts and can be detached from the ceiling with a kick (`kick`), following a realistic physical flight trajectory.
  - When the anchor ceiling is destroyed, the fixture detaches and falls.
- Destruction:
  - Heavy impacts, falls from significant heights, or projectile hits cause the glass lantern to shatter, spilling oil and igniting it in a small fiery explosion.
- World persistence:
  - Once a fixture has been detached or picked up, it must not respawn when the chunk reloads or when returning to previously visited areas.

## Pickup and Inventory

- Controls and reach:
  - Intact pickable fixtures (hanging or lying on the ground) are picked up using the standard interaction key (`E`).
  - The player must be in immediate physical proximity (melee reach) to pick up a fixture. Ceiling-mounted fixtures out of reach require flying up close or dislodging them first (e.g. by kicking or shooting).
- Inventory behavior:
  - Lanterns occupy a standard item slot in the `Quick Inventory` (the 4 item slots shared with flasks and stones; they cannot be placed in wand slots).
  - Lanterns do not stack; each lantern occupies a separate inventory slot.
  - If all 4 item slots are full, attempting to pick up a lantern fails silently (nothing happens).
- Detachment:
  - Picking up a hanging fixture cleanly removes it from the ceiling without leaving duplicates or residual anchor entities behind.
- UI presentation:
  - In the inventory, the fixture has its own custom name, description, and a distinct icon (flask with a flame inside).
  - If the lantern is extinguished, the inventory icon updates to an unlit flask without a flame.
  - The player cannot consume/drink oil directly from the lantern.

## Holding in Hand

- When the fixture is selected as the active item in the inventory, it is rendered in the character's hand (both the container and the animated flame).
- If the held lantern is extinguished, it renders an unlit container sprite without a flame animation and emits no light.
- The held fixture actively illuminates the space around the player when lit.
- Hand stability and movement:
  - While walking or levitating/flying, the held fixture smoothly sways in sync with player movement, settling back into a vertical position upon stopping.
  - When the character turns left or right, the held fixture flips and repositions properly without visual scaling distortions.
- Durability in hand:
  - The fixture cannot break while held in hand.
  - Damage taken by the player does not reduce the fixture's durability or cause it to explode in hand.
- Safety of closed fixtures:
  - Standard enclosed lanterns held in hand are completely safe for the player and surrounding environment: they do not ignite the player, wooden structures, gases, or liquids nearby as long as they are held intact.

## Belt Attachment and Passive Illumination

- Passive belt display:
  - When the player is not actively holding a lantern in hand (e.g., holding a wand, flask, item, or empty hands), the first lantern found in the player's quick inventory is displayed visually attached to the character's belt/waist.
  - When the player switches to holding the lantern in hand as the active item, the belt attachment is hidden and replaced by the held-in-hand animation.
- Passive illumination:
  - While attached to the belt, a lit lantern provides passive illumination around the player.
  - The illumination radius and intensity are noticeably better than base unlit player vision, but lower/dimmer than when actively holding the lantern in hand.
  - If the lantern on the belt is extinguished, it renders an unlit sprite and emits no passive light.
- Visual movement and physics:
  - The belt-mounted lantern sways naturally with player movement and flight.
  - Technical reference: Dynamic attachment of an item to the character model is implemented in the "Extra Backpack" mod (Steam ID: `3807317449`).

## Throwing and Weapon Usage

- Controls:
  - Behaving like vanilla throwable items (e.g., flasks), lanterns can be dropped from the inventory or thrown toward the cursor using the standard throw action (Right Mouse Button / aim).
  - The Left Mouse Button never throws a held lantern. It hangs the lantern on the ceiling directly above the player, as if it had just spawned there: on a joint, swinging, kickable, and falling when the ceiling is destroyed. The hands then take the first wand from the Quick Inventory, or the first item if there are no wands. If there is no ceiling within reach, the lantern stays in hand.
- Trajectory and flight:
  - A thrown fixture is completely untethered from any ceiling anchors and travels along a free physical trajectory.
  - Correctly collides with walls, floors, and ceilings without clipping or vibrating inside geometry.
- Impact and damage:
  - Colliding with an enemy deals physics impact damage before the lantern shatters (matching vanilla physics object impact behavior).
  - A sufficiently hard impact against solid surfaces or enemies shatters the lantern, spilling oil and igniting the impact zone.
  - Hard impact and damage thresholds reference vanilla throwable physics calculations.
  - If thrown softly or onto non-destructive surfaces without exceeding the impact threshold, the fixture remains intact on the ground, continues emitting light, and can be picked up again or kicked.

## Extended Interactions and Research

- Magical darkness:
  - Light fixtures do not illuminate areas afflicted by magical darkness.
- Environmental fog of war:
  - Fixtures clear fog of war in an area around them, allowing the player to spot threats from afar.
- Rogue mode (Under Investigation):
  - Mod settings toggle for "Rogue": the player is invisible to enemies while they stay far from light.
  - Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).
- Enemy study:
  - A separate "Enemy Study" category in Mod Settings, not affected by presets: a toggle for the mechanic (off by default), the bonus of a fully studied enemy (10%, 25%, 50%, 100%) and the base study time (3, 5, 10, 30 seconds; 10 by default).
  - While an enemy is within the study radius, in direct line of sight of the player (raycast) and within the light radius of a lantern in the world or in hand (not on the belt) or of a projectile with the Light spell modifier (`LIGHT`), the player's damage against this enemy grows from 0% to the configured bonus. An enemy whose study has begun has a small semi-transparent dot above its head: yellow while it is being studied, red while its study is paused (out of light or sight), green once it is fully studied.
  - The player studies enemy types. Each enemy type has a knowledge counter: the sum of the study progress (0 to 1) of all its enemies, so five fully studied enemies give 5. Related enemies share part of their knowledge: other variants of the same enemy (e.g. a weak and a normal zombie) give half of theirs, the rest of its herd (`herd_id`, e.g. all Hiisi) a fifth. The study takes the base study time at knowledge 0 and shrinks linearly to 0.5 seconds at knowledge 10. Bosses take 120 seconds and neither give nor get knowledge.
  - The accumulated bonus is kept after the enemy leaves the light or the line of sight.
- Fire enemies:
  - Fire-related enemies glow noticeably brighter than other enemies and dispel fog of war around themselves, so they stand out in darkness. Always on.
  - Vanilla fire enemies have tuned light; fire-related enemies of other mods are detected automatically.
  - Lit lanterns in the world attract fire-related enemies: they gather around the lantern and do not attack it. The light holds them in a trance: they notice the player only up close and fight as usual once they find prey (the player came close or hurt them). Enemies that already hunt are not lured. Lanterns in hand, in the inventory or on the belt do not attract. A Mod Settings toggle, on by default and not affected by presets.
- Natural Fear Mode:
  - Mod settings toggle for "Natural Fear": enemy categories (`herd_id`) react to lantern light. Zombies and monsters avoid it and keep their distance from the player, while Hiisi prefer lit areas. Hiisi and insects (herds `orcs` and `fly`) are attracted to lit lanterns in the world, as fire enemies are. All other enemies (zombies, slime creatures and other monsters) fear the light of lanterns in the world and in hand, even while hunting, and keep to the dark. The toggle is off by default and not affected by presets.
- Open-flame variants:
  - Separate class of open-flame lamps/torches that can actively ignite flammable surfaces and enemies on contact, extinguish quickly in liquid, and reignite near fire.
- Limited Visibility Mode:
  - The `Player vision` option reduces the player's innate vision radius, making handheld lanterns essential for navigating dark biomes. The settings presets set it together with the other options.
- Dynamic Lighting Mode:
  - Mod settings toggle for true dynamic lighting (dependent on separate R&D into engine lighting hooks).

## Compatibility

- Verify compatibility with the "Light-Up Lanterns" mod (ID: `Lightup`, Steam ID: `2316356772`). Incompatibility is highly probable and should be explicitly stated in the mod description.
