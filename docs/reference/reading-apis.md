# Reading APIs

This page lists the calls a reader uses to speak, detect changes, read command windows, capture painted text, publish
to the info key, apply verbosity and treat key hints, with their signatures. The way these parts work together is
explained in [Readers](../architecture/readers.md); the hook registrars are in the [hooks API](hooks-api.md) and the
profile shortcuts in the [profile DSL](profile-dsl.md). Every module is under `PokeAccess`.

## Speech calls

`core/speech/speech.rb`, `core/speech/text.rb`, `core/speech/backend.rb`.

- `PokeAccess.speak(text, interrupt = true, category = nil)`: speaks a line with its whitespace collapsed; an empty line
  is dropped. `interrupt` false queues the line. A nil `category` takes the innermost `Speech.as` block's, else the
  moment's ([Speech categories](../architecture/speech-and-languages.md#speech-categories)). Hands a
  `Speech::Message` to every observer, then the line to the screen reader.
- `PokeAccess.speak_clean(text, interrupt = true, category = nil)`: `speak` after `clean`, for game text.
- `PokeAccess.clean(message)`: game text made speakable. Substitutes the player's name and money codes and `\V[n]`,
  turns a name-box code into the speaker and a colon, removes other codes and tags, reads `<br>` as a space and decodes
  the five character entities.
- `PokeAccess.clean_fields(text)`: `clean` for a panel; the separator tags `<r>`, `<br>` and `<ac>` become `", "`, and a
  digit-grouping comma stays.
- `PokeAccess.sentences(parts)`: joins parts as sentences; a part that already ends in `.`, `!`, `?` or `:` takes no
  second mark, and empty parts are left out.
- `PokeAccess.speaker_name(raw)`: the name a name box shows, after the profile's name filters; a name made of question
  marks is said as `msg_speaker_unknown`.
- `PokeAccess.register_name_filter { |name| ... }`: adds a rule that answers the name to speak for a name-box code, or
  nil to keep it.
- `PokeAccess.last_spoken`: the last non-empty line spoken, or nil.
- `PokeAccess.spoken_seq`: how many lines were spoken this session.

### Dialogue

`core/dialogue/dialogue.rb`.

- `PokeAccess.say_dialogue(message)`: cleans, remembers and queues a dialogue line, led by a pending head and followed
  by a pending tail. The same cleaned line within half a second is remembered and not spoken again.
- `PokeAccess.say_dialogue_skip(message, head = nil)`: remembers a line for Shift with the info key without speaking it,
  so the copy the engine routes through the message hooks next is not spoken.
- `PokeAccess.say_screen_message(args)`: `say_dialogue` of `args[0]` when it is a non-empty String.
- `PokeAccess.before_next_line(text)`: a head said once before the next dialogue line, as `head: line`; nil drops a
  pending one.
- `PokeAccess.lead_with_name_window(win)`: heads the next dialogue line with the speaker's name that a window over the
  message shows; drops a pending head when that window is hidden or empty.
- `PokeAccess.after_next_line(text)`: a line said once after the next dialogue line.
- `PokeAccess.note_dialogue(text)`: remembers a non-blank line for Shift with the info key.
- `PokeAccess.last_dialogue`: the remembered dialogue line, or nil.
- `PokeAccess.message_depth`: how many messages `pbMessageDisplay` shows now, one inside another.
- `PokeAccess.dialogue_category`: `:battle` during a fight, else `:dialogue`.

### Money windows

`core/menus/money_window.rb`.

- `PokeAccess.money_window_text(win)`: the cleaned text of a money, coins or points window, or nil.
- `PokeAccess.say_money_window(win)`: speaks that text, queued after the message line. The stock builders a message
  opens (`\g`, `\cn`, `\pt` and those games add) go through it.
- `PokeAccess::MoneyWindow.watch { ... }`: runs the block with its hand-built money window watched and returns the
  block's value. The first `Window_UnformattedTextPokemon` sized while the block runs is taken for that window. Its
  text is said, queued, when the window is made, and again each time it changes. Core watches the Triple Triad card
  shop; Insurgence's profile and `games/royal_common/`, for Royal and World Frontier, watch the functions of theirs
  that build one.

### Speech categories and observers

`core/speech/categories.rb`, `core/speech/speech.rb`.

