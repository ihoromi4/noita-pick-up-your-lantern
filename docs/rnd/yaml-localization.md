# YAML Localization

[← Back to R&D Index](../rnd.md)

> [!NOTE]
> Status: **Postponed**. The idea has been analyzed but not implemented. Translations are still stored in `pick_up_your_lantern/files/translations.csv`.

The idea: keep the mod translations in a YAML file in the repository and convert them to the CSV format used by Noita when the game starts, using the [lua-tinyyaml](https://github.com/peposso/lua-tinyyaml) parser.

> [!NOTE]
> The library is not bundled with the mod. To implement the idea, add `tinyyaml.lua` from the repository to `pick_up_your_lantern/files/scripts/libs/`.

## Motivation

`AppendTranslations()` in `init.lua` reads `files/translations.csv` and appends it to `data/translations/common.csv`. The CSV file is hard to edit and review:

- Every row has a fixed set of columns (`key,en,ru,pt-br,es-es,de,fr-fr,it,pl,zh-cn,jp,ko,...`), and most of them are empty (`,,,,,,`). It is easy to shift a translation into the wrong language column.
- Values with commas or quotes must be wrapped in quotes, and quotes inside them must be doubled.
- Line breaks are written as a literal `\n`.
- Long rows make git diffs hard to read: changing one language shows the whole row as changed.

## File Extension

YAML files cannot be shipped with a `.yaml` extension:

- Noita's virtual file system mounts mod files only with allowed extensions (`.txt`, `.xml`, `.lua`, `.csv`, `.json`, `.frag`, `.vert`, `.png`). For a `.yaml` file `ModTextFileGetContent()` returns `nil`.
- The Steam uploader uploads only `.lua`, `.xml`, `.png`, `.txt`, `.csv`, `.bmp`, `.frag`, `.vert`, `.bank`, `.bin`, `.plz` files (see [Steam Publishing](../steam/steam_publishing.md)). A `.yaml` file would not reach Workshop subscribers.

The file must be named `translations.yaml.txt`, following the same approach as the `*.patch.txt` files used by [Diff Patch](diff-patch.md). For syntax highlighting, add a file association in VS Code:

```json
{
    "files.associations": {
        "*.yaml.txt": "yaml"
    }
}
```

## tinyyaml Limitations

[lua-tinyyaml](https://github.com/peposso/lua-tinyyaml) (version `0.1`) supports only a subset of YAML, and it fails silently on several common cases. Results of a test run in `luajit`:

| Input | Result | Impact |
| --- | --- | --- |
| `en: "Line\nTwo, \"q\""` | Correct; `\n` becomes a real line break | OK; it must be converted back to a literal `\n` when generating CSV |
| `en: \|-` block scalar | Works | OK for long descriptions, but **blank lines inside the block are lost** |
| `zh-cn: 提灯` (UTF-8) | Correct | - |
| `en: Note: something` | `"Note"` | **The value is truncated silently** |
| `en: Value # text` | `"Value"` | `#` after a space starts a comment |
| `en: 'It''s fine'` | `"It"` | The `''` escape is not supported |
| `en: 100` / `true` / `2024-01-01` | number / boolean / timestamp table | Values must be converted with `tostring` or always quoted |
| Duplicate key | The second one becomes `key_1` | No error; the duplicated key silently breaks |
| `\x41`, `\u....` escapes | Bug in `\x` handling (`ssub(i + 2, i + 3)`), `\u` is not supported | Do not use them |
| Syntax error | `error()` is raised | Without `pcall` the whole `init.lua` fails |

Resulting rule for the file: **all values must be written in double quotes** (or as `|-` blocks without blank lines), keys without quotes.

## Pros

- The file is easy to read and review: every translation is on its own line, and git diffs show exactly which language changed.
- No empty columns and no risk of shifting a column; each language is named explicitly (`pl`, `zh-cn`).
- Comments (`#`) and grouping by sections (items, settings) are available.
- Multi-line descriptions can be written as real lines instead of a literal `\n`.
- Adding a new language does not require counting commas. Missing translations can be detected and logged at startup.
- No build step: the mod still works directly from the repository or a symlink.

## Cons

- **Dependency on an incomplete parser.** A file that is valid for a YAML linter or an editor can be parsed incorrectly in the game (see the table above). The "always quote values" rule must be followed, and the code must validate the result.
- The `.yaml.txt` extension is non-standard: without an editor configuration there is no highlighting, and external tools (yamllint, Crowdin) need extra configuration.
- More runtime code: parsing and CSV generation with correct escaping (`"` → `""`, quotes around fields with `,` or `"`, line break → `\n`). This is a new failure point at game startup, so it needs `pcall` and a clear log message.
- The Noita column order (`en,ru,pt-br,es-es,de,fr-fr,it,pl,zh-cn,jp,ko`) must be kept as a constant in the code. The CSV file has the same dependency implicitly.
- Slightly longer startup: the parser builds strings character by character. With about 50 keys this takes milliseconds, so it is negligible.
- Translators can no longer open the file in a spreadsheet editor (LibreOffice, Google Sheets).

## Proposed Design

### File Format

A single file `pick_up_your_lantern/files/translations.yaml.txt` with a map of languages per key. All languages stay side by side, as in the CSV, so missing translations are easy to spot:

```yaml
# Items
item_lantern:
  en: "Lantern"
  ru: "Фонарь"
  pl: "Latarnia"
  zh-cn: "提灯"

pick_up_your_lantern_lantern_progression_desc:
  en: |-
    Lanterns spawn with a quality from dim to masterwork; deeper biomes hold brighter lanterns.
    Requires starting a new game.
```

### Code

A new module `pick_up_your_lantern/files/scripts/translations.lua`:

- `LANGUAGES = { "en", "ru", "pt-br", "es-es", "de", "fr-fr", "it", "pl", "zh-cn", "jp", "ko", }`: the column order of `common.csv`.
- `EscapeCsvField(value)`: `tostring`, line break → literal `\n`, remove `\r`; if the field contains `,` or `"`, double the quotes and wrap the field in quotes.
- `BuildTranslationsCsv(yaml_text)`: `pcall(tinyyaml.parse, yaml_text)`; build a `key,<languages...>` row for every key, sorted for deterministic output. Log warnings for keys with a `_N` suffix (possible duplicates), non-string values, unknown language codes, and a missing `en` value.
- `AppendTranslations()` moves here from `init.lua` and reads `mods/<MOD_ID>/files/translations.yaml.txt` via `ModTextFileGetContent()`.

`init.lua` loads the module with `dofile_once` and keeps calling `AppendTranslations()` in the same place. The current CSV is converted to YAML once with a script, with every value quoted, and `translations.csv` is removed.

### Alternative

Keep YAML in the repository and generate the CSV with a script before publishing. This removes the runtime parser and its risks, but adds a build step and the risk of an outdated CSV, which does not fit the current workflow without a build step.

## Verification Plan

- Run the conversion in `luajit` with a `ModTextFileGetContent` stub and compare the generated CSV with the current `translations.csv` (sorted, since the row order may differ). All keys and languages must match.
- Make sure a broken YAML file does not crash `init.lua` and an error is printed to the log.
- In the game, check lantern names and descriptions and the mod settings screen in `en`, `ru`, `pl`, `zh-cn`, including multi-line descriptions.
- Make sure `translations.yaml.txt` is not excluded in `workshop.xml`.
