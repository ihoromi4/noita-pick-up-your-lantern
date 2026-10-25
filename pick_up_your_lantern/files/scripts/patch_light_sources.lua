--- Light source patcher for Pick Up Your Lantern mod.
--- Marks vanilla light sources that count as light for enemy study with the `pul_light_source` tag.
--- Lanterns declare the tag in their own XML files; other light sources are patched here.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")

local TAG_SCRIPT_PATH = "mods/" .. MOD_ID .. "/files/scripts/light_source_tag.lua"

-- Light of the Light spell modifier (`LIGHT`), added to projectiles as an extra entity.
local LIGHT_SOURCE_PATHS = {
    "data/entities/misc/light.xml",
}

---Appends a tag to a comma-separated tag list, unless it is already there.
---@param tags string|nil Comma-separated tags.
---@param tag string Tag to add.
---@return string
local function AddTag(tags, tag)
    if tags == nil or tags == "" then
        return tag
    end
    for existing in tags:gmatch("[^,]+") do
        if existing == tag then
            return tags
        end
    end

    return tags .. "," .. tag
end

---Marks a light source file: tags its LightComponents and adds a script that tags the entity.
---Projectile extra entities are merged into the projectile, so the entity tag of the file itself
---is not enough: the script tags whichever entity the components end up on.
---@param path string Entity XML file path.
---@return nil
local function PatchLightSource(path)
    local content = ModTextFileGetContent(path)
    if content == nil or content == "" then
        print(string.format("[%s] ERROR: Failed to read %s", MOD_ID, path))
        return
    end

    local success, xml = pcall(nxml.parse, content)
    if not success or xml == nil then
        print(string.format("[%s] ERROR: Failed to parse %s", MOD_ID, path))
        return
    end

    for lua_comp in xml:each_of("LuaComponent") do
        if lua_comp.attr.script_source_file == TAG_SCRIPT_PATH then
            return
        end
    end

    for light_comp in xml:each_of("LightComponent") do
        light_comp.attr._tags = AddTag(light_comp.attr._tags, LIGHT_SOURCE_TAG)
    end
    xml.attr.tags = AddTag(xml.attr.tags, LIGHT_SOURCE_TAG)
    xml:add_child(nxml.new_element("LuaComponent", {
        execute_on_added = "1",
        remove_after_executed = "1",
        script_source_file = TAG_SCRIPT_PATH,
    }))

    ModTextFileSetContent(path, nxml.tostring(xml))
end

---Marks all vanilla light sources that count for enemy study.
---@return nil
function PatchLightSources()
    for _, path in ipairs(LIGHT_SOURCE_PATHS) do
        PatchLightSource(path)
    end
end
