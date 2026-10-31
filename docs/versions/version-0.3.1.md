# Version 0.3.1 - Lantern Modifier Hotfix

Tracking document for features, implementation progress, and known issues for **Version 0.3.1**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.3.md](version-0.3.md).

## Summary

Version 0.3.1 is a hotfix for a bug in version 0.3. Lantern modifiers did not work, and the game slowed down over time and took a long time to close. Modifiers now work again. Saves made with version 0.3 are cleaned up while you play.

## Lantern Modifier Script

- [x] Bug: the modifier script (`lantern_modifier.lua`) never ran, so lantern modifiers had no effect. A Flickering lantern did not flicker, a Cracked lantern did not leak fire, and a Short-lived lantern never burned out in hand or in the world. The cause was the `MODIFIER_SCRIPT` constant in `lantern_traits.lua`, which was deleted by mistake during the chain torch work. The `---@diagnostic disable: undefined-global` line in that file hid the error from LuaLS. Fixed: the constant is restored.
- [x] Bug: memory leak on lanterns with modifiers. Without the script path, `AttachModifierScript` added an empty `LuaComponent` with no script. The check for an existing script never found it, so a new empty component was added on every illumination update. Every lit lantern with a modifier gained a new component every 30 frames. One test save held about 45,700 of them on 11 lanterns, and the game took a long time to save and close. Fixed by the restored constant.

## Save Cleanup

- [x] Remove the leaked empty components from saves made with version 0.3 (`leaked_component_cleanup.lua`). Each loaded lantern is checked once per session. The cleanup removes every `LuaComponent` that has the `enabled_in_world` and `enabled_in_hand` tags and no script. Lanterns in the world are cleaned when their part of the map is loaded. The number of removed components is written to the game log.
- The cleanup is temporary and will be removed in version 0.4, see [version-0.4.md](version-0.4.md#cleanup).

## Release Notes

- Lantern modifiers work again. Flickering lanterns flicker, Cracked lanterns leak fire, and Short-lived lanterns burn out.
- The game no longer slows down over time and closes quickly again.
- A run started with version 0.3 can be continued. Lanterns in it are cleaned up as you play, so a short stutter may happen when such a lantern is first loaded.
- Short-lived lanterns in a run started with version 0.3 start to burn down now. A Short-lived lantern that burned out on the belt goes out when you take it in hand.
