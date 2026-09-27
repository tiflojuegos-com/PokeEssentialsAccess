# Reference

Signatures verified against the code. The `PokeAccess::` prefix is dropped in the tables and stated in each
group's lead line. Where a method takes a block, the usage column says what it yields.

## Speech and braille

`core/speech/speech.rb` (the dispatcher), `backend.rb` (the bridge to the reader), `categories.rb`, `text.rb` and
`core/dialogue/dialogue.rb` — modules `PokeAccess` and `Speech`. See [04-readers](04-readers.md).

| Signature | Returns | When to use it |
|---|---|---|
| `speak(text, interrupt = true, category = nil)` | Nothing usable | Speak an already-clean line (a resolved i18n key). `interrupt` false queues; `category` files it in the history (without one, the scope's or the moment's) |
| `speak_clean(text, interrupt = true, category = nil)` | Nothing usable | Speak text that came from the GAME: applies `clean` first |
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
| `Speech.observe(key, &blk)` | The observer array | Observe EVERYTHING spoken: the block receives a `Speech::Message` (`text`, `category`, `interrupt`, `seq`). Registering the same key replaces it |
| `Speech.unobserve(key)` | Nothing usable | Remove an observer |
| `Speech.as(category) { }` | Whatever the block returns | File everything said inside the block under a category, however deep |
| `Speech.category_of(given)` | Symbol | A line's category: the given one, else the scope's, else `Speech.deduce` |
| `voice_out(text, interrupt)` | Nothing | The one way out to the reader. Tests replace only this, so everything goes through the real `speak` |
| `last_spoken` | Last non-empty line spoken, or `nil` | Spoken diagnostic |
| `say_dialogue(message)` | Nothing | Clean, remember and speak a dialogue line QUEUED |
| `note_dialogue(text)` | Nothing | Remember a line without speaking it |
| `last_dialogue` | Last dialogue line, or `nil` | The info key with shift repeats it |

`speaking?` answers `nil` when the backend cannot tell. Treat `nil` as unknown, NEVER as silence. A raising
observer is swallowed: an instrument cannot silence the mod. `say_dialogue` does not re-speak an identical line
within 0.5 s.

**Categories** (`Speech::CATEGORIES`): `:dialogue`, `:battle`, `:menu`, `:nav`, `:info` and `:system`, each with
its spoken name (`msg_cat_*`). A line takes the one its call names (the dialogue reader, the menu cursor, the
minigames); else the innermost `Speech.as` scope's (the locator, the information keys and the mod's menu wrap their
work in one);
else what the moment says: a message on screen is dialogue, a fight is battle, off the map or under the pause menu
is a menu, and the map is navigation. The deduction is the net for the calls nobody marks, and it is refined by
marking them, not by widening the net. `Speech::REVIEW` is the history's own readouts', which are never filed.

## Message history

`core/speech/history.rb` — module `History`. It observes the dispatcher and keeps the session's last lines in
memory with their category, as many as the `history_size` setting in the general options says (`History.capacity`:
100 to 2000, 300 by default; lowering it shows with the next line). It never files its own readouts, nor the same line repeated in the same
category within a second (`REPEAT_WINDOW`). Each view (everything, or one category) keeps its place, which new lines do not move; when the line at
that place has left through the capacity, the next press goes on from the first line still kept.

| Signature | Returns | When to use it |
|---|---|---|
| `History.step(dir)` | Nothing | One line back (`-1`) or on (`1`) in the view; the first press reads the latest |
| `History.to_end(dir)` | Nothing | The first (`-1`) or the last (`1`) |
| `History.switch_category(dir)` | Nothing | The previous or next view that holds lines, said with how many; "all" is always offered |
| `History.lines_of(view)` | Array of `Speech::Message` | A view's lines, oldest to newest |
| `History.views` / `view` / `view_name(view)` | | The views in order, the current one and its spoken name |
| `History.clear` | Nothing | Forget everything (tests) |

