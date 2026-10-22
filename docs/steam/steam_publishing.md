# Publishing to Steam Workshop

This guide covers the requirements, configuration files, and publishing procedures for uploading and updating Noita mods on the Steam Workshop across Windows and Linux platforms.

## Table of Content

1. [Architecture Overview](#architecture-overview)
2. [Required Files](#required-files)
3. [Steam Configuration Files](#steam-configuration-files)
4. [Publishing on Windows](#publishing-on-windows)
5. [Publishing on Linux](#publishing-on-linux)
6. [One-Command Automation](#one-command-automation)
7. [Troubleshooting](#troubleshooting)

## Architecture Overview

Noita uses a developer executable (`noita_dev.exe`) to interface with Steam Workshop. When uploading, the engine reads your mod files from the game's `mods/` directory, checks configurations, packages approved assets, and synchronizes them with the Steam Workshop backend via Steam API.

```text
workspace-root/
├── docs/                           # Local documentation (excluded from upload)
└── your_mod/                  # Actual mod directory deployed to Noita/mods/
    ├── init.lua                    # Mod entrypoint
    ├── mod.xml                     # In-game mod metadata (must disable unsafe APIs)
    ├── workshop.xml                # Steam Workshop upload metadata & filters
    ├── workshop_preview_image.png  # Steam Workshop store card thumbnail (16:9)
    ├── workshop_id.txt             # Created after first upload; stores Steam Item ID
    └── files/                      # Mod scripts, textures, and assets
```

## Required Files

Before publishing, ensure the following core files exist in the root of your mod folder:

| File | Purpose | Required |
| --- | --- | --- |
| `mod.xml` | In-game mod descriptor and API security flag | Yes |
| `init.lua` | Mod initialization and lifecycle hooks | Yes |
| `workshop.xml` | Steam Workshop title, description, tags, and file filters | Yes |
| `workshop_preview_image.png` | Workshop thumbnail image (16:9 ratio, under 1 MB) | Yes |
| `workshop_id.txt` | Steam item ID tracker (generated on first publish) | Auto-generated |
| `mod_id.txt` | Internal folder ID for workshop subscribers | Auto-generated |

> **Note:** Only the following file extensions are uploaded by the Steam uploader: `.lua`, `.xml`, `.png`, `.txt`, `.csv`, `.bmp`, `.frag`, `.vert`, `.bank`, `.bin`, `.plz`. Git directories (`.git`) and unsupported extensions are excluded automatically.

## Steam Configuration Files

### `workshop.xml`

This file controls the public information displayed on Steam Workshop and defines which files should be omitted from the upload. Place it directly inside `your_mod/workshop.xml`:

```xml
<Mod
    name="Your Mod Name"
    description="Description of your mod."
    tags="gameplay,alchemy"
    dont_upload_folders="docs|configs|tests"
    dont_upload_files="*.bak|secret_dev_file.txt"
>
</Mod>
```

#### Description

The uploader takes the Workshop page description **only** from the `description` attribute of `workshop.xml`; it cannot be empty and is re-sent on every upload, overwriting edits made on the Steam website.

In this project the source of truth is [steam_mod_description.txt](./steam_mod_description.txt) (Steam BBCode). Copy it into `workshop.xml` before publishing:

```bash
scripts/publish_workshop.py --sync-only
```

The script normalizes line endings, keeps `&`, `<`, `>`, and line breaks as is, rejects straight double quotes (`"`), checks the 8000-character Steam limit, and leaves all other attributes unchanged. A full run of [`scripts/publish_workshop.py`](#one-command-automation) does this automatically.

> **Note:** Noita's XML parser reads attribute values literally up to the next `"` and does not decode entities, so `&quot;` or `&amp;` appear on the Workshop page as is. Use typographic quotes (`“”`) in the description instead of `"`.

> **Note:** Edit the description in `steam_mod_description.txt`, not in `workshop.xml` - the attribute is overwritten on each sync.

#### Supported Tags

Tags must be entered in lowercase and separated by commas. Only the following tags are recognized by Noita:

* `gameplay`, `graphics`, `quality of life`, `translations`
* `perks`, `spells`, `player characters`, `loadouts`
* `biomes`, `total conversions`, `game modes`
* `creatures`, `bosses`, `alchemy`, `tweaks`
* `items`, `audio`, `cheats`, `funny`
* `streaming integration`, `mod dependencies`

#### Exclusion Syntax

* `dont_upload_folders`: Pipe-separated (`|`) list of subdirectories to ignore (e.g. `docs|tests|files/debug`).
* `dont_upload_files`: Pipe-separated (`|`) list of files to ignore (e.g. `todo.txt|config.json`).

### `workshop_preview_image.png`

* Must be a valid PNG image placed in the root of the mod folder.
* Must use a **16:9 aspect ratio** (recommended: `1280x720` or `640x360`).
* File size must be **under 1 MB** (Steam Workshop preview limit). Larger images are rejected by Steam or fail to update the preview.
* Serves as the primary card image in the Steam Workshop catalogue.
* The preview is re-uploaded together with the mod on every publish, so updating the image only requires replacing the file and running the upload again.

Check the image dimensions and size before publishing:

```bash
file your_mod/workshop_preview_image.png   # Should report 16:9 dimensions, e.g. 1280 x 720
ls -l your_mod/workshop_preview_image.png  # Size must be below 1048576 bytes
```

If the file is too large, reduce it losslessly or by color quantization:

```bash
# Lossless recompression
optipng -o7 -strip all your_mod/workshop_preview_image.png

# Lossy, but usually much smaller (256-color palette)
convert your_mod/workshop_preview_image.png -strip -colors 256 PNG8:your_mod/workshop_preview_image.png
```

### `mod.xml` Constraints

Steam Workshop enforces strict security. Your `mod.xml` must not request unsafe API permissions:

```xml
<Mod
    name="Digestive Alchemy"
    description="Realism at its finest."
    request_no_api_restrictions="0"
>
</Mod>
```

> **CRITICAL:** If `request_no_api_restrictions="1"` is set (which grants access to raw `io.*` and `os.*` Lua libraries), the Steam Workshop uploader will reject the mod.

### `workshop_id.txt`

When a mod is uploaded for the first time, Noita contacts Steam, reserves a new Workshop item, and writes the numeric Steam ID to `workshop_id.txt`:

* **Subsequent uploads:** The presence of `workshop_id.txt` signals to `noita_dev.exe` that it should update the existing workshop item instead of creating a duplicate.
* **Re-uploading:** If you manually delete your mod from Steam Workshop and wish to republish it from scratch, delete `workshop_id.txt` first. Otherwise, the upload will fail with error code 2.

### `mod_id.txt`

Steam Workshop downloads subscribed mods into numbered folders (e.g., `steamapps/workshop/content/881100/<workshop_id>/`).

* Noita generates `mod_id.txt` with your folder name (`your_mod`) during upload.
* When subscribed players launch the game, Noita reads `mod_id.txt` to register virtual file paths as `mods/your_mod/...`.
* For local development, this file is optional and can be safely deleted or ignored in `.gitignore`.

## Publishing on Windows

### Step 1: Install developer tools

Copy all files from `Noita\tools_modding\` directly into your main Noita root directory (where `noita.exe` is located). This provides `noita_dev.exe` and `workshop_upload.bat`.

### Step 2: Deploy your mod

Deploy your mod folder into `Noita\mods\your_mod` using symlinks or directory copy.

### Step 3: Run the upload wizard

You can upload interactively or via batch command:

#### Interactive Wizard

Launch `workshop_upload.bat` or run:

```cmd
noita_dev.exe -workshop_upload
```

Follow the prompts on screen:

1. Enter the name of the folder inside `mods/` (`your_mod`).
2. Enter the change notes for this release (or press Enter for none).
3. Confirm details (`y`) to initiate upload.

#### Batch Mode (Non-interactive)

```cmd
noita_dev.exe -workshop_upload your_mod -workshop_upload_change_notes "Initial release"
```

## Publishing on Linux

On Linux, Noita runs inside a Wine/Proton compatibility layer. `noita_dev.exe` requires access to the active Steam Client API in order to authenticate with the Steam Workshop backend.

### Prerequisites

1. The Steam desktop client must be running and logged in.
2. The mod must be deployed into Noita's `mods` folder (use `noita-deploy -s -y`).
3. Developer tools (`noita_dev.exe`) must exist in the game directory (`steamapps/common/Noita/`).

### Method A: Direct Proton Execution (Recommended)

Running `noita_dev.exe` directly via Proton's runner script preserves full Steam IPC socket communication without container sandbox boundaries:

```bash
# Run from the Noita game directory (required)
cd "$HOME/.steam/debian-installation/steamapps/common/Noita"

# Set compatibility paths
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/debian-installation"
export STEAM_COMPAT_DATA_PATH="$HOME/.steam/debian-installation/steamapps/compatdata/881100"
export PROTON_RUNNER="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/Proton - Experimental/proton"

# Optional: write a Proton debug log to ~/steam-881100.log
export PROTON_LOG=1

# Run batch upload
"$PROTON_RUNNER" run ./noita_dev.exe \
    -workshop_upload your_mod \
    -workshop_upload_change_notes "Update description or release notes"
```

> **IMPORTANT:** The command must be executed from the Noita game directory, and `noita_dev.exe` must be referenced by a relative path (`./noita_dev.exe`). Noita resolves `mods/`, `data/`, and its config files relative to the current working directory, so running it from another directory with an absolute path to the executable fails to find the mod and the upload does not work.

> **Tip:** `PROTON_LOG=1` is not required for the upload itself, but the generated `~/steam-881100.log` is the main source of information when the upload fails silently.

### Method B: Using Protontricks

If you prefer Protontricks, invoke the executable through the app ID `881100`:

```bash
protontricks -c "wine noita_dev.exe -workshop_upload your_mod -workshop_upload_change_notes \"Update notes\"" 881100
```

> **Note:** `protontricks -c` runs the command inside the game installation directory, which satisfies the working directory requirement described in [Method A](#method-a-direct-proton-execution-recommended).

> **Tip:** If using Flatpak Protontricks (`com.github.Matoking.protontricks`) alongside a native Steam client, Flatpak sandbox permissions can block Steam's IPC pipe (`CCrossProcessPipe` broken pipe). Use [Method A](#method-a-direct-proton-execution-recommended) to bypass sandbox restrictions.

## One-Command Automation

The project includes [`scripts/publish_workshop.py`](../../scripts/publish_workshop.py), which performs a full release on Linux:

1. Checks that `workshop_preview_image.png` is under 1 MB.
2. Copies [steam_mod_description.txt](./steam_mod_description.txt) into `workshop.xml` (see [Description](#description)).
3. Deploys the mod symlink with `noita-deploy -s -y`.
4. Copies `noita_dev.exe` from `tools_modding/` if it is missing.
5. Runs the upload from the Noita directory via Proton with `PROTON_LOG=1`.

Execute a release in one command:

```bash
scripts/publish_workshop.py "v0.2.0: Updated preview image and description"
```

## Troubleshooting

### Error: `Upload failed: 2`

* **Cause:** The `workshop_id.txt` file references a Steam Workshop item ID that was deleted or belongs to another Steam account.
* **Solution:** Delete `your_mod/workshop_id.txt` and re-run the upload command to create a fresh Workshop item.

### Upload does nothing or mod is not found on Linux

* **Cause:** `noita_dev.exe` was launched from a directory other than the Noita game directory (e.g. `"$PROTON_RUNNER" run "$NOITA_DIR/noita_dev.exe"` from the project root). Noita resolves `mods/your_mod` relative to the current working directory.
* **Solution:** `cd` into `steamapps/common/Noita` first and run `./noita_dev.exe` as shown in [Method A](#method-a-direct-proton-execution-recommended). Set `PROTON_LOG=1` and inspect `~/steam-881100.log` for details.

### Workshop description is not updated

* **Cause:** The uploader reads only the `description` attribute of `workshop.xml`; it does not know about `docs/steam/steam_mod_description.txt`.
* **Solution:** Run `scripts/publish_workshop.py` (or `scripts/publish_workshop.py --sync-only` before a manual upload). See [Description](#description).

### Workshop preview image is not updated

* **Cause:** `workshop_preview_image.png` is 1 MB or larger, or it is not located in the root of the mod folder.
* **Solution:** Compress the image below 1 MB while keeping a 16:9 aspect ratio (see [`workshop_preview_image.png`](#workshop_preview_imagepng)), redeploy the mod, and run the upload again.

### Error: `"-workshop_upload" requires a Steam version of noita_dev.exe`

* **Cause:** Steam client is not running, or Wine/Proton cannot locate the running Steam process.
* **Solution:** Ensure the Steam client is open in the background before running the command.

### Uploaded mod is hidden or inaccessible on Steam

* **Cause:** Steam requires mod authors to sign the Steam Workshop Legal Agreement upon their first upload.
* **Solution:** Visit your mod page on Steam in a browser. A banner will prompt you to accept the agreement before the mod can become public.

### Error: `request_no_api_restrictions must be false (0)`

* **Cause:** Your `mod.xml` contains `request_no_api_restrictions="1"`.
* **Solution:** Set `request_no_api_restrictions="0"`. Steam Workshop prohibits mods with unrestricted operating system access.

### Mod files missing from the published package

* **Cause:** Files were excluded by `dont_upload_folders`, `dont_upload_files`, or use unsupported extensions.
* **Solution:** Verify `workshop.xml` exclusion patterns and check that all game assets use supported file formats (`.lua`, `.xml`, `.png`, etc.).
