# PokeEssentialsAccess

[Español](README.es.md) · **English**

An accessibility mod for Pokémon fangames. It lets a blind person play them with a screen reader.

---

## Contents

- [What is this?](#what-is-this)
- [What does it add?](#what-does-it-add)
- [Installing](#installing)
- [Supported games](#supported-games)
- [Notes per game](#notes-per-game)
- [The mod's keys](#the-mods-keys)
- [Repository layout](#repository-layout)
- [Documentation](#documentation)
- [Licence](#licence)

---

## What is this?

A mod that makes fangames built on **Pokémon Essentials** and run with **mkxp-z** accessible, from the gen-6
era (Essentials v16-v17) through v22 and its forks, including the engine Reborn, Rejuvenation and Desolation
run on.

It does not modify the game's scripts: it loads through mkxp-z's `preloadScript`, so it can be uninstalled
and the game is left exactly as it was.

Games that still run on the original RPG Maker XP player, such as Pokémon Insurgence and Pokémon Uranium, are
**converted** on install: next to the original executable, which is left untouched, the installer adds
`<game name> (PokeAccess).exe`, a build of mkxp-z made for the mod. That is the one to open to play with
accessibility; the launcher's **Play** button uses it on its own.

## What does it add?

- **Text reading**: menus, dialogue (whole, or page by page as the game shows it if you prefer), battle,
  Pokémon summaries, Pokédex, bag, trainer card, and so on. The voice goes out through **prism**, which
  talks to NVDA, JAWS, SAPI, UIA, ZDSR and other readers, and also sends to a braille display.
- **Sound navigation**: a binaural 3D sonar (Steam Audio) that places people, objects, doors, warps, water
  and walls around you.
- **Pathfinding**: pick a target on the map and the mod works out the route and guides you there with a
  sound (held where the key has to be kept held down) or step by step. It counts on what the game itself does (ice, hops, arrow floors, side staircases,
  currents, waterfalls, warps within the map, bridges) and, when there is no walking route, tells you what to
  do to get past: surf, use a field move, push a boulder, press the action button at a wall you can climb, or
  get off the bike.
- **Sound glossary**: step through every cue you will hear from the mod's own menu, listen to it, and read
  what it means.
- **Session recorder**: writes what the mod saw and said to a file, to attach when reporting a problem.
- **Markers**: mark any tile with `Ctrl` + `G` and find your way back to it with the locator and the guides. Labels, markers and map names are imported and exported separately from "Personalization" in the mod's menu, and every file carries the game it belongs to so they never get mixed up.
- **Verbosity**: how much is said while moving through menus. **Brief** says what matters (in the party, the name, HP and status; in battle, the move and its PP), **Medium** a little more and **Full** everything, as always, which is the default. The `T` key says the same as always at any level, and `Ctrl` + `T` repeats the focused row whole, as Full says it. You can also make **your own schemes**, which set a level for each kind of reading (party, moves, the battle box's marks, bag, shop, boxes, the Pokédex and its pages, ribbons, positions, key hints and descriptions, such as the options' or the detail of a place on the region map), and share them as files; games and plugins with screens of their own add their readings to the editor, and each scheme also sets a level for the readings it does not name, so it works in any game. It all lives in "Personalization" in the mod's menu, and a key changes the level without opening it (unassigned by default).
- **Message history**: `Home` and `End` go back through what the mod said last, all of it or by category: dialogue, battle, menus, navigation, information and system. How many messages it keeps (300 by default, up to 2000) is set in the general options.
- **Key remapping** for the games, from the mod's menu.
- **Puzzle accessibility**. This has to be done game by game; so far there is support in:
  - Pokémon Z
  - Pokémon Ópalo

## Installing

The mod works on games whose **mkxp-z** was built with `preloadScript` support. The launcher checks this
before installing and tells you if the game will not take it. If the game runs on the original RPG Maker XP
player and is in the catalog, it converts it as described above; uninstalling deletes the added executable
and leaves the folder as it was. If it is not in the catalog, an experimental conversion can be tried: the
launcher warns that the game may not start or something may fail, and asks first.

Keep the game's folder on a short path, for example `C:\Games\Pokemon Insurgence`. Windows limits path
length, and the launcher warns when the game's path is too long: from 200 characters for a converted game,
and from 126 for games that ship their own old mkxp-z, which on such a path start without loading the mod.

### With the graphical installer (recommended)

Download `pokeessentialsaccess-launcher.exe` from the
[releases page](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases); it also comes at the root
of each version's zip. A double click opens a window of native Windows controls, usable with a screen reader,
that keeps a list of your games:

| Action | Shortcut |
|--------|----------|
| Add a game (the profile is detected for you) | `Ctrl` + `A` |
| Check whether a game takes the mod, changing nothing: the selected one or another folder | `Ctrl` + `K` |
| Install or update the selected game | `Ctrl` + `I` |
| Update every game in the list | `Ctrl` + `U` |
| Play the selected game | `Ctrl` + `J` |
| Edit a game: name, folder, profile and executable | `Ctrl` + `P` |
| Uninstall the mod from a game | `Ctrl` + `D` |
| Export the player's data to a .zip: settings, verbosity schemes, labels, markers and map names | `Ctrl` + `E` |
| Import that data from a .zip; labels, markers and map names only from the same game | `Ctrl` + `M` |
| Remove a game from the list | `Ctrl` + `Q` |
| Launcher options | `Ctrl` + `O` |
| Check for a new version of the installer itself | `Ctrl` + `B` |

Dropping a game's folder onto the exe opens the window on "Add game" with that folder already chosen.

**Play** opens the executable saved for that game. If the folder has several and none is clearly the game's,
it asks which one to use, with a box to remember the choice; in **Edit**, the "Ask when playing" option clears
what was remembered. On a converted game, Play always uses the accessible executable.

Updating downloads only the files that changed and keeps **everything in `accessibility\data`**: your
settings, your object tags, the map names you typed yourself, and your recordings.

### From the console

The same exe takes commands. In a console open in its folder (cmd, PowerShell or Windows Terminal):

```
.\pokeessentialsaccess-launcher check "D:\Games\Pokemon Z"
.\pokeessentialsaccess-launcher install "D:\Games\Pokemon Z"
.\pokeessentialsaccess-launcher uninstall "D:\Games\Pokemon Z"
```

With no folder, they open a picker. With `local` in front (`local install`, `local check`…), the mod comes from
the unzipped `PokeEssentialsAccess_<version>.zip` instead of the internet. Every command, its options and the
exit codes are in `commands.txt`, at the root of the zip.

## Supported games

There is one profile per game in `games/`; the list the launcher uses to recognise a game is
[`games/catalog.json`](games/catalog.json).

**Gen-6 era** (Essentials v16-v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía,
Pokémon Realidea, Pokémon Africanus, Pokémon Awakening, Pokémon Soulstones, and the ones converted on install:
Pokémon Insurgence and Pokémon Uranium.

**Reborn's engine** (based on Essentials v16, running Ruby 3): Pokémon Reborn, Pokémon Rejuvenation and Pokémon Desolation.

**GameData era** (Essentials v18 onwards): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Eternal Emerald,
Pokémon Infinite Fusion, Pokémon Infinite Fusion 2 Hoenn, Pokémon Fire Ash, Pokémon Soulstones 2.

Plus a **generic profile** for any other Essentials fangame: it gives all the common accessibility (menus,
dialogue and battle reading, navigation and pathfinding) without the readers specific to one game.

## Notes per game

### Pokémon Insurgence

Out of the box, Insurgence uses three letters that are also the mod's, and one press does both things:

| Key | In the game | In the mod |
|-----|-------------|------------|
| `T` | registered item 4 | information on the focused thing |
| `M` | speed up the game | coordinates |
| `O` | remove the Pokémon following you | the mod's menu |

To split them, move those game actions to other keys on the game's own controls screen ("Controls", on the title
menu; the mod reads it), or move the mod's keys in its menu, under "Remap game controls".

## The mod's keys

> **Recommendation:** some games' stock keys are awkward to reach. From the mod's menu (the `O` key) you can
> reassign them; a comfortable layout is **movement** on `W`, `A`, `S`, `D`, **confirm** on `E` and **cancel**
> on `Q`. Move the game's buttons that live on those letters to other keys too: by default `A`, `S`, `D`, `Q` and
> `W` are the X, Y, Z, L and R buttons. A reassigned direction is added to the key it had and silences nothing, so
> while those buttons stay put the same press does both (in Pokémon Z's pause menu, moving down with `S` would open
> the PokeRider).

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
| `Home` | Previous message in the history. The first time in each view it reads the latest; after that it remembers where you left off, even when new messages arrive |
| `End` | Next message in the history |

### Modifiers

Combined with the keys above, they extend them:

| Combination | Action |
|-------------|--------|
| `Shift` + `J` / `L` | Change target category (people, objects, exits, and so on) |
| `Shift` + `K` | Rename the selected target |
| `Ctrl` + `K` | Open the target's tag menu |
| `Shift` + `I` | Turn the audible guidance towards the target on or off |
| `Ctrl` + `I` | Turn the step-by-step guidance on or off: it speaks the leg you are walking ("6 up") and the next one as you finish it |
| `Shift` + `T` | Repeat the last line of dialogue read |
| `Ctrl` + `T` | Repeat the focused row whole, as the Full level says it, whatever level you use |
| `Shift` + `H` | Read the opposing team's HP |
| `Shift` + `M` | Rename the current map |
| `Ctrl` + `M` | Show or hide the targets you cannot reach |
| `Ctrl` + `G` | Set a marker on the tile you stand on: it asks for a name, and a blank one deletes it. Markers get their own locator category |
| `Ctrl` + `Home` / `End` | Go to the first or the last message in the history |
| `Shift` + `Home` / `End` | Change the history's category: all, dialogue, battle, menus, navigation, information or system |

The key to **change the verbosity** (Brief, Medium, Full and your schemes) comes unassigned, since every letter belongs to some game: assign it in the mod's menu, under "Remap game controls", like any other mod key.

Tip for following the guides: on a change of direction, or after letting go of the key and pressing it
again, the first short press only turns the character without moving them. Hold the key a moment and you
will take the step.

### Global shortcuts

| Combination | Action |
|-------------|--------|
| `Ctrl` + `Alt` + `F8` | Turn the mod on or off (off also silences the sonar; on rebuilds it and retries the connection to the screen reader) |
| `Ctrl` + `Alt` + `F9` | Dump a diagnostic to a file (useful when a screen, puzzle or map turns out to be inaccessible) |
| `Ctrl` + `Alt` + `F10` | Quick spoken diagnostic (useful when something goes quiet) |

## Repository layout

These are the main folders and what they hold:

| Folder | Contents |
|--------|----------|
| `core/` | The mod's shared, game-agnostic engine. Organised by module, and inside by Essentials version (`gen6`, `v21`, `v22`) where that matters. |
| `games/` | One profile per game: its specific readers and its configuration. Each folder is a supported fangame. |
| `plugins/` | Readers for third-party plugins that several fangames install. |
| `lang/` | The text the mod speaks, translated into six languages (`es`, `en`, `fr`, `pt`, `de`, `pl`). The language picks itself (the system's, else the game's, else English) and can be pinned from the menu. |
| `loader/` | The preload that waits for the game, and the boot that loads the mod in order. |
| `native/` | C code for the 3D audio backend (`pa3d_steam.c` → `PA3D_steam.dll`). |
| `bridge/` | C code for the prism bridge, which talks to the screen reader. |
| `assets/` | The mod's sounds and the native libraries per architecture (`x86`, `x64`). |
| `test/` | The mod's test suite and its helpers. |
| `tools/` | Standalone helpers, including the script extractor. |
| `docs/` | The full technical documentation (see below). |

The launcher, the window and the console that copy the mod into a game and take it out again, has its own
repository: [PokeEssentialsAccessInstaller](https://github.com/tiflojuegos-com/PokeEssentialsAccessInstaller). Every
mod release ships its exe.

Inside `core/`, each module groups one responsibility: `foundation/` (base and configuration), `input/` (keys
and hooks), `speech/` (voice, message history and verbosity), `data/` (game data), `nav/` (navigation and pathfinding), `audio/` (3D sound),
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

## Licence

This project is free software under the **[MIT](LICENSE)** licence: you may use, modify and redistribute it
freely as long as the copyright notice is kept.

The third-party native libraries bundled in `assets/` keep their own licences.

The engine in `assets/engine/` is mkxp-z 1.3.0 built for the mod (32-bit, Ruby 1.8.7), under mkxp-z's **GPL**.
Its source code, patches and rebuild scripts are on the `pokeaccess-1.3` branch of
[tiflojuegos-com/mkxp-z-legacy](https://github.com/tiflojuegos-com/mkxp-z-legacy/tree/pokeaccess-1.3), and the sources of its
dependencies are in that repository's `pokeaccess-1.3.0` release. The licences of everything it contains are in
`assets/engine/mkxp-z-1.3.0-x86/LICENSES.txt`.
