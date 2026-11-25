--- Entity modification effects, rolled data and death handling for declarative lantern modifiers.
--- Handles stripping light/particles, switching physics/hand sprites, neutralizing explosions on break,
--- rolling weighted fill materials, and spilling them without sparks or fire.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lanterns/properties/lantern_properties_config.lua")

local FILL_MATERIAL_STORAGE = "lantern_fill_material"

---Checks whether a modifier mask contains a modifier ID.
---@param mask number Modifier mask.
---@param modifier_id number Modifier ID.
---@return boolean
local function MaskContainsModifier(mask, modifier_id)
    return math.floor(mask / (2 ^ (modifier_id - 1))) % 2 == 1
end

---Switches the in-hand sprite of a lantern to its dark variant (`*_in_hand.xml` to `*_in_hand_out.xml`).
---@param entity_id number Lantern entity ID.
---@return nil
function ShowDarkHandSprite(entity_id)
    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if image_file:find("_in_hand%.xml$") then
            ComponentSetValue2(sprite_comp, "image_file", (image_file:gsub("_in_hand%.xml$", "_in_hand_out.xml")))
            if ComponentGetIsEnabled(sprite_comp) then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        end
    end
end

---Updates the physics shape image used for the next Box2D body created when the lantern enters the world.
---@param entity_id number Lantern entity ID.
---@param image_file string|nil Target image path; no-op when nil.
---@return nil
function SwitchLanternPhysicsImage(entity_id, image_file)
    if image_file == nil then
        return
    end

    for _, shape_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "PhysicsImageShapeComponent") or {}) do
        if ComponentGetValue2(shape_comp, "image_file") ~= image_file then
            ComponentSetValue2(shape_comp, "image_file", image_file)
        end
    end
end

---Strips light, fog of war hole, flame animation and glow/spark emitters from a lantern, and switches its
---in-hand sprite to the dark variant. Idempotent and safe while components are disabled in the inventory.
---@param entity_id number Lantern entity ID.
---@return nil
function StripLanternLightAndParticles(entity_id)
    for _, light_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "LightComponent") or {}) do
        EntityRemoveComponent(entity_id, light_comp)
    end

    for _, sprite_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent") or {}) do
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        local is_enabled = ComponentGetIsEnabled(sprite_comp)
        if ComponentGetValue2(sprite_comp, "fog_of_war_hole") then
            EntityRemoveComponent(entity_id, sprite_comp)
        elseif image_file:find("_flame%.xml$") then
            -- The vanilla flame sprite has an empty "out" animation.
            ComponentSetValue2(sprite_comp, "rect_animation", "out")
            ComponentSetValue2(sprite_comp, "next_rect_animation", "out")
            if is_enabled then
                EntityRefreshSprite(entity_id, sprite_comp)
            end
        end
    end
    ShowDarkHandSprite(entity_id)

    for _, component_type in ipairs({ "ParticleEmitterComponent", "SpriteParticleEmitterComponent", }) do
        for _, comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, component_type) or {}) do
            EntityRemoveComponent(entity_id, comp)
        end
    end
end

---Removes ExplodeOnDamageComponent and clears blood material on break so fragile liquids do not ignite.
---@param entity_id number Lantern entity ID.
---@return nil
function DisableLanternExplosion(entity_id)
    for _, explode_comp in ipairs(EntityGetComponentIncludingDisabled(entity_id, "ExplodeOnDamageComponent") or {}) do
        EntityRemoveComponent(entity_id, explode_comp)
    end

    local damage_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "DamageModelComponent")
    if damage_comp ~= nil and ComponentGetValue2(damage_comp, "blood_material") ~= "" then
        ComponentSetValue2(damage_comp, "blood_material", "")
    end
end

---Returns the rolled fill material stored on a lantern, or an empty string if none.
---@param entity_id number Lantern entity ID.
---@return string
function GetLanternFillMaterial(entity_id)
    return GetStorageString(entity_id, FILL_MATERIAL_STORAGE)
