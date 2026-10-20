# Version 0.1 - MVP and Core Lifecycle

Tracking document for features, implementation progress, and known issues for **Version 0.1**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md).

## World Physics and Anchors

- [x] Migrate lanterns from `PhysicsBody2Component` to `PhysicsBodyComponent` (`lantern_small.xml`, `physics_lantern.xml`, `physics_lantern_small.xml`).
- [x] Fix ceiling attachment clipping via proper offsets (`centered="0"`, `offset_x="4.5"`, `offset_y="3.5"`, `pos_y="1"`).
- [x] Enable kick detachment (`kick`) via native `Message_Kick` event and physical impulse (`lantern_anchor.lua`).
- [x] Detachment on support collapse: lanterns detach and fall when ceiling pixels are destroyed via periodic raycast check (`lantern_anchor.lua`).
- [x] World persistence: verify that lanterns detached or picked up do not respawn when chunks are reloaded.

## Pickup and Inventory Lifecycle

- [x] Add `ItemComponent` with `preferred_inventory="QUICK"` and `is_pickable="1"`.
- [x] Prevent drinking oil directly from lantern (`drinkable="0"`).
- [x] Support clean pickup via interaction key (`E`) within melee reach without leaving ghost entities or broken joints on the ceiling.
- [x] Ensure lanterns occupy standard quick inventory item slots (non-stackable).
- [x] Full inventory edge case: verify pickup fails silently when all 4 item slots are full.
- [x] Item name display: fix lantern name displaying as an empty line in the world hover tooltip and in inventory (localized for en, ru, pl, zh-cn).
- [x] Add custom inventory UI icon with illuminated flask (`ui_lantern.png`, `ui_lantern_small.png`).
- [x] Fix dark inventory icon rendering: removed `MaterialInventoryComponent` and `PotionComponent`, handled oil (4) and fire (2) spill via custom death scripts.

## Holding in Hand

- [x] Render lantern container with animated flame in player's hand when selected as active item (`lantern_small_in_hand.xml`, `lantern_in_hand.xml`).
- [x] Ensure sprite flips horizontally without distortion when character changes facing direction (`has_special_scale="1"`).
- [x] Ambient illumination around the player using `LightComponent` (`radius="240"`).
- [x] Guarantee player and environment safety while held (no accidental player burn or surface ignition).
- [x] Prevent lantern durability loss or breakage while held in hand (`DamageModelComponent` enabled only in world).
- [x] Movement swaying tuning: implemented spring-damper pendulum model in `lantern_in_hand.lua` with natural inertial lag, footstep sway, and clean state reset within tolerance on stop.

## Throwing and Combat

- [x] Support throwing via Right Mouse Button (RMB) aim and dropping from inventory (`throw_as_item="1"`).
- [x] Apply physics impact damage to enemies on collision prior to shattering (`ProjectileComponent`).
- [x] Calibrate shatter velocity threshold (`speed_threshold="80.0"` in `PhysicsBodyCollisionDamageComponent`).
- [x] Shatter effect: small explosion, oil spill, and fire ignition on hard collision (`ExplodeOnDamageComponent`, custom death scripts).
- [x] Soft throw handling: lantern lands intact on soft impact and can be kicked or picked up again.

## True Dynamic Lighting

- [x] Investigate dynamic lighting hooks and shader implementation from "Light-Up Lanterns" (Steam ID: `2316356772`).
- [x] Add Mod Settings configuration toggle to enable/disable true dynamic lighting ("Illuminate the darkness").
- [x] Implement dynamic fog of war hole injection for lanterns and fixtures using `nxml` (`patch_lighting.lua`) with calibrated flame offsets and configurable illumination scale (100%-500%).

## Player Vision and Limited Visibility

- [x] Add player vision presets in Mod Settings (Vanilla 100%, Dim 75%, Dark 50%, Very Dark 25%, Minimal 10%, Pitch Black 0%).
- [x] Dual-system vision scaling: proportional reduction of personal illumination and persistent map fog reveal radius.
- [x] Real-time setting synchronization: seamless runtime adjustments via pause menu without game restart.
- [x] Absolute darkness mode (Pitch Black): complete zero visibility in unlit underground areas without handheld lanterns or world light sources.
- [x] Seamless lighting synergy: light from held or thrown lanterns, world fixtures, and fires cuts through the darkness.
- [x] Material illumination and burning entity lighting: enhanced glow attributes for fire, molten metals, radioactive liquid, acid, and sparks, dynamic light on burning entities (`effect_on_fire.xml`), and glow buffer integration in post-processing shaders (`post_final.frag`, `post_glow1.frag`, `post_glow2.frag`).
- [x] Automatic fallback to normal visibility upon player death for clear game-over view.
