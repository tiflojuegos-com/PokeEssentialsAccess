# PokeEssentialsAccess

[Español](README.es.md) · **English**

An accessibility mod for Pokémon fangames. It lets a blind person play them with a screen reader.

---

## Contents

- [What is this?](#what-is-this)
- [What does it add?](#what-does-it-add)
- [Installing](#installing)
- [Supported games](#supported-games)
- [The mod's keys](#the-mods-keys)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Changes](#changes)
- [Licence](#licence)

---

## What is this?

A mod that makes fangames built on **Pokémon Essentials** and run with **mkxp-z** accessible, from the gen-6
era (Essentials v16-v17) through v22 and its forks.

It does not modify the game's scripts: it loads through mkxp-z's `preloadScript`, so it can be uninstalled
and the game is left exactly as it was.

## What does it add?

- **Text reading**: menus, dialogue, battle, Pokémon summaries, Pokédex, bag, trainer card, and so on. The
  voice goes out through **prism**, which talks to NVDA, JAWS, SAPI, UIA, ZDSR and other readers, and also
  sends to a braille display.
- **Sound navigation**: a binaural 3D sonar (Steam Audio) that places people, objects, doors, warps, water
  and walls around you.
- **Pathfinding**: pick a target on the map and the mod works out the route and guides you there with a
  sound.
- **Sound glossary**: step through every cue you will hear from the mod's own menu, listen to it, and read
  what it means.
- **Session recorder**: writes what the mod saw and said to a file, to attach when reporting a problem.
- **Key remapping** for the games, from the mod's menu.
- **Puzzle accessibility**. This has to be done game by game; so far there is support in:
  - Pokémon Z
  - Pokémon Ópalo

## Installing

The mod only works on games whose **mkxp-z** was built with `preloadScript` support. Both routes check this
before installing and tell you if the game will not take it.

### With the graphical installer (recommended)

Download `pokeessentialsaccess-launcher.exe` from the
[releases page](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases) and open it. It is a window
of native Windows controls, usable with a screen reader, that keeps a list of your games:

| Action | Shortcut |
|--------|----------|
| Add a game (the profile is detected for you) | `Ctrl` + `A` |
| Install or update the selected game | `Ctrl` + `I` |
| Update every game in the list | `Ctrl` + `U` |
| Change a game's profile | `Ctrl` + `P` |
| Uninstall the mod from a game | `Ctrl` + `D` |
| Check for a new version of the installer itself | `Ctrl` + `B` |

Updating downloads only the files that changed and keeps **everything in `accessibility\data`**: your
settings, your object tags, the map names you typed yourself, and your recordings.

### By hand, with the scripts

Download the `PokeEssentialsAccess_<version>.zip` from that same page, unzip it, and use the files in
`installer/`. Each one opens a folder picker (or you can drop the game's folder onto it):

- **`Comprobar compatibilidad.bat`** — says whether the game will take the mod, without installing anything.
- **`Instalar mod.bat`** — installs the mod and registers the loader.
- **`Desinstalar mod.bat`** — removes it.

## Supported games

There is one profile per game in `games/`; the list the installer and launcher use to recognise a game is
[`games/catalog.json`](games/catalog.json).

**Gen-6 era** (Essentials v16-v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía,
Pokémon Realidea, Pokémon Africanus, Pokémon Awakening.

**GameData era** (Essentials v18 onwards): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Infinite
Fusion, Pokémon Infinite Fusion 2 Hoenn.

Plus a **generic profile** for any other Essentials fangame: it gives all the common accessibility (menus,
dialogue and battle reading, navigation and pathfinding) without the readers specific to one game.

## The mod's keys

> **Recommendation:** some games' stock keys are awkward to reach. From the mod's menu (the `O` key) you can
> reassign them; a comfortable layout is **movement** on `W`, `A`, `S`, `D`, **confirm** on `E` and **cancel**
> on `Q`.

These are the default keys the mod adds:

| Key | Action |
|-----|--------|
| `I` | Work out the route to the selected target |
| `J` | Previous target in the list |
| `L` | Next target in the list |
| `K` | Announce the selected target |
| `T` | Read the information for whatever has focus (move, item, Pokémon, trainer…); inside a puzzle, its state |
| `H` | Read your team's HP in battle |
| `G` | Read the terrain conditions in battle; outside battle, the weather and the time |
| `M` | Read the current coordinates |
| `O` | Open the mod's settings menu |

### Modifiers

Combined with the keys above, they extend them:

| Combination | Action |
|-------------|--------|
| `Shift` + `J` / `L` | Change target category (people, objects, exits, and so on) |
| `Shift` + `K` | Rename the selected target |
| `Ctrl` + `K` | Open the target's tag menu |
| `Shift` + `I` | Turn the audible guidance towards the target on or off |
| `Shift` + `T` | Repeat the last line of dialogue read |
| `Shift` + `H` | Read the opposing team's HP |
| `Shift` + `M` | Rename the current map |
| `Ctrl` + `M` | Show or hide the targets you cannot reach |

### Global shortcuts

| Combination | Action |
|-------------|--------|
| `Ctrl` + `Alt` + `F8` | Turn the mod on or off (and retry the connection to the screen reader) |
| `Ctrl` + `Alt` + `F9` | Dump a diagnostic to a file (useful when a screen, puzzle or map turns out to be inaccessible) |
| `Ctrl` + `Alt` + `F10` | Quick spoken diagnostic (useful when something goes quiet) |

## Repository layout

These are the main folders and what they hold:

| Folder | Contents |
|--------|----------|
| `core/` | The mod's shared, game-agnostic engine. Organised by module, and inside by Essentials version (`gen6`, `v21`, `v22`, `skyflyer`) where that matters. |
| `games/` | One profile per game: its specific readers and its configuration. Each folder is a supported fangame. |
| `plugins/` | Readers for third-party plugins that several fangames install. |
| `lang/` | The text the mod speaks, translated (`es.txt` Spanish, `en.txt` English). |
| `loader/` | The preload that waits for the game, and the boot that loads the mod in order. |
| `native/` | C code for the 3D audio backend (`pa3d_steam.c` → `PA3D_steam.dll`). |
| `bridge/` | C code for the prism bridge, which talks to the screen reader. |
| `installer/` | The scripts that copy the mod into a game and take it out again. |
| `assets/` | The mod's sounds and the native libraries per architecture (`x86`, `x64`). |
| `test/` | The mod's test suite and its helpers. |
| `tools/` | Standalone helpers, including the script extractor. |
| `docs/` | The full technical documentation (see below). |

Inside `core/`, each module groups one responsibility: `foundation/` (base and configuration), `input/` (keys
and hooks), `speech/` (voice), `data/` (game data), `nav/` (navigation and pathfinding), `audio/` (3D sound),
`menus/`, `battle/`, `party/`, `field/`, `dialogue/`, `puzzles/` and `util/`.

## Documentation

The technical documentation is in **[`docs/`](docs/)**, complete in both Spanish and English.

Good places to start:

- **[docs/en/01-overview.md](docs/en/01-overview.md)** — what is here and how it boots.
- **[docs/en/09-faq.md](docs/en/09-faq.md)** — the questions that come up first.
- **[docs/README.md](docs/README.md)** — index of both languages.

If you are going to touch the code, read the **invariants** in the overview first: among other things,
`core/` runs under Ruby 1.8.7, which limits the syntax you can write.

To read your own game's scripts, `ruby tools/dump_scripts.rb "<game folder>"` extracts them to readable
`.rb` files.

## Changes

The downloads for each version are on the
[releases page](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases). Release notes go here,
most recent first.

## Licence

This project is free software under the **[MIT](LICENSE)** licence: you may use, modify and redistribute it
freely as long as the copyright notice is kept.

The third-party native libraries bundled in `assets/` keep their own licences.