end

---Rolls and stores modifier-specific initial data using the current RNG stream.
---@param entity_id number Lantern entity ID.
---@param modifier LanternModifier Modifier definition.
---@return nil
function RollLanternModifierData(entity_id, modifier)
    if modifier.fill_materials == nil or #modifier.fill_materials == 0 then
        return
    end

    local total_weight = 0
    for _, entry in ipairs(modifier.fill_materials) do
        total_weight = total_weight + (entry.weight or 1)
    end

    local roll = Random(1, total_weight)
    local chosen = modifier.fill_materials[1].material
    for _, entry in ipairs(modifier.fill_materials) do
        roll = roll - (entry.weight or 1)
        if roll <= 0 then
            chosen = entry.material
            break
        end
    end

    SetStorageString(entity_id, FILL_MATERIAL_STORAGE, chosen)
end

---Applies idempotent entity-level effects of all active modifiers on a lantern.
---@param entity_id number Lantern entity ID.
---@param modifier_mask number Active modifier bitmask.
---@param lantern_type LanternType|nil Lantern type definition.
---@return nil
function ApplyLanternModifierEffects(entity_id, modifier_mask, lantern_type)
    if modifier_mask == 0 then
        return
    end

    for _, modifier in ipairs(LANTERN_MODIFIERS) do
        if MaskContainsModifier(modifier_mask, modifier.id) then
            if modifier.disables_light then
                StripLanternLightAndParticles(entity_id)
                SwitchLanternPhysicsImage(entity_id, lantern_type ~= nil and lantern_type.dark_image_file or nil)
            end
            if modifier.disables_explosion then
                DisableLanternExplosion(entity_id)
            end
        end
    end
end

---Resolves the spill count for a fill material entry, falling back to the modifier default.
---@param modifier LanternModifierMagicLiquid Modifier definition.
---@param material string Material name.
---@return number
local function ResolveSpillCount(modifier, material)
    for _, entry in ipairs(modifier.fill_materials) do
        if entry.material == material and entry.spill_count ~= nil then
            return entry.spill_count
        end
    end

    return modifier.spill_count
end

---Runs custom death behavior for active modifiers (such as spilling a rolled liquid without sparks).
---@param entity_id number Lantern entity ID.
---@param modifier_mask number Active modifier bitmask.
---@return boolean handled Whether a modifier handled the lantern death.
function TryHandleLanternModifierDeath(entity_id, modifier_mask)
    if modifier_mask == 0 then
        return false
    end

    for _, modifier in ipairs(LANTERN_MODIFIERS) do
        if MaskContainsModifier(modifier_mask, modifier.id)
            and modifier.fill_materials ~= nil and #modifier.fill_materials > 0 then
            ---@cast modifier LanternModifierMagicLiquid
            local material = GetLanternFillMaterial(entity_id)
            if material == "" then
                material = modifier.fill_materials[1].material
            end

            local spill_count = ResolveSpillCount(modifier, material)
            local pos_x, pos_y, rot = EntityGetTransform(entity_id)
            rot = rot or 0
            local offset_y = modifier.spill_offset_y or 0
            local bulb_x = pos_x - math.sin(rot) * offset_y
            local bulb_y = pos_y + math.cos(rot) * offset_y
            local spread = modifier.spill_spread or 0
            local vel_x = modifier.spill_vel_x or 0
            local vel_y_min = modifier.spill_vel_y_min or 0
            local vel_y_max = modifier.spill_vel_y_max or 0

            SetRandomSeed(GameGetFrameNum(), entity_id)
            for _ = 1, spill_count do
                local px = bulb_x + Randomf(-spread, spread)
                local py = bulb_y + Randomf(-spread, spread)
                local vx = Randomf(-vel_x, vel_x)
                local vy = Randomf(vel_y_min, vel_y_max)
                GameCreateParticle(material, px, py, 1, vx, vy, false, false, false)
            end

            return true
        end
    end

    return false
end
