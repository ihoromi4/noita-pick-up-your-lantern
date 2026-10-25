--- Tags the entity a light source was loaded into, so enemy study finds it.
--- Added to light source files by files/scripts/patch_light_sources.lua.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

EntityAddTag(GetUpdatedEntityID(), LIGHT_SOURCE_TAG)
