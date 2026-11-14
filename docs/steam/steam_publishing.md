# Publishing to Steam Workshop

This page describes how to publish a release of Pick Up Your Lantern to the Steam Workshop. The tool and the general knowledge live in the DevKit. The guide [Publishing to the Steam Workshop](../../tools/noitakit/docs/guides/cli/workshop.md) explains the Workshop files, the limits, and the troubleshooting.

## The Workshop Page Description

The text of the Workshop page lives in [steam_mod_description.txt](./steam_mod_description.txt). It uses Steam BBCode. Edit the text in this file only.

The uploader reads the text from the `description` attribute of `pick_up_your_lantern/workshop.xml`. The repository keeps a short placeholder in that attribute. The command `noitacli workshop sync` copies the full text into the attribute, and every upload does this too. Do not commit the copied text.

Never write a straight double quote (`"`) in the description. Use typographic quotes (`“”`) instead.

## Publishing a Release

1. Make sure every item in the current version notes in [versions/](../versions/) is done.
2. Check the Workshop files of the mod:

   ```bash
   noitacli workshop check
   ```

3. Start the Steam client and close the game. Then upload the release with its change notes:

   ```bash
   noitacli workshop upload "v0.3.2: Short summary of the release"
   ```

4. Open the Workshop page and check the description and the preview image.
5. Restore the placeholder in `workshop.xml` before the next commit:

   ```bash
   git checkout pick_up_your_lantern/workshop.xml
   ```
