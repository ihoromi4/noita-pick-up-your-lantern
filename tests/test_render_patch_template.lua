--- Unit tests for DiffPatch.RenderPatchTemplate.

local luaunit = require("luaunit")
local DiffPatch = dofile("pick_up_your_lantern/files/scripts/libs/diff_patch.lua")

TestRenderPatchTemplate = {}

---Tests single variable substitution.
function TestRenderPatchTemplate:TestSingleVariableSubstitution()
    local template = "const float BLUR = {{BLUR_RADIUS}};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        BLUR_RADIUS = "10.0",
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "const float BLUR = 10.0;")
end

---Tests multiple variables and multiple occurrences of the same variable.
function TestRenderPatchTemplate:TestMultipleVariablesAndRepetition()
    local template = "a = {{A}}; b = {{B}}; a_again = {{A}};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        A = "first",
        B = "second",
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "a = first; b = second; a_again = first;")
end

---Tests whitespace tolerance inside placeholder braces.
function TestRenderPatchTemplate:TestWhitespaceInsidePlaceholder()
    local template = "val = {{   SPACED_VAR   }};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        SPACED_VAR = "cleaned",
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "val = cleaned;")
end

---Tests non-string types in config values (numbers, booleans).
function TestRenderPatchTemplate:TestNonStringTypes()
    local template = "num = {{NUM}}; flag = {{FLAG}};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        NUM = 42,
        FLAG = true,
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "num = 42; flag = true;")
end

---Tests error when required template variables are missing.
function TestRenderPatchTemplate:TestMissingVariableError()
    local template = "x = {{X}}; y = {{Y}}; x2 = {{X}};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        X = "val",
    })
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "Missing required template variables: Y")
    -- When validation fails, original template should be returned untouched
    luaunit.assertEquals(result, template)
end

---Tests multiple missing variables are deduplicated in error message.
function TestRenderPatchTemplate:TestMissingVariablesDeduplicated()
    local template = "a = {{A}}; a2 = {{A}}; b = {{B}};"
    local _, ok, err = DiffPatch.RenderPatchTemplate(template, {})
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "A")
    luaunit.assertStrContains(err, "B")
end

---Tests unused keys in config table are silently ignored.
function TestRenderPatchTemplate:TestUnusedConfigKeysIgnored()
    local template = "val = {{USED}};"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, {
        USED = "yes",
        UNUSED = "ignored",
        EXTRA = 123,
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "val = yes;")
end

---Tests template with no placeholders passes with nil config.
function TestRenderPatchTemplate:TestNilConfigWithoutPlaceholders()
    local template = "no placeholders here"
    local result, ok, err = DiffPatch.RenderPatchTemplate(template, nil)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, template)
end

---Tests template with placeholders fails when config is nil.
function TestRenderPatchTemplate:TestNilConfigWithPlaceholders()
    local template = "needs {{VAR}}"
    local _, ok, err = DiffPatch.RenderPatchTemplate(template, nil)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "Missing required template variables: VAR")
end

---Tests invalid patch argument type.
function TestRenderPatchTemplate:TestInvalidPatchArgument()
    local result, ok, err = DiffPatch.RenderPatchTemplate(123, {})
    luaunit.assertFalse(ok)
    luaunit.assertEquals(result, "")
    luaunit.assertEquals(err, "Patch must be a string")
end
