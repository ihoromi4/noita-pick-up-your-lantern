# Version 0.1.0 - MVP and Core Lifecycle

Tracking document for features, implementation progress, and known issues for **Version 0.1.0**. All releases are listed in [Versions](README.md).

## World Physics and Anchors

- Migrate lanterns from `PhysicsBody2Component` to `PhysicsBodyComponent` (`lantern_small.xml`, `physics_lantern.xml`, `physics_lantern_small.xml`).
- Fix ceiling attachment clipping via proper offsets (`centered="0"`, `offset_x="4.5"`, `offset_y="3.5"`, `pos_y="1"`).
- Enable kick detachment (`kick`) via native `Message_Kick` event and physical impulse (`lantern_anchor.lua`).
- Detachment on support collapse: lanterns detach and fall when ceiling pixels are destroyed via periodic raycast check (`lantern_anchor.lua`).
- World persistence: verify that lanterns detached or picked up do not respawn when chunks are reloaded.

## Pickup and Inventory Lifecycle

- Add `ItemComponent` with `preferred_inventory="QUICK"` and `is_pickable="1"`.
- Prevent drinking oil directly from lantern (`drinkable="0"`).
- Support clean pickup via interaction key (`E`) within melee reach without leaving ghost entities or broken joints on the ceiling.
- Ensure lanterns occupy standard quick inventory item slots (non-stackable).
- Full inventory edge case: verify pickup fails silently when all 4 item slots are full.
- Item name display: fix lantern name displaying as an empty line in the world hover tooltip and in inventory (localized for en, ru, pl, zh-cn).
- Add custom inventory UI icon with illuminated flask (`ui_lantern.png`, `ui_lantern_small.png`).
- Fix dark inventory icon rendering: removed `MaterialInventoryComponent` and `PotionComponent`, handled oil (4) and fire (2) spill via custom death scripts.

## Holding in Hand

- Render lantern container with animated flame in player's hand when selected as active item (`lantern_small_in_hand.xml`, `lantern_in_hand.xml`).
- Ensure sprite flips horizontally without distortion when character changes facing direction (`has_special_scale="1"`).
- Ambient illumination around the player using `LightComponent` (`radius="240"`).
- Guarantee player and environment safety while held (no accidental player burn or surface ignition).
- Prevent lantern durability loss or breakage while held in hand (`DamageModelComponent` enabled only in world).
- Movement swaying tuning: implemented spring-damper pendulum model in `lantern_in_hand.lua` with natural inertial lag, footstep sway, and clean state reset within tolerance on stop.

## Throwing and Combat

- Support throwing via Right Mouse Button (RMB) aim and dropping from inventory (`throw_as_item="1"`).
- Apply physics impact damage to enemies on collision prior to shattering (`ProjectileComponent`).
- Calibrate shatter velocity threshold (`speed_threshold="80.0"` in `PhysicsBodyCollisionDamageComponent`).
- Shatter effect: small explosion, oil spill, and fire ignition on hard collision (`ExplodeOnDamageComponent`, custom death scripts).
- Soft throw handling: lantern lands intact on soft impact and can be kicked or picked up again.

## True Dynamic Lighting

- Investigate dynamic lighting hooks and shader implementation from "Light-Up Lanterns" (Steam ID: `2316356772`).
- Add Mod Settings configuration toggle to enable/disable true dynamic lighting ("Illuminate the darkness").
- Implement dynamic fog of war hole injection for lanterns and fixtures using `nxml` (`patch_lighting.lua`) with calibrated flame offsets and configurable illumination scale (100%-500%).

## Player Vision and Limited Visibility

- Add player vision presets in Mod Settings (Vanilla 100%, Dim 75%, Dark 50%, Very Dark 25%, Minimal 10%, Pitch Black 0%).
- Dual-system vision scaling: proportional reduction of personal illumination and persistent map fog reveal radius.
- Real-time setting synchronization: seamless runtime adjustments via pause menu without game restart.
- Absolute darkness mode (Pitch Black): complete zero visibility in unlit underground areas without handheld lanterns or world light sources.
- Seamless lighting synergy: light from held or thrown lanterns, world fixtures, and fires cuts through the darkness.
- Material illumination and burning entity lighting: enhanced glow attributes for fire, molten metals, radioactive liquid, acid, and sparks, dynamic light on burning entities (`effect_on_fire.xml`), and glow buffer integration in post-processing shaders (`post_final.frag`, `post_glow1.frag`, `post_glow2.frag`).
- Automatic fallback to normal visibility upon player death for clear game-over view.
