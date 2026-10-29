# Settings

This page lists every setting of the mod's configuration menu: its key in `settings.ini`, its default, the values it
takes and its effect, by the screen that lists it. To declare a new setting, follow
[Add a setting](../guides/add-a-setting.md).

## The settings file

- Location: `settings.ini` in the data folder (`PokeAccess::Settings::FILE`), normally `accessibility/data`
  ([Diagnostics](../architecture/diagnostics.md)).
- Format: one `key=value` per line, read by `PokeAccess::KVFile`. Blank lines and lines that start with `#` are
  skipped, a line is split at its first `=`, key and value are stripped, and a UTF-8 byte order mark is dropped.
- Contents, in this order: two comment lines, every setting in declaration order, a comment, a `bind_<button>=<code>`
  line for each remapped button sorted by name, and a `key_<action>=<code>` line for each mod key moved off its
  default. The codes are Windows virtual-key codes ([Keys](keys.md)).
- Reading: `Settings.apply` runs once, at the end of the boot, after the game's profile. A value in the file overrides
  the default and a profile's `config(:key, value)`.
- Values: a number is an integer clamped to its kind's bounds; a flag is `true` or `false`; a list value is one of the
  names its setting lists below. A line with an unknown key, or with a value its kind does not take, is dropped, and
  the setting keeps its value.
- Writing: at boot, whenever the file differs from the settings as they stand, which creates a missing file and
  removes dropped lines; when the menu closes; after Reset to defaults; when Ctrl+M steps `hide_unreachable`; when a
  verbosity scheme is put in use; and when the remap screen changes a binding.
- Every setting is written, so a new default reaches only a file that does not hold the key yet.

## Value kinds

| Kind | Values | Step | Unit said |
|---|---|---|---|
| `:flag` | `true`, `false` | Flips | On or off (`val_on`, `val_off`) |
| `:vol` | 0 to 100 | 10 | None |
| `:tone` | 0 to 100 | 5 | None |
| `:tiles` | 1 to 20 | 1 | `tiles_unit` |
| `:sonar` | 1 to 30 | 1 | `tiles_unit` |
| `:astar` | 1000 to 10000 | 500 | None |
| `:ms` | 2 to 40 | 2 | `ms_unit` |
| `:gdist` | 1 to 6 | 1 | `tiles_unit` |
| `:reach` | 32 to 1024 | 32 | `tiles_unit` |
| `:desk` | 0 to 3 | 1 | `tiles_unit` |
| `:msgs` | 100 to 2000 | 100 | `msgs_unit` |
| `:hpacl` | 6 to 20 | 2 | `tiles_unit` |

A list kind (`Config::LISTS`) steps through its values in order and wraps at both ends; a value the list does not hold
steps on from the default. Left and right step the focused row, confirm steps it as right does, the info key says its
help and Ctrl with the info key says the row and its help together. A volume or pitch row that has a sample plays
it after each step.

## Visibility

A row shows only while its conditions hold; a hidden setting keeps its value and its line in the file.

- `:show_if` names another setting and one or more values. The row shows while that setting holds one of them and
  its own row shows.
- `:needs` names capabilities. The only one is `:positional`: the positional engine's library is there and, once
  booting was tried, it booted (`Sound::Pa3d.positional?`).
- A screen that would list no row is left out of its parent's list.

The tables below use four conditions:

| Condition | Rule |
|---|---|
| Sonar | `sound_nav` is `full` and the positional engine is up |
| Navigation on | `sound_nav` is `basic` or `full` |
| Navigation full | `sound_nav` is `full` |
| Navigation and engine | `sound_nav` is `basic` or `full` and the positional engine is up |

## Menu screens

The `:config` key (O by default, [Keys](keys.md)) opens the menu, on the map only. The top screen lists General
options, Navigation and pathfinder options, Audio options, Sound glossary, Personalization, Remap game controls,
Debugging and Reset to defaults.

