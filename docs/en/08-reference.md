# Reference

Signatures verified against the code. The `PokeAccess::` prefix is dropped in the tables and stated in each
group's lead line. Where a method takes a block, the usage column says what it yields.

## Speech and braille

`core/speech/speech.rb`, `core/speech/text.rb`, `core/dialogue/dialogue.rb` — module `PokeAccess`. See
[04-readers](04-readers.md).

| Signature | Returns | When to use it |
|---|---|---|
| `speak(text, interrupt = true)` | Nothing usable | Speak an already-clean line (a resolved i18n key). `interrupt` false queues |
| `speak_clean(text, interrupt = true)` | Nothing usable | Speak text that came from the GAME: applies `clean` first |
| `clean(text)` | Speakable string | Strip `\PN`, `\V[n]`, `\C[n]` codes, `<b>` tags and control bytes |
| `stop_speech` | `true` if the backend obeyed; `false` with no bridge | Silence the reader now, saying nothing new |
| `pause_speech` | `true`/`false` | Pause ongoing speech; backend-dependent |
| `resume_speech` | `true`/`false` | Resume it |
| `speaking?` | `true`, `false` or `nil` | Ask whether the reader is still voicing something |
| `braille(text)` | `true` if the braille display took it | Send text to the braille line (UTF-8, like `speak`) |
| `braille_codepoints(cps)` | Same as `braille` | Send an array of Unicode codepoints (U+28xx cells) |
| `codepoints_to_utf8(cps)` | UTF-8 byte string | Convert codepoints; anything outside the BMP is skipped |
| `speech_backend` | `"NVDA"`, `"JAWS"`, `"SAPI 5"`... or `""` | Diagnostic line |
| `speech_ready?` | `true` if the bridge came up | Diagnostics; a normal reader never needs it |
| `init_speech!` | Bridge state | `speak` calls it; it only tries once per session |
| `retry_init!` | Bridge state after retrying | Forget a failed init; the Ctrl+Alt+F8 toggle calls it |
| `on_speak = cb` / `on_speak` | The observer, or `nil` | Observe EVERYTHING spoken; receives `(text, interrupt)` |
| `last_spoken` | Last non-empty line spoken, or `nil` | Spoken diagnostic |
| `say_dialogue(message)` | Nothing | Clean, remember and speak a dialogue line QUEUED |
| `note_dialogue(text)` | Nothing | Remember a line without speaking it |
| `last_dialogue` | Last dialogue line, or `nil` | The info key with shift repeats it |

`speaking?` answers `nil` when the backend cannot tell. Treat `nil` as unknown, NEVER as silence. `on_speak`
is a SINGLE observer: assigning a new one replaces the previous. A raising observer is swallowed.
`say_dialogue` does not re-speak an identical line within 0.5 s.

## Defensive introspection

`core/foundation/const.rb`, `core/speech/markers.rb` — module `PokeAccess`.

| Signature | Returns | When to use it |
|---|---|---|
| `const_at(name)` | The constant, or `nil` if any segment is missing | Resolve `"A::B::C"` by name, 1.8.7-safe |
| `ivar(obj, sym, fallback = nil)` | The ivar, or `fallback` | Read engine objects, which expose no accessors |
| `ivar_i(obj, sym, fallback = 0)` | The ivar as an Integer, or `fallback` | Same, for numeric ivars |
| `sprite(scene, key)` | The sprite at `@sprites[key]`, or `nil` | Reach a window on an Essentials scene |
| `attr_of(obj, *names)` | The first accessor that answers non-`nil`, or `nil` | Accessors Essentials renamed between eras |
| `dedicate(win)` | `win` | Claim a window for a dedicated reader |
| `dedicated?(win)` | `true`/`false` | Has someone claimed it? The generic reader asks this |
| `expect!(key, value)` | `value` untouched | Log once that something expected came back `nil` |

`const_at` is for when you want the CONSTANT; for the bare "does it exist?" boolean the single gate is
`Engine.has?`. In `attr_of` the order matters: put the spelling most games use first. `dedicate` sets
`@access_dedicated`, never the engine's `@ignore_input`, which would freeze a Selectable window's cursor.

## Hooks

