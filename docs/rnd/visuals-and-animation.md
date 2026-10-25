# Visual Rendering and In-Hand Animation

[← Back to R&D Index](../rnd.md)

- **[Confirmed]** When the lantern is in the world, its glass body is rendered by the physics engine from `PhysicsImageShapeComponent` (`lantern_small.png` / `lantern.png`), while `SpriteComponent` renders only the animated flame (`lantern_small_flame.xml` / `lantern_flame.xml`).
- **[Confirmed]** When the lantern is held in hands (`enabled_in_hand`), `PhysicsBodyComponent` is disabled and the body from `PhysicsImageShapeComponent` stops rendering. Therefore, a separate `SpriteComponent` (`_tags="character,enabled_in_hand"`, `_enabled="0"`) is used for hands, referencing a composite spritesheet of the bulb combined with the frame-by-frame flame animation (`lantern_small_in_hand.xml` and `lantern_in_hand.xml`).
- **[Confirmed]** For the flame animation to work in hands, `SpriteAnimatorComponent` must have `_tags="enabled_in_world,enabled_in_hand"`, and the sprite XML must specify `default_animation="default"` and `<RectAnimation name="default" ...>`.
- **[Confirmed]** For the in-hand sprite to mirror properly when the character turns left/right without distortion, the hand `SpriteComponent` requires the attributes `_tags="character,enabled_in_hand"`, `has_special_scale="1"`, `special_scale_x="1"`, and `special_scale_y="1"` (analogous to `data/entities/items/lantern.xml`).
- **[Confirmed]** For the inventory icon (`ui_sprite` in `ItemComponent`), a separate static PNG image of the bulb with flame is required (`ui_lantern_small.png` / `ui_lantern.png`), since the vanilla `lantern_small.png` / `lantern.png` contain only a dark bulb without a flame.
- **[Confirmed]** Swaying in hands during player movement is implemented via a `LuaComponent` ([files/scripts/lantern_in_hand.lua](../../pick_up_your_lantern/files/scripts/lantern_in_hand.lua)) with `_tags="enabled_in_hand"`. Instead of trigonometry based on a global frame timer, it uses a damped harmonic oscillator with numerical integration:
  - Reads player velocity from `CharacterDataComponent` (`mVelocity`) or `VelocityComponent`.
  - Stores state (`lantern_swing_angle`, `lantern_swing_vel`, `lantern_swing_phase`) in `VariableStorageComponent`.
  - Provides physically believable inertial lag opposite to the movement vector (`-vx`), sinusoidal oscillations from footsteps, and smooth damping after stopping.
  - Completely resets internal state (`angle = 0`, `vel = 0`, `phase = 0`) when the player stops and residual oscillations drop below a specified tolerance.

## Flame Desync After Throw

- **[Confirmed]** In the world, the glass body is rendered by the physics body (`PhysicsImageShapeComponent`), whereas the animated flame is rendered by a separate `SpriteComponent` (`lantern_flame.xml` / `lantern_small_flame.xml`) attached to the entity transform. Because of this, they can desync.
- **[Confirmed]** Reproduction: throw the lantern from hands while the character is facing left.
- **[Confirmed]** Cause: the engine mirrors the item in hands using the transform scale (for example, `scale_y = -1` when facing left). After throwing or dropping, the physics body controls only position and rotation, so the flipped scale persists and inverts the flame sprite relative to the body.
- **[Confirmed]** Fix: a `LuaComponent` with the script [files/scripts/lantern_in_world.lua](../../pick_up_your_lantern/files/scripts/lantern_in_world.lua) and tag `enabled_in_world` resets the transform scale to `1`. The script executes once each time the lantern returns to the world: after checking, the component disables itself, and the engine re-enables it via the `enabled_in_world` tag upon the next throw or drop.
