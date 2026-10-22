#!/usr/bin/env python3
"""Publish the mod to Steam Workshop on Linux via Proton.

Steps:
    1. Check that workshop_preview_image.png is under 1 MB (Steam limit).
    2. Copy the BBCode description from docs/steam/steam_mod_description.txt
       into the `description` attribute of workshop.xml (the uploader reads
       the description only from there).
    3. Deploy the mod symlink with `noita-deploy -s -y`.
    4. Copy noita_dev.exe from tools_modding/ if it is missing.
    5. Run `noita_dev.exe -workshop_upload` from the Noita directory via Proton.

Usage:
    scripts/publish_workshop.py "Change notes"
    scripts/publish_workshop.py --sync-only
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

MOD_NAME = "pick_up_your_lantern"
STEAM_APP_ID = "881100"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MOD_DIR = PROJECT_ROOT / MOD_NAME
DESCRIPTION_FILE = PROJECT_ROOT / "docs" / "steam" / "steam_mod_description.txt"
WORKSHOP_XML = MOD_DIR / "workshop.xml"
PREVIEW_IMAGE = MOD_DIR / "workshop_preview_image.png"

# Steam Workshop limits.
PREVIEW_MAX_BYTES = 1024 * 1024
DESCRIPTION_MAX_LENGTH = 8000

STEAM_ROOT_CANDIDATES = (
    Path.home() / ".steam" / "debian-installation",
    Path.home() / ".steam" / "steam",
)
PROTON_DIR_NAME = "Proton - Experimental"

DESCRIPTION_ATTR_RE = re.compile(r'(\bdescription\s*=\s*)"[^"]*"', re.DOTALL)


class PublishError(Exception):
    """Error that aborts publishing with a readable message."""


def check_preview_image() -> None:
    """Fail if the Workshop preview image is missing or 1 MB or larger."""
    if not PREVIEW_IMAGE.is_file():
        raise PublishError(f"{PREVIEW_IMAGE} not found.")
    size = PREVIEW_IMAGE.stat().st_size
    if size >= PREVIEW_MAX_BYTES:
        raise PublishError(
            f"{PREVIEW_IMAGE.name} is {size} bytes; it must be under 1 MB ({PREVIEW_MAX_BYTES} bytes)."
        )
    print(f"Preview image OK ({size} bytes).")


def check_attribute(text: str) -> None:
    """Fail if text cannot be stored in a double-quoted Noita XML attribute.

    Noita's XML parser reads attribute values literally up to the next `"`
    and does not decode entities such as `&quot;`, so a double quote cannot
    be escaped. `&`, `<`, `>` and line breaks are kept as is.
    """
    for line_number, line in enumerate(text.splitlines(), start=1):
        if '"' in line:
            raise PublishError(
                f"{DESCRIPTION_FILE.name}:{line_number}: double quote (\") is not allowed, "
                "use typographic quotes (“”) instead."
            )


def sync_description() -> None:
    """Copy the description file into the `description` attribute of workshop.xml."""
    description = DESCRIPTION_FILE.read_text(encoding="utf-8")
    description = description.replace("\r\n", "\n").replace("\r", "\n").strip()

    if not description:
        raise PublishError(f"{DESCRIPTION_FILE} is empty.")
    if len(description) > DESCRIPTION_MAX_LENGTH:
        raise PublishError(
            f"Description is {len(description)} characters, Steam limit is {DESCRIPTION_MAX_LENGTH}."
        )

    check_attribute(description)

    workshop_xml = WORKSHOP_XML.read_text(encoding="utf-8")
    updated, count = DESCRIPTION_ATTR_RE.subn(
        lambda match: f'{match.group(1)}"{description}"', workshop_xml, count=1
    )
    if count == 0:
        raise PublishError(f"No description attribute in {WORKSHOP_XML}.")

    if updated != workshop_xml:
        WORKSHOP_XML.write_text(updated, encoding="utf-8")
        print(f"Updated description in {WORKSHOP_XML.name} ({len(description)} characters).")
    else:
        print(f"Description in {WORKSHOP_XML.name} is already up to date.")


def deploy_mod() -> None:
    """Symlink the mod into Noita's mods directory."""
    print(f"Deploying {MOD_NAME}...")
    subprocess.run(["noita-deploy", "-s", "-y"], cwd=PROJECT_ROOT, check=True)


def find_steam_root() -> Path:
    """Return the first existing Steam installation directory."""
    for candidate in STEAM_ROOT_CANDIDATES:
        if candidate.is_dir():
            return candidate
    raise PublishError("Steam installation not found.")


def upload(change_notes: str) -> None:
    """Run the Noita Workshop uploader via Proton from the Noita directory."""
    steam_root = find_steam_root()
    noita_dir = steam_root / "steamapps" / "common" / "Noita"
    proton_bin = steam_root / "steamapps" / "common" / PROTON_DIR_NAME / "proton"

    if not proton_bin.is_file():
        raise PublishError(f"Proton not found: {proton_bin}")

    noita_dev = noita_dir / "noita_dev.exe"
    if not noita_dev.is_file():
        print("Copying noita_dev.exe from tools_modding...")
        shutil.copy2(noita_dir / "tools_modding" / "noita_dev.exe", noita_dev)

    env = os.environ.copy()
    env["STEAM_COMPAT_CLIENT_INSTALL_PATH"] = str(steam_root)
    env["STEAM_COMPAT_DATA_PATH"] = str(steam_root / "steamapps" / "compatdata" / STEAM_APP_ID)
    env["PROTON_LOG"] = "1"

    print(f"Publishing {MOD_NAME} to Steam Workshop with notes: '{change_notes}'...")
    # Noita resolves mods/ relative to the working directory, so it must run from noita_dir.
    subprocess.run(
        [
            str(proton_bin),
            "run",
            "./noita_dev.exe",
            "-workshop_upload",
            MOD_NAME,
            "-workshop_upload_change_notes",
            change_notes,
        ],
        cwd=noita_dir,
        env=env,
        check=True,
    )
    print(f"Upload finished. Proton log: {Path.home() / f'steam-{STEAM_APP_ID}.log'}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Publish the mod to Steam Workshop.")
    parser.add_argument("change_notes", nargs="?", default="Update", help="Workshop change notes.")
    parser.add_argument(
        "--sync-only",
        action="store_true",
        help="Only copy the description into workshop.xml, do not upload.",
    )
    args = parser.parse_args()

    try:
        if args.sync_only:
            sync_description()
            return 0
        check_preview_image()
        sync_description()
        deploy_mod()
        upload(args.change_notes)
    except PublishError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        print(f"Error: command failed with exit code {error.returncode}: {error.cmd}", file=sys.stderr)
        return error.returncode or 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

