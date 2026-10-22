# Version 0.1.1 - Item Radar Fix

Tracking document for features, implementation progress, and known issues for **Version 0.1.1**. Functional requirements are defined in [requirements.md](../requirements.md) and milestone planning in [roadmap.md](../roadmap.md). Previous milestone progress is tracked in [version-0.1.md](version-0.1.md).

## Item Radar Compatibility

- [x] Hide lanterns from the Item Radar perk (`ITEM_RADAR`) by default ([#1](https://github.com/ihoromi4/noita-pick-up-your-lantern/issues/1)).
- [x] Add "Show lanterns on Item Radar" toggle to Mod Settings (runtime, off by default).
- [x] Mark all lantern entities with the `lantern` tag and filter them out in `data/scripts/perks/radar_item.lua` (`patch_item_radar.lua`, `item_radar_filter.lua`).

## Release Notes

- Lanterns no longer show up on the Item Radar perk. A new "Show lanterns on Item Radar" option in Mod Settings turns them back on.
- Start a new game for the Item Radar fix to take effect. Lanterns that already exist in a run started with an older version of the mod still show up on the radar.

## Known Issues and Next Steps

- None.