- `Speech.as(category) { ... }`: files every line said inside the block under `category`; the innermost block wins.
- `Speech.category_of(given)`: `given`, else the innermost block's category, else `Speech.deduce`.
- `Speech.deduce`: `:battle` in a fight, `:dialogue` under a message, `:nav` on the map, else `:menu`.
- `Speech.label(category)`: the i18n key of a category's name, or nil.
- `Speech.observe(key) { ... }`: registers a block that gets every `Speech::Message`; the same key replaces it.
- `Speech.unobserve(key)`: removes the observer registered under `key`.
- `Speech::Message`: a Struct of `text`, `category`, `interrupt` and `seq`.
- `Speech::CATEGORIES`: `:dialogue`, `:battle`, `:menu`, `:nav`, `:info` and `:system`, each with its `msg_cat_*`
  key.
- `Speech::REVIEW`: the category of the history's own readouts, which the history never files.

An observer that raises is logged once and passed over.

### Screen reader bridge

`core/speech/backend.rb`. The bridge is `prism_pea.dll`. Without it, every call does nothing and answers false, nil or
an empty string.

| Call | Returns |
|---|---|
| `PokeAccess.voice_out(text, interrupt)` | Hands a ready line to the screen reader; the test harness replaces it |
| `PokeAccess.stop_speech` | true when the reader stopped |
| `PokeAccess.pause_speech`, `PokeAccess.resume_speech` | true when the backend obeyed; NVDA ignores both |
| `PokeAccess.speaking?` | true, false, or nil when the backend cannot tell |
| `PokeAccess.braille(text)` | true when the braille display took the text |
| `PokeAccess.braille_codepoints(cps)` | `braille` of Unicode code points (BMP only) |
| `PokeAccess.speech_backend` | The backend's name, such as `"NVDA"`, or `""` |
| `PokeAccess.speech_ready?` | true once the bridge started |
| `PokeAccess.init_speech!` | Starts the bridge once; a failure stays until `retry_init!` |
| `PokeAccess.retry_init!` | Forgets a failed start and tries again (Ctrl+Alt+F8) |

## PokeAccess::Cursor

`core/menus/cursor.rb`. Change detection. The record for `slot` lives in an instance variable of `holder`, or in a
module-wide table when `holder` is nil; `:@x` and `:x` name the same slot. The table is cleared on every map change.

- `Cursor.changed?(holder, slot, key)`: true when `key` differs from the recorded key, and records it; false when equal
  or when `key` is nil.
- `Cursor.on_change(holder, slot, key) { ... }`: the block's value when `key` changed, else nil.
- `Cursor.announce(holder, slot, key, interrupt = true, first_interrupt = nil) { ... }`: when `key` changed, speaks the
  block's line cleaned, under `:menu`, and answers true. `first_interrupt`, when not nil, replaces `interrupt` for the
  first read of a fresh or reset slot. A blank line keeps `key` pending for up to `Cursor::RETRY_FRAMES` (20) polls; a
  block that raises is logged once and does not retry.
- `Cursor.pending?(holder, slot)`: true while the slot holds no key, or only a retry marker. Ask it before `changed?`.
- `Cursor.current(holder, slot)`: the recorded key, or nil.
- `Cursor.store(holder, slot, val)`: records `val` in the slot.
- `Cursor.reset(holder, slot)`: clears the slot, so the next read speaks on the same key.
- `Cursor.reset_global`: clears the module-wide table.

## Command windows and focus readers

`core/menus/menus.rb`, `core/menus/focus_reader.rb`, `core/menus/info_window.rb`, `core/menus/screen_title.rb`,
`core/foundation/const.rb`.

- `Menus.def_extractor(cname) { |win, i| ... }`: registers the text of the focused option `i` for a window class. The
  extractor of the most derived class wins, the first registered on a tie. `screen_reader` in a profile.
- `Menus.focused_text(win)`: the focused option's text through the extractors, else `generic_focus`.
- `Menus.generic_focus(win, i)`: entry `i` of the first list among `Menus::LIST_IVARS` that holds one, as text (a
  String, a Symbol, or a non-empty `name` or `text`), or nil.
- `Menus.close_row(key)`: the text of i18n key `key`, also published to the info key as a ready line.
- `Menus.poll_sprite_menu(scene, items_ivar, dedup_slot) { |entry| ... }`: speaks the block's name for the entry of
  `items_ivar` at the scene's `@index` when the index changes.
