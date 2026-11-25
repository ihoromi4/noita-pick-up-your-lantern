--- Joint controller for hanging lanterns in world: handles ceiling support collapse and player kicking.
-- Detaches PhysicsJointComponent when ceiling pixels are destroyed or when kicked, then self-destructs.

dofile_once("mods/pick_up_your_lantern/files/scripts/utils.lua")

-- Lantern types whose joint sits higher above the origin declare their own distance in the XML file.
local CEILING_CHECK_DISTANCE_STORAGE = "lantern_ceiling_check_distance"
local DEFAULT_CEILING_CHECK_DISTANCE = 6.0
local KICK_FORCE_X = 40.0
local KICK_FORCE_Y = -20.0

---Detaches the lantern from the ceiling, cleans up joints, and applies optional kick impulse.
---@param entity_id number The lantern entity ID.
---@param entity_who_kicked number|nil Entity ID of the kicker, if kicked.
local function DetachLantern(entity_id, entity_who_kicked)
    local x, y = EntityGetTransform(entity_id)

    local joints = EntityGetComponent(entity_id, "PhysicsJointComponent")
    if joints ~= nil then
        for _, joint_id in ipairs(joints) do
            EntityRemoveComponent(entity_id, joint_id)
        end
    end

    PhysicsRemoveJoints(x - 6.0, y - 14.0, x + 6.0, y + 2.0)

    if entity_who_kicked ~= nil and entity_who_kicked ~= 0 and EntityGetIsAlive(entity_who_kicked) then
        local kx, _ = EntityGetTransform(entity_who_kicked)
        local dir_x = (x >= kx) and 1.0 or -1.0
        PhysicsApplyForce(entity_id, dir_x * KICK_FORCE_X, KICK_FORCE_Y)
    end

    local comp_id = GetUpdatedComponentID()
    if comp_id ~= nil and comp_id ~= 0 then
        EntityRemoveComponent(entity_id, comp_id)
    end
end

---Returns how far above the lantern origin the ceiling is searched for.
---@param entity_id number The lantern entity ID.
---@return number
local function GetCeilingCheckDistance(entity_id)
    local comp = FindVariableStorage(entity_id, CEILING_CHECK_DISTANCE_STORAGE)
    if comp == nil then
        return DEFAULT_CEILING_CHECK_DISTANCE
    end

    return ComponentGetValue2(comp, "value_float")
end

---Checks whether ceiling support above the lantern is still intact.
---@param entity_id number The lantern entity ID.
local function CheckCeiling(entity_id)
    local joints = EntityGetComponent(entity_id, "PhysicsJointComponent")
    if joints == nil or #joints == 0 then
        local comp_id = GetUpdatedComponentID()
        if comp_id ~= nil and comp_id ~= 0 then
            EntityRemoveComponent(entity_id, comp_id)
        end
        return
    end

    local x, y = EntityGetTransform(entity_id)
    local distance = GetCeilingCheckDistance(entity_id)

    -- Check if ceiling surface exists above the anchor point
    local has_ceiling = RaytraceSurfaces(x, y, x, y - distance)
    if not has_ceiling then
        -- Secondary check with slight horizontal offsets to avoid false detachments on tiny gaps
        has_ceiling = RaytraceSurfaces(x - 2.0, y, x - 2.0, y - distance)
            or RaytraceSurfaces(x + 2.0, y, x + 2.0, y - distance)
    end

    if not has_ceiling then
        DetachLantern(entity_id, nil)
    end
end

---Called by Noita engine when the entity receives Message_Kick.
---@param entity_who_kicked number Entity ID of the kicker.
function kick(entity_who_kicked)
    local entity_id = GetUpdatedEntityID()
    DetachLantern(entity_id, entity_who_kicked)
end

-- Periodic ceiling support check
CheckCeiling(GetUpdatedEntityID())