Keys: `hist_prev` (`Home`) and `hist_next` (`End`); with Ctrl they go to the ends and with Shift they change the
category (`Keys.history_key`). Both are remapped like any mod key. Shift+T, the last dialogue, is unchanged;
Ctrl+T says the focused row whole (see [Contextual info](#contextual-info)).

## Verbosity

`core/speech/verbosity.rb`, `verbosity_schemes.rb` — modules `Verbosity` and `VerbositySchemes`. How much is said
while moving through menus. Each kind of row is a **reading** (the `readings` registry) said at a **level**: `:brief`, `:medium`
or `:full` (`LEVELS`). A scheme sets every reading's level: the three built-in ones set them all alike and the
player's own one by one, like sliders, never saying more than `:full`, which is what the mod always said and the
default. The info key stays out of it: it always says everything.

| Signature | Returns | When to use it |
|---|---|---|
| `Verbosity.line(reading, parts, sep = ", ")` | The row | A row builder passes its parts as `[text, level it is said from]`; blank ones drop out. A bare String counts as `:full`, which is what a plugin appends |
| `Verbosity.info_line(reading, parts, sep = ", ")` | The row at its level | Publishes the whole row to the info key and to Ctrl+T and returns the trimmed one: a screen with no sheet of its own (a Pokédex list, a quest, a map tile) |
| `Verbosity.full_line(parts, sep = ", ")` | The whole row | The one Ctrl+T repeats, the third argument of `Info.set_info` |
| `Verbosity.whole { ... }` | Whatever the block returns | Building a row as Full says it, whatever the scheme: Ctrl+T's row of a builder that changes template with the level |
| `Verbosity.keep?(reading, from)` | `true`/`false` | When the level changes more than which parts go in (another template). A level that does not exist, a typo, counts as `:full` and leaves a line in the log |
| `Verbosity.level(reading)` | `:brief`, `:medium` or `:full` | The level under the active scheme (`level_in`: the reading's own, else the scheme's `OTHERS` level); a scheme that no longer exists says it `:full` |
| `Verbosity.list_entry(name, n, tot)` | "Pidgey, 3 of 8" or "Pidgey" | A list row with its position |
| `Verbosity.position(i, n)` | "3 of 8" or `nil` | The position on its own |
| `Verbosity.hints?` | `true`/`false` | Whether the key hints a screen paints are said |
| `Verbosity.with_hint(text, hint, sep = ". ")` | The line with its hint, or alone | A line of the mod's followed by the key that goes on |
| `Verbosity.descriptions?` | `true`/`false` | Whether what a screen explains about the focused option (a help, a rule, an achievement, an effect) or the detail of a place on the region map is said; only in Full, and the info key always says it |
| `Verbosity.active` | Symbol | The scheme in use: a level, or the name of one of the player's |
| `Verbosity.rotation` / `next_scheme(dir)` | | The built-in ones, then the player's by name; the next or the previous |
| `Verbosity.use(scheme)` | Nothing | Put it in use and save the setting |
| `Verbosity.rotate_scheme(dir = 1)` | Nothing | The rotation key: the next one, said as `:system` |
| `Verbosity.name_of(scheme)` / `reading_name(reading)` | String | Their spoken names |
| `Verbosity.define_reading(reading, name_key, help_key)` | The symbol | Declare a reading: the core's fourteen at the bottom of `verbosity.rb`; a plugin or a profile, those of its screens |
| `Verbosity.readings` / `reading_row(reading)` | `[reading, name key, help key]` rows | What the scheme editor lists, in declaration order |
| `Verbosity.level_in(levels, reading)` | Level | The one a scheme gives a reading: its own, else `OTHERS`', else `:full` |

| Reading | Brief | Medium | Full |
|---|---|---|---|
| `:party` | name, HP, status or fainted, able or not able | + level | + gender, shiny, Pokérus, item and markings |
| `:battle_move`, `:summary_move` | name and PP | + type | + category, power, accuracy and description |
| `:battle_marks` | no | the battle box's icons (caught, shiny, Mega, Primal and each game's own), as each foe comes in and with the HP | as Medium |
| `:learn_move` | name | + type and cost | everything |
| `:bag_item` | item, quantity and "moving" | + marks and what the screen paints of it (flavor, level, feel, which team members can use it) | as Medium |
| `:shop_item` | item and price | + how many are in the bag, marks and what an upgrade gives | as Medium |
| `:pc_slot` | name, level and fainted | + position and item | + gender, shiny, types, ability and markings |
| `:dex_entry` | number and name, or "unknown" | + caught or seen and what the list adds (rarity, stars, a region's figures) | everything |
| `:dex_page` | number, name and caught | + category, types and abilities | + height, weight, description, base stats and, in a species sub-list, the box beneath the focused species |
| `:ribbon` | the ribbon or memento, or the empty slot | + where it is | + its description |
| `:positions` | no | "3 of 10" and "page 2 of 3" | as Medium |
| `:hints` | no | the key hints | as Medium |
| `:descriptions` | no | no | what the screen explains about the option: a help, a rule, an achievement, an effect, a difficulty; and the detail of a place on the region map, after its name |

The ones plugins and profiles declare, only in the games that load them:

| Reading | Declared by | Brief | Medium | Full |
|---|---|---|---|---|
| `:quest` | `easy_questing`, `quest_ui`, Infinite Fusion Hoenn | the quest or challenge | + its state and marks (main, new, reward ready) | + a challenge's reward |
| `:map_square` | `better_region_map`, `secret_bases`, Soulstones 2 | the place or tile, whether one can fly or place there, whether it is unvisited, or what lies on it when putting decorations away | + point of interest, decoration or coordinates | + the tile's description |
| `:hall_of_fame` | `hall_of_fame_bw`, Realidea | the Pokémon, its nickname and, on reaching it, the entry | + the level | everything on the card |
| `:pokemon_choice` | Armonía, Reminiscencia, Soulstones 2 | the name | + types or category | the whole card |
| `:rem_blessing` | Reminiscencia | what the card does | + its rarity | + its category |
| `:incubator` | `hatcher`, `incubator` | the slot and, with an egg, the steps it has left | as Brief | + the screen's sentence on how close it is |

**Plugin and game readings.** A plugin or profile reader that says a kind of row the core has no reading for
declares its own with `define_reading` (with its `vb_*` and `vbh_*` keys in the six languages). Since plugin readers
load only in the games that declare them, and a profile only in its own game, the editor shows each game its
readings and no others. Each scheme also keeps `OTHERS`, the level of the readings it does not name (another
game's, a later version's): it is the editor's last row, "Other readings", and without it those readings are said
in Full. A scheme keeps the levels of readings the current game lacks, so taking it from one game to another loses
nothing.

How a reader is converted: it hands its parts with their level to `Verbosity.line` (or asks `keep?`); move rows
pass their reading to `MoveInfo.leveled` (the info key still calls `MoveInfo.line`, whole); an information window
that goes with the focused row and only counts from a level is declared with `InfoWindow.watch(..., :reading =>
[reading, level])`; its text always goes with Ctrl+T's row (`Info.add_to_row`). A reader not yet converted says its
whole row at every level: nothing is ever lost for not being done yet.

What the level leaves out is not lost. The info key says the focused thing's sheet, the same at every level, and
Ctrl+T the row whole, as Full says it. A screen with a sheet of its own publishes `Info.set_info(kind, data, row)`,
the row from `Verbosity.full_line(parts)` or, when its builder changes template with the level, from
`Verbosity.whole { builder }`; one without, `Verbosity.info_line`, and lets go of its `:text` when it closes
(`Info.clear_text`) where what lies beneath publishes nothing on the way back (on the map the key goes back to the
trainer by itself). Pages ("page 2 of 3") are positions: said from Medium with `keep?(:positions, :medium)`. Painted
hints are filtered by themselves wherever they go through `KeyHints.gate` (lines: `PaintCapture.speak_around` and
`flush_pending`, `PausePanel.say`, the trainer card) or `KeyHints.gate_sentences` (sentences: the `InfoWindow`
windows, Añil's naming screen); a hint the mod builds itself is joined with `Verbosity.with_hint`.

**The player's schemes** (`VerbositySchemes`, a `Dictionary`): `verbosity.txt`, one line per scheme,
`name=reading:level,reading:level`. No game stamp (`game_bound?` false): a scheme means the same in every game and
imports from any. The active one lives in `settings.ini`, as a symbol with its name.

| Signature | Returns | When to use it |
|---|---|---|
| `VerbositySchemes.levels(name)` | `{reading => level}`, or `nil` | |
| `VerbositySchemes.names` | The names, in order | The rotation and the menu screen |
| `VerbositySchemes.set(name, levels)` / `delete(name)` / `rename(old, new)` | Nothing | They write the file at once |
| `VerbositySchemes.valid_name?(name, except = nil)` | `true`/`false` | Not blank, not a built-in one's (internal or spoken), not another's, case aside |
| `VerbositySchemes.clean_name(name)` | String | One line, with no `=` and no leading `#` |

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
| `DIR_DELTA` | `{ direction => [dx, dy] }` | Step one tile in an RPG direction; the one direction table |

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
| `Hooks.variants(names, meth, label = nil) { |cname| ... }` | The spellings that bound | Hook a screen under EVERY spelling it takes, and report a group that binds nowhere |
| `Hooks.unbound` | Array of `"group#method"` | The groups that bound nowhere; the diagnostic prints them |
| `Hooks.wrap_global(name, tag, timing = :after, &body)` | Nothing | Top-level `Object` method (`pbDisplayMail`...). Yields `(args, x)` |
| `Hooks.wrap_kernel(name, tag, timing = :before, &body)` | Nothing | Same, trying the `Kernel` singleton first. Yields `(args, x)` |
| `Hooks.wrap_singleton(owner, name, tag, timing = :before, &body)` | Nothing | A game module's own singleton method (`Owner.name`). Yields `(args, x)`; absent, it lands in `fn_absent` as `"Owner.name"` |
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
| `Engine.bag_quantity(item)` | Integer, or `nil` when no bag answers | How many of an item without knowing the era |
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
| `I18n.t(key, vars = nil)` | The translated string | All spoken text; `vars` is a `%{name} => value` hash, and `:n` picks the plural form |
| `I18n.plural_form(code, n)` | `"one"`, `"few"`, `"many"` or `"other"`: the form that goes with `n` under the language's CLDR rule | Knowing which form `t` will read |
| `I18n.plural_forms(code)` | The forms that language writes (`%w[one other]`, or `%w[one few many]` in Polish) | Parity |
| `I18n.lang` | The active language symbol: the explicit choice, or what `:auto` resolves to (system, game, English) | Read the language without touching `Config` |
| `I18n.available_languages` | Array of symbols with a file in `lang/` | Language menu |
| `I18n.language_name(code)` | The `__language__` entry, or the code | Human name in the menu |
| `I18n.next_language(code)` | The next in the cycle, `:auto` first | Language toggle |
| `I18n.interpolate(s, vars)` | The string with `%{name}` substituted | Interpolate outside `t`; a missing var yields `""` |
| `I18n.parity_issues` | Array of `"code:key: reason"`; `[]` when in sync | The boot check and the suite |
| `I18n.table(code)` | Key => value hash, cached | Inspect a whole table |
| `I18n.duplicate_keys(code)` | Array of keys repeated in one file | Diagnose a `lang/*.txt` |

`t` never raises: a missing key falls back to the reference language and then to the key name, so the raw key
is what gets spoken. A key written by forms (`key.one=`, `key.other=`...) is looked up in the form that goes
with `vars[:n]`. `parity_issues` covers four faults: a key present in one language and missing in another, a key
duplicated within one file, `%{}` placeholders that differ between languages or forms, and forms that are not
the ones the language's rule asks for (one missing, one extra, or the key written both plain and by forms).

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
| `Data.species_types(id)` | Array of type names; `[]` when unresolved | Types of a species, with no Pokémon to ask |
| `Data.trainer_type_name(id)` | `"Hiker"`, or `nil` for a class the game lacks | A trainer class by number, constant or id |
| `Data.register(priority, provider)` | Nothing | Register a provider: 20 GameData, 10 gen-6, 0 fallback |
| `Data.active` | The active provider, or `nil` | Diagnostics |
| `Data.active_priority` | The active priority, or `nil` | `0` means only the fallback is left |
| `Data.active_entry` | `[priority, provider]`, or `nil` | Diagnostics |
| `Data.resolve(method, arg)` | Whatever the provider returns, or `nil` | The funnel: add a new resolver |
| `Data.errors` | Array of strings; `[]` on a clean run | Provider exceptions, one per `(method, class)` |

`pokemon_types` and `species_types` are the only ones that never return `nil`. The rest answer `nil` whether no provider is
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

## Paint capture, menu return, per-build text and self-check

`core/util/paint_capture.rb`, `core/menus/menu_return.rb`, `core/foundation/game_lang.rb`, `core/util/selfcheck.rb`.

| Signature | Returns | When to use it |
|---|---|---|
| `PaintCapture.arm(tag)` / `PaintCapture.take(tag)` | `take`: the rows painted while `tag` was armed, or `nil` | Reading a screen by what it PAINTS (`drawTextEx`, `pbDrawTextPositions`), which stays correct across per-language builds |
| `PaintCapture.speak_around(tag, interrupt) { nxt.call }` | The block's value | The common shape: arm, run the game's paint, speak what landed, less its key hints while the verbosity leaves them out |
| `PaintCapture.flush_pending(tag, interrupt)` | — | From a per-frame poll, for a tag armed before a blocking loop; filters the hints the same way |
| `MenuReturn.on_return { ... }` | — | A menu with its own loop that re-reads the option on the way back from a submenu; fires on the outermost exit only |
| `MenuReturn.bare("Class", :method)` / `MenuReturn.bare_fn("function")` | — | Declaring a screen that opens with neither a fade nor a dialogue |
| `GameLang.code` / `GameLang.pick(value, fallback)` | `:es`, `:en`, `:fr`... or `nil`; `pick` chooses the build's entry | Transcribed picture text in a game shipped as several per-language builds |
| `SelfCheck.run` | The report lines; writes `data/selfcheck.txt` | The "engine self-check" entry of the configuration menu |

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
| `tone_to_pitch(tone)` | Integer: playback rate in percent for a 0-100 tone | 50 at 0, 100 at 50, 200 at 100: an octave each way |
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

`core/nav/pathfinder.rb` and its parts (`route_search.rb`, `route_grid.rb`, `route_terrain.rb`, `route_events.rb`,
`route_water.rb`, `route_gates.rb`, `route_text.rb`), `core/nav/terrain.rb`,
`core/nav/event_pages.rb`, `core/nav/field_moves.rb` and `core/nav/map_meta.rb`. See
[06-navigation](06-navigation.md).

| Signature | Returns | When to use it |
|---|---|---|
| `Pathfinder.find_path(tx, ty)` | Array of RPG direction codes, or `nil` when there is no route | Route to a tile adjacent to the target; the origin is always `$game_player` |
| `Pathfinder.find_path_onto(tx, ty)` | The same, ending on it | Shores, dive spots: tiles that are stood on |
| `Pathfinder.gated_path(tx, ty)` | `[steps, gate]`, or `nil` | No walking route: up to the first assisted step (a tree or rock, a push, the action button, getting off the bike); `nil` at once where nothing could assist (`assist_possible?`) |
| `Pathfinder.trace(x, y, level, path)` | Array of `Step`, one per press (inside a run, `mid`) | Replay a route with the search's very moves |
| `Pathfinder::Step.new(x, y, level, presses = 1, gate = nil, mid = false)` | A step: `x`, `y`, `level`, `presses`, `gate`, `mid`, and `tile` (`[x, y]`) | What `move_target`, `trace` and an `assist_source` answer |
| `Pathfinder.vehicle_state` | Integer: `map_id * 8`, +4 surfing, +2 diving, +1 on the bike | What the passability memo and the event indexes answer for |
| `Pathfinder.event_epoch` | `[vehicle_state, turns]` | A stored route planned under another value is checked before it is trusted |
| `Pathfinder.path_to_text(path, cut = false)` | `"3 up, 2 left"` | Speak a route; `nil` gives "no route" (with `cut`, "the route could not be calculated from here") and `[]` gives "next to it" |
| `Pathfinder.cuts` | Integer | Searches stopped short so far (budget, node cap, beyond reach): compare it before and after to tell "no route" from "not worked out" |
| `Pathfinder.no_route_text(cut)` | The text for a target with no route | What the guides and the locator say |
| `Pathfinder.legs(path)` | `[[8, 3], [4, 2]]` | Split a route into legs; `nil` and `[]` give `[]` |
| `Pathfinder.leg_text(leg)` | `"3 up"` | Speak one leg (the step guide) |
| `Pathfinder.reachable_set` | `pkey => true` hash, cached per player tile | The hide-unreachable filter and the sonar's line of sight |
| `Pathfinder.flood(water = false)` | `[hash, complete]`, uncached | Force a recomputation; with `true`, crossing water by surfing |
| `Pathfinder.pkey(x, y)` | `x * 100000 + y` | Pack or unpack `reachable_set` keys |
| `Pathfinder.reach` | Integer of tiles (`Config.route_reach`) | The farthest a target may be for the search to consider it |
| `Pathfinder.invalidate_cache(force = false)` | Nothing | After an event that changed passability |
| `Pathfinder.passable_at?(cx, cy, d)` | `true`/`false` | Can one step be taken that way? |
| `Pathfinder.ledge_jump(cx, cy, dx, dy, d)` | The landing `[x, y]`, or `nil` | Is there a ledge hop that way? |
| `Pathfinder.surf_launch(tx, ty)` | Route to the shore whose water leads to the target, or `nil` | The target sits across water |
| `EventPages.outcome(ev, d, at = nil, act = false)` | An `Outcome` (move, transfer, ramp, whether it talks, fights or changes anything, whether it moved with Through), or `nil` | What an event's active page would do when entered facing `d`; `at` is the player's tile, for the conditions that ask; `act` reads it as an action page answered yes |
| `EventPages::ScriptCondition.register_atom(pattern) { \|m, ctx\| ... }` | Nothing | A call of a game's own in conditions; `ctx` holds `:face`, `:pos`, `:self`, `:act`, `:vars` |
| `Pathfinder.touch_source { \|ev\| ... }` | Nothing | A plugin gives its events an effect on arrival (the side stairs' `:run`) |
| `Pathfinder.arrival_rule { \|x, y, d\| ... }` | Nothing | Terrain that moves the player on arrival: `[x, y]`, `false` when the step fails, `nil` when not its own |
| `Pathfinder.leave_rule { \|x, y, dir\| ... }` | Nothing | Terrain left by a move of its own |
| `Pathfinder.held_key_rule { \|x, y\| ... }` | Nothing | Tiles where the key has to be held |
| `Pathfinder.assist_source { \|x, y, dir, level\| ... }` | Nothing | An assisted step a game or plugin adds: a `Step` with its gate, or `nil` |
| `FieldMoves.can?(move)` | `true`, `false`, or `nil` when unreadable | Can the player use that field move? |
| `MapMeta.outdoor?(map_id)` / `MapMeta.dive_map(map_id)` | `true`/`false`/`nil` / the dive map id, or `nil` | Map metadata on both eras |
| `MapMeta.always_bicycle?(map_id)` | `true`/`false` | A map that keeps the player on the bike: no getting off, no Surf |
| `MapMeta.pokecenter?(map_id)` | `true`/`false` | A Pokémon Center: the map declares its healing spot |
| `Pathfinder.blocked_target?(tx, ty)` | `true` when the target is clearly unreachable | Fast reject before a full A* |
| `Pathfinder.path_algorithm` | A symbol from `ALGORITHMS`; `:astar` by default | Read the configured algorithm |
| `Terrain.raw(x, y, count_bridge = false)` | Integer (gen-6) or a `GameData::TerrainTag`, or `nil` | The engine's raw value |
| `Terrain.number(t)` | The `id_number` of a raw value, or `nil` | Normalise the two shapes |
| `Terrain.kind(x, y, count_bridge = false)` | Stable symbol (`:ice`, `:bridge`...), or `nil` | Classify a tile; a gen-6 number goes by the name its `PBTerrain` gives it |
| `Terrain.bridge_holder` / `Terrain.bridge_height` | The object keeping the bridge height (`$PokemonGlobal`, or `$PokemonMap` before v16) / the height, `0` off every bridge | Read the bridge wherever the engine keeps it |
| `Terrain.label(x, y)` | Surface i18n key (`:surf_water`...), or `nil` | Speak the surface underfoot |
| `Terrain.surfable?(t)` | `true`/`false` | Predicate over a terrain VALUE, not coordinates |
| `Terrain.ledge?(t)` | `true`/`false` | Same |
| `Terrain.ice?(t)` | `true`/`false` | Same |
| `Terrain.bridge?(t)` | `true`/`false` | Same |
| `Terrain.grass?(t)` | `true`/`false` | Same (plain, tall or soot grass) |
| `Terrain.flag?(t, flag)` | `true`/`false` | A flag a plugin or a game adds to the modern tag (a current, climbable rock, a rail, a slide) |
| `Terrain.surfable_at?(x, y)` | `true`/`false` | Coordinate variant |
| `Terrain.ledge_at?(x, y)` | `true`/`false` | Coordinate variant |
| `Terrain.ice_at?(x, y)` | `true`/`false` | Coordinate variant |
| `Terrain.number_at(x, y)` | The `id_number`, or `nil` | Coordinate variant of `number` |
| `Terrain.flag_at?(x, y, flag)` | `true`/`false` | Coordinate variant of `flag?` |

`find_path` returns DIRECTIONS, not coordinates: RPG codes 8 up, 2 down, 4 left, 6 right, one per step.
`path_to_text` consumes exactly that. The coordinate variants are `surfable_at?`, `ledge_at?`, `ice_at?`,
`number_at` and `flag_at?`; for `grass?` and `bridge?` you go through `raw(x, y)`.

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
| `Locator.toggle_steps` | Nothing | Flip the step-by-step guide |
| `Locator.register_hazard(re, label_key)` | Nothing | Hazard sprite: a label plus its own cue |
| `Locator.register_teleporter(re)` | Nothing | Sprite that counts as a teleporter |

`show_menu` exists because gen-6 only exposes `Kernel.pbMessage` and modern only the global `pbMessage`;
calling the absent one raises `NoMethodError`.

## Region map

`core/nav/town_map.rb` — the `TownMap` module. Moving the map cursor is the one thing the three
implementations do not share (reading is uniform: `pbGetMapLocation` / `pbGetMapDetails` /
`pbGetHealingSpot` are the same three names in all thirteen games), so this registry exists only for the
fly jump.

| Signature | Returns | When to use it |
|---|---|---|
| `TownMap.register(name, handles, cursor, move, points, flyable = nil)` | Nothing | Register a cursor provider; last registered wins, so a profile overrides the core ones |
| `TownMap.jump_enabled = false` | Nothing | Hand the jump back to the screen, where the game ships one of its own |
| `TownMap.opened(scene)` / `.closed(scene)` | Nothing | Mark the screen open, and release it on close |
| `TownMap.jump(scene, dir)` | `true` if it jumped | Jump to the nearest fly point in that direction |

`handles` is a lambda taking the scene and answering whether this provider recognises it. Dispatch is by
SHAPE (which methods and ivars the scene has) and never by class name or engine version: Arcky's Region Map
and the v21+ rework both declare `PokemonRegionMap_Scene` with the cursor in different ivars. `flyable` is
only needed on a screen that knows its own set of destinations; without it, the generic rule derives it from
`pbGetHealingSpot` plus `visitedMaps`.

`plugins/better_region_map.rb` is a provider registered from the plugins layer, for Marin's BetterRegionMap addon
both Infinite Fusion games install: it is a class of its own, with its own loop, its cursor in `$PokemonGlobal.regionMapSel` and no
`pbGetMapLocation`, so none of the standard map hooks reach it.

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
| `Audio3D.guide_hold(dir, vol = 0, pitch = 100)` | `true` if handled | The cane's sound held toward `dir` (a loop), or stopped with `dir` `nil` |
| `Audio3D.footstep(kind, vol)` | `true` if handled | Footstep, centred on the player |
| `Audio3D.preview(sym, vol, pitch)` | `true` if handled | Menu audition: one channel centred on the player at that volume and pitch |
| `Audio3D.preview_stop(sym)` | Nothing | Cut a looping audition (water, wind) |
| `Audio3D.sync_tones` | Nothing | Send the dll the tones that changed, once per change; `tick` calls it |
| `Audio3D.tone_pitch(sym)` | Percent of the recording | The configured tone of a channel's family (`TONE_KEYS`) |
| `Audio3D.loop?(sym)` | `true`/`false` | Is the channel a loop? |
| `Audio3D.silence_all` | Nothing | Stop every channel |
| `Audio3D.silence_emitters` | Nothing | Stop emitters and loops, keeping steps and bumps (`:basic` mode) |
| `Audio3D.reset_map_state` | Nothing | Drop the previous map's scan |
| `Audio3D.nav_full?` | `true`/`false` | Full mode (all emitters)? |
| `Audio3D.nav_off?` | `true`/`false` | Fully off? Then the engine never even boots |
| `Audio3D.gate_report` | `"n/total playing by=..."`, then clears the window | Why a tick played or fell silent |
| `Spatial.cue(name, volume, pitch = 100)` | Nothing | Play a file from `sounds/`; volume 0 or `nil` plays nothing |
| `Spatial.earcon(name, volume, pitch = nil)` | Nothing | Named earcon from `EARCONS`; the table's pitch is the default |
| `Spatial.tone_factor(key, low = 100, high = 100)` | Float | A family's tone factor for a flat cue, reduced until the `low`/`high` pair fits mkxp's 50-150 |
| `Spatial.guide_tone_factor` | Float | The whole guide family's factor (engine and flat channel): the one that keeps its 140/70 pair inside 50-150 |
| `Spatial.busy?` | `true`/`false` | The player is NOT under free control: the soundscape falls silent |
| `Spatial.busy_reason` | A symbol (`:message`, `:in_menu`, `:battle`...) or `nil` | Name the cause in the diagnostic |
| `Spatial.keys_locked?` | `true`/`false` | Another screen genuinely owns the arrow keys |
| `Spatial.mini_update?` | `true`/`false` | The map is updated from inside a message or menu loop (`in_mini_update`, `$PokemonTemp.miniupdate`) |
| `Spatial.tick` | Nothing | One frame of steps, bumps, radar and surfaces |

`available?` returns the last `Win32API` object of the chain, not a boolean: use it only as a condition.
`busy?` is true during a message or a running interpreter; `keys_locked?` is not, so the locator keys stay
usable during a walkable cutscene. Both hold during the mini update of a menu drawn over the map that sets no
`in_menu` (Insurgence's pause menu); `keys_locked?` not while a message is up in it.

## Battle

`core/battle/battle.rb`, `core/battle/move_info.rb` — modules `Battle` and `MoveInfo`.

| Signature | Returns | When to use it |
|---|---|---|
| `Battle.set_battle(b)` | Nothing | Capture the running battle for the hp and field keys |
| `Battle.clear_battle` | Nothing | Release it; `map_poll` does this every frame |
| `Battle.in_battle?` | `true`/`false` | Is a fight running? `Spatial.busy?` asks this |
| `Battle.hp_phrase(hp, tot, as_percent)` | An hp phrase: percentage or `"hp/total"` | Centralises the branch and the divide-by-zero guard |
| `Battle.battler_state(b, hide_exact = false)` | Name, level, hp, status, its box's marks and stat stages | Describe a whole battler |
| `Battle.icon_mark(pattern, key)` | Nothing | Name a battle box icon of a game's own by its file name (`/\Adelta\z/i`); called by the profile or plugin that draws it, never by core |
| `Battle.shown_marks(b)` | Array of words | The marks that battler's box drew on its last refresh |
| `Battle.announce_hp(foe)` | Nothing | Speak the hp of a WHOLE side; `foe` true reads the opponents as a percentage |
| `Battle.foe_info` | A line covering every opponent, or `nil` | Name, level and type of each foe |
| `Battle.announce_field` | Nothing | Speak weather, terrain and field conditions |
| `Battle.types_of(pk)` | Array of type names; `[]` when nothing resolves | Types via the data provider |
| `MoveInfo.line(name, type_name, power, accuracy, opts = {})` | `"name. type. power. accuracy[. pp][. description]"` | The single assembler of a move line |
| `MoveInfo.by_id(id)` | The line, or `nil` | Resolve through GameData (v21 and v22) |
| `MoveInfo.by_id_via_data(id)` | The line, or `nil` | Resolve through the `Data` adapter, so gen-6 works too |
| `MoveInfo.power_phrase(pw)` | `"no damage"` at ≤ 0, `"variable"` at 1, else the number | Spoken power |
| `MoveInfo.accuracy_phrase(acc)` | `"never misses"` at ≤ 0, else the number | Spoken accuracy |
| `MoveInfo.painted(m, name, type_name)` | `[name, type_name]` unchanged | The name and type the summary's moves page and the fight buttons paint; a game that paints others (Insurgence's custom move) overrides it in its profile |

In `MoveInfo.line`, a `nil` `power` or `accuracy` means UNRESOLVED and omits its phrase; only a real 0 says
"no damage" or "never misses". The options are `:pp` and `:total_pp` (both needed to speak pp) and `:desc`,
appended when non-blank.

## Pokémon summary

`core/party/summary.rb` — module `Summary`: the pieces the summaries share. A game's own pages and their hooks
live in its profile and build their text with these.

| Signature | Returns | When to use it |
|---|---|---|
| `Summary::STAT_ROWS` | `[[index, key], ...]` | The stock stat order: HP, Attack, Defense, Special Attack, Special Defense and Speed, last although its index is 3 |
| `Summary.eviv_rows(pk, rows = STAT_ROWS)` | Array of spoken rows | A page's EVs and IVs, one per stat, in the stock order or the one the engine numbers them in |

## Contextual info

`core/field/contextual.rb` — module `Info`. What the information key reads.

| Signature | Returns | When to use it |
|---|---|---|
| `Info.set_info(kind, data, row = nil)` | Nothing | Publish what the info key will read and, in `row`, the focused row whole, as Full says it, for Ctrl+T |
| `Info.add_to_row(text, slot)` | Nothing | Add to Ctrl+T's row a window that goes with it (the shop's count in the bag), until the next `set_info`; one per slot |
| `Info.row_text` | The row and its windows, or `nil` | What Ctrl+T says; with no row, Ctrl+T says what the info key does |
| `Info.info_text` | The current context's text, or `nil` | The key calls it; a reader rarely needs it |
| `Info.clear_combat` | Nothing | Forget the battle context when the fight ends (`Game_Temp#in_battle=` and `Battle.battle_ended`) |
| `Info.clear_text` | Nothing | Let go of a parked `:text` line when the screen that published it closes |
| `Info.move_info(m)` | The move line, or `nil` | Describe a move object |
| `Info.move_by_id_info(pk, moveid)` | The line, or `nil` | Resolve the move on a Pokémon and publish it |
| `Info.move_info_by_id(moveid)` | The line, or `nil` | Describe from a bare id (the forget screen) |
| `Info.item_info(itemid)` | Name, description and, on a TM, the move it teaches | |
| `Info.pokemon_info(pk)` | Name, level, hp, marks (shiny as `Party.shiny_word` says it, Pokérus, Exp. Share), sign, held item and status | Quick glance |
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

On the map, the key says the trainer: `Locator.refresh_info` publishes it every frame, except while a menu with
help is open (`CommandHelp.current`), whose help is what it must say. The pause menus whose loop does not update
the map (Neo, the button menus, Royal's grid) publish it themselves on a cursor move and back from a submenu, as
the DP menu does on every `update`.

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
| `info_window(cname, key, slot, opts = {})` | Whether the class took the binding | A standing window of one of this game's screens (see `InfoWindow`) |
| `hall_of_fame(*cnames)` | Nothing | This game's clones of the Hall of Fame screen: each named class gets the family's readers (panel, banner and trainer box) |
| `poll_each_frame(&blk)` | Nothing | `Keys.on_frame`, for menus with their own loop |
| `trainer_part(key, &reader)` | The key | Defines or replaces one part of the trainer line (ribbons instead of badges, coins instead of money). Yields the player object; a new key joins the end |
| `trainer_order(keys)` | The order set | Order of the trainer line's parts; a part left out is not spoken |
| `diag_section(name, group = :scene, &body)` | Nothing | `Keys.register_diag_section` |
| `config(key, value)` | The assigned value | Override a `Config` setting |
| `button_labels(map)` | The resulting hash | Merge the game's own button relabels |
| `key_hints(map)` | The resulting hash | Which letters painted in its hints are buttons (`KeyHints`) |
| `remap_extra(sym, default_vk, label)` | Nothing | A remappable extra action |
| `puzzle(map_id, opts)` | Nothing | `Puzzles.register` |
| `hazard(pattern, label)` | Nothing | `Locator.register_hazard` |
| `teleporter(pattern)` | Nothing | `Locator.register_teleporter` |
| `transfer_script(pattern)` | Nothing | A call of the game's own that moves the player; the pattern captures the map |
| `field_move_item(move, item)` | Nothing | An item standing in for a field move (`FieldMoves.register_item`) |
| `script_condition(pattern, &reader)` | Nothing | `EventPages::ScriptCondition.register_atom` |
| `terrain_rule(&rule)` | Nothing | `Pathfinder.arrival_rule` |
| `held_key_ground(&rule)` | Nothing | `Pathfinder.held_key_rule` |
| `terrain_exit(&rule)` | Nothing | `Pathfinder.leave_rule` |
| `assisted_step(&blk)` | Nothing | `Pathfinder.assist_source` |
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

## Tags, markers and names

`core/foundation/dictionary.rb`, `tags.rb`, `marks.rb`, `map_names.rb` — the `Dictionary` module and the
three dictionaries that extend it: `Tags`, `Marks` and `MapNames`. Shareable text files under `data/`.

The three keep a different key but share one plumbing, which lives once in `Dictionary`: load the file,
merge `*_import.txt` adding **only what the store lacks**, copy to `*_export.txt`, and save with a header.
Each dictionary declares `FILE` / `IMPORT` / `EXPORT` and six hooks that know its shape: `header`,
`parse_line`, `each_stored`, `has_entry?`, `put_entry` and `line_for`.

| Dictionary | Key | File | Line |
|---|---|---|---|
| `Tags` | map + event | `tags.txt` | `87:43=Middle plate<TAB>cat=extras<TAB>hide` |
| `Marks` | map + tile | `marks.txt` | `87:15,17=Middle plate` |
| `MapNames` | map | `map_names.txt` | `87=Bastion, ground floor` |

**Game stamp.** The keys are map ids, and an id means something else in every game: a Pokémon Z tag file
dropped into Añil imports without a single error and names random events. So `save` writes
`# game: <profile>` in the header (`Game.profile_name`: the first `Game.define`, else the installer's stamp
in `installed.json`) and `import_status` refuses a file from another game, both from the menu and in the
automatic merge on load. A file with no stamp, from before this existed, imports as it always did. A store whose
entries mean the same in every game says so with `game_bound?` false and neither stamps nor refuses: that is the
verbosity schemes' case (see [Verbosity](#verbosity)).

| Signature (shared by the three) | Returns | When to use it |
|---|---|---|
| `store` | The store hash | Inspection; loads and merges the import on first use |
| `reload!` | Nothing | Forget what is loaded and reread the file (tests, after deleting it) |
| `import_status` | `[:none]`, `[:foreign, game]` or `[:ready, game]` | Whether an import can run, and if not, why |
| `import_now` | Number of new entries | Merge `*_import.txt`; `0` when missing or from another game. Once merged it is renamed `*_import.imported.txt`, so it is not merged again at every load, bringing back what the player deleted since |
| `export` | Number of entries written, or `nil` when there are none | Dump to `*_export.txt` to share |
| `count` | Number of entries | |

| Own signature | Returns | When to use it |
|---|---|---|
| `Tags.get(mid, eid)` | The custom label, or `nil` | The name the player gave an object |
| `Tags.set(mid, eid, label)` | Nothing | Set and persist it; `""` clears the name only |
| `Tags.category(mid, eid)` | Forced category symbol, or `nil` for automatic | |
| `Tags.set_category(mid, eid, cat)` | Nothing | `nil` returns to automatic |
| `Tags.hidden?(mid, eid)` | `true`/`false` | Did the player hide it? |
| `Tags.set_hidden(mid, eid, val)` | Nothing | Hide or show |
| `Tags.delete(mid, eid)` | Nothing | Forget the whole record (the menu's "Delete") |
| `Tags.each_record(&blk)` / `each_hidden` | Nothing | Walk everything, or only what is hidden. Yield `(map_id, event_id, record)` |
| `Marks.get(mid, x, y)` | The marker's name, or `nil` | |
| `Marks.set(mid, x, y, name)` | Nothing | Name and persist; blank removes it |
| `Marks.delete(mid, x, y)` | Nothing | |
| `Marks.on_map(mid)` | `[[x, y, name], ...]` in reading order | The targets of the `:marks` category |
| `Marks.any_on?(mid)` | `true`/`false` | Whether the map offers the category |
| `Marks.each_mark(&blk)` | Nothing | Walk them all. Yields `(map_id, x, y, name)` |
| `MapNames.get(mid)` | The custom name, or `nil` | It also changes how exits to that map are announced |
| `MapNames.set(mid, name)` | Nothing | Set and persist; empty restores the game's own name |
| `MapNames.delete(mid)` / `each_name` | Nothing | Forget one; walk them all, yields `(map_id, name)` |

A `Tags` record disappears only once it has no name, no category and no hidden flag: `prune` does that
internally after every write. `Tags.delete` is the other door, a deliberate one: the player asks for it from
the menu, an empty write never does it.

In the game: `Ctrl`+`G` creates, edits or deletes the marker on the player's tile (one text box; blank
deletes); `Shift`+`K` and `Ctrl`+`K` act on a selected marker as they do on an object; and the mod menu, under
"Personalization", imports and exports each dictionary and the verbosity schemes (or everything at once) and lists
each dictionary to rename, delete or show again.

## The mod's menu

`core/menus/config_menu.rb` (the frame: the modal loop, the stack of screens, the rows and how they are said),
`config_rows.rb` (the settings, the sound glossary and debug), `config_dicts.rb` (Personalization: the editable
lists, import and export), `config_verbosity.rb` (verbosity and its schemes) and `config_remap.rb` (remapping keys):
one `ConfigMenu` module split by responsibility, as the pathfinder is.

Each screen is a list of rows `{:kind => ..., ...}`: `:setting` (a SCHEMA row), `:enter` (opens another screen),
`:action`, `:entry` and `:entry_action` (the dictionaries' lists), `:scheme`, `:scheme_action` and `:reading`
(verbosity), `:sound`, `:note`, `:remap` and `:back`. A row may carry `:help`, the key the info key says. The list
is memoised per state and per the stores' write counters, so a change made with the menu open rebuilds it without
anyone being told.

In a scheme's editor each reading is a row: left and right move its level and the scheme is saved at once.
Deleting asks for a second press in a row on the same row; moving away forgets the question.

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

`core/input/key_hints.rb` — module `KeyHints`: the key hints the games paint ("[A] Curar", "D: Buscar", "Pulsa C
para acceder") said with the key the player uses today. With a button rebound in the mod's remap (which silences
the engine's own key), its letter becomes the bound key; else, where mkxp-z answers the game's input, the key its
F1 menu left the button on (`NativeKeys`); with none of that the text is unchanged. It only acts on the letters the
profile declares buttons (`key_hints` in the DSL), so a check box "[X]" or a compass point "[S]" is never taken for
a key.

| Signature | Returns | When to use it |
|---|---|---|
| `KeyHints.localize(text, letters = nil, sentences = false)` | The text with each moved button's letter swapped | In readers that read hints: brackets, "X: action" and, with `sentences`, "press X" |
| `KeyHints.key(sym, painted)` | The key bound in the mod, else F1's, else `painted` | The mod's own text naming a key (`%{key}`) |
| `KeyHints.bound_name(sym)` | The bound key's name, or `nil` | Whether a button is rebound |
| `KeyHints.table` | The profile's letter table | The one `localize` uses by default; a profile overrides it when its hints follow its own key menu |
| `KeyHints::RGSS_LETTERS` | RPG Maker XP's default letters | The table of a game that keeps them |
| `KeyHints::HINT` | The shape of a painted hint | "[C]: …" leading, or a verb asking for a key ("Pulsa…", "Press…"), in the games' languages |
| `KeyHints.gate(lines)` | The lines less their hints while the verbosity leaves them out | A hint with a figure keeps the figure ("Vial (2/3)"); one that goes takes the label it hangs from ("LISTA DE TARJETAS:") |
| `KeyHints.gate_sentences(text)` | The text less its hint sentences | A sentence ends at a stop before a space or the end, so a figure ("6.9 kg") stays whole; a text with no hint is left as it is |

Readers that already apply it: the pause panel, the summary's hints, the trainer card, the v21 party's boxes line,
option help (both eras), achievements, tip cards, the EV allocator and modal panels.

Royal paints the key its F1 menu gives each button (`KeybindingReader`), so its profile (`games/royal/key_hints.rb`)
overrides `KeyHints.table` with those same names: a letter F1 moved to another button is read as that button's.

`core/input/native_keys.rb` — module `NativeKeys`: what mkxp-z's F1 menu saved in `keybindings.mkxp1`, in
`System.data_directory`. Three header words (format, RGSS version, count) and four per binding (source type, SDL
scancode, unused, button); only keyboard bindings of the eight standard buttons count. It is read again when the
file changes. Only in games whose input mkxp-z answers: those that read the keyboard in Ruby (Africanus, Armonía,
Awakening, Ópalo, Realidea, Reminiscencia) define `Input.getstate`, and F1 never reaches their game.

| Signature | Returns | When to use it |
|---|---|---|
| `NativeKeys.name(sym, painted)` | The name of the key F1 left the button on, or `nil` while the painted one still works | Used by `KeyHints.key`: a letter first, then any key but a modifier |
| `NativeKeys.active?` | Whether there are F1 bindings to go by | `localize`'s shortcut with no rebinds |
| `NativeKeys.parse(data)` | `{action => [virtual keys]}` | Reading a file (specs) |

The mod's own keys are listed in the same remap screen, after the game's buttons. A help text that names one
carries `%{key_<action>}` (`%{key_field}`, `%{key_prev}`...) and `ConfigMenu.key_vars` fills it with the key as set.
A mod key may ship unassigned (`nil` in `KEY_DEFAULTS`, as the verbosity rotation does): it is never pressed, and
left arrow in the remap list puts it back that way. A default key a saved binding already uses (a key new in this
version that the player had given to something else) loads unassigned, so the saved binding keeps working
(`Settings.drop_taken_defaults`).

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

### Information windows

`core/menus/info_window.rb` — module `InfoWindow`. The standing window a screen writes with `text=` and
repaints as the cursor moves: where a contact lives, how many are registered, how many species the dex
has seen, what the focused option does. The global listeners on `Window_AdvancedTextPokemon` are narrowed
on purpose, so these windows are declared ONE BY ONE instead of widening the listener.

| Call | Returns | What for |
|---|---|---|
| `InfoWindow.watch(cname, key, slot, opts = {})` | Whether the class took the binding | Declares the `key` window of scene `cname` with its dedup slot. `:interrupt` for a caption that answers a keypress, rather than queueing |
| `InfoWindow.watches` | Array of `[class, key, slot, interrupt]` | The declared windows |
| `InfoWindow.silent` | Array of `"Class.key"` | Declared windows the scene does not have: a reader that can never speak. The diagnostic prints them |
