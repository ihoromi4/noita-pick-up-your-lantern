--- Offline build of the patched shaders of Pick Up Your Lantern.
--- Applies the patches of files/scripts/patches/shader_patches.lua to the unpacked vanilla shaders
--- with the real Diff Patch library, as the mod does at startup, and writes the results to files.
--- scripts/check-shaders runs it and then compiles the results with `noitacli check-shader`.
---
--- Usage from the repository root: lua5.1 scripts/shader_build.lua <game data dir> <output dir>
--- The game data dir holds the unpacked `data/` folder of the game, for example `noita/`.

local MOD_DIR = "pick_up_your_lantern"
local MOD_PREFIX = "mods/pick_up_your_lantern/"

local ShaderBuild = {}

---Reads a whole file in binary mode.
---@param path string
---@return string?
local function ReadFile(path)
    local file = io.open(path, "rb")
    if file == nil then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

---Maps a path of the virtual file system of the game to a path on disk.
---@param path string
---@param data_dir string
---@return string
local function DiskPath(path, data_dir)
    if path:sub(1, #MOD_PREFIX) == MOD_PREFIX then
        return MOD_DIR .. "/" .. path:sub(#MOD_PREFIX + 1)
    end
    if path:sub(1, 5) == "data/" then
        return data_dir .. "/" .. path:sub(6)
    end
    return path
end

---Loads the table of shader patches of the mod.
---@return table<string, ShaderPatchJob>
function ShaderBuild.LoadJobs()
    return dofile(MOD_DIR .. "/files/scripts/patches/shader_patches.lua")
end

---Returns the value sets of a job: the one the mod uses in the game, then the extra ones.
---@param job ShaderPatchJob
---@return ShaderPatchConfig[]
function ShaderBuild.ConfigSets(job)
    local sets = { { name = "default", values = job.config, }, }
    for _, extra in ipairs(job.extra_configs or {}) do
        table.insert(sets, extra)
    end
    return sets
end

---Returns the names of the {{placeholders}} in a text.
---@param text string
---@return table<string, boolean>
function ShaderBuild.Placeholders(text)
    local names = {}
    for name in text:gmatch("{{%s*([%w_]+)%s*}}") do
        names[name] = true
    end
    return names
end

---Reads the patch files of a job from the mod folder.
---@param job ShaderPatchJob
---@return table<string, string> texts Patch texts by their path.
function ShaderBuild.ReadPatches(job)
    local texts = {}
    for _, path in ipairs(job.patches) do
        texts[path] = ReadFile(DiskPath(path, ""))
    end
    return texts
end

---Applies every job in every value set to the vanilla shaders.
---The game functions ModTextFileGetContent and ModTextFileSetContent are replaced by a store in memory
---for the time of the call.
---@param jobs table<string, ShaderPatchJob>
---@param data_dir string Folder with the unpacked game files.
---@return {job: string, config: string, target: string, ok: boolean, err: string?, text: string?}[]
function ShaderBuild.Build(jobs, data_dir)
    local DiffPatch = dofile(MOD_DIR .. "/files/scripts/libs/diff_patch.lua")
    local saved_get = ModTextFileGetContent
    local saved_set = ModTextFileSetContent

    local names = {}
    for name in pairs(jobs) do
        table.insert(names, name)
    end
    table.sort(names)

    local results = {}
    for _, name in ipairs(names) do
        local job = jobs[name]
        for _, set in ipairs(ShaderBuild.ConfigSets(job)) do
            local store = {}
            ModTextFileGetContent = function(path)
                return store[path] or ReadFile(DiskPath(path, data_dir))
            end
            ModTextFileSetContent = function(path, text)
                store[path] = text
            end
            local ok, err = DiffPatch.PatchFileBatch(job.target, job.patches, set.values)
            table.insert(results, {
                job = name,
                config = set.name,
                target = job.target,
                ok = ok,
                err = err,
                text = store[job.target],
            })
        end
    end

    ModTextFileGetContent = saved_get
    ModTextFileSetContent = saved_set
    return results
end

---Returns the output file name of a result: `post_final.frag` for the default values,
---and `post_final.<config>.frag` for an extra value set.
---@param result {config: string, target: string}
---@return string
function ShaderBuild.OutputName(result)
    local file = result.target:match("[^/]+$")
    if result.config == "default" then
        return file
    end
    local stem, ext = file:match("^(.*)(%.[^.]+)$")
    return stem .. "." .. result.config .. ext
end

---Builds the shaders and writes them to the output folder. Prints one line per result.
---@param data_dir string
---@param out_dir string The folder must exist.
---@return boolean success
function ShaderBuild.Main(data_dir, out_dir)
    if ReadFile(data_dir .. "/shaders/post_final.frag") == nil then
        io.stderr:write(string.format(
            "Error: no unpacked game files in '%s'. Link the data folder of the game there, "
                .. "or set NOITA_DATA_DIR.\n",
            data_dir
        ))
        return false
    end

    local success = true
    for _, result in ipairs(ShaderBuild.Build(ShaderBuild.LoadJobs(), data_dir)) do
        local label = string.format("%s [%s]", result.target, result.config)
        if result.ok and result.text:find("{{", 1, true) then
            result.ok = false
            result.err = "the result still has a {{placeholder}}"
        end
        if result.ok then
            local path = out_dir .. "/" .. ShaderBuild.OutputName(result)
            local file = assert(io.open(path, "wb"))
            file:write(result.text)
            file:close()
            print(string.format("Patched: %s -> %s", label, path))
        else
            success = false
            io.stderr:write(string.format("FAILED: %s: %s\n", label, tostring(result.err)))
        end
    end
    return success
end

local source = debug.getinfo(1, "S").source
local is_main = arg ~= nil and arg[0] ~= nil and source:sub(2) == arg[0]
if is_main then
    if arg[1] == nil or arg[2] == nil then
        io.stderr:write("Usage: lua5.1 scripts/shader_build.lua <game data dir> <output dir>\n")
        os.exit(2)
    end
    os.exit(ShaderBuild.Main(arg[1], arg[2]) and 0 or 1)
end

return ShaderBuild