- `Menus.opening_on(row) { ... }`: runs an opener whose command list starts on `row`; a first read on another row in
  the same pulse waits.
- `FocusReader.define(cname, opts = {}) { ... }`: a reader for a screen whose cursor is an index. `focus_reader` in a
  profile. Options:
  - `:on`: the method hooked, `:update` by default.
  - `:index`: an ivar symbol (`:@index` by default) or a `@sprites` key; a key also claims that window.
  - `:items`: the ivar of the list the index points into.
  - `:slot`: the change-detection slot, `:"focus_<cname>"` by default.
  - `:queue`: false lets the first read interrupt too; by default it is queued.
  - `:key`: a proc of the scene, the index and the entry giving what must change for a new read; by default the
    entry and the index with `:items`, else the index.
  - `:optional`, `:hook_container`: passed to the hook.

  The block gets the entry, the index and the scene with `:items`, else the index and the scene, as many as it takes.
  It returns the line; nil says nothing.
- `InfoWindow.watch(cname, key, slot, opts = {})`: reads the window `key` of the scene's `@sprites` when its text
  changes, while a scene of class `cname` runs. `info_window` in a profile. Answers true when an opener bound. Options:
  - `:interrupt`: later reads interrupt; the first read in a scene is always queued.
  - `:open`: the game's own opener, tried besides `InfoWindow::OPENERS` (`pbStartScene` and `start`).
  - `:close`: the game's own close, in place of `InfoWindow::CLOSERS` (`pbEndScene`).
  - `:optional`: a window that only one of two layouts has; its absence is never recorded in `InfoWindow.silent`.
  - `:reading`: a `[reading, level]` pair; the window is said from that level up and always joins Ctrl+T.
- `ScreenTitle.say(scene)`: says the title a list screen paints in its corner (`@sprites["header"]`, which the generic
  readers leave unsaid) once per scene, queued, ahead of the first row; nothing where the scene paints none. Hooked
  before the screen's per-frame update.

### Introspection helpers

| Call | Returns |
|---|---|
| `PokeAccess.ivar(obj, sym, fallback = nil)` | An instance variable, nil when unset, `fallback` when the read raises |
| `PokeAccess.ivar_i(obj, sym, fallback = 0)` | `ivar` as an Integer |
| `PokeAccess.attr_of(obj, *names)` | The first non-nil answer among the accessors |
| `PokeAccess.sprite(scene, key)` | The sprite `key` of the scene's `@sprites`, or nil |
| `PokeAccess.const_at(name)` | The constant named `"A::B"`, or nil |
| `PokeAccess.dedicate(win)` | Claims `win` for a dedicated reader; the generic readers skip it |
| `PokeAccess.dedicated?(win)` | Whether a reader claimed `win` |

## PokeAccess::SceneWatcher

`core/menus/scene_watcher.rb`. For a screen that runs its own blocking loop.

- `SceneWatcher.wire(cls, meth, reader, opts = {})`: an around-hook on `cls#meth` calls `reader.watch(scene)` before
  the loop and `reader.unwatch` after it, and a poller calls `reader.poll` on every pulse. `opts` goes to the hook,
  such as `:optional => true`. Where the class is absent the hook binds nothing; the poller is registered anyway.
- `SceneWatcher.reader(cls, meth, slot, opts = {}) { |scene| ... }`: `wire` with a generated reader, which it returns.
  The block gets the held scene and returns `[key, text]`; anything else skips the frame. `Cursor.announce` speaks
  `text` when `key` changes, and a `text` that responds to `call` is called only then. The first read after the scene
  opens is queued and later ones interrupt; `:queued => true` queues every read.

Leave the block with `next`. Under Ruby 1.8.7 a `return` raises `LocalJumpError`, which the poll logs once. Under
Ruby 3 it raises nothing: it acts as a `return` from the top-level code, which ends the script that runs the poll.

## PokeAccess::PaintCapture

`core/util/paint_capture.rb`. A row is `[text, source, x, y]`, in paint order; `x` and `y` are nil when the function
gives no position. One tag is armed at a time, and arming replaces the previous tag.