| Screen | Group | Opened from |
|---|---|---|
| General options | `:general` | Top screen |
| Navigation and pathfinder options | `:pathfinder` | Top screen |
| Advanced navigation | `:pathfinder_adv` | Navigation and pathfinder options |
| Audio options | `:audio` | Top screen |
| Sounds on | `:audio3d_on` | Audio options |
| Volumes | `:audio3d_vol` | Audio options |
| Frequencies | `:audio3d_freq` | Audio options |
| Pitch | `:audio3d_tone` | Audio options |
| Walls and occlusion | `:audio3d_walls` | Audio options |
| Advanced positional audio | `:audio3d_adv` | Audio options |
| Verbosity | `:verbosity` | Personalization |
| Debugging | `:debug` | Top screen |

Reset to defaults asks for a second press, then puts every setting except `language` back to its default and writes
the file. The key bindings stay; the remap screen has its own reset. The Sound glossary, the dictionaries of
Personalization and the remap screen hold no settings.

## General options

| Key | Default | Values | Effect |
|---|---|---|---|
| `language` | `auto` | `auto`, or a code with a file in `lang/` | The language the mod speaks |
| `auto_detect` | `true` | Flag | Reads menus that have no reader of their own from their option list |
| `read_help` | `true` | Flag | Says the description a menu shows for the focused option |
| `dialogue_pages` | `false` | Flag | Reads the message box page by page instead of whole messages |
| `history_size` | `300` | `:msgs` | Lines the message history keeps |

- `language`: `auto` takes the first language with a file among the system's, its shipped neighbour (Catalan to
  Spanish), the game's declared language, English and Spanish
  ([Speech and languages](../architecture/speech-and-languages.md)).
- `auto_detect`: applies to a `SpriteWindow_Selectable` that no reader claims.
- `read_help`: the description is said only while the verbosity scheme says descriptions, as the full level does.
- `dialogue_pages`: each page cuts the previous one; off, each message is read whole and queued.
- `history_size`: the oldest lines go first; the history lasts the session.

## Verbosity

| Key | Default | Values | Effect |
|---|---|---|---|
| `verbosity` | `full` | `brief`, `medium`, `full`, or a scheme's name | The scheme in use for menus |

A player's schemes are kept in `verbosity.txt` in the data folder. A name that is not a scheme is said, and stepped
from, as `full`. The verbosity key, unbound by default, steps through the same values
([Readers](../architecture/readers.md)).

## Navigation and pathfinder options

| Key | Default | Values | Effect |
|---|---|---|---|
| `auto_guide` | `false` | Flag | Starts the [cane](glossary.md) toward a target when it is selected |
| `auto_steps` | `false` | Flag | Starts the [step guide](glossary.md) toward a target when it is selected |
| `hide_unreachable` | `off` | `off`, `unreachable`, `room` | Which targets the list leaves out |
| `hide_noninteractive` | `false` | Flag | Leaves decorative events with no interaction out of the list |
| `target_order` | `walk` | `near`, `walk`, `fixed` | The order the locator keys go through the targets |
| `target_numbering` | `dynamic` | `off`, `dynamic`, `static` | The number said with each target |
| `name_items` | `true` | Flag | Names the item in a ball on the ground |
| `name_trainers` | `true` | Flag | Names a trainer with no name by its class, and whether it was beaten |
| `name_species` | `true` | Flag | Names a Pokémon drawn on the map by its species |
| `name_signs` | `true` | Flag | Names an invisible event with text by what the text says |
| `surface_cues` | `true` | Flag | Says the terrain under the player when it changes |
| `puzzle_assist` | `false` | Flag | Gives the hints and routes that solve puzzles |

- `hide_unreachable`: `unreachable` leaves out the targets with no route; `room` also leaves out, on a map with
  several rooms, those outside the player's room. Ctrl with the coordinates key (Ctrl+M) steps it.
