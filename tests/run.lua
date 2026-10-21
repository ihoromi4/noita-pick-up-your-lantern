--- Test runner for Pick Up Your Lantern mod test suite.

package.path = "tests/libs/?.lua;tests/?.lua;" .. package.path

local luaunit = require("luaunit")

require("test_render_patch_template")
require("test_apply_patch")
require("test_apply_patch_batch")

os.exit(luaunit.LuaUnit.run())
