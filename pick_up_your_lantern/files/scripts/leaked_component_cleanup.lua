--- Temporary cleanup for saves made with version 0.3 (to be removed in version 0.4).
--- In version 0.3 the modifier script path was lost, so every lit lantern with a modifier got a new empty
--- LuaComponent on each illumination update. Thousands of them pile up on a lantern and slow down saving the game.
--- Each loaded lantern is checked once per session, and the empty components are removed from it.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global

local LANTERN_TAG = "lantern"
local LEAKED_TAGS = { "enabled_in_world", "enabled_in_hand", }
local UPDATE_INTERVAL_FRAMES = 60
-- All script fields of LuaComponent. The leaked components have none of them set.
local SCRIPT_FIELDS = {
    "script_source_file",
    "script_audio_event_dead",
    "script_biome_entered",
    "script_collision_trigger_hit",
    "script_collision_trigger_timer_finished",
    "script_damage_about_to_be_received",
    "script_damage_received",
    "script_death",
    "script_electricity_receiver_electrified",
    "script_electricity_receiver_switched",
    "script_enabled_changed",
    "script_inhaled_material",
    "script_interacting",
    "script_item_picked_up",
    "script_kick",
    "script_material_area_checker_failed",
    "script_material_area_checker_success",
    "script_physics_body_modified",
    "script_polymorphing_to",
    "script_portal_teleport_used",
    "script_pressure_plate_change",
    "script_shot",
    "script_teleported",
    "script_throw_item",
    "script_wand_fired",
}

-- Entity IDs are not reused within a session, so a checked lantern never needs a second check.
local checked_lanterns = {}

---Checks whether a LuaComponent is one of the empty components left by the version 0.3 leak.
---@param comp number LuaComponent ID.
---@return boolean
local function IsLeakedComponent(comp)
    for _, tag in ipairs(LEAKED_TAGS) do
        if not ComponentHasTag(comp, tag) then
            return false
        end
    end

    for _, field in ipairs(SCRIPT_FIELDS) do
        local value = ComponentGetValue2(comp, field)
        if value ~= nil and value ~= "" then
            return false
        end
    end

    return true
end

---Removes the leaked empty LuaComponents from a lantern.
---@param entity_id number Lantern entity ID.
---@return number removed Number of removed components.
local function RemoveLeakedComponents(entity_id)
    local removed = 0
    for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LuaComponent") or {}) do
        if IsLeakedComponent(comp) then
            EntityRemoveComponent(entity_id, comp)
            removed = removed + 1
        end
    end

    return removed
end

---Removes the leaked components from every loaded lantern that was not checked yet in this session.
---@return nil
function UpdateLeakedComponentCleanup()
    if GameGetFrameNum() % UPDATE_INTERVAL_FRAMES ~= 0 then
        return
    end

    for _, entity_id in ipairs(EntityGetWithTag(LANTERN_TAG) or {}) do
        if not checked_lanterns[entity_id] then
            checked_lanterns[entity_id] = true
            local removed = RemoveLeakedComponents(entity_id)
            if removed > 0 then
                print(string.format("[%s] Removed %d leaked components from lantern %d", MOD_ID, removed, entity_id))
            end
        end
    end
end
