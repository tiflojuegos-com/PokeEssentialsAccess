# Diagnostics

This page explains what the mod records to show why a screen says nothing or the wrong thing: the diagnostic dump
and the meaning of its lines, the marker file, the files of the loader, the session recorder, the self-check and the
silence watch. The procedure that uses them is in [Debug a silent screen](../guides/debug-a-silent-screen.md).

## What the diagnostics record

A reader fails without a sound. A hook that does not bind, an instance variable under another name and an exception
that a rescue swallows all leave the screen quiet while the game runs on ([Hooks](hooks.md)). The diagnostics turn
those outcomes into text: what did not bind, the first occurrence of each failure, and the live values the readers
saw. They run in the real game, which the test stubs only imitate.

The diagnostic files go to the [data folder](../reference/glossary.md), `PokeAccess::Paths::DATA`, except those the
preload script writes ([Files of the loader](#files-of-the-loader)). The data folder is
`accessibility/data` when that folder can be written, and otherwise `accessibility` inside the folder mkxp-z keeps
for the game (`System.data_directory`).

| File | Written by | Holds |
|---|---|---|
| `diag.txt` | `Keys.diag_dump` | The diagnostic dumps, appended |
| `hook_loaded.txt` | `PokeAccess.write_marker` | The marker file: the load line and first failures |
| `loader_error.txt` | The loader | Load errors and the boot's `[diag]` lines |
| `preload_started.txt` | `AccessPreload` | Proof that the preload script ran, and a stall |
| `selfcheck.txt` | `SelfCheck.run` | The self-check reports, appended |
| `recordings/rec-<date>-<time>.txt` | `Recorder` | One session recording |

## The diagnostic dump

Ctrl+Alt+F9 appends a dump of the mod's state to `diag.txt`, and so does the row Full diagnostics (`dbg_diag_full`)
of the Debugging screen in the configuration menu. The mod says only whether the file was written (`diag_saved` or
`diag_not_saved`). The three Ctrl+Alt gestures are polled on every [pulse](loading.md) before the mod checks whether
it is switched on and whether the game window has the focus, so a dump also works with the mod switched off by
Ctrl+Alt+F8.

A dump is a header, `=== PokeAccess diag <time> ===`, followed by the lines of each section. `Keys.diag_build` runs
the sections in the order of `Keys::DIAG_ALL` and guards each one: a section that raises adds
`<section>: ERR <class>: <message>`, and the next section runs. Inside a section, `Keys.dv` guards each value, which
prints as `ERR(<class>)` when reading it raises. `Keys.cut` shortens a long field and marks the cut with
`...[cortado]`.

The other dump rows of the Debugging screen copy one group of sections to the clipboard, short enough to paste into
a message (`Keys::DIAG_SECTIONS`):

| Row | Group | Sections |
|---|---|---|
| `dbg_diag_audio` | `:audio` | `diag_audio3d` |
| `dbg_diag_events` | `:events` | `diag_locator`, `diag_focus` |
| `dbg_diag_perf` | `:perf` | `diag_perf`, `diag_polls` |
| `dbg_diag_map` | `:map` | `diag_map`, `diag_pathfinder`, `diag_puzzle`, `diag_surface` |
| `dbg_diag_scene` | `:scene` | `diag_scene`, `diag_runtime` |

Code outside `core/input/diag.rb` adds sections. `Keys.register_diag_section(name, group)` appends a section to the
full dump and to one group, `:scene` by default; a profile does the same with `diag_section` in its `Game.define`
block ([Profile DSL](../reference/profile-dsl.md)). The silence watch adds its line this way:

```ruby
# core/util/silence.rb
PokeAccess::Keys.register_diag_section(:diag_silence, :scene) do |o|
  q = PokeAccess::Silence.quiet
  o.push("silent: #{q.empty? ? 'none' : q.join(', ')}")
end
```

Ctrl+Alt+F10 speaks a short status and writes nothing: the scene's class, the map's name and the player's tile, the
last line spoken, and the number of hooks in `Hooks.missing` when there are any.

## Lines of the dump

The sections follow in dump order. Each item names a line by the word it starts with.

### Timing

`diag_perf` prints one `perf:` line with an entry per measured label, as `label avg=<ms> max=<ms> n=<count>`:
`frame_world`, `frame_control`, `frame_nav` and `frame_sound` for the stages of the map frame, and `input_frame` for
the pulse. The section then clears the measurements, so each report that includes it covers the time since the
previous one. `(sin datos)` means that nothing was measured.

### Engine, hooks and failures

`diag_focus` opens with the engine lines:

- `mod:` the installed version: `mod_version` in `installed.json` in the data folder, else `version` in
  `accessibility/version.json`, else `?`.
- `engine:` `Engine.kind`, `Engine.version`, `Engine.fork`, and the capabilities that answer true
  ([Engine eras](engine-eras.md)) except `gamedata`, `gen6` and `sky_fork`, which `kind=` and `fork=` already state.
  `PokeBattle_Scene`, `$player` and `$Trainer` are added when they exist.
- `voice:` whether the screen reader bridge loaded (`prism=`), whether a screen reader backend was acquired
  (`ready=`), its name (`backend=`) and whether it is speaking ([Speech and languages](speech-and-languages.md)).
- `timing:` the mod's clock, `uptime_scale` (the units of `System.uptime` per second of wall time, `nil` in the first
  second), the frame rate measured since the previous report of this line (`n/a` in the first one, and when less than
  half a second has passed) and `Graphics.frame_rate`.

The input state, the hooks and the failures follow:

- `enabled=` the Ctrl+Alt+F8 switch, then `focused?`, the game window's handle, and `typing_ttl`, the pulses left
  during which a text field keeps the mod's keys off.
- `focus:` the foreground window, the active window and the process id, to compare with the game window.
- `scene=` the class of `$scene`, then whether a menu or a message window is open, whether the map interpreter runs
  and whether the player surfs.
- `hooks:` the lists `missing`, `fn_absent`, `overrides` and `unbound`, and `guard_suppressed=` on the next line.
  [Hooks](hooks.md#diagnostic-lists) explains each list.
- `info_windows:` the number of information windows declared (`declaradas`), the declared windows a scene did not
  have (`sin_ventana`, as `Class.key`), and the scene classes on which no opener bound (`sin_entrada`), whose windows
  are never read.
- `dialogue:` the forms of `pbMessageDisplay` the game defines (`:singleton` for gen-6 `Kernel.pbMessageDisplay`,
  `:bare` for the top-level function), the forms the mod wrapped, the number of dialogue lines received and the last
  one.
- `caches=` the cache resets registered with `PokeAccess::Caches`; `data_err=` the errors of the data provider.
- `logged=` and `swallowed=` the failures of the session ([The marker file](#the-marker-file)). `swallowed=` gives
  each place with its count and its first failure, the most frequent first.
- `plugins:` the plugin readers loaded (`cargados`), and the plugins the game has by their probe whose reader did not
  load (`sin_declarar`). A plugin in `sin_declarar` runs without a reader in this game ([Loading](loading.md)).
- `plugins_juego:` the plugins the game's `PluginManager` registers, with their versions: `ninguno registrado` for
  none, `sin PluginManager` for a game without it.
- `config:` and `filters:` a few settings ([Settings](../reference/settings.md)), with the language chosen and the
  one in use, the game's declared language and the system's. `trainer_line:` the parts of the trainer line that the
  info key says (`Config.trainer_parts`).
- `rebinds=` the remapped buttons. `f1=` the engine's own key table when mkxp-z answers the game's input, or
  `entrada en Ruby, F1 no aplica` for a game that reads the keyboard itself ([Keys](../reference/keys.md)).

### Map and navigation

`diag_map`, `diag_locator`, `diag_pathfinder`, `diag_puzzle` and `diag_surface` describe the player's surroundings
as the navigation layer sees them ([World and routes](world-and-routes.md)):

- `map=` the map's id and name, its size, the player's tile and facing, and the number of events. `terrain` gives the
  terrain tags of the player's tile and of the four around it. Off the map the section prints
  `no game_map/player (probably a menu/title)`.
- `categories(<n>)=` the locator's categories. `locator:` the category, the selected target's index, the number of
  targets and the target's name. `targetlist=` the first ten targets with their tiles, and whether the list is stale.
- `guides:` whether the cane and the step guide are on, the step reached, the steps left and the two auto guide
  settings.
- `pathfinder:` the search settings in use and the algorithm. `reachable:` the number of tiles the player can walk to,
  their bounds, and whether that region is complete. `touch_events:` how many tiles of the map carry each kind of
  touch effect, then the bridge level, whether the engine's answers cannot be kept (`stair=`, true partway up a side
  stair or in the debug walk-through), and the counts of gates, actions and pushable pieces.
- `target_route:` with a target selected: its distance, the kind of plan chosen and its statistics. Then
  `target_reachable=`, the route as it is said (`route=`), and its assisted step (`gate=`), surf plan and door sides.
- `puzzle:` the puzzle declared for the map, the switches and variables it watches (`watch`) and the pieces it found;
  `puzzle: none for this map` otherwise.
- `surface_label_map=`, `surface_targets=` and `surf_cue:` the surface labels and targets, the terrain under and in
  front of the player, and whether the tile ahead can be surfed.

### Positional audio

`diag_audio3d` reports the soundscape ([Guide and sound](guide-and-sound.md)):

- `audio3d:` whether the positional engine's library is there, the `sound_nav` mode, whether the engine booted or
  was tried, and whether the soundscape is active. `audio3d device:` the output rate and latency.
- `audio3d cfg:`, `audio3d vols:` and `audio3d tones:` the audio settings, with the pitches sent to the engine
  (`sent=`). `audio3d chans=` the loaded channels.
- `audio3d gate:` the current `Control.reason`, then how many soundscape frames played out of the total since the
  previous report, with the reasons that kept the others quiet; the report starts the count again. `sonar reach:` how
  many events of the map ping and how many of those the locator keys cannot reach.
- `audio3d emitters=` and `audio3d walkers:` the emitters, and the moving events the scene watches.
- `paths:` the data folder, the working folder and the library folder.
- `nearby_events=` up to twelve events nearest the player within twelve tiles, as `name@x,y:<family>/g/i/los/R`. The
  flags say whether the event has a graphic, can be interacted with, is in line of sight and can be reached.

### Scene and runtime

`diag_scene` and `diag_runtime` name what a silent screen is made of, so that a reader can be bound to it:

- `battle_ref=` whether a battle is referenced, and `trainer=` the player's name. `player_sel:` how the game selects
  the player's sprite.
- `pictures=` the pictures on screen by number and name. `choice=` and `choices=` the choice box of an event.
- `live_cmd_windows=` every live command window (`Window_DrawableCommand`) with its class, whether it is active and
  visible, its index, its number of commands and its first eight rows.
- `painted=` the strings drawn lately, as `source:text`, the latest last ([Readers](readers.md)).
- `$scene=` the scene's class and the methods the class defines itself, which are the candidate hook points.
  `ivars:` its instance variables with a short preview of each value. `@sprites keys=`, then one line per sprite with
  its class and index.
- `live_selectables=` up to twelve visible selectable windows (`SpriteWindow_Selectable`, `Window_CommandPokemon`).

### Input layers and added sections

`diag_polls` prints `input_update_layers:`, the aliases of `Input.update` whose names contain `update__access`, and
`frame_pollers=`, the number of blocks registered on the pulse. The registered sections come last: `silent:` from the
silence watch, then those of plugins and profiles, such as `logros_poll` (`plugins/logros.rb`).

## The marker file

The marker file is `hook_loaded.txt` in the data folder (`PokeAccess.marker_file`). `PokeAccess.write_marker`
appends a line that starts with the time. It writes nothing until `Paths::DATA` exists, a few files into the load of
`core/`.

`core/speech/backend.rb` writes the load line, `cargado ruby=<version> prism=<true|false>`, as it loads. The line
shows that the core loaded that far, and `prism=false` means that the screen reader bridge did not bind.

The other lines record failures, each one once:

- `PokeAccess.log_once(key, e)` writes the first failure for a key as `<key>: <error>`, such as `frame_<step>` for a
  step of the map frame or `settings_write` for the settings file.
- `PokeAccess.swallowed(e)` serves the rescues that keep a reader from breaking the game. It writes the first failure
  from each place as `swallowed <site>: <error>`, where the site is the innermost frame of the mod's own code, such as
  `core/nav/guide.rb:120`, and counts every later one.
- The hook layer writes the first failure of each hook body (`hook body <key>`), a wrapper it could not install
  (`wrap Class#method`), and after an F12 reset, `game reset: <n> wrappers put back` ([Hooks](hooks.md#failures)).

`PokeAccess.format_error` writes an exception as `Class: message @ frame <- frame <- frame`, with its top three
backtrace frames. The dump's `logged=` line repeats the `log_once` failures, and `swallowed=` adds the count of each
site.

Two static tests keep failures from vanishing. `test/static/rescue_reports_test.rb` requires every broad rescue to
report what it caught or raise it again, and `test/static/silent_io_test.rb` requires a trace from every method that
touches a file and rescues ([Static checks](../reference/static-checks.md)).

## Files of the loader

The preload script runs before `PokeAccess::Paths` exists, so it writes to the literal folder
`accessibility/data`; the boot's log, `PokeAccessBoot.log`, uses the data folder once it is known
([Loading](loading.md)).

- `preload_started.txt` holds `preload ok ruby=<version>`, written each time mkxp-z runs the preload script. A
  missing file means that the preload script never ran. When the game is still not ready for the mod after 1800 frames
  (`AccessPreload::STALL_FRAME`), one `stalled:` line follows, with the frame count, whether `$scene` is set and
  whether the game's scripts finished (`scripts_done`).
- `loader_error.txt` holds the problems of the boot: a folder without `manifest.rb`, a manifest of the wrong shape, a
  declared import or plugin reader that is missing, and a module that raised while it was evaluated, with its
  backtrace. It also names the plugins the generic profile detected. At the end of the boot, two `[diag]` lines
  appear when they apply: the hooks without a method (`Hooks.missing` and `Hooks.unbound`), and a data layer with no
  engine provider. An exception out of the boot script itself replaces the file's content with that error, and an
  error while the preload puts the wrappers back after an F12 reset adds an `after reset:` line.

## The session recorder

The session recorder writes a transcript of what the mod saw and said, for a problem that lies in a sequence of
events rather than in one moment. The row Record session (`dbg_rec_start`) of the Debugging screen starts it and says
the file's name. The same row, labelled `dbg_rec_stop` while it runs, stops it and says how many events it saved.

`Recorder.start` opens `recordings/rec-<YYYYMMDD>-<HHMMSS>.txt` in the data folder. Its first line is
`# pea-recording 1`, then the engine's kind, version and fork, separated by tabs. Every other line is tab-separated:
the clock in seconds, the kind of event, its fields, and the text last.

- `say` a line spoken, `1` when it interrupted and `0` when it queued, taken from an observer on the speech output.
- `in` what the player pressed on a pulse (`confirm`, `cancel` or `dir`), or `tecla:<name>` for a key of the mod.
- `map`, `pos`, `scene` and `sel` the map, the player's tile, the scene (its class and `Control.reason`) and the
  locator's selection, each written when it changes.
- `diag` one line of a diagnostic section, tagged with the reason it was taken.

The recorder samples on every pulse, so it also runs inside the menus' own loops. The first snapshot, tagged `start`,
holds `diag_focus`, `diag_map`, `diag_locator`, `diag_pathfinder`, `diag_surface`, `diag_audio3d`, `diag_scene` and
`diag_runtime` (`Recorder::SNAP_START`); `diag_perf` stays out because it clears the timing window. A new map adds
`diag_map`, `diag_locator`, `diag_pathfinder` and `diag_surface`, and a change of scene or of `Control.reason` adds
`diag_scene`, both on the next pulse, once the readers have updated. A snapshot identical to the previous one with the
same tag becomes a single `(igual que el anterior)` row. Rows are kept in memory and appended to the file after the
first snapshot, every 120 rows and on stop.

`test/support/replay.rb` audits a recording from the transcript alone. It reports a line spoken with RPG Maker
control codes, a line repeated with nothing from the player in between, and a selection change that nothing was said
after. A recording placed in `test/fixtures/recordings/` becomes part of the suite, since
`test/unit/foundation/recorder_test.rb` audits every file there ([Tests](../guides/tests.md)).

## The self-check

The row Engine self-check (`dbg_selfcheck`) tests in the running game what the suite only stubs. `SelfCheck.run`
checks the screen size, the input buttons, the map and the player, the trainer global (`$Trainer` or `$player`),
`pbDrawTextPositions` and `_INTL`, the pictures, the positional engine's library and whether the data folder can be
written. It adds facts that are neither pass nor fail: the engine kind, the language the build declares, whether
`Array#+` changes the array it is called on, the number of registered extractors and picture texts, and the audio
device. It ends with the hooks that did not bind. It appends the report to `selfcheck.txt`, and the mod says how many
checks failed and how many hooks did not bind.

## The silence watch

The silence watch lists the screens that came up and said nothing. On every pulse, `Silence.tick` takes the current
screen: the class whose hooked method ran last (`Hooks.screen`), which also names a screen that runs its own loop and
never becomes `$scene`, or the class of `$scene` before any hook has run. A new screen gets 120 pulses, two seconds at
60 frames per second. A line spoken in that time ends the watch for that screen; a screen still silent at the end is
noted as `Class@map_id`, with `?` off the map. Each class is noted once, and the list stops at 20.

A screen on the list can be correct, since a cutscene is silent too. A screen on it that should speak points at a
reader bound to the wrong method. The dump prints the list as `silent:`.
