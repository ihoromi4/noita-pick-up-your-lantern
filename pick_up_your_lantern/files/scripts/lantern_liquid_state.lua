--- Liquid states of the held lantern.
--- When the player dives into oil or water with a lantern in hand, the lantern becomes oil-soaked or wet.
--- The state is kept on the lantern until the player dives into the other liquid with it.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lantern_illumination.lua")

local LANTERN_TAG = "lantern"
local CHECK_INTERVAL_FRAMES = 10

---Returns the name of the liquid the player's head is submerged in.
---@param player_id number Player entity ID.
---@return string|nil material_name Material name, or nil if the player is not submerged.
local function GetSubmergedMaterial(player_id)
    local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
    if damage_model == nil or not ComponentGetValue2(damage_model, "mAirAreWeInWater") then
        return nil
    end

    local material_id = ComponentGetValue2(damage_model, "mLiquidMaterialWeAreIn")
    if material_id == nil or material_id < 0 then
        return nil
    end

    return CellFactory_GetName(material_id)
end

---Applies the liquid the player is submerged in to the lantern in hand.
---Called every frame from OnWorldPostUpdate, checks every CHECK_INTERVAL_FRAMES frames.
---@return nil
function UpdateLanternLiquidState()
    if GameGetFrameNum() % CHECK_INTERVAL_FRAMES ~= 0 then
        return
    end

    local player_id = FindPlayer()
    if player_id == 0 then
        return
    end

    local lantern_id = GetHeldItem(player_id)
    if lantern_id == 0 or not EntityHasTag(lantern_id, LANTERN_TAG) or IsLanternExtinguished(lantern_id) then
        return
    end

    local material_name = GetSubmergedMaterial(player_id)
    if material_name == nil then
        return
    end

    local state_id = GetLiquidStateByMaterial(material_name)
    if state_id == LANTERN_LIQUID_STATE_NONE or state_id == GetLanternLiquidState(lantern_id) then
        return
    end

    SetLanternLiquidState(lantern_id, state_id)
    UpdateLanternDescription(lantern_id)
    UpdateLanternIllumination(true)
end
