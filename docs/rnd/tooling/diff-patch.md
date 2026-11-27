# Diff Patch

[← Back to R&D Index](../README.md)

The diff patch library `pick_up_your_lantern/files/scripts/libs/diff_patch.lua` applies unified diff patches to files in the virtual file system of the game. The library now lives in the noita-modding skill of the DevKit, and the mod keeps a copy of it.

The skill page [Diff Patches](../../../tools/noitakit/skills/noita-modding/references/diff-patch.md) describes the library. It covers the patch files with the extension `.patch.txt`, the `{{NAME}}` placeholders, how the library finds a hunk, the functions, and the known pitfalls. The original file of the library is `tools/noitakit/skills/noita-modding/assets/diff_patch/diff_patch.lua`. Update the copy of the mod from that file and keep its version header.
