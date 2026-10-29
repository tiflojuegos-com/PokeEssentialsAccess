# Overview

This page says what the mod does, how its code is divided into layers, which rules every part follows and where each
part lives in the source tree. Read it first; each of the other architecture pages explains one part in depth.

## What the mod does

PokeEssentialsAccess makes Pokémon Essentials fangames playable with a screen reader. It reads the game's screens
aloud: menus, dialogue, battles, summaries, the Pokédex and the bag. On the map it adds navigation by sound. A locator
lists what is around the player, a guide leads the way to a chosen target, and positional audio places people,
objects, doors, water and walls around the player.

The mod is Ruby code that runs inside the game on the mkxp-z player, loaded after the game's own scripts
([Loading](loading.md)). Speech reaches the screen reader through `prism_pea.dll`, the screen reader bridge built from
`bridge/` ([Speech and languages](speech-and-languages.md)). The positional engine, PA3D, is a library built from
`native/` on Steam Audio ([Guide and sound](guide-and-sound.md)). A separate program, the
[launcher](../reference/glossary.md), installs, updates and removes the mod
([Install and release](../guides/install-and-release.md)).

## Layers

The mod's Ruby code is in three layers, loaded in this order at boot:

- `core/` holds what every Essentials game has: the readers of the stock screens, the hooks, the speech output, the
  world model, the routes and the sound. Code that differs between [engine eras](engine-eras.md) sits in a
  subsystem's `gen6/`, `v21/` and `v22/` subfolders, where the subsystem has them.
- `plugins/` holds one [plugin reader](../reference/glossary.md) per community plugin, the code that reads the
  screens that plugin adds. A profile declares the readers its game needs; under the generic profile the boot
  detects them.
- `games/` holds one [profile](../reference/glossary.md) per folder, with that game's own screens, rules and data, and
  the shared profiles (`games/<name>_common/`) that the games of one family import. `games/catalog.json` tells the
  launcher which profile each game takes.

### What each layer may name

`test/static/coupling_test.rb` checks these boundaries on every constant the code names:

- Core names no profile, no plugin reader and no class that only one surveyed fangame defines.
- The code of one era names nothing from another era, and the core shared by all eras names none of them.
- A plugin reader names no profile, and no other file names a plugin reader's modules.
- A profile names nothing from another profile, except what a shared profile it imports defines.
- A profile does not reopen a core module, `Config` aside. It changes what a core reader does with `override`, and
  the diagnostic dump lists each override ([Profile DSL](../reference/profile-dsl.md)).

A string couples by name and is allowed. A hook names its class as a string, such as `"Battle::Scene"`, and binds only
in the games that have that class ([Hooks](hooks.md)).

### Placement of readers

A reader goes to the layer of the screen's origin. A stock Essentials screen goes to core and a community plugin's
screen to `plugins/`. A screen that a family of games shares goes to their shared profile, and a screen the game wrote
or edited goes to the game's profile. [Readers](readers.md#placement-by-origin) explains the rule and its exception
for an old or edited copy of a plugin, and [Choose where a reader goes](../guides/choose-where-a-reader-goes.md)
applies it.

## Design rules

- The mod never edits the game's scripts. The launcher registers the mod's preload script in the game's `mkxp.json`,
  and the mod attaches its code to the game's methods while the game runs ([Hooks](hooks.md)). Uninstalling removes
  the entry and the mod's files.
- Code that a Ruby 1.8.7 game can load follows Ruby 1.8.7. Each fangame runs the Ruby of its own mkxp-z build, 1.8.7
  in some and 3.x in others, and `test/check187.py` sweeps the files a 1.8.7 game loads
  ([Ruby versions](engine-eras.md#ruby-versions)).
- Spoken text comes from `lang/`. A reader asks `PokeAccess::I18n.t` for a key, every `lang/*.txt` file holds every
  key, and English is the fallback ([The mod's language](speech-and-languages.md#the-mods-language)). Static checks
  keep the files in parity and every key the code names defined.
- The mod says text as the screen paints it. A reader takes the [painted text](../reference/glossary.md) in the game's
  own words, and composes a line from the game's data only where nothing was painted, as the Pokédex info page does
  in `core/battle/v21/pokedex_info_v21.rb`. A reader passes on the sex sign drawn beside a name as drawn
  (`core/party/party_storage.rb`).
- A reader does not break the game. A reader's hook body runs inside a rescue, so a failing reader goes quiet and the
  game goes on. The hooks that decide whether the game's method runs log the error and raise it again
  ([Hooks](hooks.md#failures)).
- Accessibility with a screen reader comes before any other consideration.

## Source tree

| Path | Holds |
|---|---|
| `core/` | The core layer; `core/manifest.rb` gives its load order |
| `plugins/` | Plugin readers; `plugins/manifest.rb` maps each one to its probe |
| `games/` | Profiles, shared profiles and the launcher's catalog, `games/catalog.json` |
| `lang/` | The spoken strings, one file per language |
| `loader/` | `preload_access.rb` and `boot.rb` |
| `assets/` | Sounds, native libraries for `x86` and `x64`, and the mkxp-z build for converted games |
| `bridge/` | Source of `prism_pea.dll`, the screen reader bridge |
| `native/` | Source of `PA3D_steam.dll`, the positional engine |
| `tools/` | Maintainer scripts: script dumps, map views, game reports, coverage and mutation testing |
| `test/` | The suite: behavior and unit tests, and the static checks in `test/static/` |
| `docs/` | This documentation |
| `version.json` | The mod's version, the launcher version a release ships and the oldest launcher that installs it |

The subsystems of `core/`:

| Folder | Holds |
|---|---|
| `core/foundation/` | Services loaded first: settings, paths, i18n, engine detection, the profile DSL, the event bus |
| `core/util/` | Text helpers, painted-text capture, the session recorder, the self-check and the silence watch |
| `core/data/` | Data providers: names and fields from ids, whatever the era |
| `core/speech/` | The speech output, its categories, the message history and verbosity |
| `core/input/` | Hooks, keyboard, focus, remapping, key hints, the two beats, player control, the diagnostic dump |
| `core/menus/` | Command windows, change detection, scene watchers, the configuration menu and menu screens |
| `core/battle/` | Battle screens, the Battle Arena's judgment, the Bug-Catching Contest's comparison and the Pokédex pages |
| `core/party/` | Party, summary and storage screens |
| `core/dialogue/` | Messages and their pages |
| `core/field/` | Field screens and messages: evolution, hatching, mail, fishing, phone, berries, minigames, the event timer |
| `core/world/` | The World layer: terrain, passability, events and map mechanics |
| `core/routes/` | The route planner and its searches |
| `core/nav/` | The locator, the guide, the pathfinder, the town and region maps |
| `core/sound/` | Positional audio, the sound cues and the soundscape |
| `core/puzzles/` | Map puzzles as the player hears them |

The [Tests](../guides/tests.md) guide runs the suite, and the [Static checks](../reference/static-checks.md)
reference lists what each check guards.
