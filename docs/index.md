# Documentation

Welcome to the documentation of **Pick Up Your Lantern**, a Noita mod that lets you pick up, hold, carry and throw lanterns. This page lists the main documents and suggests where to start depending on why you are here.

## Contents

- [Main Documents](#main-documents)
- [Where to Start](#where-to-start)
- [Writing Documentation](#writing-documentation)

## Main Documents

| Document | What it covers | Who it is for |
| --- | --- | --- |
| [Player Guides](guides.md) | How lanterns, the belt lantern, lantern quality, creatures in lantern light, limited vision and Mod Settings work in the game. | Players |
| [Developer Documentation](dev.md) | Architecture, engine quirks and implementation details. | Contributors |
| [Functional Requirements](requirements.md) | What the mod is meant to do: the full feature specification. | Contributors, designers |
| [Development Roadmap](roadmap.md) | Planned features grouped by release. | Everyone |
| [Version Notes](versions/version-0.3.1.md) | What each release delivered, with fixed issues. Each file links to the previous one. | Everyone |
| [Publishing to Steam Workshop](steam/steam_publishing.md) | How to upload and update the mod on the Steam Workshop. | Maintainers |

## Where to Start

### I Want to Play

1. Read [Lanterns](guides/lanterns.md) to learn how to pick up, hold, throw and hang lanterns, and how creatures react to their light.
2. Read [Lantern Quality and States](guides/lantern-quality-and-states.md) to understand why some lanterns shine brighter than others.
3. Try a darker preset from [Vision and Darkness](guides/vision-and-darkness.md); this is where lanterns matter most.
4. Use [Settings](guides/settings.md) as a reference when adjusting the mod.

### I Want to Know What Is New

1. Read the Summary in the latest [Version Notes](versions/version-0.3.1.md).
2. Check the [Development Roadmap](roadmap.md) to see what comes next.

### I Want to Contribute

1. Skim the [Player Guides](guides.md) first, so you know how the mod behaves in the game.
2. Read [Architecture](dev/architecture.md): it explains the mod layout, what runs at startup and every frame, and how lanterns move between the world, the inventory and the hand.
3. Go to the document for the area you want to change:
   - picking up, physics, ceiling anchors, chains and the tube lamp cable: [Lantern Entities](dev/lantern-entities.md);
   - in-hand sprites, swinging and the belt lantern: [Holding and Belt](dev/holding-and-belt.md);
   - throwing, hanging on the left mouse button and shattering: [Throwing](dev/throwing.md);
   - light, quality tiers, modifiers and liquid states: [Lantern Properties and Progression](dev/lantern-properties-and-progression.md);
   - limited vision, shaders, polymorph, the All-Seeing Eye and the fire enemy glow: [Vision and Lighting](dev/vision-and-lighting.md);
   - enemy study, luring enemies to lanterns and Natural Fear: [Creatures and Light](dev/creatures-and-light.md).
4. Check the [Functional Requirements](requirements.md) and the [Development Roadmap](roadmap.md) before adding a feature, and the current version notes in [versions/](versions/) for open tasks. Engine research and rejected approaches are collected in the [R&D Notes](rnd.md).
5. Follow the code style and commit conventions in [AGENTS.md](../AGENTS.md). See the [README](../README.md) for running the tests.

### I Want to Publish a Release

1. Make sure every item in the current version notes in [versions/](versions/) is done.
2. Follow [Publishing to Steam Workshop](steam/steam_publishing.md).

## Writing Documentation

- Player guides describe behavior and settings in plain words, without code or file names.
- Developer documents describe how things work and why, with links to the source files.
- Only confirmed, implemented behavior goes into these documents.
- Every new document needs a link from [Player Guides](guides.md) or [Developer Documentation](dev.md).
