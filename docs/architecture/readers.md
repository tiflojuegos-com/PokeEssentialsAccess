# Readers

This page explains how a screen becomes speech: the dialogue reader, command windows and change detection, painted
text capture, information windows, scene watchers, the info key, verbosity, the message history and key hints. Read it
before writing a reader; the [reading APIs reference](../reference/reading-apis.md) lists the calls it names with
their signatures.

## What a reader is

A [reader](../reference/glossary.md) is code that turns a screen's state into speech. It runs inside a hook on a method
the screen calls ([Hooks](hooks.md)) or in a poller that runs on every pulse ([Pulse](loading.md#pulse)). It ends in
`PokeAccess.speak`, the speech output every spoken line goes through
([Speech and languages](speech-and-languages.md#the-speech-output)).

The shape of a reader follows how the screen keeps its state:

- A command window keeps its options and its cursor; the command-window reader reads it.
- A screen drawn with sprites keeps an index on the scene; a focus reader reads it.
- A screen that draws text no variable keeps is read by capturing the painted text.
- A standing window whose text changes while its scene runs is an information window.
- A screen that runs its own input loop is read by a scene watcher.
- A screen whose content is fixed when it opens is read once, with `read_on_open`
  ([hooks API](../reference/hooks-api.md)).

Most shapes speak only when something changed, and `PokeAccess::Cursor` decides when that is.

## Dialogue

Message boxes go through `pbMessageDisplay`. The mod wraps the `Kernel.pbMessageDisplay` singleton that gen-6
defines and the top-level function of later versions, each where the game defines it (`core/dialogue/dialogue.rb`).
`PokeAccess.say_dialogue` cleans each message of its control codes, queues it behind current speech and remembers it
for Shift with the info key. It does not say again a copy of the same cleaned line within half a second, since one
message can reach more than one wrapper.

A speaker's name box, opened by codes such as `\xn[...]` (`NAME_CODES` in `core/speech/text.rb`), becomes the name and
a colon at the head of the line. With the `dialogue_pages` setting on ([Settings](../reference/settings.md)),
`DialoguePages` (`core/dialogue/pages.rb`) says a long message page by page as the window pauses, each page cutting off
the one before.

Menu screens print some prompts on their own help window, outside `pbMessageDisplay`. Hooks on those scenes hand the
prompt to `say_dialogue` through `say_screen_message` (`core/menus/screen_messages.rb`), and `UIHelperWrap` does the
same for the message methods of `UIHelper` (`core/menus/uihelper.rb`). `PokeAccess.message_depth` counts the messages on
screen, one inside another; a reader that watches a window's text keeps quiet for a message deeper than its screen.

## Command windows

Most menus are command windows, instances of `Window_DrawableCommand` or a subclass. One after-hook on
`Window_DrawableCommand#update` (`core/menus/menus.rb`) reads all of them. When the focus of an active window changes,
the hook takes the focused option's text and speaks it.

The text comes from an extractor: a block registered for a window class with `Menus.def_extractor`, or with
`screen_reader` in a profile ([profile DSL](../reference/profile-dsl.md)). The extractor of the most derived class the
window belongs to wins. The hook reads a window without an extractor, or whose extractor raises, from its own option
list: `Menus.generic_focus` tries the instance variables in `Menus::LIST_IVARS` in order. The hook then says a row of
question marks as the word for unknown and a row of only dashes, dots or underscores as empty, and it reads a
checkbox row with its state.

The hook leaves two kinds of window alone. A window with `@ignore_input` set takes no input. A window claimed with
`PokeAccess.dedicate` belongs to a dedicated reader. The claim is a flag of the mod's own, because setting
`@ignore_input` would freeze the cursor.

While the `auto_detect` setting is on (the default), a second hook reads a `SpriteWindow_Selectable` that is not a
command window, from its option list in the same way.

A screen drawn with sprites keeps its cursor as an index on the scene. `FocusReader.define`, or `focus_reader` in a
profile, declares a reader for it. After each call of the hooked method it reads the index, or the index of a window
in `@sprites`, and says the focused entry when it changes.

## Change detection

`PokeAccess::Cursor` (`core/menus/cursor.rb`) decides when a reader speaks. A reader gives it a key, a value that tells
what has the focus, such as the index. `Cursor.announce` runs the reader's block and speaks its line, under the
`:menu` speech category, only when the key differs from the last one recorded for that reader.

The record lives on a holder, the window or scene the reader reads. It is an instance variable of the holder, so it
disappears with the screen, and a screen that opens again starts fresh. A slot, a symbol that names the reader, keeps
apart the records of readers that share a holder. A nil holder uses a module-wide table, cleared on every map change.

A blank line does not use up its key. `announce` keeps the key pending for up to `Cursor::RETRY_FRAMES` polls, because
a row's data can land a few frames after the cursor moves. `Cursor.reset` forgets a key, so a menu that reopens on the
same entry says it again. The classic pause menu runs `pbShowCommands` again on the same window after every option, and
a hook resets that window first.

### Interrupting and queueing

A line either cuts off current speech or waits behind it. The hook queues the first read of a command window, so the
menu's title or question finishes first. Later moves interrupt, so the player hears where the cursor is now.

A row can change while the cursor stays still, such as a quantity the item storage changes in place. The key of a
command window includes a witness: the row count and the focused row, taken from the window's list. A new witness reads
the row again. The read interrupts when nothing was said since the window's last read. It is queued when something
was, since that line is usually the game's message about the change. The window keeps the session's spoken count in
the slot `:cmd_seq` to tell the two cases apart.

Some openers update their list once on row 0 and then move the cursor to their start row. `Menus.opening_on` holds
back, during the pulse it opens in, a first read on any row other than the start row. The storage scene's command
menus open through it (`PokemonStorageScene#pbShowCommands`).

## Painted text capture

Many screens draw text that no variable keeps, such as a summary page or a results table. `PokeAccess::PaintCapture`
(`core/util/paint_capture.rb`) reads such a screen by what it draws. Wrappers on `drawTextEx`, `pbDrawTextPositions`
and `drawFormattedTextEx` record each string before the game draws it, with its position and a symbol for the
function that drew it ([PaintCapture](../reference/reading-apis.md#pokeaccesspaintcapture)).

A reader arms a capture with a tag before the game draws and takes the rows after it. One tag is armed at a time, and
arming replaces a stale one. `PaintCapture.sample` captures what its block draws under a tag of its own and then
restores any capture already armed, so samples nest. `PaintCapture.lines` orders the rows as the page lays them out,
top to bottom, each line left to right.

Reminiscencia's profile reads the warnings its Pokocho maker flashes this way, inside its `Game.define` block:

```ruby
# games/reminiscencia/pokocho.rb
around("Poffin", :drawTextAnnouncement, :optional => true) do |_s, nxt, _a|
  PokeAccess::PaintCapture.speak_around(:rem_pokocho_warn, true) { nxt.call }
end
```

`speak_around` arms a tag, runs the game's drawing and speaks what landed. For a tag armed before a screen's own input
loop, a poller calls `flush_pending`, which speaks once a burst of rows has landed.

Command-list rows drawn with `pbDrawShadowText` stay out of armed captures; `shadow_sample` reads them. Images drawn
with `pbDrawImagePositions` are read with `icons` and `icon_rows`, which give each image's path and position.

The capture keeps the strings as the game drew them, in the language of the build the player runs. A screen that draws
its text inside pictures has nothing to capture; its profile transcribes the pictures (`PictureCues`, `picture_texts`
in a profile).

Every string these wrappers see, captured or not, also joins a list of the last 40 distinct strings
(`PaintCapture.recent`). The
diagnostic dump prints that list as `painted=`, which shows what a silent screen draws ([Diagnostics](diagnostics.md)).

## Information windows

Some scenes keep a window whose text changes while the scene runs, such as the phone's window with the focused
contact's map. `InfoWindow.watch`, or `info_window` in a profile, names one by its scene class and its key in the
scene's `@sprites`. The mod enters the scene on its opener and leaves it on its close (`core/menus/info_window.rb`).

On every pulse, the mod speaks each watched window of the live scene whose text changed, without its key hints while
the verbosity leaves them out. A window's reads are queued unless it is declared `:interrupt`, and its first read in a
scene is always queued. A window declared with `:reading` belongs to
the focused row. It is said from the given level of that reading up, and Ctrl+T always says it with the row. A declared
window that the scene lacks is recorded, unless it is declared `:optional`, and the diagnostic dump lists it.

## Scene watchers

A screen that runs its own blocking input loop may update no command window and return from no method a reader could
hook. `PokeAccess::SceneWatcher` (`core/menus/scene_watcher.rb`) reads it in two parts. An around-hook on the loop
method holds the scene while the loop runs. A poller reads the held scene on every pulse, which runs inside the loop
because the loop calls `Input.update`. An around-hook does not put its method on the reentrancy guard's stack, so the
hooks inside the loop still run ([Hooks](hooks.md)).

`SceneWatcher.reader` builds the common case. Its block gets the held scene and returns a pair of a key and a text;
`Cursor.announce` speaks the text when the key changes.

```ruby
# games/awakening/glossary.rb
AwakeningGlossary = SceneWatcher.reader("Scene_Glosario", :main, :aw_glossary) do |s|
  idx = PokeAccess.ivar(s, :@index)
  cmds = PokeAccess.ivar(s, :@commands)
  ok = idx && cmds.is_a?(Array) && idx >= 0 && idx < cmds.length
  ok ? [idx, cmds[idx].to_s] : nil
end
```

The first read after the scene opens is queued and later ones interrupt. A reader that adds to another's line passes
`:queued => true`, which queues every read. A text that responds to `call` is built only when the key changes.
`SceneWatcher.wire` takes any object that answers `watch(scene)`, `unwatch` and `poll`, for a reader with more state.

## Info key

The [info key](../reference/glossary.md) (T by default, [Keys](../reference/keys.md)) says the details of what has the
focus. Readers publish those details to `PokeAccess::Info` (`core/field/contextual.rb`) as the focus moves, with
`Info.set_info`. Each publication names a kind, which tells `Info` how to word the data: a move, an item, a Pokémon,
the trainer, the battle's foe, a ready line or the map. Publishing stores the object, and the line is built when the
key is pressed.

Two modifiers change what the key says (`Keys.info_key` in `core/input/input.rb`):

- Ctrl with the info key (Ctrl+T) says the focused row whole, as the full level says it, followed by the standing
  windows that belong to the row. A screen that published no row answers Ctrl+T as it answers T.
- Shift with the info key says the last dialogue line again.

A screen that published a ready line clears it when it closes (`Info.clear_text`), and the other kinds stay. The end
of a battle clears a published move, foe or ready line.

While the mod listens on the map, each map frame publishes the map kind. Its line comes from the map owners, blocks
registered with `Info.map_owner` and asked in order when the key is pressed. Core registers the puzzles and the
minigames, and profiles add their own screens over the map. When no owner answers, the key describes the forced
movement around the player, such as where each press leads on ice. On other ground it says the trainer line: name,
money, badges, Pokédex and play time, in the order of `Config.trainer_parts`, which a profile changes with
`trainer_part` and `trainer_order`.

A game screen that answers T itself claims the key with `Keys.yield_key!(:info)` on every frame, and the mod's key then
does nothing for four pulses.

## Verbosity and readings

[Verbosity](../reference/glossary.md) decides how much of a row is said. A reading is a kind of row, such as a bag item
(`:bag_item`) or a move in battle (`:battle_move`). Three readings cut across screens: positions in lists
(`:positions`), key hints (`:hints`) and descriptions (`:descriptions`). Each reading is said at one of three levels:
brief, medium or full.

A scheme gives every reading its level. Each built-in scheme puts every reading at one level, and full is the default.
A player's own scheme sets each reading apart and keeps one level for the readings it does not name
(`Verbosity::OTHERS`); without that entry, they are said in full. The player's schemes live in `verbosity.txt` in the
data folder (`VerbositySchemes::FILE`), with no game stamp, so schemes exported from one game import into any other.
The verbosity key, unbound by default, moves to the next scheme, the built-in ones first, and says its name.

A row builder passes its parts as pairs of a text and the lowest level that says it. `Verbosity.line` keeps the parts
that the reading's level reaches and joins them; a bare string counts as a full-level part. The shop's rows show the
shape, and the same parts go whole to the info key:

```ruby
# core/menus/menus.rb
parts = [[ad.getDisplayName(stock[i]).to_s, :brief], [price, :brief]]
parts.push([PokeAccess::I18n.t(:shop_worn), :brief]) if PokeAccess::Menus.mart_worn?(ad, stock[i])
PokeAccess::Menus.mart_marks(ad, stock[i]).each { |k| parts.push([PokeAccess::I18n.t(k), :medium]) }
PokeAccess::Info.set_info(:item, stock[i], PokeAccess::Verbosity.full_line(parts))
PokeAccess::Verbosity.line(:shop_item, parts)
```

The info key and Ctrl+T ignore the levels. `Verbosity.full_line` joins every part, and `Verbosity.whole` builds a row
as the full level says it, whatever the scheme. `Verbosity.info_line` publishes the whole row to the info key and
returns the leveled one, for a screen with no sheet of its own, such as a Pokédex list.

Plugins and profiles declare their readings with `Verbosity.define_reading`, which gives each one a name, a help text
and a group. The scheme editor in the configuration menu lists the readings declared in the running game, under their
groups (`Verbosity::GROUPS`). A reading that fits no core group goes in the `:game` group.

## Message history

`PokeAccess.speak` hands every line, as a `Speech::Message`, to the observers: the message history and the session
recorder. `PokeAccess::History` (`core/speech/history.rb`) keeps the last lines said, as many as the `history_size`
setting allows, each under its [speech category](speech-and-languages.md#speech-categories). It does not file a line
that repeats the previous one, in text and category, within one second, which is a repaint.

The history keys (Home and End by default) step one line back or on. With Ctrl they go to the first or the last line.
With Shift they move between views: one for every line and one for each category that holds any. Each view keeps its
own place, and the first press reads the latest line.

## Key hints

Games paint key hints, such as `[A] Curar` or `Pulsa C para acceder`. `PokeAccess::KeyHints`
(`core/input/key_hints.rb`) treats them in two ways.

While the `:hints` reading is brief, `KeyHints.gate` removes the hint lines from a screen's painted lines, and
`KeyHints.gate_sentences` removes the hint sentences from a text. A hint that carries a count keeps the count without
its key. A dropped hint also drops the label line above it that ends in a colon. `speak_around`, `flush_pending` and the
information windows apply them.

`KeyHints.localize` rewrites the key a hint names as the key the player uses now: the one bound with the mod's remap,
else the one mkxp-z's F1 menu moved the button to. It changes only the key token, and only for the letters the profile
declares with `key_hints`, which maps each painted letter to a button. A profile for a game that keeps the RPG Maker XP
keyboard declares `KeyHints::RGSS_LETTERS`. The mod's own lines that name a game key go through `localize` too.

## Placement by origin

The origin of a screen decides where its reader goes:

- A screen of stock Essentials goes in `core/`, in its era's folder where the eras differ (`core/menus/gen6/`,
  `core/menus/v21/`, `core/menus/v22/`), with `:optional` hooks for the methods some versions lack.
- A screen of an unedited community plugin goes in `plugins/`, with a probe in `plugins/manifest.rb`. The reader stays
  there when only one game ships the plugin.
- A screen shared by a family of games, such as the Reborn engine's, goes in a shared profile such as
  `games/rv_common/`.
- A game's own screen, or an older or edited copy of a plugin, goes in that game's profile.

The last rule protects the plugin readers. An older copy of a plugin can keep its method names with other arities, and
the plugin's reader would bind to them and read the wrong arguments without an error. Soulstones 2 ships an edited
Enhanced UI 1.1.2, read by `games/soulstones2/enhanced_ui.rb`, and its profile does not declare the plugin reader.
The probe of `plugins/dbk_enhanced_ui.rb`, `Battle::Scene#pbGetFinalModifiers`, does not match that copy, so the
generic profile's detection would not load the reader there and the diagnostic dump does not list it as missing.
The guide [Choose where a reader goes](../guides/choose-where-a-reader-goes.md) walks through the choice.
