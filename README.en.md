# PokeEssentialsAccess

[Español](README.es.md) · **English**

An accessibility mod for Pokémon fangames made with Pokémon Essentials. It lets a blind person play them with their
screen reader.

---

## Contents

- [What it is](#what-it-is)
- [What it does](#what-it-does)
- [Installing](#installing)
- [Supported games](#supported-games)
- [Notes per game](#notes-per-game)
- [Keys](#keys)
- [Repository layout](#repository-layout)
- [Technical documentation](#technical-documentation)
- [Licence](#licence)

---

## What it is

A mod that makes **Pokémon Essentials** fangames running on **mkxp-z** accessible. It covers the gen-6 era
(Essentials v16 and v17) through v22 and its forks, including the engine Reborn, Rejuvenation and Desolation run on.

It does not change the game's scripts. It loads through mkxp-z's `preloadScript`, so uninstalling it leaves the game
as it was.

Some games still run on the original RPG Maker XP player, such as Pokémon Insurgence and Pokémon Uranium. When the mod
is installed, the launcher **converts** them: it leaves the original executable alone and adds
`<game name> (PokeAccess).exe` next to it, a build of mkxp-z made for the mod. That is the one to open to play with
accessibility, and the launcher's **Play** button already uses it.

## What it does

### Reading

- Reads menus, dialogue, battles, Pokémon summaries, the Pokédex, the bag, the trainer card, and the screens of each
  game and of many plugins.
- Dialogue is read whole or, if you prefer, page by page, as the game shows it.
- Also reads the standard Essentials minigames: Voltorb Flip, the slot machine, mining, the duel and the tile puzzle.
- The voice goes out through **prism**, which talks to NVDA, JAWS, SAPI, UIA, ZDSR and other screen readers, and also
  sends the text to a braille display.

### Verbosity

Choose how much is said as you move through menus:

- **Brief**: what matters. In the party, the name, HP and status; in battle, the move and its PP.
- **Medium**: a little more.
- **Full**: everything. This is the default.

At any level, `T` gives the details of what has focus and `Ctrl` + `T` repeats the whole row, as Full would say it.

You can also make **your own schemes**. A scheme sets a level for each kind of reading (party, moves, bag, shop,
boxes, Pokédex, positions, key hints, descriptions…) and one for everything it does not name, so it works in any game.
Games and plugins with screens of their own add their readings to the editor, and schemes can be shared as files.

All of this is under "Personalization" in the mod's menu. The key that changes the level without opening the menu
comes unassigned (see [Keys](#keys)).

### Message history

`Home` and `End` go back through what the mod said last, all together or by category: dialogue, battle, menus,
navigation, information and system. It keeps 300 messages by default, and up to 2000 if you change it in "General
options".

### Sound navigation

- A binaural 3D sonar (Steam Audio) places people, objects, doors, warps, water and walls around you.
- The **proximity radar** gives a short beep when something you can interact with is right in front of you.
- Under "Sounds on" you can turn each sound off on its own.
- The **sound glossary**, in the mod's menu, lets you hear every sound and read what it means.

### Targets and routes

- The **locator** goes through what is on the map by category: people, objects, exits and more.
- Pick a target and the mod works out the route and guides you there with a sound or step by step.
- The route counts on what the game does: ice, hops, arrow floors, side staircases, currents, waterfalls, warps within
  the map and bridges.
- When there is no way on foot, it tells you what to do to get past: surf, use a field move, push a boulder, press
  Action at a wall you can climb, or get off the bike.

Under "Navigation and pathfinder options" you decide how the target list works:

- **Hide targets**: none, those with no route, or also those in other rooms when a map joins several.
- **Hide non-interactable objects**: leaves out the decoration you cannot do anything with.
- **Target order**: by straight distance, by walking distance, or fixed.
- **Target numbering**: off (the place in the list is said), dynamic (each target keeps its number while you stay on
  the map) or static (it also counts the hidden ones, so numbers can skip).
- Whether to name **pickup items**, unnamed **trainers** by their class and whether you beat them, map **Pokémon** by
  their species, and **signs** by what their text says.
- **Surface cues**: says the ground under you when it changes.

### Labels, markers and map names

- You can name a target with `Shift` + `K` and the map with `Shift` + `M`.
- `Ctrl` + `K` opens the target's menu: rename it, take its name off, change its category or hide it.
- `Ctrl` + `G` sets a **marker** on the tile you stand on. Markers have their own locator category and are followed
  with the same guides.
- "Personalization" holds the lists **Object labels**, **Markers** and **Map names**. From them you can rename or
  delete each entry, and show again an object you hid.
- Each list is imported and exported on its own. Every file carries the game it belongs to, so they never get mixed
  up.

### Puzzles

- The route counts on the standard mechanics, such as boulders pushed with Strength, in any game.
- Puzzles of a game's own are prepared one game at a time. So far there is support in Pokémon Z and Pokémon Ópalo.
  Inside a puzzle, `T` says its state.
- The "Puzzle assist" option, off by default, gives the hints and routes that solve them.

### Other tools

- **Key remapping**: "Remap game controls" changes the game's keys and the mod's.
- **Session recorder**: "Record session", under "Debugging", writes what the mod saw and said to a file, to attach
  when you report a problem.

## Installing

The mod works on games whose **mkxp-z** supports `preloadScript`. The launcher checks this before installing and tells
you if the game does not.

- If the game runs on the original RPG Maker XP player and is in the catalog, the launcher converts it as described
  above. Uninstalling deletes the added executable and leaves the folder as it was.
- If it is not in the catalog, you can try an experimental conversion. The launcher warns you that the game may not
  start or may fail at something, and asks you to confirm.

Keep the game in a folder with a short path, for example `C:\Games\Pokemon Insurgence`. Windows limits path length,
and the launcher warns when the game's path is too long: from 200 characters for a converted game, and from 126 for
games that ship an old mkxp-z, which on such a path start without loading the mod.

### With the launcher (recommended)

Download `pokeessentialsaccess-launcher.exe` from the
[releases page](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases). It also comes at the root of each
version's zip. Opening it shows a window of native Windows controls, usable with a screen reader, that keeps the list
of your games:

| Action | Shortcut |
|--------|----------|
| Add a game (the profile is detected for you) | `Ctrl` + `A` |
| Check whether a game takes the mod, changing nothing: the selected one or another folder | `Ctrl` + `K` |
| Install or update the selected game | `Ctrl` + `I` |
| Update every game in the list | `Ctrl` + `U` |
| Play the selected game | `Ctrl` + `J` |
| Edit a game: name, folder, profile and executable | `Ctrl` + `P` |
| Uninstall the mod from a game | `Ctrl` + `D` |
| Export your data to a .zip: settings, verbosity schemes, labels, markers and map names | `Ctrl` + `E` |
| Import that data from a .zip; labels, markers and map names only from the same game | `Ctrl` + `M` |
| Remove a game from the list | `Ctrl` + `Q` |
| Launcher options | `Ctrl` + `O` |
| Check for a new version of the launcher itself | `Ctrl` + `B` |

Dropping a game's folder onto the exe opens the window on "Add game" with that folder already chosen.

**Play** opens the executable saved for that game. If the folder has several and none is clearly the game's, it asks
which one to use, and you can tick a box to remember the choice; to forget it, use "Ask when playing" in **Edit**. On
a converted game, Play always opens the accessible executable.

Updating downloads only the files that changed and keeps everything in `accessibility\data`: your settings, your
verbosity schemes, your labels, markers and map names, and your recordings.

### From the console

The same exe takes commands. In a console open in its folder (cmd, PowerShell or Windows Terminal):

```
.\pokeessentialsaccess-launcher check "D:\Games\Pokemon Z"
.\pokeessentialsaccess-launcher install "D:\Games\Pokemon Z"
.\pokeessentialsaccess-launcher uninstall "D:\Games\Pokemon Z"
```

With no folder, they open a picker. With `local` in front (`local install`, `local check`…), the mod comes from the
unzipped `PokeEssentialsAccess_<version>.zip` instead of the internet. Every command, its options and the exit codes
are in `commands.txt`, at the root of the zip.

## Supported games

Each game has its profile in `games/`. The list the launcher uses to recognise games is
[`games/catalog.json`](games/catalog.json).

- **Gen-6 era** (Essentials v16 and v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía, Pokémon
  Realidea, Pokémon Africanus, Pokémon Awakening, Pokémon Soulstones and Pokémon HGSS: Sevii Islands, plus the ones
  converted on install: Pokémon Insurgence and Pokémon Uranium.
- **Reborn's engine** (based on Essentials v16, running Ruby 3): Pokémon Reborn, Pokémon Rejuvenation and Pokémon
  Desolation.
- **GameData era** (Essentials v18 onwards): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Eternal Emerald,
  Pokémon Grueling Gold, Pokémon Infinite Fusion, Pokémon Infinite Fusion 2 Hoenn, Pokémon Fire Ash and Pokémon
  Soulstones 2.

Any other Essentials fangame gets a **generic profile**. It gives all the common accessibility (menus, dialogue,
battle, navigation and pathfinding), without the readers made for one particular game.

## Notes per game

### Pokémon Insurgence

Out of the box, Insurgence uses three letters that are also the mod's, and one press does both things:

| Key | In the game | In the mod |
|-----|-------------|------------|
| `T` | Registered item 4 | Details of what has focus |
| `M` | Speed up the game | Coordinates |
| `O` | Remove the Pokémon following you | The mod's menu |

To split them, move those game actions to other keys on the game's controls screen ("Controls", on the title menu;
the mod reads it), or move the mod's keys under "Remap game controls".

### Pokémon HGSS: Sevii Islands

In Sevii, `Shift` is both the game's speed-up key and the mod's modifier. Every combination with `Shift`
(`Shift` + `T`, `Shift` + `H`…) speeds the game up for a moment, and the mod says "Fast speed" and "Normal speed",
cutting off what it was saying. To avoid it, move the mod's "Shift modifier" to another key under "Remap game
controls".

## Keys

> **Tip:** some games' default keys are hard to reach. You can change them from the mod's menu (the `O` key). A
> comfortable layout is **movement** on `W`, `A`, `S` and `D`, **Confirm** on `E` and **Cancel** on `Q`. If you do
> this, also move the game's buttons that live on those letters: by default, `A`, `S`, `D`, `Q` and `W` are the X, Y,
> Z, L and R buttons. A reassigned direction is added to the key it had and does not replace it, so while those
> buttons stay where they are, the same press does both. For example, in Pokémon Z's pause menu, moving down with `S`
> would open the PokeRider.

### The mod's keys

| Key | What it does |
|-----|--------------|
| `J` | Previous target in the list |
| `L` | Next target in the list |
| `K` | Says the selected target: its name, its number, the direction and how many steps away it is |
| `I` | Works out the route to the target and says it |
| `T` | Details of what has focus: move, item, Pokémon, trainer… Inside a puzzle, its state. On ground that moves you, such as ice or arrows, that movement and where each direction takes you |
| `H` | In battle, your team's HP, and in the Safari Zone, the Safari Balls left. Outside battle, each Pokémon in your party with its HP and status |
| `G` | In battle, the field, the weather, the terrain and each side's conditions. Outside battle, the weather, the game's clock and the time of day |
| `M` | The map and your coordinates |
| `O` | Opens the mod's menu |
| `Home` | Previous message in the history. The first time in each view it reads the latest; after that it remembers where you left off, even when new messages arrive |
| `End` | Next message in the history |

### With modifiers

| Combination | What it does |
|-------------|--------------|
| `Shift` + `J` / `L` | Changes the target category, says how many targets it has and selects the first |
| `Shift` + `K` | Names the target. Escape or a blank name cancels |
| `Ctrl` + `K` | Opens the target's menu: rename, take the name off, change the category or hide. On a marker, it opens the marker's menu |
| `Shift` + `I` | Turns the sound guide to the target on or off |
| `Ctrl` + `I` | Turns the step-by-step guide on or off; it says the leg you are on ("6 up") and the next one as you finish it |
| `Shift` + `T` | Repeats the last line of dialogue |
| `Ctrl` + `T` | Repeats the whole focused row, as the Full level would say it |
| `Shift` + `H` | The opposing team's HP |
| `Shift` + `M` | Names the current map |
| `Ctrl` + `M` | Changes which targets are hidden: none, those with no route, or also those in other rooms |
| `Ctrl` + `G` | Sets a marker where you stand and asks for its name. Escape or a blank name cancels. Delete it with `Ctrl` + `K` or from the marker list |
| `Ctrl` + `Home` / `End` | First or last message in the history |
| `Shift` + `Home` / `End` | Changes the history's category: all, dialogue, battle, menus, navigation, information or system |

The key to **change the verbosity** (Brief, Medium, Full and your schemes) comes unassigned, because some game uses
every letter. Assign it under "Remap game controls", like any other mod key.

For following the guides: after a change of direction, or after letting go of the key and pressing it again, the first
short press only turns the character. Hold the key a moment to take the step.

### On the region map

With the region map open, `J`, `L`, `I` and `K` move the cursor to the nearest fly point to the left, to the right, up
and down. In Pokémon Royal these jumps are turned off.

### In the mod's menu

The menu runs on the arrows and the game's Confirm and Cancel. Left and Right change the row's value. Also:

- `T` says the row's help.
- `Ctrl` + `T` says the row, its value and its help.

### Global shortcuts

| Combination | What it does |
|-------------|--------------|
| `Ctrl` + `Alt` + `F8` | Turns the mod on or off. Off also silences the sonar; turning it on rebuilds it and reconnects to the screen reader |
| `Ctrl` + `Alt` + `F9` | Writes a diagnostic to a file, useful when you find a screen, puzzle or map that is not accessible |
| `Ctrl` + `Alt` + `F10` | A quick spoken diagnostic, useful when something goes quiet |

## Repository layout

| Folder | Contents |
|--------|----------|
| `core/` | The core shared by every game, by module. Some modules have a subfolder per Essentials version (`gen6`, `v21`, `v22`) |
| `games/` | One profile per game, with its readers and its configuration |
| `plugins/` | Readers for third-party plugins that several fangames use |
| `lang/` | The text the mod speaks, in six languages (`es`, `en`, `fr`, `pt`, `de`, `pl`). The language picks itself (the system's, else the game's, else English) and can be pinned in the menu |
| `loader/` | The preload, which waits for the game, and the boot, which loads the mod in order |
| `native/` | The C code of the 3D audio, which builds `PA3D_steam.dll` |
| `bridge/` | The C code of the bridge to prism, which talks to the screen reader |
| `assets/` | The mod's sounds, the native libraries per architecture (`x86`, `x64`) and the mkxp-z for converted games |
| `test/` | The mod's tests and their helpers |
| `tools/` | Standalone helpers, such as the script extractor |
| `docs/` | The technical documentation |

The modules of `core/` are `foundation/` (base and settings), `util/`, `data/` (game data), `speech/` (voice, history
and verbosity), `input/` (keys and hooks), `menus/`, `battle/`, `party/`, `dialogue/`, `field/`, `world/` (terrain,
passability and events), `routes/` (the route planner), `nav/` (locator and guides), `sound/` (3D audio and sounds) and
`puzzles/`.

The launcher, the window and the console that put the mod into a game and take it out, has its own repository:
[PokeEssentialsAccessInstaller](https://github.com/tiflojuegos-com/PokeEssentialsAccessInstaller). Every mod release
ships its exe.

## Technical documentation

The technical documentation is in **[`docs/`](docs/README.md)**:

- [docs/README.md](docs/README.md): the index, with the architecture, step-by-step guides and the reference.
- [docs/architecture/overview.md](docs/architecture/overview.md): what is here and how it boots.

Before touching the code, read the overview's [design rules](docs/architecture/overview.md#design-rules). Among other
things, code that a Ruby 1.8.7 game loads has to follow Ruby 1.8.7, which limits the syntax you can use.

To read your own game's scripts, `ruby tools/dump_scripts.rb "<game folder>"` extracts them to readable `.rb` files.

## Licence

This project is free software under the **[MIT](LICENSE)** licence: you may use, modify and redistribute it as long as
you keep the copyright notice.

The third-party native libraries in `assets/` keep their own licences.

The engine in `assets/engine/` is mkxp-z 1.3.0 built for the mod (32-bit, Ruby 1.8.7), under mkxp-z's **GPL**. Its
source code, patches and rebuild scripts are on the `pokeaccess-1.3` branch of
[tiflojuegos-com/mkxp-z-legacy](https://github.com/tiflojuegos-com/mkxp-z-legacy/tree/pokeaccess-1.3), and the sources
of its dependencies are in that repository's `pokeaccess-1.3.0` release. The licences of everything it contains are in
`assets/engine/mkxp-z-1.3.0-x86/LICENSES.txt`.
