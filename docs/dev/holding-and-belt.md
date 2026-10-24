# Holding and Belt

How a lantern is drawn and animated in the player's hand and on the player's belt.

## Contents

- [Sprites in the World and in Hand](#sprites-in-the-world-and-in-hand)
- [Mirroring](#mirroring)
- [Inventory Icon](#inventory-icon)
- [Swinging](#swinging)
- [Flame Desync After Throw](#flame-desync-after-throw)
- [Belt Lantern](#belt-lantern)

## Sprites in the World and in Hand

- **In the world**, the glass body is drawn by the physics engine from `PhysicsImageShapeComponent` (`lantern_small.png`, `lantern.png`). A `SpriteComponent` draws only the animated flame (`lantern_small_flame.xml`, `lantern_flame.xml`).
- **In hand**, `PhysicsBodyComponent` is disabled, so the body from `PhysicsImageShapeComponent` is not drawn. A separate `SpriteComponent` with `_tags="character,enabled_in_hand"` and `_enabled="0"` draws a combined sprite sheet of the glass and the flame animation: `files/props_gfx/lantern_in_hand.xml` and `lantern_small_in_hand.xml`.
- For the flame to animate in hand, `SpriteAnimatorComponent` needs `_tags="enabled_in_world,enabled_in_hand"`, and the sprite XML needs `default_animation="default"` with a `<RectAnimation name="default" ...>`.
- A burnt-out lantern uses `lantern_in_hand_out.xml` and `lantern_small_in_hand_out.xml`: the glass without a flame.

## Mirroring

For the in-hand sprite to flip with the character without distortion, its `SpriteComponent` needs `_tags="character,enabled_in_hand"`, `has_special_scale="1"`, `special_scale_x="1"` and `special_scale_y="1"`, as in vanilla `data/entities/items/lantern.xml`.

## Inventory Icon

The vanilla `lantern_small.png` and `lantern.png` show a dark glass without a flame, so `ItemComponent.ui_sprite` points to separate static icons with a lit flame: `files/props_gfx/ui_lantern_small.png` and `ui_lantern.png`.

## Swinging

`files/scripts/lantern_in_hand.lua` runs every frame while the lantern is held (`_tags="enabled_in_hand"`). It is a damped spring pendulum integrated per frame:

- reads the player velocity from `CharacterDataComponent.mVelocity` or `VelocityComponent`;
- tilts the lantern against the direction of movement, adds a sine sway for steps, and lets the swing die down after the player stops;
- stores `lantern_swing_angle`, `lantern_swing_vel` and `lantern_swing_phase` in `VariableStorageComponent`, so the state survives inventory switches;
- resets the state to zero once the player stands still and the remaining swing falls below the tolerance.

Tuning constants are at the top of the script: `SPRING_K`, `DAMPING`, `TILT_FACTOR`, `SWAY_AMOUNT`, `STEP_FREQ`, `MAX_TARGET_ANGLE`, `MAX_ANGLE`, `VELOCITY_THRESHOLD`.

## Flame Desync After Throw

In the world, the glass body and the flame sprite are separate: the glass follows the physics body, the flame follows the entity transform.

The engine mirrors a held item through the transform scale, for example `scale_y = -1` while facing left. After a throw or drop, the physics body controls only position and rotation, so the mirrored scale stays and flips the flame away from the glass.

`files/scripts/lantern_in_world.lua`, tagged `enabled_in_world`, resets the transform scale to `1`. It runs once each time the lantern enters the world: after the check it disables its own component, and the engine enables it again through the tag on the next throw or drop.

## Belt Lantern

When the hands hold anything other than a lantern, the first lantern from the Quick Inventory hangs on the player's belt and gives off a dimmer light.

The approach follows the "Extra Backpack" mod (Steam ID `3807317449`), which hangs a bag on the vanilla `belt_root` hotspot, the same hotspot the vanilla rat tail uses. No code or graphics are copied from it.

### Entity

```text
player
└── pul_belt_lantern  (tag pul_belt)
    ├── InheritTransformComponent  belt_root, only_position="1"
    ├── LuaComponent               lantern_in_hand.lua (pendulum)
    ├── SpriteComponent            copy of the lantern's in-hand sprite, scale 0.6
    ├── LightComponent             only for a lit lantern
    └── SpriteComponent            fog_of_war_hole, if the lantern has one
```

- `files/entities/lantern_belt.xml` declares the attachment and the pendulum. Lua adds the sprite, light and fog of war hole from the data of the carried lantern.
- The belt reuses the in-hand pendulum instead of a verlet chain, because the pendulum already works with the animated `lantern_in_hand.xml` sprite.
- `only_position="1"` leaves rotation and scale free: the pendulum sets the rotation, and `scale_x = ±1` is copied from the player every frame.

### Update Loop

`UpdateLanternBelt()` in `files/scripts/lantern_belt.lua` runs from `OnWorldPostUpdate`, so mirroring is applied in the same frame before rendering:

- If the held item is any lantern, all `pul_belt` entities are killed. The belt shows nothing even if other lanterns are in the inventory.
- Otherwise the lantern with the lowest `ItemComponent.inventory_slot` in `inventory_quick` is used.
- The belt entity stores the lantern ID and whether it was lit (`belt_lantern_id`, `belt_lantern_lit`). If either no longer matches, for example another lantern, a lantern that went out, a reloaded player or a return from polymorph, the entity is recreated.

### Light

- Light radius: `GetLanternLightRadius(lantern_id, illumination_scale * tier * belt_light_scale) * GetLanternModifierFactor()`.
- Fog of war hole: `GetLanternFogHoleScale(lantern_id, illumination_scale * tier * belt_light_scale)`.
- Both start from the base of the carried lantern's type, and the light color is copied from its `LightComponent`. The liquid state of the carried lantern applies too.
- `belt_light_scale` is the `Belt lantern light` setting (0–100%, 50% by default). It applies immediately.
- The patched `post_final.frag` lets lights through the limited vision darkness, so the belt light works under every vision preset.

### Modifiers

Flickering and burn time logic lives in `lantern_traits.lua` (`ConsumeLanternFuel`, `GetLanternModifierFactor`), so it applies to the belt light too. A Short-lived lantern on the belt keeps burning fuel. When the fuel runs out, the belt shows a burnt-out lantern, and the item itself is extinguished (`ExtinguishLantern`) the next time it is taken in hand or dropped. This avoids touching disabled item components in the inventory.

Tuning constants in `lantern_belt.lua`: `SPRITE_SCALE`, `SPRITE_Z_INDEX`.
