# Workshop Media

How to record animated GIFs of the mod and prepare them for the Steam Workshop page. The last section describes the gameplay recordings of Steam, which suit a future video better than a GIF.

## Contents

- [Limits of the Workshop](#limits-of-the-workshop)
- [Recording a GIF in the Game](#recording-a-gif-in-the-game)
- [Converting the GIF](#converting-the-gif)
- [What Does Not Work](#what-does-not-work)
- [Tips for Recording](#tips-for-recording)
- [Steam Game Recordings](#steam-game-recordings)

## Limits of the Workshop

- The Workshop accepts an uploaded GIF only up to 2 MB.
- The media gallery of the Workshop page shows an image at about 636 × 358 pixels. A larger GIF only spends the size limit.

These limits cost quality. A GIF of 2 MB holds only a few seconds of the game, and the frame stays small. A video on YouTube has no such limits, so a longer showcase should be a video.

## Recording a GIF in the Game

Noita has a built-in GIF recorder.

1. Turn on the recording mode in the settings of the game.
2. Play. The game keeps the last seconds of play in a buffer.
3. Press F11. The game opens a simple editor of the buffer.
4. Save the GIF from the editor.

The game saves the GIF into the folder `save_rec/screenshots_animated` of its player data. Under Proton on Linux, this folder is inside the Wine prefix of the game:

```text
~/.steam/debian-installation/steamapps/compatdata/881100/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita/save_rec/screenshots_animated/
```

The start of the path depends on the installation of Steam. On Windows, the folder is `%USERPROFILE%\AppData\LocalLow\Nolla_Games_Noita\save_rec\screenshots_animated`.

A GIF of the game is a good source for the Workshop:

- The frame is 480 × 270 pixels, close to the internal resolution of Noita. The player and the lantern stay well visible.
- The GIF has no interface of the game: no inventory, no health bar, and no text in the corners.
- Each frame lasts 0.03 seconds, so the GIF plays at about 33 frames per second.

The GIF is large because the game does not compress it. Every frame is stored whole and has its own palette of 256 colors. A clip of 6.75 seconds took 7.4 MB, and a clip of 11.7 seconds took 18 MB.

## Converting the GIF

The script [prepare_gif.py](../../scripts/prepare_gif.py) converts a GIF of the game for the Workshop. It needs [gifsicle](https://www.lcdf.org/gifsicle/) in `PATH`.

```bash
scripts/prepare_gif.py                       # the newest GIF of the game
scripts/prepare_gif.py --input path/to.gif   # a given GIF
scripts/prepare_gif.py --max-size 1.5        # a smaller size limit in MB
```

The script finds the player data of the game with `find_save_root()` of the DevKit, so it works under Proton and on Windows. It takes the newest GIF from `save_rec/screenshots_animated` and writes the result with the same file name to `tmp/gifs/`, which Git ignores.

The conversion has two steps:

1. The script keeps every second frame and doubles the delay of each frame. The clip keeps its speed and plays at about 16 frames per second. The new delay comes from the delay of the source GIF, so a source with another frame rate also keeps its speed.
2. `gifsicle -O3 --lossy=30` compresses the result. All frames get one shared palette, and most frames store only the area that changed.

The two steps need two calls of `gifsicle`. A delay option applies only to the inputs that follow it, so a delay set in the same call as the frame selection is lost.

The frame size stays 480 × 270. Steam scales the GIF up in the gallery.

### Size Limit

The script keeps the result under 2 MB by default. When the result is larger, the script compresses harder and tries again. It tries the settings in this order and stops at the first one that fits:

1. Every second frame, with the lossy level 30, then 60, then 100.
2. Every third frame, with the same lossy levels.
3. Every fourth frame, with the same lossy levels.

A higher lossy level keeps the motion smooth, so the script tries it first. Fewer frames make the motion choppier. When even the last setting is too large, the script prints a warning, and the clip must be shorter.

The script prints each attempt with its frame count, delay and size. `--max-size 0` turns the limit off, and `--step` and `--lossy` set the first attempt.

### Measured Sizes

A clip of 6.75 seconds (225 frames, 7.4 MB) gave these results at 480 × 270:

| Settings | Size |
| --- | --- |
| `-O3` only | 7.35 MB |
| Every second frame, lossy 30 | 1.0 MB |
| All frames, lossy 30 | 2.0 MB |

A clip of 11.7 seconds (390 frames, 18 MB) needed every third frame to fit:

| Settings | Size |
| --- | --- |
| Every second frame, lossy 30 | 2.99 MB |
| Every second frame, lossy 100 | 2.31 MB |
| Every third frame, lossy 30 | 1.99 MB |

At about 16 frames per second, one second of play takes about 0.25 MB. A clip of 6 to 8 seconds therefore fits into 2 MB without dropping more frames.

## What Does Not Work

- **A smaller palette.** `gifsicle --colors 128` or `--colors 64` makes the file much smaller, but it breaks the dark scenes of Noita. The rocks almost disappear, and only their bright edges stay. The script never reduces the palette.
- **Scaling to 636 × 358.** The factor from 480 to 636 is 1.325, which is not a whole number. The pixels get different widths, and the pixel art blurs. The file also grows: the clip of 6.75 seconds took 10.5 MB with `-O3` and 3.0 MB with lossy 30.
- **Scaling by 2.** The same clip at 960 × 540 took 17.9 MB with `-O3`, far above the limit.

## Tips for Recording

- Keep a clip at 6 to 8 seconds, and show one action in it: picking up, throwing, or carrying a lantern on the belt.
- Record in bright places when you can. A dark cave looks almost black in the small gallery of Steam. Noise in the dark also compresses badly.
- Show the contrast of darkness and lantern light when the light is the subject of the clip.

## Steam Game Recordings

The game recording of Steam captures the whole screen while you play. It is not useful for the Workshop, because it shows the interface of the game and needs a full conversion. It is a better source for a video, such as a showcase on YouTube.

Steam saves the recordings in its user data:

```text
~/.steam/debian-installation/userdata/<steam-id>/gamerecordings/video/bg_881100_<date>_<time>/
```

`881100` is the app id of Noita. Each recording is a folder with a stream of MPEG-DASH:

- `session.mpd` is the manifest of the stream.
- `init-stream0.m4s` and `chunk-stream0-*.m4s` hold the video: HEVC (H.265), 1920 × 1080, 60 frames per second, about 12 Mbit/s.
- `init-stream1.m4s` and `chunk-stream1-*.m4s` hold the sound: AAC, stereo, 48 kHz.
- Each chunk holds 3 seconds.

The folder `gamerecordings/timelines/` holds only the time marks of the recordings.

`ffmpeg` reads `session.mpd` directly. It prints the warning `Error when loading first fragment`, but it still decodes every frame. Joining the video chunks gives one plain MP4 file without sound:

```bash
cd ~/.steam/debian-installation/userdata/<steam-id>/gamerecordings/video/bg_881100_<date>_<time>
cat init-stream0.m4s $(ls chunk-stream0-*.m4s | sort) > clip.mp4
```

A video editor can open either `session.mpd` or the joined file. The player is small in a full frame of 1080p, so crop the frame around the player when the video is shown small.
