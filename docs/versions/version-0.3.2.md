# Version 0.3.2 - All-Seeing Eye Lifetime Fix

Tracking document for features, implementation progress, and known issues for **Version 0.3.2**. All releases are listed in [Versions](README.md). Previous milestone progress is tracked in [version-0.3.1.md](version-0.3.1.md).

## Summary

Spell modifiers that change the projectile lifetime now also change how long the All-Seeing Eye spell reveals the area. The revealed area also stays bright while the player stays near the cast point. The temporary cleanup of saves made with version 0.3.0 is removed.

## All-Seeing Eye Spell

- [x] Bug: spell modifiers that change the projectile lifetime did not change how long the All-Seeing Eye spell (`X_RAY`) revealed the area. The reveal circle now keeps its full strength for 10 seconds, plus 5 frames for each frame of lifetime that the modifiers add. Then it fades over 10 seconds as before. Details: [Vision and Lighting](../dev/vision-and-lighting.md#all-seeing-eye) and [All-Seeing Eye Projectile Lifetime](../rnd/lighting/all-seeing-eye-lifetime.md).
- [x] Change: the reveal circle stays at full strength while the player stays near the cast point. The reveal timer starts to count down only when the player first moves farther than 64 px from the cast point. Coming back does not pause it again. A repeated cast moves the circle to the new cast point, and the timer waits again.

## Cleanup

- [x] Removed the temporary leaked component cleanup that was added in version 0.3.1 (`leaked_component_cleanup.lua`). It removed the empty `LuaComponent` components that version 0.3.0 added to lit lanterns with a modifier.

## Release Notes

- The All-Seeing Eye spell now keeps the area bright for 10 seconds before it starts to fade.
- The area stays bright while you stay near the place where you cast the spell. The 10 seconds start when you walk away.
- Modifiers that change the projectile lifetime also change how long the area stays bright. For example, Null Shot makes it last about 33 seconds, and Reduce Lifetime makes it last about 6.5 seconds.
- Runs started with version 0.3.0 are no longer cleaned up. If you still play such a run, please start a new game.
