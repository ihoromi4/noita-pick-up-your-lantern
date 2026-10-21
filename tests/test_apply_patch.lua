--- Unit tests for DiffPatch.ApplyPatch.

local luaunit = require("luaunit")
local DiffPatch = dofile("pick_up_your_lantern/files/scripts/libs/diff_patch.lua")

---Helper to read whole text file.
---@param path string
---@return string
local function ReadFile(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

TestApplyPatch = {}

---Tests simple line replacement in unified diff.
function TestApplyPatch:TestSimpleReplacement()
    local content = "line 1\nline 2\nline 3\n"
    local patch = [[
--- a
+++ b
@@ -1,3 +1,3 @@
 line 1
-line 2
+line TWO
 line 3
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "line 1\nline TWO\nline 3\n")
end

---Tests line insertion without removal.
function TestApplyPatch:TestInsertionOnly()
    local content = "line 1\nline 2\n"
    local patch = [[
--- a
+++ b
@@ -1,2 +1,3 @@
 line 1
+line 1.5
 line 2
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "line 1\nline 1.5\nline 2\n")
end

---Tests line deletion without addition.
function TestApplyPatch:TestDeletionOnly()
    local content = "line 1\nline to delete\nline 2\n"
    local patch = [[
--- a
+++ b
@@ -1,3 +1,2 @@
 line 1
-line to delete
 line 2
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "line 1\nline 2\n")
end

---Tests multiple hunks in a single patch file applied sequentially.
function TestApplyPatch:TestMultipleHunks()
    local content = "header\nblock 1\nsep 1\nsep 2\nblock 2\nfooter\n"
    local patch = [[
--- a
+++ b
@@ -1,3 +1,3 @@
 header
-block 1
+BLOCK ONE
 sep 1
@@ -4,3 +4,3 @@
 sep 2
-block 2
+BLOCK TWO
 footer
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "header\nBLOCK ONE\nsep 1\nsep 2\nBLOCK TWO\nfooter\n")
end

---Tests LF line ending preservation.
function TestApplyPatch:TestLineEndingPreservationLf()
    local fixture = ReadFile("tests/fixtures/sample_lf.frag")
    local patch = [[
--- sample.frag
+++ sample.frag
@@ -4,3 +4,3 @@

-const float BLUR_RADIUS = 5.0;
+const float BLUR_RADIUS = 10.0;

]]
    local result, ok, err = DiffPatch.ApplyPatch(fixture, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertFalse(result:find("\r\n", 1, true) ~= nil)
    luaunit.assertTrue(result:find("const float BLUR_RADIUS = 10.0;\n", 1, true) ~= nil)
end

---Tests CRLF line ending preservation.
function TestApplyPatch:TestLineEndingPreservationCrlf()
    local fixture = ReadFile("tests/fixtures/sample_crlf.frag")
    local patch = [[
--- sample.frag
+++ sample.frag
@@ -4,3 +4,3 @@

-const float BLUR_RADIUS = 5.0;
+const float BLUR_RADIUS = 10.0;

]]
    local result, ok, err = DiffPatch.ApplyPatch(fixture, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertTrue(result:find("\r\n", 1, true) ~= nil)
    luaunit.assertTrue(result:find("const float BLUR_RADIUS = 10.0;\r\n", 1, true) ~= nil)
end

---Tests trailing newline preservation when target content has no trailing newline.
function TestApplyPatch:TestNoTrailingNewlinePreserved()
    local content = "line 1\nline 2"
    local patch = [[
--- a
+++ b
@@ -1,2 +1,2 @@
 line 1
-line 2
+line 2 modified
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "line 1\nline 2 modified")
end

---Tests fallback matching when lines differ only in trailing whitespace (RTrim fallback).
function TestApplyPatch:TestRTrimFallback()
    -- Source has trailing space on line 2, patch does not
    local content = "line 1\nline 2   \nline 3\n"
    local patch = [[
--- a
+++ b
@@ -1,3 +1,3 @@
 line 1
-line 2
+line REPLACED
 line 3
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "line 1\nline REPLACED\nline 3\n")
end

---Tests idempotency: re-applying a patch returns true and leaves content unchanged.
function TestApplyPatch:TestIdempotency()
    local content = "int a = 1;\nint b = 2;\n"
    local patch = [[
--- a
+++ b
@@ -1,2 +1,2 @@
 int a = 1;
-int b = 2;
+int b = 42;
]]
    local once, ok1, err1 = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok1)
    luaunit.assertNil(err1)
    luaunit.assertEquals(once, "int a = 1;\nint b = 42;\n")

    local twice, ok2, err2 = DiffPatch.ApplyPatch(once, patch)
    luaunit.assertTrue(ok2)
    luaunit.assertNil(err2)
    luaunit.assertEquals(twice, once)
end

---Tests failure when context does not match in target content.
function TestApplyPatch:TestContextMismatchFailure()
    local content = "completely different content\n"
    local patch = [[
--- a
+++ b
@@ -1,2 +1,2 @@
 missing line 1
-missing line 2
+replacement
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "failed to match context")
    -- Content must remain unmodified on failure
    luaunit.assertEquals(result, content)
end

---Tests comments starting with # and headers are ignored outside hunks.
function TestApplyPatch:TestIgnoresCommentsAndHeaders()
    local content = "target line\n"
    local patch = [[
# This is a comment at the top
# Another descriptive comment
--- old_file.frag
+++ new_file.frag
# Comment right before hunk
@@ -1,1 +1,1 @@
-target line
+patched line
# Trailing comment
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "patched line\n")
end

---Tests template rendering integration inside ApplyPatch.
function TestApplyPatch:TestTemplateIntegration()
    local content = "radius = 5.0;\n"
    local patch = [[
--- a
+++ b
@@ -1,1 +1,1 @@
-radius = 5.0;
+radius = {{NEW_RADIUS}};
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch, {
        NEW_RADIUS = "15.0",
    })
    luaunit.assertTrue(ok)
    luaunit.assertNil(err)
    luaunit.assertEquals(result, "radius = 15.0;\n")
end

---Tests ApplyPatch fails early if template variables are missing.
function TestApplyPatch:TestMissingTemplateVariableFails()
    local content = "radius = 5.0;\n"
    local patch = [[
--- a
+++ b
@@ -1,1 +1,1 @@
-radius = 5.0;
+radius = {{UNKNOWN}};
]]
    local result, ok, err = DiffPatch.ApplyPatch(content, patch, {})
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "Missing required template variables: UNKNOWN")
    luaunit.assertEquals(result, content)
end

---Tests error when content is empty or invalid.
function TestApplyPatch:TestEmptyOrInvalidContent()
    local patch = "@@ -1,1 +1,1 @@\n-a\n+b\n"
    local _, ok1, err1 = DiffPatch.ApplyPatch("", patch)
    luaunit.assertFalse(ok1)
    luaunit.assertStrContains(err1, "Target content is empty or invalid")

    local _, ok2, err2 = DiffPatch.ApplyPatch(nil, patch)
    luaunit.assertFalse(ok2)
    luaunit.assertStrContains(err2, "Target content is empty or invalid")
end

---Tests error when patch contains no valid @@ hunks.
function TestApplyPatch:TestPatchWithoutHunks()
    local content = "some content\n"
    local patch = "# Just comments\n--- a\n+++ b\n"
    local result, ok, err = DiffPatch.ApplyPatch(content, patch)
    luaunit.assertFalse(ok)
    luaunit.assertStrContains(err, "No valid diff hunks")
    luaunit.assertEquals(result, content)
end
