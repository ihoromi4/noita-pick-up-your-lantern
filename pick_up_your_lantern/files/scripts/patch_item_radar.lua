--- Item Radar perk patcher for Pick Up Your Lantern mod.
--- Prepends a filtered EntityGetInRadiusWithTag to data/scripts/perks/radar_item.lua to hide lanterns.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
local RADAR_ITEM_PATH = "data/scripts/perks/radar_item.lua"
local FILTER_LINE = 'local EntityGetInRadiusWithTag = dofile_once("mods/' .. MOD_ID .. '/files/scripts/item_radar_filter.lua")\n'

---Prepends the lantern filter to the Item Radar perk script.
function PatchItemRadar()
    local content = ModTextFileGetContent(RADAR_ITEM_PATH)
    if content == nil then
        print(string.format("[%s] ERROR: Failed to read %s", MOD_ID, RADAR_ITEM_PATH))
        return
    end
    if content:find(FILTER_LINE, 1, true) ~= nil then
        return
    end
    ModTextFileSetContent(RADAR_ITEM_PATH, FILTER_LINE .. content)
end
