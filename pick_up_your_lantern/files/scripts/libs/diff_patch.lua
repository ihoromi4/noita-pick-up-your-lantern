--- Single-file Unified Diff Patcher & Template Engine for Noita Mods.
--- Supports {{var}} interpolation, strict variable validation, CRLF/LF preservation,
--- idempotency checks, and batch patching.

---@diagnostic disable: undefined-global

local DiffPatch = {}

--- Removes trailing whitespace (spaces and tabs) from a line for fallback matching.
---@param s string
---@return string
local function RTrim(s)
    return (s:gsub("[ \t]+$", ""))
end

--- Splits text into lines and detects the dominant line ending (\r\n or \n).
---@param str string
---@return string[] lines, string eol
local function SplitLines(str)
    local eol = str:find("\r\n", 1, true) and "\r\n" or "\n"
    local normalized = str:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    local pos = 1
    local len = #normalized

    while pos <= len do
        local next_nl = normalized:find("\n", pos, true)
        if next_nl then
            table.insert(lines, normalized:sub(pos, next_nl - 1))
            pos = next_nl + 1
        else
            table.insert(lines, normalized:sub(pos))
            break
        end
    end

    -- Handle trailing newline accurately
    if len > 0 and normalized:sub(len, len) == "\n" then
        table.insert(lines, "")
    end

    return lines, eol
end