`core/input/hooks.rb` — module `Hooks`. See [03-hooks](03-hooks.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Hooks.wrap(cname, meth, opts = {}, &mw)` | Nothing | The engine: raw middleware on the chain. Yields `(obj, call_next, args)` |
| `Hooks.before_hook(cname, meth, opts = {}, &body)` | Nothing | Speak BEFORE the original blocks. Yields `(obj, args)` |
| `Hooks.after_hook(cname, meth, opts = {}, &body)` | Nothing | The normal case, with the original's result. Yields `(obj, result, args)` |
| `Hooks.around_hook(cname, meth, opts = {}, &body)` | Nothing | Full control; the body's value is the method's. Yields `(obj, call_next, args)` |
| `Hooks.frame_hook(cname, meth, &body)` | Nothing | Per-frame driver that can host a whole modal loop. Yields `(obj, args)` |
| `Hooks.read_on_open(cname, meth = :pbStartScene, opts = {}, &blk)` | Nothing | Opening summary, queued and cleaned. Yields `(scene)`, returns the text |
| `Hooks.override(target, meth, opts = {}, &body)` | Nothing | Declared REPLACEMENT. Yields `(receiver, original, args)` |
| `Hooks.wrap_global(name, tag, timing = :after, &body)` | Nothing | Top-level `Object` method (`pbDisplayMail`...). Yields `(args, x)` |
| `Hooks.wrap_kernel(name, tag, timing = :before, &body)` | Nothing | Same, trying the `Kernel` singleton first. Yields `(args, x)` |
| `Hooks.missing` | Array of `"Class#method"` | The class exists and the method does not: LIKELY TYPO |
| `Hooks.fn_absent` | Array of function names | Found in neither `Kernel` nor `Object`. Informational |
| `Hooks.overrides` | Array of `"Target.meth (tag)"` | Installed replacements; the diagnostic prints them |
| `Hooks.suppressed` | Array of `"outer>inner"`, capped at 40 | Pairs the reentrancy guard dropped this session |

`frame_hook` takes NO `opts`: it fixes `:hook_container` internally. In `around_hook`, `call_next` takes no
arguments (it replays the caller's own); to change them, mutate `args` in place. An `around`/`override`
body's failure is logged and RE-RAISED; every other body's is swallowed.

In `wrap_global` / `wrap_kernel`, `timing` decides what arrives as `x`: `:before` → `nil`, `:after` → the
result, `:around` → `call_next` (you call it). `override` takes as `target` either a mod module (replacing
its singleton method) or a game class name as a string (its instance method).

| Option | Effect |
|---|---|
| `:optional => true` | The method is legitimately absent on some games: skipped silently instead of counting in `Hooks.missing` |
| `:hook_container => true` | The method is a container that delegates the announcement to hooked methods it drives: its original runs WITHOUT the reentrancy guard |
| `:timing => :before` | `read_on_open` only: for openers that BLOCK in their own loop |
| `:tag => "..."` | `override` only: names the owner in the `overrides` listing |

An absent CLASS is always a silent no-op: that is normal cross-game variance.

## Cursor dedup

`core/menus/cursor.rb` — module `Cursor`. The default primitive for every cursor or selection reader. See
[04-readers](04-readers.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Cursor.changed?(holder, slot, key)` | `true` (and stores the key) when it differs; `false` otherwise | Gate arbitrary work |
| `Cursor.on_change(holder, slot, key, &blk)` | The block's value on change; `nil` otherwise | Build the line lazily |
| `Cursor.announce(holder, slot, key, interrupt = true, first_interrupt = nil, &blk)` | Nothing | The common case: on a change, speak what the block returns |
| `Cursor.pending?(holder, slot)` | `true` on the FIRST read of a fresh or reset cursor | Tell an opening read from a later move |
| `Cursor.reset(holder, slot)` | Nothing usable | On (re)opening a screen whose cursor may sit on the same entry |
| `Cursor.reset_global` | Nothing | Drop the table for readers with no instance; already registered in `Caches` |

| Argument | What it is |
|---|---|
| `holder` | The scene or instance the state lives on (ivar `@access_cur_<slot>`), so it dies with it. `nil` uses a module-wide table per slot |
| `slot` | A symbol owned by that reader, raw (`:my_list`). A leading `@` is tolerated and dropped |
| `key` | An index, a string or a tuple (`[page, index]`) |

A `nil` key ALWAYS counts as "unchanged": a missing value never speaks. `pending?` is checked BEFORE the
`changed?` that records the key. `announce` does nothing when the line is `nil` or blank, and uses
`first_interrupt` only while the slot is `pending?`.

## Blocking loops

`core/menus/scene_watcher.rb` — module `SceneWatcher`. For screens running their own input loop, where the
cursor hooks never fire.

| Signature | Returns | When to use it |
|---|---|---|
| `SceneWatcher.wire(cls, meth, reader)` | Nothing | The plumbing: `reader` answers `watch(scene)`, `unwatch` and `poll` |
| `SceneWatcher.reader(cls, meth, slot, &blk)` | The generated holder | The ONE-call form: hold, poll, dedup and speak. Yields `(scene)` |

The `reader` block returns `[key, text]`; `nil` or a non-pair skips the frame. If `text` answers `call` it is
only invoked once the key actually changed, which is what makes a reader that queries the game to word
itself cheap. Blocks use `next`, not `return` (`define_method` under 1.8.7).

## Engine

`core/foundation/engine.rb` — module `Engine`. See [02-engines](02-engines.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Engine.has?(cap)` | `true`/`false` | The single capability gate; never gate on a version number |
| `Engine.gamedata?` | `true` on the GameData era (v17+) | Pick a provider or an era-specific reader |
| `Engine.gen6?` | The opposite | Same |
| `Engine.kind` | `:gamedata` or `:gen6` | Label a line or index a table by era |
| `Engine.player` | `$player`, `$Trainer` or `nil` | The player object without knowing the era |
| `Engine.version` | Comparable Float: 16.0, 19.0, 21.1... memoised | The diagnostic line ONLY |
| `Engine.fork` | `:sky` or `nil` | The diagnostic line ONLY |
| `Engine.scene_classes(*names)` | Array of names to hook | Several candidate classes: drops those another already covers |
| `Engine.scene_class(*names)` | The first name, or `nil` | ALIASES of one screen: hook exactly one |
| `Engine.era_scene(era, own, other)` | The name to hook, or `""` | A reader written against ONE era when both aliases exist |

`has?` takes three forms: a registered symbol (`:ui_rework`), a class name (`"UI::BaseScreen"`), or class
plus instance method (`"Battle::Scene::MenuBase#setIndexAndMode"`). An unregistered symbol is logged once and
answers `false`. An `""` from `era_scene` binds nothing, exactly like an absent class.

| `CAPABILITIES` symbol | Probe |
|---|---|
| `:gamedata` / `:gen6` | The engine era |
| `:sky_fork` | The Sky fork |
| `:ui_rework` | `UI::BaseScreen` (the v22 UI rework) |
| `:battle_scene` | `Battle::Scene` (the v19+ battle scene) |
| `:dbk` | `Battle#pbToggleSpecialActions` (Deluxe Battle Kit) |
| `:mui` | `UIHandlers` (Modular UI Scenes) |

The last two are third-party plugins and sit there for the DIAGNOSTIC, not for gating: their readers bind
per method with `:optional`. A one-off screen needs no registration: pass its class name to `has?` directly.

## i18n

`core/foundation/i18n.rb` — module `I18n`. See [05-extending](05-extending.md).

| Signature | Returns | When to use it |
|---|---|---|
| `I18n.t(key, vars = nil)` | The translated string | All spoken text; `vars` is a `%{name} => value` hash |
| `I18n.lang` | The active language symbol, or the reference one (`:en`) | Read the language without touching `Config` |
| `I18n.available_languages` | Array of symbols with a file in `lang/` | Language menu |
| `I18n.language_name(code)` | The `__language__` entry, or the code | Human name in the menu |
| `I18n.next_language(code)` | The next in the cycle | Language toggle |
| `I18n.interpolate(s, vars)` | The string with `%{name}` substituted | Interpolate outside `t`; a missing var yields `""` |
| `I18n.parity_issues` | Array of `"code:key: reason"`; `[]` when in sync | The boot check and the suite |
| `I18n.table(code)` | Key => value hash, cached | Inspect a whole table |
| `I18n.duplicate_keys(code)` | Array of keys repeated in one file | Diagnose a `lang/*.txt` |

`t` never raises: a missing key falls back to the reference language and then to the key name, so the raw key
is what gets spoken. `parity_issues` covers three faults: a key present in one language and missing in
another, a key duplicated within one file, and `%{}` placeholders that differ between languages.

## Data

`core/data/data.rb` — module `Data`. See [04-readers](04-readers.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Data.species_name(id)` | `"Pikachu"`, or `nil` | Species name without knowing the era |
| `Data.species_entry(id)` | The pokédex entry, or `nil` | Dex flavour text |
| `Data.move_name(id)` | `"Tackle"`, or `nil` | |
| `Data.move_type_name(id)` | `"Normal"`, or `nil` | |
| `Data.move_power(id)` | `40`, or `nil` | |
| `Data.move_accuracy(id)` | `100`, or `nil` | |
| `Data.move_description(id)` | Text, or `nil` | |
| `Data.type_name(id)` | `"Fire"`, or `nil` | |
| `Data.item_name(id)` | `"Potion"`, or `nil` | |
| `Data.item_name_plural(id)` | `"Potions"`, or `nil` | Quantities |
| `Data.item_description(id)` | Text, or `nil` | |
| `Data.item_id(sym)` | The internal id for `:POTION`, or `nil` | Turn a symbol into an id |
| `Data.ability_name(id)` | `"Static"`, or `nil` | |
| `Data.nature_name(id)` | `"Timid"`, or `nil` | |
| `Data.stat_name(stat)` | `"Attack"`, or `nil` | Takes a symbol or an index, per engine |
| `Data.status_name(status)` | `"Poisoned"`, or `nil` | |
| `Data.pokemon_types(pk)` | Array of type names; `[]` when unresolved | Types of one specific Pokémon |
| `Data.register(priority, provider)` | Nothing | Register a provider: 20 GameData, 10 gen-6, 0 fallback |
| `Data.active` | The active provider, or `nil` | Diagnostics |
| `Data.active_priority` | The active priority, or `nil` | `0` means only the fallback is left |
| `Data.active_entry` | `[priority, provider]`, or `nil` | Diagnostics |
| `Data.resolve(method, arg)` | Whatever the provider returns, or `nil` | The funnel: add a new resolver |
| `Data.errors` | Array of strings; `[]` on a clean run | Provider exceptions, one per `(method, class)` |

`pokemon_types` is the only one that never returns `nil`. The rest answer `nil` whether no provider is
registered or the datum is genuinely absent; a provider exception is recorded in the marker and also answers
`nil`, so the reader degrades instead of crashing.

## Plugins

`core/foundation/plugins.rb` — module `Plugins`. The loader fills the table in; nothing here loads anything.

| Signature | Returns | When to use it |
|---|---|---|
| `Plugins.loaded` | Array of names loaded this session | Diagnostics |
| `Plugins.note_loaded(name)` | Nothing | The loader calls it as it evaluates each declared reader |
| `Plugins.table` | Name => probe hash, from `plugins/manifest.rb` | Look up what gives each plugin away |
| `Plugins.table = t` | The assigned hash | The loader sets it; a non-Hash leaves `{}` |
| `Plugins.game_plugins` | Sorted array of `"name version"`, or `nil` | What the game's own `PluginManager` declares |
| `Plugins.undeclared` | Sorted array | Plugins present whose reader nobody declared: they run mute |

`game_plugins` returns `nil`, not `[]`, when the game has no `PluginManager`: older games paste plugin code
straight into the script list, so "none installed" would be a lie. The `undeclared` probe goes through
`Engine.has?`, so it can name a method and not only a class.

## Utilities

`core/util/` — modules `Util` and `KVFile`.

| Signature | Returns | When to use it |
|---|---|---|
| `Util.join_parts(parts, sep = ". ")` | String, dropping nils and blanks | The "name. detail. extra" idiom where any piece may be absent |
| `Util.types_phrase(t1, t2)` | `"type1/type2"`, collapsed and deduped | Loose type names; for a Pokémon use `Data.pokemon_types` |
| `Util.playtime_parts(secs)` | `[hours, minutes]`, or `nil` when `secs` is `nil` | Play time on a trainer card or a save slot |
| `Util.dex_seen?(sp)` | `true`/`false`, or `nil` when nothing resolves | Seen, tolerant of how each engine exposes the dex |
| `Util.dex_owned?(sp)` | Same | Owned |
| `Util.badge_count(who)` | Integer, or `nil` | Badges, be it `numbadges`, `badge_count` or the array |
| `Util.union_groups(n, &blk)` | Array of index groups | Union-find grouping; the block decides whether `i` and `j` belong together |
| `KVFile.each(path, opts = {}, &blk)` | Nothing | The one parser for the mod's key=value `.txt` files. Yields `(key, value)` |

`dex_seen?`/`dex_owned?` distinguish "not seen" (`false`) from "unknown" (`nil`). In `KVFile.each`,
`:strip_value => false` keeps a value's leading spaces, which in the language tables are part of the spoken
text. A missing file yields nothing and is not an error.

## Diagnostics and clock

`core/speech/markers.rb`, `core/foundation/perf.rb`, `core/util/recorder.rb`, `core/input/diag.rb`. See
[07-diagnostics](07-diagnostics.md).

| Signature | Returns | When to use it |
|---|---|---|
| `write_marker(extra = "")` | Nothing | Append a line to the load marker |
| `log_once(key, e)` | Nothing | Record the FIRST failure per key; takes an exception or a string |
| `format_error(e)` | `"Class: message @ frame <- frame <- frame"` | Format an exception for the marker |
| `clock` | Float: seconds since the mod loaded | The single source of cue pacing |
| `freq_to_seconds(f)` | Float: seconds between cues for a 0-100 setting | ~0.15 s at 100, ~1.5 s at 0 |
| `uptime_scale` | Float, or `nil` while it cannot be measured | Divisor for comparing two engine `System.uptime` stamps |
| `Perf.measure(label, &blk)` | The block's value | Time a per-frame hook; accumulates sum, max and count |
| `Perf.report` | One-line string, or `"(sin datos)"` | Print averages and maxima in ms |
| `Perf.reset` | Nothing | Start a clean measurement window |
| `Recorder.toggle` | The file name on start, the event count on stop | The single debug-menu gesture |
| `Recorder.start` | The file name, or `nil` if it could not start | Begin a session recording |
| `Recorder.stop` | Event count for the WHOLE session | Stop it and flush what is pending |
| `Recorder.recording?` | `true`/`false` | |
| `Recorder.path` | Path of the current or last file, or `nil` | |
| `Recorder.note(kind, *fields)` | Nothing | Append an event; tabs and newlines are replaced |
| `Recorder.on_change(kind, key, *fields)` | `true` if it wrote | Record only when the field changed |
| `Keys.register_diag_section(name, group = :scene, &body)` | Nothing | Own section in the dump. Yields the output line array |
| `Keys.diag_build(sections)` | The dump as a String | Build a subset of sections |
| `Keys.diag_dump` | Nothing | Dump everything to `diag.txt` and speak the summary |
| `Keys.diag_section_to_clip(group)` | Nothing | Copy a subset to the clipboard |

`clock` is wall time on purpose: `System.uptime` does not return seconds on one fangame's mkxp-z, and
`Graphics.frame_count` jumps when a save is loaded. Footsteps do NOT go through it: they fire on a tile
change, so they follow the player even with the turbo held.

## Pathfinding

`core/nav/pathfinder.rb`, `core/nav/terrain.rb` — modules `Pathfinder` and `Terrain`. See
[06-navigation](06-navigation.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Pathfinder.find_path(tx, ty)` | Array of RPG direction codes, or `nil` when there is no route | Route to a tile adjacent to the target; the origin is always `$game_player` |
| `Pathfinder.path_to_text(path)` | `"3 up, 2 left"` | Speak a route; `nil` gives "no route" and `[]` gives "next to it" |
| `Pathfinder.reachable_set` | `pkey => true` hash, cached per player tile | The hide-unreachable filter and the sonar's line of sight |
| `Pathfinder.reachable_tiles` | The same hash, uncached | Force a recomputation |
| `Pathfinder.pkey(x, y)` | `x * 100000 + y` | Pack or unpack `reachable_set` keys |
| `Pathfinder.reach` | Integer of tiles (`Config.route_reach`) | The farthest a target may be for the search to consider it |
| `Pathfinder.invalidate_cache(force = false)` | Nothing | After an event that changed passability |
| `Pathfinder.passable_at?(cx, cy, d)` | `true`/`false` | Can one step be taken that way? |
| `Pathfinder.ledge_jump(cx, cy, dx, dy, d)` | The landing `[x, y]`, or `nil` | Is there a ledge hop that way? |
| `Pathfinder.surf_launch(tx, ty)` | Route to the shore, or `nil` | The target sits across water |
| `Pathfinder.blocked_target?(tx, ty)` | `true` when the target is clearly unreachable | Fast reject before a full A* |
| `Pathfinder.path_algorithm` | A symbol from `ALGORITHMS`; `:astar` by default | Read the configured algorithm |
| `Terrain.raw(x, y, count_bridge = false)` | Integer (gen-6) or a `GameData::TerrainTag`, or `nil` | The engine's raw value |
| `Terrain.number(t)` | The `id_number` of a raw value, or `nil` | Normalise the two shapes |
| `Terrain.kind(x, y, count_bridge = false)` | Stable symbol (`:ice`, `:bridge`...), or `nil` | Classify a tile |
| `Terrain.label(x, y)` | Surface i18n key (`:surf_water`...), or `nil` | Speak the surface underfoot |
| `Terrain.surfable?(t)` | `true`/`false` | Predicate over a terrain VALUE, not coordinates |
| `Terrain.ledge?(t)` | `true`/`false` | Same |
| `Terrain.ice?(t)` | `true`/`false` | Same |
| `Terrain.bridge?(t)` | `true`/`false` | Same |
| `Terrain.grass?(t)` | `true`/`false` | Same (plain, tall or soot grass) |
| `Terrain.surfable_at?(x, y)` | `true`/`false` | Coordinate variant |
| `Terrain.ledge_at?(x, y)` | `true`/`false` | Coordinate variant |
| `Terrain.ice_at?(x, y)` | `true`/`false` | Coordinate variant |

`find_path` returns DIRECTIONS, not coordinates: RPG codes 8 up, 2 down, 4 left, 6 right, one per step.
`path_to_text` consumes exactly that. Only three `*_at?` variants exist — `surfable_at?`, `ledge_at?` and
`ice_at?`; for `grass?` and `bridge?` you go through `raw(x, y)`.

`invalidate_cache` without `force` is throttled to once every two seconds, because a cutscene with many
events would trigger a costly re-flood per event. Pass `true` from callers that KNOW passability changed.

## Locator

`core/nav/locator.rb`, `core/nav/guide.rb`, `core/nav/locator_naming.rb` — module `Locator`. See
[06-navigation](06-navigation.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Locator.rebuild_targets` | Nothing | Rebuild the current category's list, nearest first |
| `Locator.step(delta)` | Nothing | Move through the list (+1/-1) |
| `Locator.cycle_category(dir)` | Nothing | Change category (+1/-1) |
| `Locator.select_current` | Nothing | Select the focused target and announce it |
| `Locator.announce_selected(withname)` | Nothing | Speak the target; `withname` prepends name and ordinal |
| `Locator.announce_route` | Nothing | Speak the route to the selected target |
| `Locator.announce_coords` | Nothing | Speak the map name and the coordinates |
| `Locator.toggle_hide_unreachable` | Nothing | Flip the unreachable filter; persists and rebuilds |
| `Locator.rename_target` | Nothing | Prompt for a label for the focused object and persist it |
| `Locator.rename_map` | Nothing | Prompt for a map name and persist it |
| `Locator.tag_menu` | Nothing | Open the tagging, recategorising and hiding menu |
| `Locator.show_menu(msg, choices, cancel)` | The chosen index, or the cancel one | A choice menu that works on both eras |
| `Locator.map_poll` | Nothing | The locator's per-frame work; the frame driver calls it |
| `Locator.forget_map` | Nothing | Forget the current map so it is announced again |
| `Locator.toggle_guide` | Nothing | Flip the guide cane |
| `Locator.register_hazard(re, label_key)` | Nothing | Hazard sprite: a label plus its own cue |
| `Locator.register_teleporter(re)` | Nothing | Sprite that counts as a teleporter |

`show_menu` exists because gen-6 only exposes `Kernel.pbMessage` and modern only the global `pbMessage`;
calling the absent one raises `NoMethodError`.

## Audio

`core/audio/audio3d.rb`, `core/audio/spatial.rb` — modules `Audio3D` and `Spatial`. See
[06-navigation](06-navigation.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Audio3D.boot` | `true` once ready | Initialise the dll and its channels exactly once |
| `Audio3D.available?` | A truthy value if the dll and its entry points resolved | Check the dll before anything else |
| `Audio3D.device_rate` | 44100 or 48000, `nil` before boot | Pick the right sound file |
| `Audio3D.device_latency` | Latency in ms, `nil` before boot | Diagnostics |
| `Audio3D.range` | Integer of tiles | Emitter detection radius |
| `Audio3D.wall_range` | Integer of tiles | Wall and wind probe range |
| `Audio3D.alt_dist` | Integer of tiles | Below this, two emitters alternate instead of sounding together |
| `Audio3D.occlusion_mode` | `:hear`, `:occlude` or `:hide` | What to do with an emitter behind a wall |
| `Audio3D.wav(name)` | The `.wav` path for the device rate | Resolve a sound file |
| `Audio3D.tick` | Nothing | One sonar frame; the `Game_Player#update` hook calls it |
| `Audio3D.bump(dir, interact = false)` | `true` if it handled the cue | Wall or object collision, panned to that tile |
| `Audio3D.guide(dir, vol)` | `true` if handled | Guide-cane cue, panned toward the next step |
| `Audio3D.footstep(kind, vol)` | `true` if handled | Footstep, centred on the player |
| `Audio3D.silence_all` | Nothing | Stop every channel |
| `Audio3D.silence_emitters` | Nothing | Stop emitters and loops, keeping steps and bumps (`:basic` mode) |
| `Audio3D.reset_map_state` | Nothing | Drop the previous map's scan |
| `Audio3D.nav_full?` | `true`/`false` | Full mode (all emitters)? |
| `Audio3D.nav_off?` | `true`/`false` | Fully off? Then the engine never even boots |
| `Audio3D.gate_report` | `"n/total playing by=..."`, then clears the window | Why a tick played or fell silent |
| `Spatial.cue(name, volume, pitch = 100)` | Nothing | Play a file from `sounds/`; volume 0 or `nil` plays nothing |
| `Spatial.earcon(name, volume, pitch = nil)` | Nothing | Named earcon from `EARCONS`; the table's pitch is the default |
| `Spatial.busy?` | `true`/`false` | The player is NOT under free control: the soundscape falls silent |
| `Spatial.busy_reason` | A symbol (`:message`, `:in_menu`, `:battle`...) or `nil` | Name the cause in the diagnostic |
| `Spatial.keys_locked?` | `true`/`false` | Another screen genuinely owns the arrow keys |
| `Spatial.tick` | Nothing | One frame of steps, bumps, radar and surfaces |

`available?` returns the last `Win32API` object of the chain, not a boolean: use it only as a condition.
`busy?` is true during a message or a running interpreter; `keys_locked?` is not, so the locator keys stay
usable during a walkable cutscene.

## Battle

`core/battle/battle.rb`, `core/battle/move_info.rb` — modules `Battle` and `MoveInfo`.

| Signature | Returns | When to use it |
|---|---|---|
| `Battle.set_battle(b)` | Nothing | Capture the running battle for the hp and field keys |
| `Battle.clear_battle` | Nothing | Release it; `map_poll` does this every frame |
| `Battle.in_battle?` | `true`/`false` | Is a fight running? `Spatial.busy?` asks this |
| `Battle.battler_at(idx)` | The battler, or `nil` | Name a slot whose menu text arrived blank |
| `Battle.hp_phrase(hp, tot, as_percent)` | An hp phrase: percentage or `"hp/total"` | Centralises the branch and the divide-by-zero guard |
| `Battle.battler_state(b, hide_exact = false)` | Name, level, hp, status and stat stages | Describe a whole battler |
| `Battle.announce_hp(foe)` | Nothing | Speak the hp of a WHOLE side; `foe` true reads the opponents as a percentage |
| `Battle.foe_info` | A line covering every opponent, or `nil` | Name, level and type of each foe |
| `Battle.announce_field` | Nothing | Speak weather, terrain and field conditions |
| `Battle.types_of(pk)` | Array of type names; `[]` when nothing resolves | Types via the data provider |
| `MoveInfo.line(name, type_name, power, accuracy, opts = {})` | `"name. type. power. accuracy[. pp][. description]"` | The single assembler of a move line |
| `MoveInfo.by_id(id)` | The line, or `nil` | Resolve through GameData (v21 and v22) |
| `MoveInfo.by_id_via_data(id)` | The line, or `nil` | Resolve through the `Data` adapter, so gen-6 works too |
| `MoveInfo.power_phrase(pw)` | `"no damage"` at ≤ 0, `"variable"` at 1, else the number | Spoken power |
| `MoveInfo.accuracy_phrase(acc)` | `"never misses"` at ≤ 0, else the number | Spoken accuracy |

In `MoveInfo.line`, a `nil` `power` or `accuracy` means UNRESOLVED and omits its phrase; only a real 0 says
"no damage" or "never misses". The options are `:pp` and `:total_pp` (both needed to speak pp) and `:desc`,
appended when non-blank.

## Contextual info

`core/field/contextual.rb` — module `Info`. What the information key reads.

| Signature | Returns | When to use it |
|---|---|---|
| `Info.set_info(kind, data)` | Nothing | Publish the context the info key will read |
| `Info.info_text` | The current context's text, or `nil` | The key calls it; a reader rarely needs it |
| `Info.clear_combat` | Nothing | Forget the battle context when back on the map |
| `Info.move_info(m)` | The move line, or `nil` | Describe a move object |
| `Info.move_by_id_info(pk, moveid)` | The line, or `nil` | Resolve the move on a Pokémon and publish it |
| `Info.move_info_by_id(moveid)` | The line, or `nil` | Describe from a bare id (the forget screen) |
| `Info.item_info(itemid)` | Name, description and, on a TM, the move it teaches | |
| `Info.pokemon_info(pk)` | Name, level, hp, gender, held item and status | Quick glance |
| `Info.summary_text(pk)` | Full sheet: species, types, nature, ability, item and six stats | |
| `Info.trainer_info` | Name, money, badges, pokédex and play time | Dispatched on which player global the engine exposes |
| `Info.note_item_desc(id, desc)` | Nothing usable | Make the info key read the EXACT description the screen shows |

| `set_info` `kind` | What it reads |
|---|---|
| `:move` | The selected move object |
| `:item` | The selected item id |
| `:pokemon` | The current Pokémon |
| `:trainer` | The trainer (ignores `data`) |
| `:battle_foe` | The current foe (ignores `data`, calls `Battle.foe_info`) |
| `:text` | A ready-made line a profile publishes itself |

`clear_combat` drops only `:move`, `:battle_foe` and `:text`; the field context (`:pokemon`, `:item`,
`:trainer`) is kept.

## Game profiles

`core/foundation/game.rb` — module `Game` and its `Definition`. Each method is a thin layer over a raw call.
See [05-extending](05-extending.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Game.define(name = nil, &blk)` | The `Definition` | Open a profile block; additive and repeatable |
| `Game.profiles` | Array of identifiers defined | Diagnostics |
| `after(cname, meth, opts = {}, &blk)` | Nothing | `Hooks.after_hook` |
| `before(cname, meth, opts = {}, &blk)` | Nothing | `Hooks.before_hook` |
| `around(cname, meth, opts = {}, &body)` | Nothing | `Hooks.around_hook` |
| `read_on_open(cname, meth = :pbStartScene, opts = {}, &blk)` | Nothing | `Hooks.read_on_open` |
| `override(target, meth, &body)` | Nothing | `Hooks.override` with `:tag => "game_<profile>"` |
| `kernel(fname, timing = :before, &body)` | Nothing | `Hooks.wrap_kernel` for a loose function |
| `screen_reader(cname, &blk)` | Nothing | Reader for the focused option of a command window |
| `poll_each_frame(&blk)` | Nothing | `Keys.on_frame`, for menus with their own loop |
| `diag_section(name, group = :scene, &body)` | Nothing | `Keys.register_diag_section` |
| `config(key, value)` | The assigned value | Override a `Config` setting |
| `button_labels(map)` | The resulting hash | Merge the game's own button relabels |
| `remap_extra(sym, default_vk, label)` | Nothing | A remappable extra action |
| `puzzle(map_id, opts)` | Nothing | `Puzzles.register` |
| `hazard(pattern, label)` | Nothing | `Locator.register_hazard` |
| `picture_texts(map)` | The resulting hash | Picture file name => spoken text |
| `on_picture(&blk)` | Nothing | React to a picture being shown. Yields `(picture_name, args)` |

`override` from a profile takes no `opts`: it fixes the `:tag` to the profile name, which is what the
diagnostic lists.

## Configuration

`core/foundation/config.rb`, `core/foundation/settings.rb` — modules `Config` and `Settings`. See
[05-extending](05-extending.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Config.<key>` | The current value | Every `SCHEMA` row and every `OTHER` entry has an accessor |
| `Config.<key> = v` | The assigned value | Write from a profile or from the menu |
| `Config.schema_group(group)` | Array of `[key, default, kind, group, label, help]` rows | Build a menu page |
| `Config.schema_row(key)` | The row, or `nil` | Look up a setting's kind or default |
| `Config.keys_of_kind(kind)` | Array of keys of that kind | Persist a whole kind |
| `Settings.read` | String hash of `settings.ini` | Read the file raw |
| `Settings.write` | Nothing | Serialise the current `Config` values to the ini |
| `Settings.apply` | Nothing | At boot: read, clamp and apply; create the ini when missing |
| `Settings.schema_keys` | Array of persisted keys, in write order | Know what this version stores |

Numeric values are clamped with `Config::KIND_BOUNDS` on apply, so a hand-edited ini can never go out of
range. Of the mod hotkeys only the ones the player actually moved are written, so a future change of default
reaches everyone who left them alone.

## Tags and names

`core/foundation/tags.rb`, `core/foundation/map_names.rb` — modules `Tags` and `MapNames`. Shareable text
files.

| Signature | Returns | When to use it |
|---|---|---|
| `Tags.get(mid, eid)` | The custom label, or `nil` | The name the player gave an object |
| `Tags.set(mid, eid, label)` | Nothing | Set and persist it; `""` clears the name only |
| `Tags.category(mid, eid)` | Forced category symbol, or `nil` for automatic | |
| `Tags.set_category(mid, eid, cat)` | Nothing | `nil` returns to automatic |
| `Tags.hidden?(mid, eid)` | `true`/`false` | Did the player hide it? |
| `Tags.set_hidden(mid, eid, val)` | Nothing | Hide or show |
| `Tags.each_hidden(&blk)` | Nothing | Walk what is hidden. Yields `(map_id, event_id, record)` |
| `Tags.store` | `{map_id => {event_id => record}}` hash | Inspection; loads and merges the import on first use |
| `Tags.import_now` | Number of new records | Merge `tags_import.txt` |
| `Tags.export` | Number of records written, or `nil` when there are none | Dump to `tags_export.txt` to share |
| `MapNames.get(mid)` | The custom name, or `nil` | It also changes how exits to that map are announced |
| `MapNames.set(mid, name)` | Nothing | Set and persist; empty restores the game's own name |

A `Tags` record disappears only once it has no name, no category and no hidden flag: `prune` does that
internally after every write. There is deliberately no bulk delete: clearing the label is not the same as
forgetting the object.

## Events and caches

`core/foundation/events.rb`, `core/foundation/caches.rb` — modules `Events` and `Caches`.

| Signature | Returns | When to use it |
|---|---|---|
| `Events.on(name, &block)` | The subscriber array | Subscribe; they run in subscription order, each guarded |
| `Events.emit(name, *args)` | Nothing | Emit to every subscriber |
| `Caches.register(name, &block)` | The block | Register a per-run state reset, idempotent by name |
| `Caches.reset_all` | Nothing | Run them all; fires on `:map_changed` |
| `Caches.names` | Array of registered names | Diagnostics |

| Core event | Arguments |
|---|---|
| `:map_changed` | `map_id`. Also on loading a save, even onto the same map |
| `:tags_changed` | None. The player edited object tags |

`:map_changed` is emitted by the locator's map-change detector, which compares the IDENTITY of `$game_map` as
well as its id: loading a save rebuilds the object, so a load also triggers the cache reset.

## Keys

`core/input/input.rb` — module `Keys` (named that way to avoid clashing with RGSS's `::Input`).

| Signature | Returns | When to use it |
|---|---|---|
| `Keys.enabled` | `true`/`false` | Is the mod active? Ctrl+Alt+F8 toggles it |
| `Keys.key(name)` | `true` only on the edge frame | A configured key by its `Config.keys` name |
| `Keys.raw_down?(vk)` | `true`/`false` | Physical state of a virtual key, focus-independent |
| `Keys.shift_down?` | `true`/`false` | The shift modifier, configurable |
| `Keys.ctrl_down?` | `true`/`false` | The control modifier, configurable |
| `Keys.focused?` | `true`/`false`, fail-safe `true` | Is the game window in the foreground? |
| `Keys.global_poll` | Nothing | The contextual keys; the `Input#update` hook calls it |
| `Keys.on_frame(&blk)` | The poller array | A block once per frame in every scene |
| `Keys.run_frame_pollers` | Nothing | Run them all, each guarded |
| `Keys.typing!` | `4` | While a text field is active: suppresses EVERY mod key |
| `Keys.menu_lock!` | `4` | While a raw-input menu is active: suppresses movement keys, keeps read-only ones |
| `Keys.hotkey?(slot, fkey)` | `true` only on the edge frame | The Ctrl+Alt+`<function key>` gesture |

`typing!` and `menu_lock!` decay over four frames, so they must be called every frame while the situation
lasts. The difference is how much they silence: `typing!` everything, `menu_lock!` only what competes with
the game.

## Disk paths

`core/foundation/paths.rb` — module `Paths`. Constants, not methods.

| Constant | What it is |
|---|---|
| `Paths::ROOT` | `accessibility` |
| `Paths::CORE` | `accessibility/core` |
| `Paths::GAME` | `accessibility/game`, the game profile |
| `Paths::SOUNDS` | `accessibility/sounds` |
| `Paths::LIB` | `accessibility/lib`, the per-architecture dlls |
| `Paths::LANG` | `accessibility/lang`, the translations |
| `Paths::DATA` | The first WRITABLE location: the game folder or mkxp-z's AppData |

`DATA` is picked once at load by trying to write: mkxp-z reads through its virtual filesystem but writes to
the OS working directory, which on a tester's machine can be read-only.
