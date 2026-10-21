--- Unit tests for DiffPatch.ApplyPatchBatch.

local luaunit = require("luaunit")
local DiffPatch = dofile("pick_up_your_lantern/files/scripts/libs/diff_patch.lua")

TestApplyPatchBatch = {}

---Tests batch patching with an array of raw patch strings.
function TestApplyPatchBatch:TestBatchStringPatches()
    local content = "a = 1;\nb = 2;\nc = 3;\n"
    local patches = {
        "@@ -1,1 +1,1 @@\n-a = 1;\n+a = 10;\n",
        "@@ -2,1 +2,1 @@\n-b = 2;\n+b = 20;\n",
    }
    local result, ok, err = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "a = 10;\nb = 20;\nc = 3;\n")
end

---Tests batch patching with table entries ({patch=, name=} and {[1]=}).
function TestApplyPatchBatch:TestBatchTableEntries()
    local content = "step 1\nstep 2\n"
    local patches = {
        {
            name = "patch_step_1",
            patch = "@@ -1,1 +1,1 @@\n-step 1\n+STEP ONE\n",
        },
        {
            "@@ -2,1 +2,1 @@\n-step 2\n+STEP TWO\n",
        },
    }
    local result, ok, err = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "STEP ONE\nSTEP TWO\n")
end

---Tests per-patch config overrides shared batch config.
function TestApplyPatchBatch:TestBatchConfigOverride()
    local content = "val1 = 0;\nval2 = 0;\n"
    local patches = {
        {
            name = "p1",
            patch = "@@ -1,1 +1,1 @@\n-val1 = 0;\n+val1 = {{VAL}};\n",
        },
        {
            name = "p2",
            patch = "@@ -2,1 +2,1 @@\n-val2 = 0;\n+val2 = {{VAL}};\n",
            config = {
                VAL = 999,
            },
        },
    }
    local shared_config = {
        VAL = 100,
    }
    local result, ok, err = DiffPatch.ApplyPatchBatch(content, patches, shared_config)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "val1 = 100;\nval2 = 999;\n")
end

---Tests atomicity: if an intermediate patch fails, content rolls back to original.
function TestApplyPatchBatch:TestBatchRollbackOnFailure()
    local content = "initial 1\ninitial 2\n"
    local patches = {
        {
            name = "success_patch",
            patch = "@@ -1,1 +1,1 @@\n-initial 1\n+modified 1\n",
        },
        {
            name = "failing_patch",
            patch = "@@ -1,1 +1,1 @@\n-nonexistent context\n+replacement\n",
        },
    }
    local result, ok, err = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "[failing_patch]")
    -- Must roll back to original content, not intermediate state
    luaunit.assertEquals(result, content)
end

---Tests error message includes patch name or default index.
function TestApplyPatchBatch:TestBatchErrorIncludesPatchName()
    local content = "content\n"
    local patches = {
        "@@ -1,1 +1,1 @@\n-missing\n+replacement\n",
    }
    local _, ok, err = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "[patch[1]]")
end

---Tests error on empty or invalid patches table.
function TestApplyPatchBatch:TestBatchEmptyOrInvalidList()
    local content = "content\n"
    local _, ok1, err1 = DiffPatch.ApplyPatchBatch(content, {})
    luaunit.assertFalse(ok1)
    luaunit.assertStrContains(err1, "Patches list must be a non-empty table")

    local _, ok2, err2 = DiffPatch.ApplyPatchBatch(content, "not a table")
    luaunit.assertFalse(ok2)
    luaunit.assertStrContains(err2, "Patches list must be a non-empty table")
end

---Tests error on invalid entry type in patches table.
function TestApplyPatchBatch:TestBatchInvalidEntryType()
    local content = "content\n"
    local patches = {
        12345,
    }
    local result, ok, err = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "Invalid patch entry at index 1")
    luaunit.assertEquals(result, content)
end

---Tests batch idempotency: running batch twice leaves content unchanged and returns true.
function TestApplyPatchBatch:TestBatchIdempotency()
    local content = "line A\nline B\n"
    local patches = {
        "@@ -1,1 +1,1 @@\n-line A\n+line ALPHA\n",
        "@@ -2,1 +2,1 @@\n-line B\n+line BETA\n",
    }
    local first, ok1, err1 = DiffPatch.ApplyPatchBatch(content, patches)
    luaunit.assertTrue(ok1)
    luaunit.assertNil(err1)
    luaunit.assertEquals(first, "line ALPHA\nline BETA\n")

    local second, ok2, err2 = DiffPatch.ApplyPatchBatch(first, patches)
    luaunit.assertTrue(ok2)
    luaunit.assertNil(err2)
    luaunit.assertEquals(second, first)
end
