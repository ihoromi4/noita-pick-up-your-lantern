--- Records when a chain torch's coals touch lava or liquid_fire so chain_torch_fire.lua
--- keeps the torch lit and can relight a doused torch in hot liquids.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")

local HOT_LIQUID_FRAME_STORAGE = "lantern_hot_liquid_frame"

---Called by MaterialAreaCheckerComponent when lava or liquid_fire is present near the torch.
---@param _pos_x number
---@param _pos_y number
---@return nil
function material_area_checker_success(_pos_x, _pos_y)
    local entity_id = GetUpdatedEntityID()
    SetStorageFloat(entity_id, HOT_LIQUID_FRAME_STORAGE, GameGetFrameNum())
end
