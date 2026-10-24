# Pick Up Your Lantern

A Noita mod that allows picking up, holding, and throwing lanterns.

## Documentation

Start with the [Documentation Index](docs/index.md).

The index is the single entry point to all project documentation, and this README deliberately links only to it. As the mod grows, documents get added, renamed and split, and keeping one entry point means only the index has to change, so links scattered across the repository never go stale or contradict each other.

## Testing

Unit tests use LuaUnit and run under LuaJIT (matching Noita's runtime environment) or standard Lua 5.1+:

```bash
# Run all unit tests
luajit tests/run.lua

# Run with verbose test output
luajit tests/run.lua -v

# Run a specific test suite or test pattern
luajit tests/run.lua -p TestApplyPatch
luajit tests/run.lua -p TestRenderPatchTemplate
luajit tests/run.lua -p TestApplyPatchBatch
```
