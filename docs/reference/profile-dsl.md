# Profile DSL

This page lists what a [profile](glossary.md) declares: the keys of `games/<profile>/manifest.rb` and every method
its `PokeAccess::Game.define` blocks can call, with arguments and effect. [Loading](../architecture/loading.md)
explains how profiles load, and [Add a profile](../guides/add-a-game-profile.md) gives the steps to write one.

## Manifest keys

`games/<profile>/manifest.rb` evaluates to a Hash. `loader/boot.rb` also accepts a bare Array, read as `:modules`.

| Key | Value | Effect |
|---|---|---|
| `:modules` | `%w[...]` of file names without `.rb` | The profile's files, evaluated in this order |
| `:plugins` | `%w[...]` of reader names, or `:auto` | The [plugin readers](glossary.md) the profile loads |
| `:imports` | `%w[...]` of `<name>_common` folders | The [shared profiles](glossary.md) the profile loads |

- The loader evaluates core, then the plugin readers that the profile and its shared profiles declare, then each
  shared profile's modules in `:imports` order, then the profile's own.
- `:auto` loads each reader whose [probe](glossary.md) the running game has. Only `games/generic/manifest.rb` uses it.
- A module, plugin reader or shared profile the manifest names and the disk lacks is logged to the game's
  `accessibility/data/loader_error.txt` and skipped.
- The launcher finds the shared profiles to install by reading `:imports` as a `%w[...]` literal of names that end
  in `_common`. Written any other way, the profile loads without them.
- `test/static/manifest_check.rb` requires every `.rb` file of the folder in `:modules` exactly once, each entry
  with its file. The `compat` script a catalog entry names is the exception.

```ruby
# games/reborn/manifest.rb (shortened)
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    own_voice
    fight_menu
  ],
  :plugins => %w[fl_roulette]
}
```

## Game.define

`PokeAccess::Game.define(name = nil) { ... }` runs its block on a `PokeAccess::Game::Definition`, whose methods are
listed below. Each method forwards to one registration call of the toolkit, named in the tables. A profile may call
`Game.define` in any number of files; every block adds registrations.

- The first name given that does not end in `_common` is the profile's name, `Game.profile_name`. With none, the name
  is the `profile` of the game's `installed.json`, and `generic` becomes `generic:<game title>`.
- The name stamps the player's tag, mark and map-name files as `# game: <name>`. An import stamped with another
  game's name is refused (`core/foundation/dictionary.rb`).
- An `override` carries the name in `Hooks.overrides`, as `game_<name>`. A `kernel` wrapper that cannot be installed
  is written to the marker file under `game_<name>_<function>`.
- `test/static/profile_names_test.rb` requires the first define in a profile's load order to name the profile's
  folder, and every define in a shared profile to name the shared profile.
- Two core helpers call `Game.define` with the name they receive: `PokeAccess::SpriteButtonMenu.define(game, bare = [])`
  binds the reader of a sprite-button pause menu, and `PokeAccess::LocationBanner.define(game)` the reader of the
  JessLetreros zone banners.

```ruby
# games/opalo/constants.rb
PokeAccess::Game.define("opalo") do
  key_hints "Z" => :a, "X" => :b, "C" => :c, "D" => :z
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }
end
```

## Settings and names

| Method | Arguments | Effect |
|---|---|---|
| `config(key, value)` | a `Config` key and its value | Assigns `Config.<key>` |
| `button_labels(map)` | button => i18n key | Names the game's buttons on the remap screen |
| `key_hints(map)` | painted letter => action | Says each letter of the game's hints as the action's key now |
| `names(table, map)` | table name; id => i18n key or literal | Adds the game's ids to a core name table |
| `trainer_part(key)` | part name; block | Defines or replaces a part of the trainer line |
| `trainer_order(keys)` | part names | Sets the parts of the trainer line and their order |
| `remap_extra(sym, default_vk, label)` | action, virtual-key code, i18n key | A raw-key action on the remap screen |

