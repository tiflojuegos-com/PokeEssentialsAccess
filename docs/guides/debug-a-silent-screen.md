# Debug a silent screen

This guide goes from a screen that says nothing to the cause, with the diagnostic dump and the game's scripts. Use it
when the mod speaks elsewhere in the game and one screen stays quiet.

## Writing the diagnostic dump

1. Install the mod from the working tree into the game, so the diagnostic dump describes the code under test
   ([Install and release](install-and-release.md)).
2. Open the screen and leave it up for a few seconds, longer than the silence watch's 120 pulses. Move its cursor
   once if it has one.
3. Press Ctrl+Alt+F9 with the screen still open. The mod says whether it saved the
   [diagnostic dump](../architecture/diagnostics.md), and appends it to `diag.txt` in the data folder. Each dump starts
   with a `=== PokeAccess diag` line and the time.
4. Keep two more files of the same folder at hand: the [marker file](../reference/glossary.md), `hook_loaded.txt`,
   and the boot log, `loader_error.txt`.

The configuration menu (O by default, [Keys](../reference/keys.md)) has a Debugging screen (`cat_debug`). Its item
"Full diagnostics (to file)" (`dbg_diag_full`) writes the same diagnostic dump, and "Diagnostics: scene and runtime
(to clipboard)" (`dbg_diag_scene`) copies the parts that name the screen. Ctrl+Alt+F10 says a short status instead:
the scene, the map and position, the last line said and how many hooks are missing.

When nothing is said anywhere in the game, the screen is not the cause. Read the `mod:`, `voice:` and `enabled=`
lines of the diagnostic dump first: the installed version, the screen reader bridge, and whether the mod is on
(Ctrl+Alt+F8 switches it).

## Naming the screen

Read these lines of the diagnostic dump:

- `silent:` lists each screen that said nothing in the `Silence::WINDOW` (120) pulses after it came up, as
  `<class>@<map id>`, up to 20 screens. The class is the one of the last hooked method that ran (`Hooks.screen`), or
  `$scene`'s before any hook ran. It can be a window class that many screens share, such as `Window_DrawableCommand`.
- `$scene=` gives the class of `$scene` and the methods it defines itself (`methods=`), followed by its instance
  variables (`ivars:`) and its sprites (`@sprites keys=`). A screen that runs in its own loop leaves `$scene` as it
  was.
- `live_cmd_windows=` lists the live command windows with their class, `act=` (active), `vis=` (visible), `idx=`
  (index), `n=` (row count), `c0=` (class of the first row) and their first rows.
- `live_selectables=` lists the visible selectable windows with their class and index.
- `pictures=` lists the pictures on screen by number and file name. A screen drawn with pictures has no window to
  read.
- `painted=` lists the strings painted lately, as the [painted text](../reference/glossary.md) capture saw them.

Search the game's scripts for the names these lines give: a window's class, a string the screen paints, a picture's
file name. The [script dumps](../reference/glossary.md) live in `../../decompiled Scripts/<game>/`, and
`ruby tools/dump_scripts.rb "<game folder>"` makes one. Read the class the search finds before going on: a class named
after the screen may not be the one the game runs.

## Finding the cause

Each subsection starts from a line of the diagnostic dump or of the marker file. Check them in order.

### Class without a reader

Search the mod for the class name as a string, as `rg -n '"<Class>"' core games plugins`. When no registration names
it, write a reader ([Add a reader](add-a-reader.md)).

A screen of a community plugin needs its [plugin reader](../reference/glossary.md) loaded. The `plugins:` line lists
the plugin readers loaded (`cargados=`) and the plugins the game has whose reader was not loaded (`sin_declarar=`).
Declare a missing one in the profile ([Add a plugin reader](add-a-plugin-reader.md)).

### Hook that does not bind

The `hooks:` line prints the lists described in the [Hooks API](../reference/hooks-api.md#diagnostic-lists).

- `missing=` holds `<Class>#<meth>` when the class exists in this game and the method does not. Hook the method this
  game's class defines. Give `:optional => true` only when the method is absent from some games for a real reason.
- `unbound=` holds a group label when none of the class names of a `variants` group exists in this game. Add the
  game's name to the group.

The boot writes both lists to `loader_error.txt` as well.

### Reader skipped by the guard

`guard_suppressed=` holds pairs written `<outer>><Class>#<meth>`. Find a pair whose `<Class>#<meth>` is the silent
screen's reader: `<outer>` is the method whose `after` hook was running its original when the guard skipped the
reader. A pair ending in `Window_DrawableCommand#update` is the command-window reader of `core/menus/menus.rb`.

When `<outer>` is the screen's loop, or a method that runs the loop, its `after` hook silences the screen. Register
that hook with `:hook_container => true`, or move it to a method that returns before the loop
([Containers](../architecture/hooks.md#containers)). Most pairs are correct; a pair points at a fault only when its
outer method says nothing.

### Reader that raises

A `hook body <Class>#<meth>@<n>: <error>` line in the marker file is the first failure of that registration. The mod
swallows the exception, and the call goes on as if unhooked. The error gives the class, the message and the top three
backtrace frames. The `swallowed=` line of the diagnostic dump counts the failures by place in the mod.

A command-window extractor that raises writes `extractor <class>: <error class>: <message>`, and the row is read
without it.

### Reader that reads nil

The hook binds and runs, and says nothing because what it reads is `nil`. Compare each instance variable and accessor
the reader reads with the class in the game's scripts, and with the `ivars:` line when the screen is `$scene`.
`PokeAccess.ivar` and `PokeAccess.attr_of` answer `nil` for a name the object does not have, without an error
([Failures](../architecture/hooks.md#failures)). Read the name this game uses, and give `attr_of` every name when they
differ between the reader's games.

### Command window that is not read

Find the window in `live_cmd_windows=`. The command-window reader reads only an active window (`act=true`) with an
index. It passes over a window with `@ignore_input` set and one that a dedicated reader claimed with
`PokeAccess.dedicate`. When the window is read with the wrong text, register an extractor for its class with
`screen_reader` in the profile.

### Screen that speaks only when it closes

An `after` hook on the screen's loop, or on an opener that runs the loop, speaks when the method returns. Use
`read_on_open` with `:timing => :before`, or hook a method the loop calls. `test/static/blocking_hooks_test.rb`
reports an `after` hook on a loop of a surveyed game.

## Confirming the fix

1. Reproduce the silence in a test before changing the reader
   ([Testing the reader](add-a-reader.md#testing-the-reader)).
2. Change the reader and run the suite with `ruby test/run_all.rb`.
3. Install the mod again, open the screen and write a new diagnostic dump. The screen speaks, and `silent:` leaves
   its class out.
