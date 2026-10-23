# Engine eras

This page explains how one copy of the mod runs on Essentials versions with different APIs: the engine eras and their
detection, the capabilities readers gate on, the class names that change between versions, the engine of Reborn and
its shared profile, and the Ruby constraints the code follows. Read it before writing a reader meant for more than one
game.

## Eras

Each fangame starts from one Essentials version and keeps its API, so the mod meets every version at once. An
[engine era](../reference/glossary.md) is a family of versions the mod treats alike.

| Era | Essentials versions | Data | Battle scene |
|---|---|---|---|
| gen-6 | v16 and v17 | `PB*` tables | `PokeBattle_Scene` |
| GameData | v18 | `GameData::*` | `PokeBattle_Scene` |
| GameData | v19 to v21.1 | `GameData::*` | `Battle::Scene` |
| GameData with the v22 interface | v22 | `GameData::*` | `Battle::Scene` |

The Sky fork puts the v22 interface, `UI::BaseScreen` and the `UI::*Visuals` classes, on a v21.1 base. Añil and Royal
run it: they define `Essentials::VERSION` as `"21.1"` and `UI::BaseScreen` (Añil's `297_UI_base.rb`). Their screens
take the v22 readers and their battles the v21 one.

`Engine.kind` tells only two eras apart, `:gen6` and `:gamedata`. Every finer distinction is a capability.

## Detection

`core/foundation/engine.rb` answers what the running engine is:

- `Engine.gamedata?` is true when `GameData::Species` is defined. `Engine.gen6?` is its negation.
- `Engine.version` is the Essentials version as a Float. It reads `Essentials::VERSION` or `ESSENTIALS_VERSION`.
  Without either, a GameData game reads 19.0 with `Battle::Scene` and 18.0 without it, and a gen-6 game reads its
  `ESSENTIALSVERSION` (17.0 when that parses below 1) or 16.0.
- `Engine.fork` is `:sky` on GameData with a version below 21.9 and `UI::BaseScreen` defined, and `nil` otherwise.
- `Engine.player` is `$player`, or `$Trainer` where `$player` is not set.

The version serves the diagnostic dump, the header of a session recording and the fork test; readers never compare
it. The mod loads after the game's
scripts ([Loading](loading.md)), so these tests see every class the game defines.

### Data providers

`PokeAccess::Data` turns an id into a name or a field through a provider. Each provider registers only where its tables
exist, and the one with the highest priority serves:

- `DataV21` (`core/data/v21/data_v21.rb`), priority 20, where `GameData::Move` exists.
- `DataRV` (`games/rv_common/data_rv.rb`), priority 15, on the Reborn engine.
- `DataG6` (`core/data/gen6/data_g6.rb`), priority 10, where `PBMoves` exists and `GameData` does not.
- `DataFallback` (`core/data/data_fallback.rb`), priority 0, always; it answers most names with the raw id.

`DataG6` does not register where `GameData` exists, so a game that ships `PB*` shims beside GameData resolves
through `DataV21`. When only the fallback serves, the boot logs it to `loader_error.txt`. A provider that raises
answers `nil`, and its first error per method and exception class goes to the marker file. `Data.optional` asks for a
datum only some providers give, such as `:map_infos`, and answers `nil` where the active provider lacks it.

## Capabilities

Readers gate on what the engine has, never on a version number. A fork can carry a feature of a later version, as the
Sky fork carries the v22 interface, and a version test would miss it. `Engine.has?` takes three shapes:

- A registered symbol, looked up in `Engine::CAPABILITIES`.
- A constant name such as `"UI::PokemonSummaryVisuals"`, true when every segment resolves (`PokeAccess.const_at`).
- `"Class#method"`, such as `"FightMenuDisplay#setIndex"`, true when the class has that instance method, public or
  private.

Any exception answers false. An unregistered symbol answers false too, and is logged once: a misspelt symbol would
otherwise silence its readers without a trace.

The registered symbols are `:gamedata`, `:gen6` and `:sky_fork` for the era and the fork, `:ui_rework` for
`UI::BaseScreen`, and `:battle_scene` for `Battle::Scene`. `:dbk` (Deluxe Battle Kit) and `:mui` (Modular UI Scenes)
name third-party plugins; the diagnostic dump lists them, and they gate nothing. Readers pass a class name or
`Class#method` directly, as `core/menus/v22/screen_v22.rb` does with `"UI::BaseScreen"`. The engine line of the
diagnostic dump walks `CAPABILITIES` and prints the ones that hold (`core/input/diag.rb`), and the boot matches the
plugin [probes](../reference/glossary.md) of `plugins/manifest.rb` with `has?` (`loader/boot.rb`).

## Era folders

`core/<area>/` holds the code every era shares. Its subfolders hold the parts of one era:

- `gen6/`: gen-6 screens, `PokeBattle_Scene` and the `PB*` data.
- `v21/`: the GameData screens of v19 to v21.1, before the interface rework.
- `v22/`: the `UI::` interface of v22.

The folders do not decide what loads. `core/manifest.rb` lists every core file, and the boot evaluates all of them in
every game. A hook in an era file binds nothing where its class is absent ([Hooks](hooks.md)); code that does more
than hook checks `has?` first. Because every core file loads in every game, the `v21/` and `v22/` files follow the
Ruby 1.8.7 rules too.

`coupling_test.rb` keeps the folders apart: no era folder names a constant another defines, and shared core names none
of theirs.

Shared core still calls Essentials functions by name. `era_census.txt` lists each `pb*` name that shared core calls
and some surveyed source lacks, and `era_calls_test.rb` requires an entry in its `KNOWN` table for each, saying which
safe shape the call takes:

- A ladder tries one era's spelling and falls back to the other's. `Engine.bag_quantity` asks the bag for `quantity`,
  then for `pbQuantity`.
- A guarded call reaches the function only where the game has it, and the absence is the right answer elsewhere.
- An optional wrap binds a function only some games ship, and binds nothing where the name is absent.

The checks are listed in the [static checks reference](../reference/static-checks.md).

## Class names across versions

Class names change with the Essentials version, inside one era too. Pokémon Z names its summary
`PokemonSummaryScene`, the v16 name (`134_PScreen_Summary.rb`). Soulstones, also a gen-6 game, names it
`PokemonSummary_Scene`, the v17 name, as GameData games such as Relict do. Some games define one name as an empty
subclass of the other, so scripts written for either keep working; Africanus does it in
`0187_BES-T_Compatibility.rb`. A reader therefore asks the era and resolves the name separately:

- `Engine.scene_classes(*names)` gives the names that exist, leaving out a subclass of another listed class and a
  second name for the same class. A reader that serves every era hooks each.
- `Engine.scene_class(*names)` gives the first of those, for aliases of one screen.
- `Engine.era_scene(era, own, other)` gives the name a reader written for one era binds, or `""`, which binds nothing.

`era_scene` decides as follows:

- A GameData reader gets `""` on gen-6.
- Where `own` is absent, a gen-6 reader running on gen-6 takes `other` if it exists. Any other reader gets `""`.
- Where only `own` exists, the reader takes it.
- Where both exist, the reader of the running era takes the one `scene_class` picks, and the other era's reader gets
  `""`.

```ruby
# core/party/gen6/summary_g6.rb
SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")
# core/party/v21/summary_v21.rb
SCENE = PokeAccess::Engine.era_scene(:gamedata, "PokemonSummary_Scene", "PokemonSummaryScene")
```

With these two lines, Z and Soulstones bind the gen-6 reader under their own names, Relict binds the GameData reader,
and no game binds both.

One method can also take its arguments in a different order. `pbLevelUp` passes the old stats as HP, Attack, Defense,
Speed, Sp. Atk and Sp. Def in v16 and v17, as in Z's `087_PokeBattle_Scene.rb`. The GameData games that keep
`PokeBattle_Scene` pass Speed last, as in Fire Ash's `212_Scene_Animations.rb`. The gen-6 battle reader binds in both
and picks the order by `Engine.gamedata?` (`Battle.levelup_from_args`). Accessor names change between versions in the
same way; `PokeAccess.attr_of` tries several ([Hooks](hooks.md#failures)).

## The Reborn engine

Reborn, Rejuvenation and Desolation share an engine of the gen-6 lineage. It runs Ruby 3.1 and keeps its data in a
`$cache` of objects keyed by symbol. It has no `GameData`, so `Engine.kind` is `:gen6`, and the catalog lists the
three games as `gen6`.

What this engine does its own way lives in the [shared profile](../reference/glossary.md) `games/rv_common/`, which
the manifests of the three games import (`:imports => %w[rv_common]`). It loads after core and the plugin readers and
before each game's own modules ([Loading](loading.md)). Its first module, `games/rv_common/data_rv.rb`, registers
`DataRV` when `$cache` answers the species, move and ability tables and `GameData` is absent. `DataRV` takes names
from the game's own helpers, such as `getMoveName`, which go through the game's translations where it has them.

Core names no constant of `rv_common`, as of any profile (`coupling_test.rb`). The two meet through seams core leaves
open:

- Data only some providers give. Core asks `Data.optional(:map_infos)`, `Data.optional(:common_events)` and similar,
  and `DataRV` answers them.
- Replaced methods. A module of `rv_common` replaces a core method with `Hooks.override`, as
  `games/rv_common/time_weather_rv.rb` does with `PokeAccess::Battle.clock_text`.

Tests load the shared profile with `Harness.load_common("rv_common")` and put a provider in place for one block with
`Harness.with_provider` ([Tests](../guides/tests.md)).

## Ruby versions

The gen-6 games run Ruby 1.8.7 inside mkxp-z, except the Reborn engine, which runs Ruby 3.1. The GameData games run
Ruby 3. Code that a 1.8.7 game can load must parse and behave alike under 1.8.7:

- Every file under `core/`, since the boot loads every core file in every game.
- Every file under `loader/`.
- Every file under `plugins/`, since a plugin can be installed in a gen-6 game.
- Every profile, except the ones the catalog lists as `gamedata` and the shared profiles only those import. The
  `MODERN` lists of `test/check187.py` and `test/check187_real.rb` name them, and `mts_mutator_guard_test.rb` checks
  both lists against the catalog. The profiles of the Reborn engine are checked, since the catalog lists them as
  `gen6`.

A file that 1.8.7 cannot parse raises `SyntaxError` as it loads. The boot logs the error to `loader_error.txt` and the
mod runs without that file.

### What 1.8.7 rejects

- Syntax of later versions: `key: value` hash keys, keyword arguments, `->` lambdas, `&.`, `%i[]` and `<<~`
  heredocs.
- A `rescue` owned by a `do` or brace block. In 1.8.7 only `begin`, `def`, `class` and `module` own one.
- A method chain whose line starts with the dot.
- Library methods added later, such as `sum`, `dig`, `clamp`, `each_with_object`, `flat_map`, `to_h`,
  `define_singleton_method` and `File.write`, and the argument of `round`, `ceil` and `floor`.

`test/check187.py` holds the full list. Each of its rules carries a line it must flag and a 1.8.7-safe line it must
not, and the script checks them before it sweeps.

### What 1.8.7 runs differently

Some code parses in both Rubies and behaves differently in 1.8.7:

- A Hash keeps no insertion order. Code that needs an order keeps an Array (`core/foundation/caches.rb`).
- `"".to_sym` raises (`core/foundation/i18n.rb`).
- Every object answers `id`, so `respond_to?(:id)` is true for all of them (`core/nav/locator.rb`).
- `s[0]` gives a character code, not a one-character string.
- `Hash#select` returns an Array of pairs.
- A block with one parameter receives every yielded value as one Array, where Ruby 3 passes the first.
  `block_arity_test.rb` checks the calls, and the suite's arity net checks blocks kept and called later
  (`test/support/arity_net.rb`).
- A call that matches a regex inside a `gsub`, `sub` or `scan` block resets the match globals of the block, so a
  capture read after that call is `nil` (`match_globals_test.rb`).
- `const_defined?` rejects a name with `::`, so `PokeAccess.const_at` resolves `"A::B::C"` one segment at a time.

The Ruby 3 games have constraints of their own. A wrapper marks its `*args` with `ruby2_keywords`, so keyword arguments
reach the game's method as keywords (`Hooks.pass_keywords`). A module prepended to a game class changes how a hook keeps
the original method ([Hooks](hooks.md)).

### The checkers

`test/check187.py` sweeps the files for the shapes above. When the sweep finds none, it runs `test/check187_real.rb`
under a real 1.8.7 interpreter, found through `RUBY187` or at `../tools/ruby-1.8.7-*/bin/ruby.exe` beside the
repository; that script parses every file without running it. Without an interpreter, the sweep reports `PARCIAL` and
passes. The suite runs both through `ruby187_test.rb`.

## Core methods games redefine

Some games' utility scripts redefine methods of Ruby's own classes, and in those games the mod's code runs on top of
the redefinitions. The mod avoids those methods everywhere:

- Luka's Scripting Utilities make `Hash#has_key?` false for a `nil` or `false` value (Añil, Royal, Relict). The mod
  calls `key?`.
- Marin's give `Array` a `to_hash` by index, which `Hash[pairs]` then reads (Añil, Awakening, Relict, the MTS of Z).
  The mod builds each hash by hand.
- Armonía's `merge` writes into the receiver, and its `Array#first` and `Array#last` take an index and answer a
  boolean; Africanus' and Awakening's take no count. The mod writes `dup.merge!` and slices with `[]`.
- Several games' `String#capitalize` keeps the rest of the word as it is and fails on an empty string. The mod calls
  `PokeAccess::Util.capitalized`.

`game_overrides_test.rb` rejects those calls in `core/`, `games/`, `plugins/` and `loader/`.

The MTS of Pokémon Z redefines `Array#+` and `Array#-` as in-place mutators that return the receiver, so
`CONST + extra` changes the constant for the rest of the session. `mts_mutator_guard_test.rb` sweeps every file that
loads under Z for those shapes.

`ruby tools/game_overrides.rb <scripts folder>` lists the core methods a game's scripts redefine. With `--run`, it runs
the suite with the redefinitions applied to the mod's own calls.