| Function wrapped | Feeds |
|---|---|
| `drawTextEx` | Armed captures, source `:dtex` |
| `pbDrawTextPositions` | Armed captures, source `:positions` |
| `drawFormattedTextEx` | Armed captures, source `:formatted` |
| `pbDrawShadowText` | `shadow_sample`, never an armed capture |
| `pbDrawImagePositions` | `icons` and `icon_rows` only |

Each of the four text functions also feeds `recent`.

### Capturing

- `PaintCapture.arm(tag)`: starts a capture under `tag`.
- `PaintCapture.armed?(tag)`: true while `tag` is armed.
- `PaintCapture.pending?(tag)`: true while `tag` is armed and at least one row landed.
- `PaintCapture.sample { ... }`: the rows the block draws, as `take_pairs` gives them, under a tag of its own; a
  capture already armed is restored after.
- `PaintCapture.speak_around(tag, interrupt) { ... }`: arms `tag`, runs the block, speaks the rows through
  `KeyHints.gate` and `text`; returns the block's value.
- `PaintCapture.flush_pending(tag, interrupt)`: from a poller, speaks the rows of a tag armed before a blocking loop
  once some have landed, as `speak_around` does.
- `PaintCapture.shadow_sample { ... }`: the strings the block draws with `pbDrawShadowText`.
- `PaintCapture.icons { ... }`: the image paths the block draws; an enclosing `icons` gets them too.
- `PaintCapture.icon_rows { ... }`: the images the block draws as `[path, x, y, source x, source y]`; an enclosing
  `icon_rows` gets them too.
- `PaintCapture.note(text, source = :dtex, x = nil, y = nil)`: records one string, as the wrappers do.

### Taking the rows

Each `take` call disarms the tag, so a second call finds nothing.

| Call | Returns |
|---|---|
| `PaintCapture.take(tag, source = nil)` | The texts, of one source when given; nil when `tag` is not armed |
| `PaintCapture.take_pairs(tag)` | The rows; `[]` when `tag` is not armed |
| `PaintCapture.take_by_source(tag)` | `{source => [text, ...]}`; `{}` when `tag` is not armed |
| `PaintCapture.take_laid_out(tag, source)` | One source's texts in reading order; `[]` when not armed |

### Laying out

- `PaintCapture.laid_out(pairs)`: the texts by `y`, then `x`; rows without a position follow in paint order.
- `PaintCapture.lines(pairs) { |row| ... }`: one line per height, top to bottom, each joined left to right and
  cleaned; rows without a position are left out, and the optional block filters the rows.
- `PaintCapture.pair_labels(rows)`: rows trimmed, blanks dropped, and a row ending in a colon joined to the next.
- `PaintCapture.text(rows, dedup = true)`: the rows as one line, joined with `", "` and cleaned; repeats dropped unless
  `dedup` is false.
- `PaintCapture.recent`: the last `PaintCapture::RECENT_MAX` (40) distinct strings drawn, captured or not, as
  `"source:text"`.

## PokeAccess::Info

`core/field/contextual.rb`. What the info key says. Pressing the key runs `Keys.info_key` (`core/input/input.rb`): with
Shift, the last dialogue line; with Ctrl, `Info.row_text` when the screen published a row; else `Info.info_text`.

- `Info.set_info(kind, data, row = nil)`: publishes what the info key says next, and the focused row whole for
  Ctrl+T, or nil where the screen has none. Clears the windows added to the previous row.
- `Info.add_to_row(text, slot)`: adds a standing window of the focused row to Ctrl+T, one text per slot, until the next
  `set_info`.
- `Info.row_text`: the row and its windows as sentences, or nil.
- `Info.info_text`: the line of the published kind.
- `Info.clear_text`: forgets a published ready line; other kinds stay.
- `Info.clear_combat`: forgets a published move, foe or ready line; runs when a battle ends.
- `Info.map_owner(name) { ... }`: registers a block that answers the info key on the map, or nil to pass; the same name
  replaces it. Owners are asked in registration order.
- `Info.map_text`: the first owner's answer, else the forced-movement lines, else `trainer_info`.

