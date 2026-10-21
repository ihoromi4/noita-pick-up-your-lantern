# Pick Up Your Lantern

A Noita mod that allows picking up, holding, and throwing lanterns.

## Documentation

The project documentation is organized under the `docs/` directory:

- [Functional Requirements](docs/requirements.md): Comprehensive functional specifications, in-world physics, inventory lifecycle, holding, throwing, and combat mechanics.
- [Development Roadmap](docs/roadmap.md): Release milestones and feature scopes across versions.

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
