# Backlog

This document lists the tasks that are not done yet. Tasks are grouped by topic. The release schedule is in the [Development Roadmap](roadmap.md).

## Rules

- Keep open tasks only in this document. Group them by topic.
- When a task is done, remove it from this document.
- Then describe the result in one to three sentences in the notes of the version that includes it. The notes are the `version-X.Y.Z.md` files in [versions/](versions/). Put the description under `Completed Work` or under a section for its topic. If the version has no notes file yet, create it with the first completed task.

## All-Seeing Eye Spell

- Bug: spell modifiers that change the projectile lifetime do not change how long the All-Seeing Eye spell (`X_RAY`) reveals the area. The projectile lifetime is the number of frames before the projectile disappears. It is the `lifetime` field of the `ProjectileComponent`. The vanilla projectile `data/entities/projectiles/deck/xray.xml` has `lifetime="1000"`, which is about 17 seconds. Modifiers add `c.lifetime_add` to this value. Examples are `ZERO_DAMAGE` (+280 frames), `LIFETIME` (+75 frames), `LIFETIME_DOWN` (-42 frames), and `SHORTLIVED_SHOT` (-200 frames).
  - Cause: the projectile only starts the reveal circle. The reveal circle is the area that the mod passes to the shader as `pul_xray`, so the limited vision does not darken it. `RegisterXRayProjectiles` in `files/scripts/all_seeing_eye.lua` creates the circle when it first finds a new projectile with the `pul_xray` tag. After that, `AdvanceXRayReveal` runs the circle on fixed timers. The circle grows by `XRAY_GROWTH_PER_FRAME` pixels per frame. Once it covers the screen or reaches `XRAY_MAX_RADIUS`, it fades out over `XRAY_FADE_FRAMES` (600 frames). The script never reads the projectile lifetime and does not react to the death of the projectile.
  - As a result, the circle always lasts about 12 to 13 seconds, whatever the modifiers are. With `ZERO_DAMAGE`, the projectile lives for 1280 frames, but the circle still disappears after the same 12 to 13 seconds.
  - Possible fix: link the circle to the projectile lifetime. When a new projectile is found, read the `lifetime` of its `ProjectileComponent` and store it in the circle. Keep the circle at full strength while the projectile is alive, and start the fading when the projectile dies. First, check in the game that the `lifetime` field already includes `c.lifetime_add` at that moment.
  - A repeated cast takes over the size and strength of the active circle. The fix should also take over the lifetime of the new projectile, so the latest cast decides when the fading starts.
  - Modifiers that shorten the lifetime should make the circle shorter, but the circle must still appear. The script finds a projectile only if it lives until the next `OnWorldPreUpdate`.
- Change: the reveal circle stays open while the player stays near the cast point. The cast point is the position of the All-Seeing Eye projectile. The projectile has `speed_min="0"` and `speed_max="0"`, so it does not move after the cast. The reveal timer starts to count down only when the player first moves farther than the hold distance from the cast point. The reveal timer is the number of frames left before the circle starts to fade. The hold distance is a new constant, for example `XRAY_HOLD_DISTANCE`, and its value is still to be chosen.
  - While the player stays within the hold distance, the timer does not start, and the circle keeps its full strength.
  - Once the player has left, the timer counts down until the end and does not stop again. Coming back to the cast point does not pause the timer or the fading. The circle needs a flag, for example `is_released`, that turns on once and never turns off.
  - The reveal timer starts from the projectile lifetime, see the bug above. The engine still removes the projectile when its own lifetime runs out, even while the player stands still. The circle must therefore keep its own timer and cast point in the script and must not depend on the projectile being alive.
  - A repeated cast moves the circle to the new cast point. The hold distance is then measured from the new cast point. The new circle starts with the flag turned off, so the timer waits again until the player leaves.
  - Without a player entity, for example after death, the timer counts down as usual. `UpdateAllSeeingEye` already receives the player entity, so it can pass the player position to `UpdateXRayReveal`.

## Natural Fear Mode