| Kind | `data` | The info key says |
|---|---|---|
| `:move` | A move object | `Info.move_info(data)` |
| `:item` | An item id | `Info.item_info(data)` |
| `:pokemon` | A Pokémon | `Info.pokemon_info(data)` |
| `:trainer` | Unused | `Info.trainer_info` |
| `:battle_foe` | Unused | `Battle.foe_info` |
| `:text` | A ready line | The line |
| `:map` | Unused | `Info.map_text` |

### Line builders

- `Info.move_info(m, reading = nil)`: type, category, power, accuracy, PP and description; with `reading`, the parts
  that reading's level says.
- `Info.move_by_id_info(pk, moveid, reading = nil)`: `move_info` of the Pokémon's move with that id, publishing it.
- `Info.move_info_by_id(moveid, reading = nil)`: `move_info` of a move known by id, publishing it; its name alone
  where no move object can be built.
- `Info.item_info(itemid)`: name, description and the move a machine teaches.
- `Info.note_item_desc(id, desc)`, `Info.noted_item_desc(id)`: a description a screen shows for an item, used ahead of
  the data's.
- `Info.pokemon_info(pk)`: name, level, HP, marks, gender, held item and status; an egg says only that it is an egg.
- `Info.summary_text(pk, dex = nil, id = nil)`: the whole data sheet of a Pokémon and its first page's trainer lines.
- `Info.trainer_info`: the trainer line, the parts of `Config.trainer_parts` that answer, in that order.
- `Info.set_trainer_part(key) { |player| ... }`: defines or replaces a part of `Info::TRAINER_PARTS`; a new key joins
  the end of the order. `trainer_part` in a profile; `trainer_order` sets the order.

The default parts are `:name`, `:money`, `:badges`, `:pokedex` and `:playtime`.

### Claiming the key

- `Keys.yield_key!(name)`: called each frame a game screen answers a mod key itself; the key does nothing for four
  pulses.
- `Keys.yielded?(name)`: whether a screen claimed the key.

## PokeAccess::Verbosity

`core/speech/verbosity.rb`. A part is `[text, level]`, the level being the lowest that says the text; a bare string is
a full-level part.

| Constant | Value |
|---|---|
| `Verbosity::LEVELS` | `[:brief, :medium, :full]` |
| `Verbosity::LEVEL_KEYS` | Each level's name key: `vb_level_brief`, `vb_level_medium`, `vb_level_full` |
| `Verbosity::OTHERS` | `:others`, a scheme's level for the readings it does not name |
| `Verbosity::GROUPS` | `:general`, `:map`, `:battle`, `:pokemon`, `:items`, `:dex`, `:game`, with `vbg_*` keys |

### Building rows

- `Verbosity.line(reading, parts, sep = ", ")`: the non-blank parts the reading's level reaches, joined with `sep`.
- `Verbosity.kept(reading, parts)`: those parts' texts, in order.
- `Verbosity.full_line(parts, sep = ", ")`: every non-blank part, as the full level says the row.
- `Verbosity.info_line(reading, parts, sep = ", ")`: publishes `full_line` to the info key as a ready line and a row,
  and returns `line`.
- `Verbosity.whole { ... }`: runs the block with every reading at full and returns its value.
- `Verbosity.join(texts, sep)`: `texts` joined; with `". "`, joined as sentences.
- `Verbosity.keep?(reading, from)`: whether a part said from level `from` up goes into the reading's row.
- `Verbosity.level(reading)`: the reading's level under the active scheme; full inside `whole`.
- `Verbosity.list_entry(name, n, tot)`: `"name, n of tot"` while positions are said, else the name.
- `Verbosity.position(i, n)`: `"i of n"` while positions are said, else nil.
- `Verbosity.hints?`: whether key hints are said (`:hints` at medium or full).
- `Verbosity.with_hint(text, hint, sep = ". ")`: `text` followed by `hint` while hints are said.
- `Verbosity.descriptions?`: whether descriptions are said (`:descriptions` at full).

### Readings

- `Verbosity.define_reading(reading, name_key, help_key, group)`: declares a reading for the scheme editor; declaring
  it again replaces it in place. An unknown group is logged and becomes `:game`.
- `Verbosity.readings`: the declared readings as `[reading, name key, help key, group]` rows.
- `Verbosity.readings_in(group)`: the rows of one group, in declaration order.
- `Verbosity.reading_row(reading)`: one reading's row, the `OTHERS` row, or nil.
- `Verbosity.reading_name(reading)`: a reading's spoken name.

