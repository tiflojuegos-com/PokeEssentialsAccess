# Static checks

This page lists every check under `test/static/`, what it guards, and every [census](glossary.md) those checks read,
with the script that builds it and its sources. Read it when a static check fails or after adding a
[script dump](glossary.md), a [reference copy](glossary.md) or a test file.
[Run and write tests](../guides/tests.md) runs the suite and regenerates the censuses.

## How the checks run

- The checks are the `*_test.rb` files of `test/static/`. None ends in `_gd_test.rb`, so the gen-6 pass runs them all.
- A path filter runs them only when a fragment matches their path: `ruby test/run_all.rb static`.
- The census checks read the committed `.txt` files, so they run without the script dumps.
- `manifest_check_test.rb`, `ruby187_test.rb`, `profile_load_test.rb`, `preload_trigger_test.rb` and
  `uranium_compat_test.rb` start processes of their own.
- `ruby187_test.rb` runs `python`, which must be on the path. `match_globals_test.rb` and `rescue_reports_test.rb`
  parse with the `prism` library.

## Runner checks

`test/run.rb` also checks the pass as a whole:

- Before the tests, the gen-6 pass compares the test files on disk with `test/static/test_census.txt`. A difference
  stops the pass and names up to ten files each way.
- After the tests, each of these fails the pass: a text that reached `PokeAccess.speak` with raw control codes (the
  reader should call `speak_clean`), a one-parameter block of the mod handed several values (`ArityNet`), and a test
  file that failed to load.
- With `PA_SWALLOWED` set, the pass also lists the failures the mod's rescues swallowed (`PokeAccess.swallowed_sites`).
  The list fails nothing.

## Layers, manifests and profiles

- `manifest_check_test.rb`: runs `test/static/manifest_check.rb`, which also runs alone. Every `.rb` of `core/` and of
  each profile is listed once in its manifest, and every entry has its file. `games/catalog.json` has one entry per
  profile folder, shared profiles aside; each entry has an `engine` of `gen6`, `gamedata` or `any`, at least one
  identity layer (`titles`, `detect` or `exes`) except the generic profile, valid `compat` and `convert` entries, and
  detection that resolves its own titles to itself. No exe is claimed twice.
- `catalog_detect_test.rb`: detection as the launcher matches it, by the longest declared title, else by the longest
  `detect` match on folder and exe. `pokemon_z` takes Z's folders and never a `Z:` drive or `mkxp-z`; the two
  Soulstones games stay apart; every unaccented "pokemon" title has its accented twin.
- `imports_test.rb`: every `:imports` names a [shared profile](glossary.md) with a manifest. A shared profile has no
  catalog entry, imports no other and is imported by some playable profile. No file is copied between two playable
  profiles; files are compared with each one's profile name blanked out.
- `coupling_test.rb`: no constant crosses layers. An era folder names nothing another era folder defines, shared core
  names nothing an era folder defines, a profile names nothing another profile defines (a shared profile it imports
  aside), plugins name no profile, and no other file names what a plugin defines. No profile reopens a core module but
  `Config`. No core file names a class that one surveyed fangame alone defines (`fangame_classes.txt`). Allow tables:
  `ALLOWED_CROSSINGS` and `SINGLE_GAME_NAMES`, both empty.