- The Giant Laser-Drone (Jättilaser-lennokki, `drone_lasership`) fears lantern light in the Natural Fear mode, but it should not. The drone is a robot, and robots are immune to fire. The guides say that creatures immune to fire do not fear the light.
  - Cause: the immunity is never checked in code. `IsFearful` in `files/scripts/lantern_fear.lua` filters only by fire enemies, lured herds, and excluded enemies. The drone has the `robot` herd, so it counts as fearful.
  - The design assumed that fire immunity alone stops the reaction. In fact, immunity only cancels the `LIGHT_BURN_DAMAGE` fire damage and the panic that it starts. `Scorch` still adds `FEAR_PUSH_SPEED` to the velocity of the drone, and `SetScared` still gives it the look of fear. The rage branch also works, because it does not use damage at all.
  - The drone inherits the `fire="0.0"` damage multiplier from `data/entities/base_enemy_robot.xml`. The drone is light (mass 0.8) and flies, so the push moves it along both axes and is easy to notice.
  - The same bug likely affects every creature immune to fire: other robots, ghosts, and others. The fix should skip enemies whose fire damage multiplier is 0 in `IsFearful`.
- The Hiisi Healer (Parantajahiisi, `scavenger_heal`) fears lantern light in the Natural Fear mode, but it should not. It is a Hiisi, and lanterns should attract Hiisi.
  - Cause: the Natural Fear mode recognizes Hiisi only by the `orcs` herd. The list is `NATURAL_FEAR_LURED_HERDS` in `files/scripts/enemy_ai_home.lua`. In vanilla data, the Hiisi Healer has the `healer` herd instead of `orcs`.
  - As a result, `IsNaturalFearLuredHerd` returns false for the Hiisi Healer. `IsFearful` then counts it as a fearful enemy, so the light scorches it.
  - Two other Hiisi have the `healer` herd too: the invisibility Hiisi (`scavenger_invis`) and the shield Hiisi (`scavenger_shield`). They likely have the same bug. The `healer` herd also has the coward (`coward`) and the healer drone (`healerdrone_physics`), which need a check.
  - A whole `healer` herd in the lured list would also attract the healer drone, which is a robot. The fix may need to recognize these Hiisi by their file names instead of the herd.

## Cleanup

- Remove the temporary leaked component cleanup that was added in version 0.3.1. In version 0.3.0, every lit lantern with a modifier got a new empty `LuaComponent` on each illumination update. The cleanup removes these components from lanterns in saves made with version 0.3.0. To remove it, delete `files/scripts/leaked_component_cleanup.lua` and the two lines that load and call it in `init.lua`.

## Temple Lantern Modifiers

- Magic liquid modifier for the temple lantern (`physics/temple_lantern.xml`): with a small chance, a temple lantern is filled with a magic liquid instead of plasma.
- A lantern with this modifier gives no light.
- When it breaks, it spills one of the magic liquids instead of `plasma_fading`:
  - Concentrated Mana (`magic_liquid_mana_regeneration`);
  - Flummoxium (`material_confusion`);
  - Unstable Teleportatium (`magic_liquid_unstable_teleportation`).

## Visual Polish and UI

- Custom UI icons redesign: create dedicated pixel-art icons visually matching physical lantern props (`ui_lantern.png`, `ui_lantern_small.png`) with clear illumination.

## Open-Flame Variants

- Implement open-flame torches and braziers that actively ignite flammable materials, gases, and enemies on contact while held.
- Immediate extinguishing upon liquid contact (without a delay).

## Rogue Mode

- A Mod Settings toggle that makes the player invisible to enemies while they stay far from light.
- Investigate whether the player's visibility can be set per enemy type (e.g., zombies see in the dark, Hiisi do not).

## Extinguishing and Submersion

- Implement a 2-second submersion timer: lanterns submerged in water or non-flammable liquids extinguish and cease emitting light.
- Dynamic state tracking: switch inventory icon to an unlit flask when extinguished.
- Update in-hand and belt sprites to render unlit containers without flame animations.
- Magical and hermetic lanterns remain lit underwater.

## Additional Liquid Interactions

- React to other liquids besides oil and water (e.g., alcohol flicker, toxic sludge tint, blood dimming).

## Reignition Mechanics

- Reignite unlit lanterns when exposed to open fire, burning materials, or high environmental heat.

## Full Playthrough Guarantee in Darkness

- Verify that the game can be fully completed with the mod enabled at the darkest vision presets (Minimal 10% and Pitch Black 0%).
- Guarantee that every biome, including the main path, side biomes, parallel worlds, and boss arenas, offers at least one reliable way to get sufficient illumination (e.g., spawned lanterns, light fixtures, glowing materials, or light sources the player can bring along).
- Close any biome where no light source can be obtained, by adding guaranteed lantern spawns or other light sources.

## Full Release Polish

- Finalized balance, performance optimization, and compatibility verification.