Core declares these readings, each with the name key `vb_<reading>` and the help key `vbh_<reading>`:

| Group | Readings |
|---|---|
| `:general` | `:positions`, `:hints`, `:descriptions` |
| `:map` | `:room_note`, `:route_transfers`, `:teleport` |
| `:battle` | `:battle_move`, `:battle_marks` |
| `:pokemon` | `:party`, `:summary_move`, `:learn_move`, `:ribbon` |
| `:items` | `:bag_item`, `:shop_item`, `:pc_slot` |
| `:dex` | `:dex_entry`, `:dex_page` |

Plugins and profiles declare more; `rg -n "Verbosity.define_reading" plugins games` lists them.

### Schemes

- `Verbosity.active`: the scheme in use, a level or the name of a player's scheme as a Symbol; `:full` when that
  scheme is gone.
- `Verbosity.rank(level)`: the level's place in `LEVELS`; an unknown level is logged and ranks as full.
- `Verbosity.level_in(levels, reading)`: the level a `{reading => level}` hash gives a reading, else its `OTHERS`
  level, else full.
- `Verbosity.rotation`: the built-in schemes, then the player's by name.
- `Verbosity.next_scheme(dir)`: the scheme `dir` steps away from the active one in the rotation.
- `Verbosity.use(scheme)`: puts a scheme in use and saves the settings.
- `Verbosity.rotate_scheme(dir = 1)`: the verbosity key; uses the next scheme and says `vb_now`.
- `Verbosity.name_of(scheme)`: a scheme's spoken name.

`VerbositySchemes` (`core/speech/verbosity_schemes.rb`) keeps the player's schemes in `VerbositySchemes::FILE`,
`verbosity.txt` in the data folder, one `name=reading:level,...` line each. The file carries no game stamp
(`VerbositySchemes.game_bound?` is false), so an export from one game imports into any other.

| Call | Effect |
|---|---|
| `VerbositySchemes.levels(name)` | The scheme's `{reading => level}`, or nil |
| `VerbositySchemes.names` | The schemes' names, in order |
| `VerbositySchemes.set(name, levels)` | Saves a scheme, replacing one of that name |
| `VerbositySchemes.delete(name)` | Forgets a scheme |
| `VerbositySchemes.rename(old, new_name)` | Renames a scheme |
| `VerbositySchemes.valid_name?(name, except = nil)` | Not blank, not a built-in scheme's, not another scheme's |

## PokeAccess::KeyHints

`core/input/key_hints.rb`. `key_hints` in a profile merges a `{painted letter => button}` hash into
`Config.key_hint_letters`, the table these calls read.

- `KeyHints.gate(lines)`: the lines less their key hints while hints are left out. A hint with a count keeps the count
  without its key; a dropped hint also drops the line above it when that line ends in a colon.
- `KeyHints.gate_sentences(text)`: the text less its key-hint sentences while hints are left out; a sentence ends at a
  stop followed by a space or the end.
- `KeyHints.localize(text, letters = nil, sentences = false)`: each key token of a moved button replaced by the key used
  now: bracketed (`[A]`), labelling a line (`C/X:`) and, with `sentences`, asked for by a verb (`pulsa la tecla Z`).
  `letters` defaults to `KeyHints.table`. Returns `text` unchanged when no letters are declared, or while neither the
  mod's remap nor mkxp-z's F1 bindings move a button.
- `KeyHints.key(sym, painted)`: the key to say for button `sym`: the one bound with the mod's remap, else the one
  mkxp-z's F1 menu gave it, else `painted`.
- `KeyHints.bound_name(sym)`: the name of the key bound to `sym` with the mod's remap, or nil.
- `KeyHints.table`: `Config.key_hint_letters`.

| Constant | Matches or holds |
|---|---|
| `KeyHints::RGSS_LETTERS` | RPG Maker XP's letters: Z X C as `:a :b :c`, A S D as `:x :y :z`, Q W as `:l :r` |
| `KeyHints::HINT` | A hint: a leading bracketed key, or a leading verb that asks for a key |
| `KeyHints::KEY_TOKEN` | The bracketed key that leads a hint, with its colon |
| `KeyHints::VERBS`, `KEY_WORDS`, `NAMED` | The verbs and phrases before a key in a sentence, for `localize` |
