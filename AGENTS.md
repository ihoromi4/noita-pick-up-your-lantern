# AGENTS.md

You are working in a context of the **Pick Up Your Lantern** - a mod for Noita game that allows picking up, holding, and throwing lanterns.

## Core directories and files

- `docs/`: Markdown documentation of the mod. The index of the documentation: @docs/README.md
- `docs/backlog.md`: Planned releases and tasks that are not done yet, grouped by target release and topic.
- `docs/versions/`: Completed work and release notes for each version.
- `pick_up_your_lantern/`: Source files of the mod.
- `pick_up_your_lantern/init.lua`: Mod initialization file.
- `tools/noitakit/`: The Noita Mod Tools DevKit, a Git submodule with the CLI tools and the agent skills. Run the tools with `uv run tools/noitakit/src/noitakit/noitacli.py <command>` from the repository root. In Claude Code, the plain command `noitacli` also works.

## Knowledge

The DevKit holds three skills in `tools/noitakit/skills/`. Each `SKILL.md` is the index of short leaves, and many leaves hold facts that were tested in the game. Open the index that matches the task before you search the wiki, the game files, or your memory. In Claude Code, the skills load as `noitakit:noita-modding`, `noitakit:noita-mod-tools`, and `noitakit:noita-research`.

- `noita-modding/SKILL.md` covers the engine and the Lua API. Read it before you write or debug mod code, for example perks, creatures, items, physics, GUI, the inventory, pixel scenes, biomes, mod settings, or saves.
- `noita-mod-tools/SKILL.md` covers the `noitacli` tools. Read it before you deploy the mod, launch the game, read a `logger.txt`, or publish the mod.
- `noita-research/SKILL.md` covers experiments in the game. Read it when the leaves and the wiki do not tell how the game behaves, and before any experiment.

## Game Runs

These rules protect the saves of the user and the meaning of a test result. The leaves `run-game.md` and `game-log.md` of `noita-mod-tools` explain them.

- Check the Lua files with `noitacli check-lua --all`. Then deploy the mod with `noitacli deploy -s -y`. The symlink lets the game load each edit at the next start without a new deploy.
- The game writes `print` lines and Lua errors to `logger.txt` only when a magic numbers file enables the log. The Workshop mod "Enable Logging" does this, and so does every sandbox mod from `noitacli lab new`.
- In a session with a human, keep the real runs safe. When the game mode "Save Slots Enabler" is enabled, ask the human to start a new game in slot 6 of the "New Game" menu. Without it, a new game may replace the run in `save00`, so copy that run first with `noitacli saves snapshot`. The game option `-save_slot` has no effect. Ask before you continue an existing run in any slot.
- An automatic run uses `save00`. `noitacli run --fresh` and `--new` move the run of `save00` into a snapshot. After the last run, put it back with `noitacli saves restore <name>`, and tell the user.
- An automatic run needs `--until` without a value, which stops the game at the sentinel `[PROBE:DONE]`, and a `--timeout`.
- A run result is valid only when the game has closed and `noitacli log` shows the sentinel, the world as `ok`, and no Lua errors.
- Never pass the options `-clean_*` to the game. They delete player data.
- Remove all probes before a commit, and check with `noitacli lab check`.

## Rules

- Use Conventional Commits naming convention for new commits
- Never add Co-Authored-By trailers or any other AI attribution (e.g. "Generated with ...") to commit messages

## Documentation

- Write documentation in full sentences. Do not drop articles, conjunctions, prepositions, or verbs to save space
- Each sentence carries one idea. Prefer short sentences, around 20 words or fewer. A longer sentence is fine when splitting it would break a single idea apart
- Explain each term the first time it appears. Always use the same word for the same concept
- Before you hand over the text, reread every sentence. If a sentence needs a second read to make sense, rewrite it
- Player guides describe behavior and settings in plain words, without code or file names
- Developer documents describe how things work and why, with links to the source files
- Only confirmed, implemented behavior goes into player guides and developer documents
- Every new document needs a link from [Player Guides](docs/guides/README.md) or [Developer Documentation](docs/dev/README.md)

## Code style

- Use 4 spaces indentation for Python and Lua.
- Follow PEP 8 guidelines for Python.

Lua style:

- Follow LuaLS conventions for Lua.
- Document function signatures using LDoc.
- Variables names should use snake case.
- Constants should use upper snake case.
- Function names should use upper camel case.
- Add a trailing comma to all fields in tables, including the last one.

## Markdown style guide

- Use a single H1 heading.
- Add newlines before and after headings.
- Do not add position numbering in headings.
- Use section links `[Link Text](#anchor-name)`.
- Use relative file links inside docs `[Other File Name](.../other-file.md)`.
- After you edit Markdown files, check them with `scripts/mdlint <files>` and fix the reported problems. Without arguments, the script checks all Markdown files of the repository. The script wraps the linter of the DevKit, so the configuration lives in `tools/noitakit/.markdownlint-cli2.jsonc`.
