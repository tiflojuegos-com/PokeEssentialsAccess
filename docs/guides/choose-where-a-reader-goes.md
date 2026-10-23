# Choose where a reader goes

This guide decides where a new [reader](../reference/glossary.md) lives: in `core/`, in `plugins/`, in a
[shared profile](../reference/glossary.md) or in one game's profile. The origin of the screen decides it, whatever the
number of games that show it. Use it before [Add a reader](add-a-reader.md) or
[Add a plugin reader](add-a-plugin-reader.md); [Overview](../architecture/overview.md) describes the three layers.

## Starting point

- The class that draws the screen and the method to hook are known, from the game's
  [script dump](../reference/glossary.md). [Debug a silent screen](debug-a-silent-screen.md) finds the real class of
  a screen.
- The script dumps of the surveyed games are at hand, in `../../decompiled Scripts`.

## Steps

1. Find where the class comes from.
   - Stock Essentials: the class is in the upstream Essentials repository, found with
     `git grep -l "class <Name>" v19 v19.1 v20 v20.1 v21 v21.1` in a checkout of it. Its tags start at `v19`, so a
     gen-6 screen is stock when two or more unrelated games carry it nearly identical.
   - A plugin: the script dump has the class under `_PluginScripts/`, a probe of `plugins/manifest.rb` names it, or
     a copy of the plugin defines it. A plugin that a base kit bundles in its own script tree is still a plugin:
     `plugins/dbk_enhanced_ui.rb` reads the Enhanced Battle UI of the Deluxe Battle Kit that La Base de Sky bundles.
   - The game's own: `test/static/fangame_classes.txt` lists the class with a single game and `script`.
     `test/static/all_classes.txt` gives the number of surveyed sources that define each class.
2. Compare the copies. Diff the class across the script dumps that define it. A copy of a plugin whose methods take
   other parameters, that draws differently or that sits in a folder whose name starts with `[Edited]` is an edited
   or old version.
3. Place the reader by the origin, with the table and the rules below.
4. Run `ruby test/run_all.rb static`. `coupling_test`, `imports_test` and `plugins_test` fail a reader in the wrong
   layer ([Static checks](../reference/static-checks.md)).

| Origin | The reader goes to |
|---|---|
| Stock Essentials, alike in every era | `core/<subsystem>/` |
| Stock Essentials of one era | `core/<subsystem>/gen6/`, `v21/` or `v22/` |
| A third-party plugin, unedited | `plugins/<name>.rb`, with its probe in `plugins/manifest.rb` |
| A saga, an author or a derived engine several games share | a shared profile, `games/<name>_common/` |
| The game's own screen, or its old or edited copy of a plugin | the game's profile, `games/<profile>/` |

## Stock screens

- Core registers the hook with `:optional => true`, so it binds in each game whose version has the method.
- A variant of a stock screen inside one era needs no file of its own. `core/menus/gen6/move_relearner_g6.rb` reads
  the gen-6 Move Relearner on `pbDrawMoveList`, and the older screen of Insurgence and Uranium on `pbRefreshInfo`.
- A core reader splits by variants, never by hooks. With the third variant of one screen, or with two once the file
  passes about 150 lines, it becomes a folder named after the screen: `base.rb` with what every variant shares, and
  one file per variant whose header names the version or games it serves. List the files in order in
  `core/manifest.rb`. The Pokédex search is split this way: `core/menus/pokedex_search/base.rb`, with the variants
  `core/menus/pokedex_search/grid.rb` and `core/menus/pokedex_search/list.rb`.
- There is no `legacy/` folder. A new era folder appears only for a stock Essentials version that needs its own
  detection in several modules ([Engine eras](../architecture/engine-eras.md)).
- `test/static/coupling_test.rb` fails a core file that names a class only one surveyed fangame defines.

## Plugins

- Every unedited plugin goes to `plugins/`, whether one game ships it or many. It is third-party code a
  [probe](../reference/glossary.md) identifies, and another game may ship it.
- The [generic profile](../reference/glossary.md) loads the reader in any game that has the probe; a game's own
  profile declares it under `:plugins`.

## Shared profiles

- A reader of a screen that the games of one saga, one author or one derived engine share lives in a shared profile,
  `games/<name>_common/`, which each of those profiles imports with `:imports`. `test/static/imports_test.rb` fails a
  file copied between two playable profiles, even when the copies differ only in their profile names.
- A shared profile has no catalog entry and imports no other one, and some playable profile imports it. The loader
  evaluates its modules after the plugin readers and before the importing profile's own modules; the launcher installs
  it in `accessibility/common/<name>/`.
- `games/lostie_common/` holds what Pokémon Z and Ópalo share, `games/skyflyer_common/` what Añil and Royal share, and
  `games/infinitefusion_common/` what the two Infinite Fusion games share.
- A derived engine that a saga shares belongs to the saga: its readers go to the shared profile, and it adds no
  [engine era](../reference/glossary.md). The engine of Reborn, Rejuvenation and Desolation lives in
  `games/rv_common/`, which registers its data provider with `PokeAccess::Data.register`.

## A game's own screen

- A screen only the game has goes to its profile, even when its reader reads no argument.
- So does a plugin the game edited. Drimer's Trainer Sensor as Pokémon Z edits it is read by
  `games/pokemon_z/trainer_sensor.rb`, and as Añil and Royal edit it by `games/skyflyer_common/trainer_sensor.rb`.
- A profile changes what a core reader does with `override`. `test/static/coupling_test.rb` fails a profile that
  reopens a core module other than `PokeAccess::Config`.

## The version exception

A game that ships an older version of a plugin, or one it edited, has the reader of that copy in its profile, and its
manifest leaves the `plugins/` reader out. The `plugins/` reader binds by class and method name. On a copy whose
methods take other parameters it binds without an error and reads arguments that mean something else.

`plugins/dbk_enhanced_ui.rb` reads the current [DBK] Enhanced Battle UI, which Añil, Emerald, Relict and Royal ship.
Soulstones 2 ships Enhanced UI 1.1.2, edited. `games/soulstones2/enhanced_ui.rb` reads it, and
`games/soulstones2/manifest.rb` leaves `dbk_enhanced_ui` out.

| Method of `Battle::Scene` | Current release | Soulstones 2's 1.1.2 |
|---|---|---|
| `pbUpdateMoveInfoWindow` | `(battler, specialAction, cw)` | `(battler, index)` |
| `pbUpdateBattlerInfo` | `(battler, effects, idxEffect = 0)` | `(battler)` |
| `pbUpdateBattlerSelection` | `(idxSide, idxPoke, select)` | `(index, select)` |

The probe of `dbk_enhanced_ui` is `Battle::Scene#pbGetFinalModifiers`, a method 1.1.2 lacks. The generic profile
therefore never loads the reader for 1.1.2, and the census does not count Soulstones 2 among the games that ship the
current release. `test/static/arity_test.rb` excuses the first two methods of the table for this reason.

When the same old version appears in a second game, its reader moves to `plugins/` as a file of its own, with a probe
of its own. `plugins/fl_character_selection_v1.rb` reads the version of FL's Character Selection that predates its
module, probed by `CharacterSelectionScene`, beside `plugins/fl_character_selection.rb`, probed by
`CharacterSelection`.
