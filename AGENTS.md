# AGENTS.md

You are working in a context of the **Pick Up Your Lantern** - a mod for Noita game that allows picking up, holding, and throwing lanterns.

## Core directories and files

- `docs/`: Markdown documentation of the mod.
- `pick_up_your_lantern/`: Source files of the mod.
- `pick_up_your_lantern/init.lua`: Mod initialization file.

## Code style

Follow LuaLS (Lua Language Server):

- Use 4 spaces indentation.
- Document function signatures using LDoc.
- Variables names should use snake case.
- Constants should use upper snake case.
- Function names should use upper camel case.
- Add a trailing comma to all fields in tables, including the last one.

Markdown style guide:

- Use a single H1 heading.
- Add newlines before and after headings.
- Do not add position numbering in headings.
- Use section links `[Link Text](#anchor-name)`.
- Use relative file links inside docs `[Other File Name](.../other-file.md)`.
