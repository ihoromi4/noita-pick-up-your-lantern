--- Dynamic lighting patcher for Pick Up Your Lantern mod.
--- Injects fog_of_war_hole SpriteComponent into light fixtures using nxml.

---@diagnostic disable: undefined-global
local nxml = dofile_once("mods/pick_up_your_lantern/files/scripts/libs/nxml.lua")
dofile_once("mods/pick_up_your_lantern/files/scripts/lantern_illumination.lua")

local SETTING_ID = "pick_up_your_lantern.illuminate_the_darkness"

---Lantern entity files that declare their own fog of war hole SpriteComponent.
local LANTERN_ENTITIES = {
    "data/entities/props/physics/lantern_small.xml",
    "data/entities/props/physics_lantern.xml",
    "data/entities/props/physics_lantern_small.xml",
}

---Target entity definitions for dynamic lighting injection.
---Lanterns are not listed: their light and fog of war hole are declared in their own XML files.
---@type table<number, {path: string, tags: string, enabled: string, alpha: string, image_file: string, offset_x?: number, offset_y?: number, scale?: number}>
local TARGET_ENTITIES = {
    {
        path = "data/entities/props/physics/chain_torch.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics/chain_torch_blue.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics/chain_torch_ghostly.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics_torch_stand.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics_torch_stand_blue.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics_mining_lamp.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics/temple_lantern.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
    {
        path = "data/entities/props/physics_barrel_burning.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole.xml",
    },
    {
        path = "data/entities/props/physics_tubelamp.xml",
        tags = "enabled_in_world",
        enabled = "1",
        alpha = "0.55",
        image_file = "data/particles/fog_of_war_hole_64.xml",
    },
}

---Checks whether dynamic lighting is enabled in mod settings.
---@return boolean
local function IsSettingEnabled()
    local is_enabled = ModSettingGet(SETTING_ID)
    if is_enabled == nil then
        is_enabled = ModSettingGetNextValue(SETTING_ID)
    end
    if is_enabled == nil then
        is_enabled = true
    end

    return is_enabled
end

---Finds an existing fog of war hole SpriteComponent child if present.
---@param xml table
---@return table|nil
local function FindFogOfWarHole(xml)
    for child in xml:each_of("SpriteComponent") do
        if child.attr.fog_of_war_hole == "1" then
            return child
        end
    end

    local inner_entity = xml:first_of("Entity")
    if inner_entity ~= nil then
        for child in inner_entity:each_of("SpriteComponent") do
            if child.attr.fog_of_war_hole == "1" then
                return child
            end
        end
    end

    return nil
end

---Builds attribute table for dynamic lighting SpriteComponent.
---@param target table
---@param global_scale number
---@return table<string, string>
local function BuildSpriteAttributes(target, global_scale)
    local attrs = {
        _tags = target.tags,
        _enabled = target.enabled,
        alpha = target.alpha,
        image_file = target.image_file,
        smooth_filtering = "1",
        fog_of_war_hole = "1",
    }

    if target.offset_x ~= nil or target.offset_y ~= nil then
        attrs["transform_offset.x"] = tostring(target.offset_x or 0)
        attrs["transform_offset.y"] = tostring(target.offset_y or 0)
    end

    local target_scale = target.scale or 1.0
    local total_scale = target_scale * global_scale
    -- Always enabled so the scale can be changed at runtime via special_scale_x/y.
    attrs.has_special_scale = "1"
    attrs.special_scale_x = tostring(total_scale)
    attrs.special_scale_y = tostring(total_scale)

    return attrs
end

---Updates attributes of an existing fog of war hole SpriteComponent.
---@param sprite_elem table
---@param target table
---@param global_scale number
---@return nil
local function UpdateFogOfWarHole(sprite_elem, target, global_scale)
    local attrs = BuildSpriteAttributes(target, global_scale)
    for k, v in pairs(attrs) do
        sprite_elem.attr[k] = v
    end
end

---Injects a new fog of war hole SpriteComponent into the entity XML node.
---@param xml table
---@param target table
---@param global_scale number
---@return nil
local function InjectFogOfWarHole(xml, target, global_scale)
    local target_node = xml:first_of("Entity") or xml
    local attrs = BuildSpriteAttributes(target, global_scale)
    local sprite_elem = nxml.new_element("SpriteComponent", attrs)
    target_node:add_child(sprite_elem)
end

---Patches a single target entity file with dynamic lighting SpriteComponent.
---@param target table
---@param global_scale number
---@return nil
local function PatchTarget(target, global_scale)
    local content = ModTextFileGetContent(target.path)
    if content == nil or content == "" then
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        return
    end

    local existing_sprite = FindFogOfWarHole(xml)
    if existing_sprite ~= nil then
        UpdateFogOfWarHole(existing_sprite, target, global_scale)
    else
        InjectFogOfWarHole(xml, target, global_scale)
    end

    ModTextFileSetContent(target.path, nxml.tostring(xml))
end

---Removes the fog of war hole SpriteComponent declared in a lantern XML file.
---@param path string Lantern entity file path.
---@return nil
local function RemoveLanternFogOfWarHole(path)
    local content = ModTextFileGetContent(path)
    if content == nil or content == "" then
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        return
    end

    local sprite_elem = FindFogOfWarHole(xml)
    if sprite_elem == nil then
        return
    end

    xml:remove_child(sprite_elem)
    ModTextFileSetContent(path, nxml.tostring(xml))
end

---Patches light fixture entity XML files to pierce fog of war when enabled in mod settings.
---When disabled, removes the fog of war holes declared in lantern XML files instead.
---@return nil
function PatchLighting()
    local is_enabled = IsSettingEnabled()
    if not is_enabled then
        for _, path in ipairs(LANTERN_ENTITIES) do
            RemoveLanternFogOfWarHole(path)
        end
        return
    end

    local global_scale = GetIlluminationScale()

    for _, target in ipairs(TARGET_ENTITIES) do
        PatchTarget(target, global_scale)
    end
end
