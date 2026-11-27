--- Test runner for Pick Up Your Lantern mod test suite.

package.path = "tests/libs/?.lua;tests/?.lua;" .. package.path

local luaunit = require("luaunit")

require("test_shader_patches")

os.exit(luaunit.LuaUnit.run())
