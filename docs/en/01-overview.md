# Overview

Accessibility mod for Pokémon Essentials fangames running on mkxp-z: reads the screen through a screen
reader, adds sound-based navigation and pathfinding.

It does not modify the game's scripts. It is injected through mkxp-z's `preloadScript`; uninstalling leaves
the game as it was.

## Figures

| | |
|---|---|
| Core modules | 133, in `core/manifest.rb` |
| Game profiles | 16, in `games/` |
| Plugin readers | 49, in `plugins/` |
| Languages | 6 (`es`, `en`, `fr`, `pt`, `de`, `pl`), in `lang/` |
| Suite | 2599 (gen-6, static checks included) + 409 (gamedata) |
| Ruby | 1.8.7 in the game; the system one in tests |

## Layers

| Layer | Contents | Rule |
|---|---|---|
| `core/` | What any Essentials game has | Knows nothing of plugins or specific games |
| `plugins/` | Readers for third-party plugins | One plugin = one file; hooks are `:optional` |
| `games/<profile>/` | Code for one fangame | Never references another profile |

Inside `core/` the layout is **module first**: `core/<module>/` holds the engine-agnostic readers, and the
`gen6/`, `v21/`, `v22/` subfolders hold only what differs per era. Anything shared by several
eras lives at the module root.

Modules: `audio`, `battle`, `data`, `dialogue`, `field`, `foundation`, `input`, `menus`, `nav`, `party`,
`puzzles`, `speech`, `util`.

## Startup

`preloadScript` runs **before** `Scripts.rxdata`, when no game class exists yet. So
`loader/preload_access.rb` defers loading: it wraps `Graphics.update` and evaluates `accessibility/boot.rb`
once the main loop is running (`$scene` assigned, or -- as a fallback -- 120 frames **and** the script list
finished, which is known because `Main` has defined `pbCallTitle`).

Consequence: by the time the mod loads, the game's classes and `PluginManager` already exist.

### What that costs on the very first run

Four games (Africanvs, Realidea, Reminiscencia and the English build of Pokemon Z) call `pbSetUpSystem` at
top level, two thirds of the way down their script list, and with no save yet that call stops there to ask
which language to play in. The mod is not loaded yet, so that list is not read.

It is deliberate. Loading earlier means loading with the rest of the list unread: measured on Pokemon Z
2.13, the prompt appears in script 152 of 235 and **eleven hooked classes do not exist yet**, the pause
menu among them -- silent for the rest of the session, which is how the bug was reported. A screen of two
or three options, once per install and undoable from the mod's own options, was traded for a pause menu
that always speaks.

For the player: on that first screen, press Enter to take the default; the mod's language is changed
afterwards from its configuration menu.

## Load order

```
loader/boot.rb
  1. core/manifest.rb           ordered module list, no .rb
  2. declared plugins/          the ones the profile names, or :auto
  3. games/<profile>/manifest.rb
```

All three manifests are Ruby literals; `read_manifest` evaluates them, because RGSS ships no JSON parser.

Profile manifest format, two accepted shapes:

```ruby
%w[module_a module_b]                                    # modules only

{ :modules => %w[module_a], :plugins => %w[tip_cards] }  # modules + declared plugins
{ :modules => %w[module_a], :plugins => :auto }          # the generic profile only
```

A module missing from the manifest **is not loaded** and nothing warns. A declared plugin that does not
exist is logged and skipped: a half-finished install costs one screen, not the whole mod.

## Where things are

| You need | File | Document |
|---|---|---|
| To hook a game method | `core/input/hooks.rb` | [03-hooks](03-hooks.md) |
| To speak text | `core/speech/speech.rb` | [04-readers](04-readers.md) |
| To read data without knowing the era | `core/data/data.rb` | [04-readers](04-readers.md) |
| To know which engine is running | `core/foundation/engine.rb` | [02-engines](02-engines.md) |
| Defensive introspection | `core/foundation/const.rb` | [08-reference](08-reference.md) |
| To avoid repeated reads | `core/menus/cursor.rb` | [04-readers](04-readers.md) |
| Spoken text | the six `lang/*.txt` | [05-extending](05-extending.md) |
| Routes and sonar | `core/nav/`, `core/audio/` | [06-navigation](06-navigation.md) |
| To diagnose a failure | `core/input/diag.rb` | [07-diagnostics](07-diagnostics.md) |

## Invariants

1. **Accessibility wins.** When in doubt, speak too much rather than stay silent.
2. **Nothing breaks the game.** Every reader runs under `rescue`; a failure costs one unspoken line, not
   the frame.
3. **Gate on capability, never on version.** See [02-engines](02-engines.md).
4. **Spoken text lives in `lang/`.** Exception: the `games/` profiles, which cover Spanish-only fangames
   and may carry literals.
5. **Ruby 1.8.7 in `core/`.** A static check enforces it.

## Tests

```bash
ruby test/run_all.rb                    # both engines + static checks
ruby test/run_all.rb behavior/battle    # filter by path fragment
```

The static checks cover manifest integrity, key parity across the six `lang/` files, Ruby 1.8.7
compatibility, cross-layer coupling, `plugins/` consistency, and two censuses built from the decompiled
games: the arity and parameter names of every hooked method (loops included) and the era coverage of every
Essentials API name the shared core calls.

## Installing

At the end of a change, not halfway through:

```bash
powershell -File installer/install.ps1 -Force
```

Reinstalling on top updates in place and keeps `settings.ini` and the tags.