- `target_order`: by straight distance, by walking distance with the targets without a route last, or an order fixed
  while the player stays on the map.
- `target_numbering`: `off` says the place in the list; `dynamic` keeps each target's number while the player stays
  on the map; `static` also counts the targets the hide settings leave out, so numbers can skip.
- `puzzle_assist`: on, the mod says what each control would change and how far a piece is from its goal, and routes
  may push several boulders or go first to the control that opens the way. Off, it says positions and states only.

## Advanced navigation

| Key | Default | Values | Effect |
|---|---|---|---|
| `route_style` | `shortest` | `shortest`, `balanced`, `straightest` | Which route is chosen among several |
| `route_reach` | `128` | `:reach` | The farthest target, in Manhattan tiles, that a route is searched for |
| `route_limit` | `effort` | `effort`, `time`, `none` | When a search gives up |
| `astar_max` | `2500` | `:astar` | Tiles a search may examine |
| `route_budget_ms` | `12` | `:ms` | Milliseconds a route operation may take |
| `path_algorithm` | `regions` | See below | The search algorithm |
| `astar_weight` | `w150` | `w125`, `w150`, `w200`, `w300` | The heuristic's weight in weighted A* |
| `hpa_cluster` | `10` | `:hpacl` | The side of an HPA* cluster, in tiles |
| `edge_relax` | `false` | Flag | Lets a route reach exits and floors on the map's border that read as walls |
| `regions_background` | `true` | Flag | Explores the map a little on every map frame, so routes answer at once |

- `route_style`: `shortest` takes the fewest presses, then the fewest turns; `balanced` counts a turn as a press;
  `straightest` takes the fewest turns while the route stays within 5/4 of the shortest plus 4 presses, and the
  balanced route otherwise ([World and routes](../architecture/world-and-routes.md)).
- `route_limit`: `effort` stops a search once it has examined `astar_max` tiles, `time` stops the whole route
  operation after `route_budget_ms`, and `none` never stops. `astar_max` shows with `effort` and `route_budget_ms`
  with `time`.
- `path_algorithm`: `regions`, `astar`, `weighted`, `greedy`, `dijkstra`, `bfs`, `dfs`, `jps` or `hpa`. The row's
  help is the chosen algorithm's own (`help_algo_<value>`). `hpa_cluster` shows with `hpa`.
- `astar_weight`: 1.25, 1.5, 2 or 3; shows with `path_algorithm` `weighted`. A higher weight examines fewer tiles,
  and the route may stray further from the shortest.

## Audio options

| Key | Default | Values | Effect |
|---|---|---|---|
| `sound_nav` | `full` | `off`, `basic`, `full` | Which navigation sounds play |
| `sonar_only_locatable` | `false` | Flag | The sonar plays only for what the locator keys reach |
| `game_bump` | `false` | Flag | Also plays the game's own bump at a wall |
| `audio3d_hrtf` | `true` | Flag | Spatializes the positional engine through the HRTF; off, in plain stereo |
| `audio3d_volume` | `80` | `:vol` | Master volume of the positional engine |

- `sound_nav`: `off` plays no footsteps or walls and does not start the positional engine; `basic` plays footsteps
  and wall cues; `full` adds the sonar, water, wind and the radar. The guide, puzzles and minigames sound in every
  mode ([Guide and sound](../architecture/guide-and-sound.md)).
- `game_bump`: off, the game's bump is silent while the mod's wall cue is on.
- `audio3d_hrtf`: off, the engine plays in plain stereo. Each sound pans between the left and the right, and its
  pitch rises up to 20 % straight ahead and falls as much straight behind; a sound on the player keeps its pitch.
  Occlusion, air absorption, distance and the families' tones apply as with the HRTF.
- `sonar_only_locatable` shows with Sonar, `game_bump` with Navigation on, and `audio3d_hrtf` and `audio3d_volume`
  with Navigation and engine.

## Sound families

