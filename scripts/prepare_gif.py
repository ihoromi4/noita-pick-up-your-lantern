#!/usr/bin/env python3
"""Prepare a GIF that Noita recorded for the Steam Workshop page.

The script takes the newest GIF from the folder `save_rec/screenshots_animated`
of the game. It keeps every second frame, doubles the frame delay so that the
speed stays the same, and compresses the result with `gifsicle -O3 --lossy`.
The frame size stays as the game wrote it (480x270).

When the file is larger than the limit of the Steam Workshop (2 MB), the
script raises the lossy level and then keeps fewer frames until the file fits.

The result goes to `tmp/gifs` in the repository root. The script needs
`gifsicle` in PATH.

Usage:
    scripts/prepare_gif.py [--input FILE] [--step N] [--lossy N] [--max-size MB]
"""

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools/noitakit/src"))

from noitakit.common import find_save_root  # noqa: E402

OUTPUT_DIR = ROOT / "tmp/gifs"
GAME_GIF_DIR = Path("save_rec/screenshots_animated")
# The Steam Workshop accepts GIF files up to 2 MB.
DEFAULT_MAX_SIZE_MB = 2.0
LOSSY_LEVELS = (30, 60, 100)
MAX_STEP = 4


def find_latest_gif() -> Path:
    """Return the newest GIF that the game saved."""
    save_root = find_save_root()
    if save_root is None:
        sys.exit("Error: the player data folder of Noita was not found.")
    gif_dir = save_root / GAME_GIF_DIR
    gifs = sorted(gif_dir.glob("*.gif"), key=lambda p: p.stat().st_mtime)
    if not gifs:
        sys.exit(f"Error: no GIF files in {gif_dir}")
    return gifs[-1]


def read_frames(gif: Path) -> tuple[int, int]:
    """Return the frame count and the first frame delay in hundredths of a second."""
    info = subprocess.run(
        ["gifsicle", "--info", str(gif)],
        check=True, capture_output=True, text=True,
    ).stdout
    count = len(re.findall(r"^\s*\+ image #", info, re.MULTILINE))
    delay = re.search(r"delay ([0-9.]+)s", info)
    delay_cs = round(float(delay.group(1)) * 100) if delay else 3
    return count, delay_cs


def convert(source: Path, target: Path, step: int, lossy: int) -> None:
    """Drop frames, fix the delay, and compress `source` into `target`."""
    count, delay_cs = read_frames(source)
    frames = [f"#{i}" for i in range(0, count, step)]
    print(f"Trying step {step}, lossy {lossy}...")
    # The first pass selects frames. The second pass sets the delay and
    # compresses, because a delay option applies only to the inputs after it.
    select = subprocess.run(
        ["gifsicle", "--unoptimize", str(source), *frames],
        check=True, capture_output=True,
    )
    subprocess.run(
        ["gifsicle", f"--delay={delay_cs * step}", "-O3", f"--lossy={lossy}",
         "--output", str(target)],
        input=select.stdout, check=True, capture_output=True,
    )
    print(f"  Frames: {count} -> {len(frames)}, "
          f"delay: {delay_cs / 100:.2f}s -> {delay_cs * step / 100:.2f}s, "
          f"size: {target.stat().st_size / 1_000_000:.2f} MB")


def compression_ladder(step: int, lossy: int) -> list[tuple[int, int]]:
    """Return (step, lossy) pairs from the best quality to the smallest file.

    Stronger lossy compression is tried first, because it keeps the motion
    smooth. Fewer frames come next. Fewer colors are not used, because a
    smaller palette breaks the dark scenes of Noita.
    """
    ladder = []
    for next_step in range(step, MAX_STEP + 1):
        for next_lossy in LOSSY_LEVELS:
            if next_step == step and next_lossy < lossy:
                continue
            ladder.append((next_step, next_lossy))
    return ladder or [(step, lossy)]


def main() -> None:
    """Convert the chosen GIF and keep it under the size limit."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--input", type=Path,
                        help="GIF to convert (default: the newest GIF of the game)")
    parser.add_argument("--step", type=int, default=2,
                        help="keep every N-th frame (default: 2)")
    parser.add_argument("--lossy", type=int, default=30,
                        help="lossy compression level of gifsicle (default: 30)")
    parser.add_argument("--max-size", type=float, default=DEFAULT_MAX_SIZE_MB,
                        help="size limit in MB; the script compresses harder "
                             "until the file fits, 0 turns this off "
                             f"(default: {DEFAULT_MAX_SIZE_MB})")
    args = parser.parse_args()

    if shutil.which("gifsicle") is None:
        sys.exit("Error: gifsicle is not installed.")
    if args.step < 1:
        sys.exit("Error: --step must be 1 or greater.")

    source = args.input or find_latest_gif()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    target = OUTPUT_DIR / source.name
    max_bytes = args.max_size * 1_000_000

    print(f"Source: {source} ({source.stat().st_size / 1_000_000:.2f} MB)")
    if args.max_size > 0:
        ladder = compression_ladder(args.step, args.lossy)
    else:
        ladder = [(args.step, args.lossy)]
    for step, lossy in ladder:
        convert(source, target, step, lossy)
        if args.max_size <= 0 or target.stat().st_size <= max_bytes:
            break
    else:
        print(f"Warning: the file is still larger than {args.max_size} MB. "
              "Record a shorter clip.")
    print(f"Saved: {target}")


if __name__ == "__main__":
    main()