- `config` assigns the value directly, without the `:config_changed` event. For a menu setting it is the game's
  default: the boot applies `settings.ini` afterwards, and a value stored there replaces it. Two keys outside the
  menu are set by profiles: `money_label`, the i18n key of the money amount (`:tr_money` by default), and
  `gender_numbers`, option number => label key for a gender choice drawn in pictures. The menu settings are in
  [Settings](settings.md).
- `key_hints` fills `Config.key_hint_letters`. An action is a button such as `:a` or `:z`, or an action a profile
  registers with `remap_extra`. `PokeAccess::KeyHints::RGSS_LETTERS` holds RPG Maker XP's default letters. Only
  letters checked against the code that reads the key belong in the map; only the key token of a hint changes.
- `names` takes `:status_names`, `:weather_names` or `:field_weather_names`. A literal string serves a game in
  Spanish only.
- `trainer_part` takes a block given the player object, answering a fragment or nil. A new name joins the end of the
  order. Core's parts are `:name`, `:money`, `:badges`, `:pokedex` and `:playtime`; the info key on the map and the
  trainer card say them joined, each part that answers.
- `trainer_order` leaves out of the line every part it does not list.
- `remap_extra` registering a symbol again replaces its row. The remap screen lists the extras after the game's
  buttons ([Keys](keys.md)).

## Hooks

| Method | Forwards to | Block gets |
|---|---|---|
| `after(cname, meth, opts = {})` | `Hooks.after_hook` | instance, result, args |
| `before(cname, meth, opts = {})` | `Hooks.before_hook` | instance, args |
| `around(cname, meth, opts = {})` | `Hooks.around_hook` | instance, the next call, args |
| `read_on_open(cname, meth = :pbStartScene, opts = {})` | `Hooks.read_on_open` | the scene; answers the text |
| `override(target, meth)` | `Hooks.override`, tagged `game_<name>` | receiver, original, args |
| `kernel(fname, timing = :before)` | `Hooks.wrap_kernel` | args and result; args and the next call for `:around` |

The options, timings and failure behavior of each registrar are in the [hooks API reference](hooks-api.md).

- `around` bodies call the next call to run the game's method.
- `read_on_open` says the text queued; nil or an empty text says nothing.
- `override` through the DSL takes no options, so a target that does not resolve goes to `Hooks.missing`.
- `kernel` takes `:before`, `:after` or `:around`. A function found nowhere goes to `Hooks.fn_absent`.

## Readers

| Method | Forwards to | Block gets |
|---|---|---|
| `screen_reader(cname)` | `Menus.def_extractor` | window, index; answers the focused option |
| `focus_reader(cname, opts = {})` | `FocusReader.define` | entry, index, scene with `:items`, else index, scene |
| `info_window(cname, key, slot, opts = {})` | `InfoWindow.watch` | no block |
| `hall_of_fame(*cnames)` | `HallOfFame.bind` | no block |
| `poll_each_frame` | `Frame.each_pulse` | nothing |
| `diag_section(name, group = :scene)` | `Keys.register_diag_section` | the array of output lines |

- `screen_reader` reads the focused option of a command window class. Among the registered classes the window
  belongs to, the most derived wins, the first registered on a tie. A block that raises is logged once to the
  marker file, and the generic read takes over.
