# Version 0.3.2 - All-Seeing Eye Lifetime Fix

Tracking document for features, implementation progress, and known issues for **Version 0.3.2**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.3.1.md](version-0.3.1.md).

## Summary

Spell modifiers that change the projectile lifetime now also change how long the All-Seeing Eye spell reveals the area.

## All-Seeing Eye Spell

- [x] Bug: spell modifiers that change the projectile lifetime did not change how long the All-Seeing Eye spell (`X_RAY`) revealed the area. The reveal circle now keeps its full strength for 10 seconds, plus 5 frames for each frame of lifetime that the modifiers add. Then it fades over 10 seconds as before. Details: [Vision and Lighting](../dev/vision-and-lighting.md#all-seeing-eye) and [All-Seeing Eye Projectile Lifetime](../rnd/all-seeing-eye-lifetime.md).

## Release Notes

- The All-Seeing Eye spell now keeps the area bright for 10 seconds before it starts to fade.
- Modifiers that change the projectile lifetime also change how long the area stays bright. For example, Null Shot makes it last about 33 seconds, and Reduce Lifetime makes it last about 6.5 seconds.