The screens Sounds on, Volumes, Frequencies and Pitch hold one row per family and kind, built from the families in
`core/sound/catalog.rb` (`Sound::Catalog.rows`).

- Switch (`:flag`, Sounds on): off, the family's sounds play nothing. Every switch defaults to `true`.
- Volume (`:vol`, Volumes): the family's volume; 0 plays nothing.
- Frequency (`:vol`, Frequencies): how often a ping repeats, from 1.5 seconds between pings at 0 to 0.15 seconds at
  100 (`PokeAccess.freq_to_seconds`).
- Pitch (`:tone`, Pitch): 50 plays the recording, and each step of 5 is a tenth of an octave, to an octave down at 0
  and up at 100 (`PokeAccess.tone_to_pitch`). A sound played without the positional engine keeps its pitch inside the
  range its catalog entry allows. Every pitch defaults to `50`.

A row shows under the family's condition. A family without its own row of a kind uses another family's, named in the
tables.

| Family | Switch | Volume, default | Shows | Marks |
|---|---|---|---|---|
| People | `sound_people` | `audio3d_npc`, 85 | Sonar | A person nearby |
| Objects | `sound_objects` | `audio3d_object`, 85 | Sonar | An object to examine |
| Hazards | `sound_hazards` | `audio3d_hazard`, 85 | Sonar | A puzzle hazard, such as spikes or a beam |
| Traps | `sound_traps` | `audio3d_trap`, 85 | Sonar | A puzzle obstacle that moves |
| Controls | `sound_controls` | `audio3d_control`, 85 | Sonar | A lever, button or switch |
| Pushes | `sound_pushes` | `audio3d_push`, 85 | Sonar | A block or boulder to push |
| Belts | `sound_belts` | `audio3d_belt`, 85 | Sonar | A tile that carries the player |
| Doors | `sound_doors` | `audio3d_door`, 85 | Sonar | A door or map exit |
| Exits | `sound_exits` | `audio3d_exit`, 85 | Sonar | A crossing at the map's edge |
| Teleporters | `sound_teleporters` | `audio3d_teleporter`, 90 | Sonar | A teleporter, portal or elevator |
| Marks | `sound_marks` | `audio3d_mark`, 85 | Sonar | A marker the player set |
| Water | `sound_water` | `audio3d_water`, 70 | Sonar | The water nearby, as a loop |
| Shore | None | `audio3d_shore`, 40 | Sonar | While surfing, the nearest land to get off onto |
| Wind | `sound_wind` | `audio3d_wind`, 55 | Sonar | A wall on each side, as a loop |
| Steps | `sound_steps` | `footstep_volume`, 80 | Navigation on | The player's footsteps |
| Wall | `sound_wall` | `wall_volume`, 80 | Navigation on | A bump into a wall or into something to use |
| Guide | None | `event_volume`, 70 | Always | The guide toward the target |
| Jumps | `sound_jumps` | `jump_volume`, 70 | Always | A ledge the route jumps |
| Ledges | `sound_ledges` | Jumps' | Navigation on | A ledge in front of the player |
| Radar | `proximity_radar` | `radar_volume`, 31 | Navigation full | Something to interact with in front |
| Grid | `sound_grid` | `puzzle_volume`, 70 | Always | The cell of a puzzle grid |
| Minigame | `sound_minigame` | `minigame_volume`, 60 | Always | The rhythm or closeness in a minigame |