- `focus_reader` says the focused entry of a screen whose cursor is an index, each time the index moves. The first
  read is queued and later ones interrupt; a nil line says nothing. Its options are those of `FocusReader.define`
  ([Command windows and focus readers](reading-apis.md#command-windows-and-focus-readers)).
- `info_window` watches an [information window](glossary.md), a `@sprites` entry repainted with `text=`, and reads it
  when its text changes while the scene runs. `slot` is the window's dedup symbol, distinct per window of one scene.
  A class the game lacks registers nothing; the diagnostic dump lists a window never found. Its options are those of
  `InfoWindow.watch`, in the same section of the reading APIs.
- `hall_of_fame` binds the member panel, banner and trainer box readers (`writePokemonData`, `writeWelcome`,
  `writeTrainerData`) to each class given, for a game's own copies of the Hall of Fame; core binds the stock classes.
- `poll_each_frame` runs its block on every pulse, after every `Input.update`, in every scene, after the remap and
  the global keys. It serves a menu the game drives from a blocking loop of its own. A block that raises is logged
  once.
- `diag_section` adds a section to the full diagnostic dump and to one group of the Debugging screen: `:audio`,
  `:events`, `:perf`, `:map` or `:scene` ([Diagnostics](../architecture/diagnostics.md)).

## Pictures

| Method | Arguments | Effect |
|---|---|---|
| `picture_texts(map)` | picture file name => text | Says the text when the picture is shown |
| `picture_texts_multibuild(base, map)` | language; name => language => text | The build's text, else `base`'s |
| `on_picture` | block given the name and the show arguments | Runs on every picture shown |

A text is an i18n key or a literal. A picture shown again before it is erased is not said again. `picture_texts_multibuild`
serves a game released as one build per language: `base` is the pictures' own language, and the text is picked by
the build's language (`GameLang`), never the player's ([Speech and languages](../architecture/speech-and-languages.md)).

## Events in the locator

| Method | Arguments | Effect |
|---|---|---|
| `event_name` | block given the event; answers a name or nil | Names events before core does |
| `event_category(cat)` | category; block given the event | Files the events the block accepts under `cat` |
| `event_hidden` | block given the event | Leaves the events it accepts out of the locator and the sonar |
| `name_mark` | block given the target; answers words or nil | Words said after the name in the target line |
| `hazard(pattern, label)` | regexp on the sprite name, i18n key | Names the event, files it as an object, cues it |
| `teleporter(pattern)` | regexp on the sprite name | A transfer event wearing it is an exit, with the teleporter cue |
| `transfer_script(pattern)` | regexp whose first group is the map id | A script call that transfers the player |

- `event_name` rules run newest first, after the player's own label. `event_category` rules run newest first, and
  the player's own category still wins. `name_mark` words come in registration order, none twice.
- An `event_category` rule decides between `:people` and `:objects`, for an event with a sprite that does not
  transfer the player. The locator files exits, signs and extras by what the event does (`Locator.in_category?`).
- `transfer_script` serves doors that transfer the player by a script call instead of the Transfer Player command.

## Field moves

| Method | Arguments | Effect |
|---|---|---|
| `field_move_item(move, item)` | move, item | The item lets the player use the move with no Pokémon that knows it |
| `field_move_tool(move, items, only = false)` | move, item or list, `only` | The items, all in the bag, stand in |
| `field_moves_unnamed` | none | Obstacles are said without what clears them |
| `surf_company(kind)` | `:anyone` or `:dependents`; optional block | The check the game's own Surf makes for company |
| `field_gate(pattern, label, item)` | regexp on a script, label key, item | An obstacle the game's own item clears |
| `script_condition(pattern)` | regexp; block given the match, context | A script call the event conditions test |

- `field_move_tool` still asks for the move's badge. With `only`, the tools are the one way to use the move.
- `field_moves_unnamed` is the generic profile's one rule: nobody checked how an unknown game clears its obstacles.
- `surf_company(:anyone)` declares a Surf that asks nothing of who walks along. `:dependents` declares one that refuses
  while a dependent event follows the player, unless the block answers true.
- `script_condition` blocks answer the value the call returns, or `:unknown`.

## Terrain and passability

- `terrain_rule(owner = nil)`: terrain that moves the player once they arrive on it. The block gets x, y and the
  direction and answers the `[x, y]` the player ends on, `[x, y, presses]` for ground ridden across with the key held,
  false when the step cannot be taken, or nil off its terrain.
- `held_key_ground(owner = nil)`: tiles where the direction key has to stay held. The block gets x and y and answers
  true on such a tile.
- `terrain_exit(owner = nil)`: terrain the player leaves by a move of its own. The block gets x, y and the direction
  and answers the `[x, y]` the press lands on, false when it fails, or nil off its terrain.
- `assisted_step(owner = nil)`: an action that gets the player past what stops a walk, for the assisted route. The
  block gets x, y, the direction and the bridge level and answers a `Routes::Moves::Step` with its gate, or nil.
- `plain_passability`: the game's player passability reads nothing an event's end can change besides the map's tiles,
  tileset and events and the mode, checked against its scripts. The answers of the
  [passability probe](glossary.md) then outlive an event's end.
- `loose_pushes`: the game pushes its pushables after the plain `passable?` check, not the strict one.
- `pull_script(pattern)`: a script the game moves its pushables with that also lets the player pull them, the action
  button facing one.
- `push_script(pattern, move = nil)`: a script the game moves its pushables with, tried before the stock ones, and the
  field move it needs. A block, when given, is the condition the game moves them under, asked as a route is searched.

The `owner` of a terrain rule is a Hash of the tiles the rule answers for. Without one, the rule is asked on every
tile.

| Owner key | Takes in a tile by |
|---|---|
| `:tags` | its terrain tag number |
| `:kinds` | its terrain kind |
| `:flags` | a terrain flag |
| `:tiles` | a block given x and y, reading only the map's tiles and events |

A list may come as a block, read when asked. `assisted_step` takes the keys prefixed `front_`, for the tile in front.
An unknown key raises `ArgumentError`. State the game's passability reads beyond the map goes in with
`PokeAccess::World::Probe.mode_reader`, which profiles call directly
([World and routes](../architecture/world-and-routes.md)).

## Puzzles

`mechanic(kind, maps) { ... }` declares a puzzle of kind `:state`, `:grid` or `:facing` on one map id or a list of
them, the same declaration on each. A `:state` puzzle reads watched flags, phases and an info line, a `:grid` its
cells, and a `:facing` puzzle its turning statues ([Puzzles](../architecture/world-and-routes.md#puzzles)). The
block declares the puzzle with these verbs:

- `watch(opts)`: a watched flag, `:switch` or `:var`, with its `:label` and its `:on` and `:off` words.
- `controls`: the controls are the events whose page, fired by the player, writes a watched flag.
- `obstacle(pattern, opts = {})`: the events whose graphic matches block the way. With `:moving => true` the
  obstacle moves, sounds as a trap and stays out of the list. `:label` names the walls the pattern matches.
- `solved(say = nil, opts = {})`: the win. The block is its test, and `say` is what the mod says once it holds.
  `:quiet => true` leaves the win to the info key.
- `hint(label)`: the hint the puzzle assist says.
- `arrival_hint(label)`: a rule said queued on arriving at the map, when descriptions are on.
- `spot(opts)`: a named point for the locator, `:at => [x, y]` or `:event => id`, with its `:label`.
- `info`: the block answers the info key's line.
- `active`: the block answers whether the puzzle answers the info key.
- `phase(test, opts = {})`: a phase, live while `test` holds; the first live phase is current. It takes `:title`,
  `:quiet`, `:hint`, `:progress`, `:values`, `:sum`, `:spots`, `:hidden` and `:track`.
- `cells(cols, list)`: the grid's cells in reading order, `cols` to a row.
- `lit`: the block answers whether a cell, by its index, is lit.
- `target`: the block answers the letter asked for now, as `{:name, :pattern}`, or nil.
- `statues(pattern, label)`: the statues' graphic and name.
- `goals(map)`: the facing checked for each statue, as `{[x, y] => direction}`.

```ruby
# games/opalo/puzzles.rb
mechanic(:state, 36) do
  watch :switch => 313, :label => :op_lights,       :on => :op_lights_on, :off => :op_lights_off
  watch :switch => 314, :label => :op_lights_north, :on => :op_lights_on, :off => :op_lights_off
  arrival_hint :op_traps_hint
end
```
