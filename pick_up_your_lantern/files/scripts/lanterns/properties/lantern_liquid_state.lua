--- Liquid states of the held lantern.
--- When the player dives into oil or water with an oil lantern in hand, the lantern becomes oil-soaked or wet.
--- A wet lantern dries and loses the wet state on contact with fire, hot liquids, or in a Hot biome.
--- Otherwise the state is kept on the lantern until the player dives into the other liquid with it.

local MOD_ID = "pick_up_your_lantern"

---@diagnostic disable: undefined-global
dofile_once("mods/" .. MOD_ID .. "/files/scripts/utils.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lanterns/properties/lantern_traits.lua")
dofile_once("mods/" .. MOD_ID .. "/files/scripts/lanterns/properties/lantern_illumination.lua")
local nxml = dofile_once("mods/" .. MOD_ID .. "/files/scripts/libs/nxml.lua")

local LANTERN_TAG = "lantern"
local CHECK_INTERVAL_FRAMES = 10
local DRY_STEAM_COUNT = 6
local DRY_STEAM_VEL_Y = -20
local BIOMES_ALL_PATH = "data/biome/_biomes_all.xml"
local BIOME_MAP_IMAGE_PATH = "data/biome_impl/biome_map.png"
local BIOME_CHUNK_SIZE = 512
local BIOME_MAP_ORIGIN_ROW = 14
local RGB_MOD = 16777216

---@type {filename: string, bgr: number|nil}[]
local biome_entries = {}
local biome_map_image_id = nil
local biome_map_width = 0
local biome_map_height = 0
local hot_biomes_resolved = false
---@type table<string, boolean>
local hot_biome_names = {}
---@type table<number, boolean>
local hot_biome_bgrs = {}

---Converts an ARGB or RGB hex color string from _biomes_all.xml to a 24-bit BGR integer matching ModImageGetPixel.
---@param hex_str string|nil Hex color string, e.g. "ffd57917".
---@return number|nil bgr 24-bit BGR integer, or nil if invalid.
local function ArgbHexToBgr(hex_str)
    if hex_str == nil then
        return nil
    end
    local clean = hex_str:gsub("^#", ""):gsub("^0[xX]", "")
    if #clean == 8 then
        clean = clean:sub(3, 8)
    elseif #clean ~= 6 then
        return nil
    end

    local r = tonumber(clean:sub(1, 2), 16)
    local g = tonumber(clean:sub(3, 4), 16)
    local b = tonumber(clean:sub(5, 6), 16)
    if r == nil or g == nil or b == nil then
        return nil
    end

    return b * 65536 + g * 256 + r
end

---Reads the biome list and opens biome_map.png for pixel lookups of unnamed hot biomes.
---Called once at mod init (file scope of init.lua).
---@return nil
function InitHotBiomes()
    local content = ModTextFileGetContent(BIOMES_ALL_PATH)
    if content ~= nil then
        local ok, root = pcall(nxml.parse, content)
        if ok and root ~= nil then
            for _, child in ipairs(root.children or {}) do
                if child.name == "Biome" and child.attr ~= nil and child.attr.biome_filename ~= nil then
                    table.insert(biome_entries, {
                        filename = child.attr.biome_filename,
                        bgr = ArgbHexToBgr(child.attr.color),
                    })
                end
            end
        end
    end

    local image_id, width, height = ModImageMakeEditable(BIOME_MAP_IMAGE_PATH, 0, 0)
    if image_id ~= nil and width ~= nil and height ~= nil and width > 0 and height > 0 then
        biome_map_image_id = image_id
        biome_map_width = width
        biome_map_height = height
    end
end

---Resolves which biomes are hot once the world and biome modifiers have initialized.
---@return nil
local function EnsureHotBiomesResolved()
    if hot_biomes_resolved then
        return
    end
    hot_biomes_resolved = true

    for _, entry in ipairs(biome_entries) do
        local is_hot = LANTERN_ALWAYS_HOT_BIOMES[entry.filename] == true
        if not is_hot then
            local modifier_desc = BiomeGetValue(entry.filename, "mModifierUIDescription")
            is_hot = modifier_desc == LANTERN_HOT_BIOME_MODIFIER_DESC
        end

        if is_hot then
            local biome_name = BiomeGetValue(entry.filename, "name")
            if biome_name ~= nil and biome_name ~= "" and biome_name ~= "_EMPTY_" then
                hot_biome_names[biome_name] = true
            end
            if entry.bgr ~= nil then
                hot_biome_bgrs[entry.bgr] = true
            end
        end
    end