| Family | Frequency, default | Pitch |
|---|---|---|
| People | `audio3d_freq_npc`, 90 | `audio3d_tone_npc` |
| Objects | `audio3d_freq_object`, 10 | `audio3d_tone_object` |
| Hazards | `audio3d_freq_hazard`, 10 | `audio3d_tone_hazard` |
| Traps | `audio3d_freq_trap`, 10 | `audio3d_tone_trap` |
| Controls | `audio3d_freq_control`, 10 | `audio3d_tone_control` |
| Pushes | `audio3d_freq_push`, 10 | `audio3d_tone_push` |
| Belts | `audio3d_freq_belt`, 10 | `audio3d_tone_belt` |
| Doors | `audio3d_freq_door`, 70 | `audio3d_tone_door` |
| Exits | `audio3d_freq_exit`, 70 | `audio3d_tone_exit` |
| Teleporters | `audio3d_freq_teleporter`, 70 | `audio3d_tone_teleporter` |
| Marks | `audio3d_freq_mark`, 80 | `audio3d_tone_mark` |
| Water | None | `audio3d_tone_water` |
| Shore | None | Steps' (`footstep_tone`) |
| Wind | None | `audio3d_tone_wind` |
| Steps | None | `footstep_tone` |
| Wall | None | `wall_tone` |
| Guide | `guide_freq`, 75 | `guide_tone` |
| Jumps | None | `jump_tone` |
| Ledges | None | Jumps' (`jump_tone`) |
| Radar | None | `radar_tone` |
| Grid | None | `grid_tone` |
| Minigame | None | None |

The Frequencies screen also holds `guide_rhythm` after `guide_freq`:

| Key | Default | Values | Effect |
|---|---|---|---|
| `guide_rhythm` | `distance` | `distance`, `constant` | How the guide's period changes with the target's distance |

With `distance`, the period `guide_freq` sets grows with the target's distance, up to twice as long at
`Guide::FALLOFF` tiles or more; with `constant`, it stays as set. The Sounds on screen also lists the Guide sound row
(`lbl_on_guide`) before `sound_jumps`. That row switches the cane as its key does and is not a setting: the
file does not save it.

## Walls and occlusion

| Key | Default | Values | Effect |
|---|---|---|---|
| `audio3d_occlusion` | `hide` | `hear`, `occlude`, `hide` | What becomes of a person, object or door behind a wall |
| `audio3d_air` | `false` | Flag | Distant sounds lose treble |
| `audio3d_wall_range` | `3` | `:tiles` | How far a wall is felt for the wind |
| `audio3d_wall_falloff` | `50` | `:vol` | How fast the wind drops with the wall's distance |
| `audio3d_desk_range` | `2` | `:desk` | How far a counter's attendant is heard through a wall |

- The first four show with Sonar; `audio3d_desk_range` shows while `audio3d_occlusion` is `hide` and shown.
- `audio3d_occlusion`: `hear` plays the sound as usual, `occlude` muffles it and `hide` silences it.
- `audio3d_wall_falloff`: a higher value leaves only the nearest walls audible.
- `audio3d_desk_range`: the attendants of a service counter, such as a nurse or a clerk, stay audible within that
  many tiles while `hide` silences the rest; 0 silences them too.

## Advanced positional audio

| Key | Default | Values | Effect |
|---|---|---|---|
| `audio3d_range` | `12` | `:sonar` | The sonar's range for people and objects |
| `audio3d_alt_dist` | `5` | `:tiles` | Two cues this close play in turns rather than at once |
| `guide_distance` | `3` | `:gdist` | How many tiles to the side the guide and the jump play |

`audio3d_range` and `audio3d_alt_dist` show with Sonar. `guide_distance` shows with Navigation and engine and applies
when the next step goes left or right. Up and down, the guide plays from the centre, higher ahead and lower behind.

## Debugging

| Key | Default | Values | Effect |
|---|---|---|---|
| `transfer_active_page_only` | `true` | Flag | An exit is a tile whose event's active page transfers the player |
| `route_stats` | `false` | Flag | Adds the algorithm, the tiles examined and the time to each route said |
| `revert_surf_sound` | `false` | Flag | Leaves out the shore cue while the player surfs |

`transfer_active_page_only` off counts every page of the event, so a character whose cutscene changes maps reads as
an exit. The rest of the Debugging screen is described in [Diagnostics](../architecture/diagnostics.md).
