# AGENTS.md

You are working in a context of the **Pick Up Your Lantern** - a mod for Noita game that allows picking up, holding, and throwing lanterns.

## Core directories and files

- `docs/`: Markdown documentation of the mod.
- `pick_up_your_lantern/`: Source files of the mod.
- `pick_up_your_lantern/init.lua`: Mod initialization file.

## Rules

- Use Conventional Commits naming convention for new commits

## Development

- Use Conventional Commits convention for commit naming

## Documentation

- Write documentation in full sentences. Do not drop articles, conjunctions, prepositions, or verbs to save space
- Each sentence carries one idea. Prefer short sentences, around 20 words or fewer. A longer sentence is fine when splitting it would break a single idea apart
- Explain each term the first time it appears. Always use the same word for the same concept
- Before you hand over the text, reread every sentence. If a sentence needs a second read to make sense, rewrite it

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
