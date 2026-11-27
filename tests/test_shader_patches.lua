--- Tests for the shader patches of the mod: the template values and the build on the vanilla shaders.
--- The build tests need the unpacked game files in `noita/` or in NOITA_DATA_DIR, and are skipped without them.
--- scripts/check-shaders also compiles the built shaders with glslang.

local luaunit = require("luaunit")
local ShaderBuild = dofile("scripts/shader_build.lua")

local DATA_DIR = os.getenv("NOITA_DATA_DIR") or "noita"

---Checks whether the unpacked game files are available.
---@return boolean
local function HasGameData()
    local file = io.open(DATA_DIR .. "/shaders/post_final.frag", "rb")
    if file == nil then
        return false
    end
    file:close()
    return true
end

---Returns the sorted keys of a table.
---@param map table<string, any>
---@return string[]
local function SortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

TestShaderPatches = {}

---Every patch file of every job exists.
function TestShaderPatches:TestPatchFilesExist()
    for name, job in pairs(ShaderBuild.LoadJobs()) do
        for path, text in pairs(ShaderBuild.ReadPatches(job)) do
            luaunit.assertNotNil(text, string.format("%s: cannot read %s", name, path))
        end
    end
end

---Each value set gives a value to every placeholder of the patches, and has no unused key.
function TestShaderPatches:TestConfigsMatchPlaceholders()
    for name, job in pairs(ShaderBuild.LoadJobs()) do
        local used = {}
        for _, text in pairs(ShaderBuild.ReadPatches(job)) do
            for placeholder in pairs(ShaderBuild.Placeholders(text or "")) do
                used[placeholder] = true
            end
        end
        for _, set in ipairs(ShaderBuild.ConfigSets(job)) do
            local label = string.format("%s [%s]", name, set.name)
            luaunit.assertEquals(SortedKeys(set.values), SortedKeys(used), label .. ": keys differ from placeholders")
        end
    end
end

---Each value is GLSL code whose number literals are float literals.
---GLSL 1.10 has no implicit conversion from int to float, so `2` instead of `2.0` breaks the shader
---on strict drivers, such as Mesa.
function TestShaderPatches:TestValuesUseFloatLiterals()
    for name, job in pairs(ShaderBuild.LoadJobs()) do
        for _, set in ipairs(ShaderBuild.ConfigSets(job)) do
            for key, value in pairs(set.values) do
                luaunit.assertIsString(value, string.format("%s [%s] %s", name, set.name, key))
                for literal in value:gmatch("[%w_%.]+") do
                    if literal:match("^%d") then
                        luaunit.assertStrContains(
                            literal,
                            ".",
                            false,
                            string.format("%s [%s] %s: '%s' is an int literal", name, set.name, key, literal)
                        )
                    end
                end
            end
        end
    end
end

---Every job applies to the vanilla shader of the current game build and leaves no placeholder.
function TestShaderPatches:TestBuildOnVanillaShaders()
    luaunit.skipIf(not HasGameData(), "no unpacked game files in " .. DATA_DIR)
    for _, result in ipairs(ShaderBuild.Build(ShaderBuild.LoadJobs(), DATA_DIR)) do
        local label = string.format("%s [%s]", result.target, result.config)
        luaunit.assertTrue(result.ok, label .. ": " .. tostring(result.err))
        luaunit.assertNil(result.text:find("{{", 1, true), label .. ": a placeholder is left")
    end
end

---The build restores the game functions that it replaces.
function TestShaderPatches:TestBuildRestoresGameFunctions()
    luaunit.skipIf(not HasGameData(), "no unpacked game files in " .. DATA_DIR)
    ModTextFileGetContent = nil
    ShaderBuild.Build(ShaderBuild.LoadJobs(), DATA_DIR)
    luaunit.assertNil(ModTextFileGetContent)
end

---Output names keep the extension, so that glslang finds the stage.
function TestShaderPatches:TestOutputName()
    local target = "data/shaders/post_final.frag"
    luaunit.assertEquals(ShaderBuild.OutputName({ config = "default", target = target, }), "post_final.frag")
    luaunit.assertEquals(ShaderBuild.OutputName({ config = "dark", target = target, }), "post_final.dark.frag")
end