- `plugins_test.rb`: the detection table, `plugins/manifest.rb`, and the files of `plugins/` match one to one, each
  entry with a [probe](glossary.md). Every plugin a profile declares exists. Some profile declares every plugin file,
  or the file is a reader only the generic profile loads, whose probe no surveyed game ships and a reference copy
  defines. Every hook in `plugins/` is `:optional`, and no two readers claim one `Class#method`. Each profile declares
  the plugins its game ships (`plugin_census.txt`), save one its game ships in an edited copy that the profile reads
  itself, listed in `OWN_COPIES` (Revival's Modular Menu), which counts as declared. Such a profile does not load the
  plugin's reader too.
- `profile_load_test.rb`: every profile, and every shared profile on its own, loads whole as the loader loads it, in a
  Ruby process of its own under each engine's stubs. A misspelt DSL method shows only when its `define` block runs.
- `profile_names_test.rb`: the first `define` a profile's modules run, through `Game.define` or a core wrapper of it
  (`NAMERS`), names the profile's folder. Every `define` of a shared profile names the shared profile.
- `parse_all_test.rb`: every `.rb` under `core/`, `games/`, `plugins/`, `loader/` and `tools/` parses. A pass loads
  one profile only, so this is the check that reaches the rest.

## Hooks against the games

- `hooked_classes_test.rb`: every class the mod hooks by a string name exists in some surveyed source
  (`all_classes.txt`) or in a reference copy (`reference_census.txt`). Every census in `CENSUSES` states, in its
  header, the number of surveyed sources in `SOURCES`.
- `arity_test.rb`: every `args[N]` a hook body reads is an argument that each surveyed game passes that method
  (`arity_census.txt`). A body bound to several classes reads one meaning per position. Allow tables: `ALLOW` and
  `MEANING_ALLOW`, each entry with its reason; an entry the scan does not find fails.
- `blocking_hooks_test.rb`: no `after_hook` binds to a method that is the screen's own blocking loop in a game its
  reader runs in (`loop_census.txt`); such a hook speaks only when the player leaves. A hook whose line carries
  `# blocks-on-purpose`, a `read_on_open` with `:timing => :before` and a [container](glossary.md) are left out. Allow
  table: `KNOWN_NO_DUMP`, the hooks no script dump can confirm.
- `ivars_test.rb`: every instance variable a reader takes off a game object exists in a game that reader runs in
  (`ivar_census.txt`). A plugin reader only the generic profile loads may take one a reference copy uses. Lists:
  `SELF_INTROSPECTION` (the diagnostic dump and the session recorder) and `UNSURVEYED`.
- `info_window_lifecycle_test.rb`: each scene `PokeAccess::InfoWindow` watches declares a lifecycle that meets one its
  games define (`lifecycle_census.txt`). A watch whose lifecycle meets none is never entered.
- `era_calls_test.rb`: each `pb*` name that shared core calls and some surveyed source lacks (`era_census.txt`) has an
  entry in `KNOWN`, which says whether the call is a ladder, a guarded call or an optional wrap
  ([Era folders](../architecture/engine-eras.md#era-folders)). An entry for a name the census does not list fails
  too.
- `field_moves_test.rb`: the field-move rules of each game's profile hold against the game's scripts
  (`field_move_census.txt`). Each function a game clears an obstacle or crosses water with asks for its stock move
  (`STOCK`), is wrapped, or has its move ruled by the profile; each item, move and switch it reads is one the profile
  names. Every game with its own profile is in the census.

## Ruby compatibility

- `ruby187_test.rb`: `test/check187.py` passes on the tree with `OK` or `PARCIAL`, and flags each planted shape by
  line and rule. `test/check187_real.rb` parses each file without running it, leaves out the modern games' folders,
  and fails on a file that does not compile or a `core/manifest.rb` entry it never parsed.
- `block_arity_test.rb`: no call in the mod to a method of the mod that yields two or more values passes a block with
  one plain parameter; `|(a, b)|` is fine. The names Ruby's own collections yield by (`STD`) are left out.
- `match_globals_test.rb`: inside a `gsub`, `sub` or `scan` block, every match global (`$~`, `$1` to `$9`, `$&`) is read
  before the block calls anything that matches a regex. Ruby 1.8.7 resets them at that call.
- `mts_mutator_guard_test.rb`: no file that loads under Pokémon Z adds or subtracts arrays in the shapes the MTS turns
  into in-place changes, such as `CONST + extra`. Its `MODERN` list equals the lists of `check187.py` and
  `check187_real.rb`, and the catalog's `gamedata` profiles with the shared profiles only they import. Allow table:
  `ALLOW`.
- `game_overrides_test.rb`: no code line of `core/`, `games/`, `plugins/` or `loader/` calls `has_key?`, `Hash[]`,
  `merge`, `first(n)`, `last(n)` or `capitalize`, which some games redefine (`BANNED` gives the safe spelling).
- `shadowed_names_test.rb`: inside `module PokeAccess`, an unqualified name the games also define, such as `Settings`,
  `Battle` or `Events`, names something the mod's module of that name has. The game's module needs `::`
  (`all_classes.txt`).

## Failures and state

- `rescue_reports_test.rb`: every rescue that catches `StandardError` or `Exception` reports what it caught
  (`swallowed`, `log_once`, `write_marker` or the data layer's `note_error`) or raises it again. One-line `x rescue y`
  probes are out, and so are the `EXEMPT` files.
- `silent_io_test.rb`: a method of more than one line in `core/`, `games/` or `plugins/` that touches a file and rescues
  at its own level leaves a trace in its rescue: a log line, a swallowed record, a marker, a speak or a raise. Allow
  table: `ALLOWED`, the two marker writers.
- `dedup_test.rb`: change detection state that outlives a screen has a reset path, so the second visit to the screen
  speaks. A module `@last*`, `@prev*` or `@seen*` variable a speaking file guards on is set to `nil` in some method, and
  a slot of the `PokeAccess::Cursor` table has its reset unless its key changes by itself. Every `speak_changed` tag
  has its `UIV21.reset`. Allow tables: `ALLOW` and `SELF_SCOPED`, the slots whose holder lives and dies with its screen.
- `dead_code_test.rb`: every module method (`def self.x`) of `core/`, `games/`, `plugins/` and `loader/` is named
  somewhere besides its definition, in the mod or in the tests. `DYNAMIC` lists the names Ruby calls by itself.
- `inline_comments_test.rb`: no full-line comment sits inside a `def` or a hook block in `core/`, `games/`,
  `plugins/`, `loader/` or `tools/`.

## Spoken text

- `i18n_parity_test.rb`: every file of `lang/` has every key, none twice, with the same `%{var}` placeholders and the
  plural forms its language's rule asks for. The French file addresses the player with tu.
- `i18n_refs_test.rb`: every key the code references exists in `lang/en.txt`: `I18n.t(:key)` and `t(:key)` calls,
  row labels and helps, reading declarations, the keys a profile gives the battle name tables, and the tables whose
  symbols reach `I18n.t`.

## Tools and boot scripts

- `dump_scripts_test.rb`: `tools/dump_scripts.rb` over synthetic game folders in each format: `Scripts.rxdata`,
  `PluginScripts.rxdata`, a loose script tree and a `Game.rgssad` archive.
- `preload_trigger_test.rb`: `loader/preload_access.rb` in a Ruby process of its own over a made-up game folder. It
  marks that it ran, loads the mod once on the first frame the game is ready for it, once Main's `pbCallTitle` exists,
  notes a stall once, and keeps the mod's failures from ending the game.
- `uranium_compat_test.rb`: `games/uranium/compat.rb` in a Ruby process of its own, against stand-ins of what mkxp-z
  and Uranium's scripts give it.

## Censuses

The censuses are generated files under `test/static/`. Each states its builder and format in its header; none is
edited by hand.

- `all_classes.txt`: every class or module name a surveyed source defines, with how many define it. Built by
  `build_fangame_census.rb`; read by `hooked_classes_test.rb` and `shadowed_names_test.rb`.
- `arity_census.txt`: for each hooked method, the fewest and most parameters the games declare and their distinct
  signatures. Built by `build_arity_census.rb`; read by `arity_test.rb`.
- `era_census.txt`: the `pb*` names shared core calls that some source lacks, with the sources that define each.
  Built by `build_era_census.rb`; read by `era_calls_test.rb`.
- `fangame_classes.txt`: the class names one source alone defines, with its game and whether a plugin or the game's
  own scripts define it. Built by `build_fangame_census.rb`; read by `coupling_test.rb`.
- `plugin_census.txt`: the classes that give each plugin away, with the profiles whose games ship them. Built by
  `build_fangame_census.rb`; read by `plugins_test.rb`.
- `field_move_census.txt`: each definition of the functions games clear obstacles and cross water with, with its
  place, its guard, the calls it makes and the names it reads. Built by `build_field_move_census.rb`; read by
  `field_moves_test.rb`.
- `ivar_census.txt`: each instance variable readers take off a game object, with the profiles whose game has it.
  Built by `build_reader_census.rb`; read by `ivars_test.rb`.
- `loop_census.txt`: each `Class#method` with an `after_hook`, with the profiles where that method is the screen's
  blocking loop. Built by `build_reader_census.rb`; read by `blocking_hooks_test.rb` and
  `test/behavior/menus/plugins_smoke_test.rb`.
- `lifecycle_census.txt`: for each scene `InfoWindow` watches, the lifecycle methods the mod declares and those the
  games define. Built by `build_reader_census.rb`; read by `info_window_lifecycle_test.rb`.
- `test_census.txt`: every test file `test/run.rb` must find. Built by `build_reader_census.rb`; read by
  `test/run.rb`.
- `reference_census.txt`: the classes, `Class#method` names and instance variables each reference copy defines. Built
  by `build_reference_census.rb`; read by `hooked_classes_test.rb`, `ivars_test.rb` and `plugins_test.rb`.

## Census sources

- Script dumps: one folder per game under `../../decompiled Scripts`, holding the game's scripts as `.rb` files. A
  builder's first argument or `PA_DUMPS` names another folder. A script dump's folder takes its profile's name;
  `ReaderSites::PROFILE_OF` maps the folders named otherwise. `tools/dump_scripts.rb "<game folder>" [out_dir]` makes
  a script dump.
- The vanilla Essentials scripts, at `../../pokemon-essentials/Data/Scripts` or `PA_VANILLA`. The arity, era, fangame
  and reader builders survey them as one more source, `vanilla`, when the folder exists.
- Reference copies: third-party plugins no surveyed game ships, under `../../../repositorios genericos/_refmods`, in its
  `pokeliberty`, `FL-essentials` and `eeveeexpo` collections. `build_reference_census.rb` takes another folder as its
  first argument or `PA_REFERENCE`.

Each census built from the script dumps gives the count of its surveyed sources in its header, as
`surveyed sources (N)`, `surveyed games (N)` or `surveyed profiles (N)`. `hooked_classes_test.rb` and
`era_calls_test.rb` compare that number with their `SOURCES` constant, so a new source changes both constants.

## Builders

- `ruby test/static/build_census.rb ["path\to\decompiled Scripts"]` runs `build_arity_census.rb`,
  `build_era_census.rb`, `build_fangame_census.rb`, `build_field_move_census.rb` and `build_reader_census.rb` with the
  argument, then `build_reference_census.rb` with its default folder. It prints `every census regenerated` or the
  builders that failed, and exits non-zero on a failure.
- Each builder also runs alone, with its own folder as its first argument.
- `build_reader_census.rb` writes `test_census.txt` after the censuses it builds from the script dumps. The test
  census reads no script dump, but the script stops with `dumps folder not found` before writing anything when the
  script dumps are missing.
- A maintainer runs the builders by hand after adding or refreshing a script dump or a reference copy, after adding
  a test file, and after adding a reader or a profile.