--- Parses unified diff text into structured hunks.
--- Ignores comments, headers (---, +++), and metadata outside hunks.
---@param patch_text string
---@return table[] hunks, string? err
local function ParseHunks(patch_text)
    local lines = SplitLines(patch_text)
    local hunks = {}
    local current_hunk = nil

    for idx, line in ipairs(lines) do
        if line:sub(1, 2) == "@@" then
            if current_hunk then
                table.insert(hunks, current_hunk)
            end
            current_hunk = {
                header = line,
                line_num = idx,
                old_lines = {},
                new_lines = {},
            }
        elseif current_hunk then
            local prefix = line:sub(1, 1)
            local content = line:sub(2)

            if prefix == " " then
                table.insert(current_hunk.old_lines, content)
                table.insert(current_hunk.new_lines, content)
            elseif prefix == "-" then
                -- Ignore "--- " file header if encountered without prior hunk termination
                if line:sub(1, 4) ~= "--- " then
                    table.insert(current_hunk.old_lines, content)
                end
            elseif prefix == "+" then
                if line:sub(1, 4) ~= "+++ " then
                    table.insert(current_hunk.new_lines, content)
                end
            elseif prefix == "\\" then
                -- "\ No newline at end of file" - standard git diff marker, ignore
            elseif prefix == "#" or line:match("^%s*$") then
                -- Allow empty lines or '#' comments between hunks;
                -- if encountered, close current hunk so comments don't corrupt context
                if #current_hunk.old_lines > 0 or #current_hunk.new_lines > 0 then
                    table.insert(hunks, current_hunk)
                    current_hunk = nil
                end
            end
        end
    end

    if current_hunk and (#current_hunk.old_lines > 0 or #current_hunk.new_lines > 0) then
        table.insert(hunks, current_hunk)
    end

    if #hunks == 0 then
        return {}, "No valid diff hunks (@@ ... @@) found in patch"
    end

    return hunks, nil
end

--- Searches for a sequence of lines in source_lines starting at search_start.
--- First tries exact match, then falls back to trailing-whitespace-insensitive match.
---@param source_lines string[]
---@param target_lines string[]
---@param search_start number
---@return number? match_index
local function FindBlock(source_lines, target_lines, search_start)
    local target_count = #target_lines
    if target_count == 0 then
        return search_start
    end

    local max_start = #source_lines - target_count + 1

    -- Pass 1: Exact match
    for i = search_start, max_start do
        local matched = true
        for j = 1, target_count do
            if source_lines[i + j - 1] ~= target_lines[j] then
                matched = false
                break
            end
        end
        if matched then
            return i
        end
    end

    -- Pass 2: RTrim fallback (ignores trailing spaces/tabs differences)
    for i = search_start, max_start do
        local matched = true
        for j = 1, target_count do
            if RTrim(source_lines[i + j - 1]) ~= RTrim(target_lines[j]) then
                matched = false
                break
            end
        end
        if matched then
            return i
        end
    end

    return nil
end

--- Interpolates {{var}} placeholders in a patch template using values from config.
--- Validates that ALL placeholders present in the template are provided in config.
--- Unused keys in config are silently ignored.
---@param patch string Raw patch string potentially containing {{var}} placeholders.
---@param config table<string, any>? Key-value table of template arguments.
---@return string rendered_patch, boolean success, string? err
function DiffPatch.RenderPatchTemplate(patch, config)
    if type(patch) ~= "string" then
        return "", false, "Patch must be a string"
    end

    config = config or {}
    local missing_map = {}
    local missing_list = {}

    local rendered = patch:gsub("{{%s*([%w_]+)%s*}}", function(key)
        local val = config[key]
        if val == nil then
            if not missing_map[key] then
                missing_map[key] = true
                table.insert(missing_list, key)
            end
            return "{{" .. key .. "}}"
        end
        return tostring(val)
    end)

    if #missing_list > 0 then
        local err_msg = "Missing required template variables: " .. table.concat(missing_list, ", ")
        return patch, false, err_msg
    end

    return rendered, true, nil
end

--- Applies a single unified diff patch (with optional template config) to content.
---@param content string Target file content.
---@param patch string Unified diff text (may contain {{var}} placeholders).
---@param config table<string, any>? Optional template parameters.
---@return string new_content, boolean success, string? err
function DiffPatch.ApplyPatch(content, patch, config)
    if type(content) ~= "string" or content == "" then
        return content or "", false, "Target content is empty or invalid"
    end

    -- Step 1: Render and validate template variables
    local rendered_patch, render_ok, render_err = DiffPatch.RenderPatchTemplate(patch, config)
    if not render_ok then
        return content, false, render_err
    end

    -- Step 2: Parse hunks
    local hunks, parse_err = ParseHunks(rendered_patch)
    if parse_err then
        return content, false, parse_err
    end

    -- Step 3: Apply hunks sequentially
    local source_lines, eol = SplitLines(content)
    local search_start = 1

    for hunk_idx, hunk in ipairs(hunks) do
        local match_index = FindBlock(source_lines, hunk.old_lines, search_start)

        if not match_index then
            -- Idempotency check: check if this hunk was already applied earlier
            local already_applied_index = FindBlock(source_lines, hunk.new_lines, 1)
            if already_applied_index then
                search_start = already_applied_index + #hunk.new_lines
            else
                local first_line = hunk.old_lines[1] or "<empty>"
                local err = string.format(
                    "Hunk #%d (%s at line %d) failed to match context near: '%s'",
                    hunk_idx,
                    hunk.header,
                    hunk.line_num,
                    first_line
                )
                return content, false, err
            end
        else
            -- Replace old_lines with new_lines
            local old_count = #hunk.old_lines
            for _ = 1, old_count do
                table.remove(source_lines, match_index)
            end
            for j = #hunk.new_lines, 1, -1 do
                table.insert(source_lines, match_index, hunk.new_lines[j])
            end

            search_start = match_index + #hunk.new_lines
        end
    end

    return table.concat(source_lines, eol), true, nil
end

--- Applies an ordered list of patches to content atomically.
--- Each entry in `patches` can be either:
---   1. A raw patch string: `"--- a\n+++ b\n..."`
---   2. A table descriptor: `{ patch = "...", config = {...}, name = "01_uniforms" }`
--- If any patch fails, rolls back and returns the original unpatched content.
---@param content string Target file content.
---@param patches (string|table)[] Array of patch strings or patch descriptor tables.
---@param config table<string, any>? Shared default config table for all patches in the batch.
---@return string new_content, boolean success, string? err
function DiffPatch.ApplyPatchBatch(content, patches, config)
    if type(content) ~= "string" or content == "" then
        return content or "", false, "Target content is empty or invalid"
    end
    if type(patches) ~= "table" or #patches == 0 then
        return content, false, "Patches list must be a non-empty table"
    end

    local current_content = content

    for idx, entry in ipairs(patches) do
        local patch_str
        local merged_config = {}
        local patch_name = string.format("patch[%d]", idx)

        -- Copy shared config first
        if type(config) == "table" then
            for k, v in pairs(config) do
                merged_config[k] = v
            end
        end

        if type(entry) == "string" then
            patch_str = entry
        elseif type(entry) == "table" then
            patch_str = entry.patch or entry[1]
            if entry.name then
                patch_name = entry.name
            end
            -- Override with per-patch local config if provided
            if type(entry.config) == "table" then
                for k, v in pairs(entry.config) do
                    merged_config[k] = v
                end
            end
        else
            return content, false, string.format("Invalid patch entry at index %d", idx)
        end

        local next_content, ok, err = DiffPatch.ApplyPatch(current_content, patch_str, merged_config)
        if not ok then
            return content, false, string.format("[%s] %s", patch_name, err or "Unknown error")
        end

        current_content = next_content
    end

    return current_content, true, nil
end

--- Reads patch content from Noita VFS.
--- Noita's virtual filesystem requires files to have whitelisted extensions (.txt, .lua, .xml, etc.).
--- If path ends in .patch, attempts .patch.txt and .txt fallbacks.
---@param path string
---@return string? content
local function ReadPatchFile(path)
    local raw = ModTextFileGetContent(path)
    if raw and raw ~= "" then
        return raw
    end

    if path:match("%.patch$") then
        raw = ModTextFileGetContent(path .. ".txt")
        if raw and raw ~= "" then
            return raw
        end
        raw = ModTextFileGetContent((path:gsub("%.patch$", ".txt")))
        if raw and raw ~= "" then
            return raw
        end
    end

    return nil
end

--- High-level Noita VFS helper: reads target_path and patch_path, applies patch, and writes back.
---@param target_path string Path to target file (e.g., "data/shaders/post_final.frag").
---@param patch_path string Path to .patch file in mod VFS.
---@param config table<string, any>? Optional template parameters.
---@return boolean success, string? err
function DiffPatch.PatchFile(target_path, patch_path, config)
    local content = ModTextFileGetContent(target_path)
    if not content or content == "" then
        return false, "Cannot read target file: " .. tostring(target_path)
    end

    local patch = ReadPatchFile(patch_path)
    if not patch or patch == "" then
        return false, "Cannot read patch file: " .. tostring(patch_path)
    end

    local patched, ok, err = DiffPatch.ApplyPatch(content, patch, config)
    if not ok then
        return false, string.format("Failed patching '%s' with '%s': %s", target_path, patch_path, err)
    end

    ModTextFileSetContent(target_path, patched)
    return true, nil
end

--- High-level Noita VFS helper: applies multiple .patch files from VFS to a single target file.
---@param target_path string Path to target file (e.g., "data/shaders/post_final.frag").
---@param patch_paths string[] Array of VFS paths to .patch files.
---@param config table<string, any>? Shared template parameters.
---@return boolean success, string? err
function DiffPatch.PatchFileBatch(target_path, patch_paths, config)
    local content = ModTextFileGetContent(target_path)
    if not content or content == "" then
        return false, "Cannot read target file: " .. tostring(target_path)
    end

    local batch_entries = {}
    for _, path in ipairs(patch_paths) do
        local raw_patch = ReadPatchFile(path)
        if not raw_patch or raw_patch == "" then
            return false, "Cannot read patch file: " .. tostring(path)
        end
        table.insert(batch_entries, {
            name = path,
            patch = raw_patch,
        })
    end

    local patched, ok, err = DiffPatch.ApplyPatchBatch(content, batch_entries, config)
    if not ok then
        return false, string.format("Batch patch failed on '%s': %s", target_path, err)
    end

    ModTextFileSetContent(target_path, patched)
    return true, nil
end

return DiffPatch