end

---Checks whether the given world position lies inside a Hot biome (Hot modifier, Desert, Pyramid or Lava Lake).
---@param x number World X coordinate.
---@param y number World Y coordinate.
---@return boolean
local function IsInHotBiome(x, y)
    EnsureHotBiomesResolved()

    local biome_name = BiomeMapGetName(x, y)
    if biome_name ~= nil and hot_biome_names[biome_name] then
        return true
    end

    -- Unnamed hot biomes such as Lava Lake and parts of the Pyramid report "_EMPTY_" from BiomeMapGetName.
    if biome_name == "_EMPTY_" and biome_map_image_id ~= nil then
        local col = (math.floor(x / BIOME_CHUNK_SIZE) + math.floor(biome_map_width / 2)) % biome_map_width
        local row = math.floor(y / BIOME_CHUNK_SIZE) + BIOME_MAP_ORIGIN_ROW
        if row >= 0 and row < biome_map_height then
            local pixel = ModImageGetPixel(biome_map_image_id, col, row)
            if pixel ~= nil and hot_biome_bgrs[pixel % RGB_MOD] then
                return true
            end
        end
    end

    return false
end

---Returns the material ID and name of the liquid the player's head is submerged in.
---@param damage_model number Player DamageModelComponent ID.
---@return number|nil material_id Material ID, or nil if the player is not submerged.
---@return string|nil material_name Material name, or nil if the player is not submerged.
local function GetSubmergedMaterial(damage_model)
    if not ComponentGetValue2(damage_model, "mAirAreWeInWater") then
        return nil, nil
    end

    local material_id = ComponentGetValue2(damage_model, "mLiquidMaterialWeAreIn")
    if material_id == nil or material_id < 0 then
        return nil, nil
    end

    return material_id, CellFactory_GetName(material_id)
end

---Checks whether a material carries a drying tag (fire, lava, molten, hot).
---@param material_id number Material ID.
---@return boolean
local function IsDryingMaterial(material_id)
    for _, raw_tag in ipairs(CellFactory_GetTags(material_id) or {}) do
        local tag = raw_tag:gsub("^%[", ""):gsub("%]$", "")
        if LANTERN_DRYING_MATERIAL_TAGS[tag] then
            return true
        end
    end

    return false
end

---Updates the liquid state of the lantern in hand from submersion, fire contact, or a Hot biome.
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

    local _, lantern_type = GetLanternType(lantern_id)
    if not lantern_type.supports_liquid_states then
        return
    end

    local damage_model = EntityGetFirstComponent(player_id, "DamageModelComponent")
    if damage_model == nil then
        return
    end

    local current_state = GetLanternLiquidState(lantern_id)
    local material_id, material_name = GetSubmergedMaterial(damage_model)
    local next_state = LANTERN_LIQUID_STATE_NONE
    local dried = false

    if material_id ~= nil and material_name ~= nil then
        next_state = GetLiquidStateByMaterial(material_name)
        if next_state == LANTERN_LIQUID_STATE_NONE then
            if current_state == LANTERN_LIQUID_STATE_WET and IsDryingMaterial(material_id) then
                dried = true
            else
                return
            end
        end
    elseif current_state == LANTERN_LIQUID_STATE_WET then
        local player_x, player_y = EntityGetTransform(player_id)
        if ComponentGetValue2(damage_model, "is_on_fire") or IsInHotBiome(player_x, player_y) then
            dried = true
        else
            return
        end
    else
        return
    end

    if next_state == current_state then
        return
    end

    SetLanternLiquidState(lantern_id, next_state)
    if dried then
        local x, y = EntityGetTransform(lantern_id)
        GameCreateCosmeticParticle("steam", x, y, DRY_STEAM_COUNT, 0, DRY_STEAM_VEL_Y)
    end
    UpdateLanternDescription(lantern_id)
    UpdateLanternIllumination(true)
end
