# Where to Start

This guide suggests which documents to read first, depending on your goal.

## Contents

- [I Want to Play](#i-want-to-play)
- [I Want to Know What Is New](#i-want-to-know-what-is-new)
- [I Want to Contribute](#i-want-to-contribute)
- [I Want to Publish a Release](#i-want-to-publish-a-release)

## I Want to Play

1. Read [Lanterns](guides/lanterns.md) to learn how to pick up, hold, throw and hang lanterns, and how creatures react to their light.
2. Read [Lantern Quality and States](guides/lantern-quality-and-states.md) to understand why some lanterns shine brighter than others.
3. Try a darker preset from [Vision and Darkness](guides/vision-and-darkness.md); this is where lanterns matter most.
4. Use [Settings](guides/settings.md) as a reference when adjusting the mod.

## I Want to Know What Is New

1. Read the latest entry in [Versions](versions/README.md) and open its version notes for full details.
2. Check the [Backlog](backlog.md) to see what is planned next.

## I Want to Contribute

1. Skim the [Player Guides](guides/README.md) first, so you know how the mod behaves in the game.
2. Read [Architecture](dev/architecture.md): it explains the mod layout, what runs at startup and every frame, and how lanterns move between the world, the inventory and the hand.
3. Go to the document for the area you want to change:
   - picking up, physics, ceiling anchors, chains and the tube lamp cable: [Lantern Entities](dev/lantern-entities.md);
   - in-hand sprites, swinging and the belt lantern: [Holding and Belt](dev/holding-and-belt.md);
   - throwing, hanging on the left mouse button and shattering: [Throwing](dev/throwing.md);
   - light, quality tiers, modifiers and liquid states: [Lantern Properties and Progression](dev/lantern-properties-and-progression.md);
   - limited vision, shaders, polymorph, the All-Seeing Eye and the fire enemy glow: [Vision and Lighting](dev/vision-and-lighting.md);
   - light sources, the visibility API, luring enemies to lanterns and Natural Fear: [Creatures and Light](dev/creatures-and-light.md).
4. Check the [Backlog](backlog.md) before adding a feature or picking up an open task. Engine research and rejected approaches are collected in the [R&D Notes](rnd/README.md).
5. Follow the code style and commit conventions in [AGENTS.md](../AGENTS.md). See the [README](../README.md) for running the tests.

## I Want to Publish a Release

1. Make sure that the notes of the release version in [Versions](versions/README.md) are complete.
2. Update [steam_mod_description.txt](steam/steam_mod_description.txt) if the Workshop page text needs changes.
3. Check and upload the release using the Steam Workshop publishing guide in the `tools/noitakit` documentation. Start from its README or run `noitacli workshop --help` to find the commands.
4. Restore the short placeholder in `pick_up_your_lantern/workshop.xml` with `git checkout pick_up_your_lantern/workshop.xml` before the next commit.
