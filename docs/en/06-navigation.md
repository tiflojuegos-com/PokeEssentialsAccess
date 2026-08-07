# Navigation

Two subsystems orient the player around the map: `core/nav/pathfinder.rb` computes the route to a target and
`core/audio/audio3d.rb` builds the soundscape. The locator picks the target; the guide consumes the route.

## Pathfinding

| Call | Returns |
|---|---|
| `find_path(tx, ty)` | RPG direction codes (`8` `2` `4` `6`) to a tile **adjacent** to the target; `[]` when already beside it, `nil` when there is no route |
| `path_to_text(path)` | The spoken route ("3 up, 2 left"), or the "no route" / "next to it" text |
| `reachable_set` | `{ pkey => true }` of walkable-to tiles, cached per player tile |
| `surf_launch(tx, ty)` | A route to the reachable shore tile nearest the target, or `nil` |
| `reach` | The configured manhattan distance cap (`route_reach`) |

The origin is **always** `$game_player`: there is no start parameter. Arrival is `target_reached?`
(manhattan ≤ 1), because the typical target — NPC, sign, item — occupies a tile the player cannot enter.

```ruby
# core/nav/pathfinder.rb
def self.find_path(tx, ty)
  with_budget do
    with_bridges do
      px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
      far = (px - tx).abs + (py - ty).abs > FLOOD_MIN
      next nil if far && blocked_target?(tx, ty)
      find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
    end
  end
end
```

`with_bridges` forces `$PokemonGlobal.bridge = 2` for the search, so it can cross a bridge the player has not
stepped onto yet. `blocked_target?` rejects the target using the cached flood, only beyond `FLOOD_MIN` (24)
tiles, with the flood complete and `edge_relax` off. Two passes: no ledge hops, then with them if that fails.

### Algorithms

`path_algorithm` picks the frontier; neighbour expansion and the fewer-turns tiebreak are shared.

| Value | Frontier | Priority | Note |
|---|---|---|---|
| `:astar` (default) | binary heap | `2g + 2h` | optimal route; also where an unknown value lands |
| `:weighted` | heap | `2g + 3h` | weights doubled to express 1.5x in pure integers |
| `:greedy` | heap | `2h` | straight at the goal, prone to detours |
| `:dijkstra` | heap | `2g` | optimal without a heuristic, expands more |
| `:bfs` / `:dfs` | queue / stack | — | no heap; DFS is for experimenting only |
| `:jps` | jump points | `g + h` | a straight corridor costs one expansion |
| `:hpa` | cluster graph | `g + h` | hierarchical, for large maps |

`straight_routes` adds +1 to the cost of every turn. JPS drops to A* (`@jps_fallback`) on ice, slides,
recursion past 80 levels, or when its step budget (`[astar_max * 8, 20000]`) runs out. HPA* tiles the map into
clusters of `HPA_CLUSTER` (10) tiles and routes portal to portal to a synthetic sink (`HPA_SINK`), refining
each hop with a **live** local A*: a stale graph can only produce `:fallback`, never a wrong route. Both run
in the first pass only.

### Special neighbours

`step_target(cx, cy, dir, allow_ledge, edge_relax)` resolves which tile the search may enter. Water is no
special case: the game's own passability already depends on `$PokemonGlobal.surfing`.

| Terrain | Resulting neighbour |
|---|---|
| Ledge (tag 1) | Never a standable node: checked **before** the passability test, since modern engines report it passable from the high side. Crossing it is always the two-tile hop (`ledge_jump`), gated by `allow_ledge`, a real landing and the opposite side's passage bit being open (`LEDGE_OPP_BIT`; permissive when the tileset cannot be read) |
| Ice (tag 12) | Where the slide **ends** (`ice_slide`), not the adjacent tile; capped at 200 steps |
| Slide | A sprite-less event that forces a move route. `slide_index` indexes them per map (`pkey => { direction => destination }`) and the search jumps to the destination |
| Map border | With `edge_relax`, a passable border tile counts as a neighbour even when the directional passage fails |

### Caches and budget

`$game_player.passable?` is costly and one search calls it thousands of times. With `route_cache` it is
memoised per `[map_id, surfing, diving]`, keyed by `pkey(cx, cy) * 16 + d`; it does not track moving events,
which is why it can be turned off. `invalidate_cache(force = false)` drops passability, the reachable set, the
HPA* graph, the surf route and the slide index; it is throttled to 2 s, and `Caches` registers it with
`force = true` (no throttle) for map changes and save loads.

`reachable_tiles` is a BFS with the search's expansion (ledge hops allowed, slides ridden, `edge_relax`
false), bounded by `reach`, 10,000 nodes and the same deadline; if cut short, `@rs_full` goes false and
`blocked_target?` stops rejecting anything. `reachable_set` caches it per `[x, y, map_id]` and it is shared by
`hide_unreachable`, the surface list and `surf_launch`.

By default the search stops on **node count** (`astar_max`, 2500); with `route_auto` it stops on **time**
(`route_budget_ms`, 8 ms) and `over_budget?` reads the clock every `BUDGET_CHECK` (256) nodes. The deadline is
one per **`find_path` call**, not per search: the up to three a route may run share it, and nesting
`with_budget` keeps the outer one. Every search honours it except the local A* in `hpa_low`. Once it runs out,
a **partial route** is still returned when the best node ended within 2 tiles of the target.

## Locator categories

Shift + arrow changes category; the arrow alone walks the list, sorted by distance. The spoken name comes
from the matching `tcat_*` key.

| Symbol | What it lists |
|---|---|
| `:all` | Everything the keys can reach: character sprites and examinable events |
| `:people` / `:objects` | The `event_category` split: whoever moves or talks, and the rest |
| `:exits` | Map transfers, with wide doorways collapsed into one |
| `:signs` | Signs and events that only show text |
| `:extras` | Hazards, traps, controls, push tiles and teleporters |
| `:surfaces` | Synthetic targets: the nearest tile of each surface the player can walk to |
| `:puzzles` | Cells a profile declared through the puzzle API |
| `:lens` | Lens of Truth (`#EOT`) tiles, only where the map has any |

The first seven are `Config.categories` and persist in `settings.ini`. `:puzzles` and `:lens` do not: they
are inserted only where the map has them, so no empty category is ever offered.

## 3D audio

`PA3D_steam.dll` (Steam Audio HRTF + miniaudio) is the mod's single audio engine: footsteps and bumps go
through it too. It needs `phonon.dll` of the matching architecture in `accessibility/lib`.

| Entry point | `Win32API` signature | Use |
|---|---|---|
| `PA3D_Init` | `[] → i` | startup; must return 1 |
| `PA3D_Channel` | `["p", "i"] → i` | loads a wav (null-terminated path) and returns its channel; 2nd arg = loop |
| `PA3D_Listener` | `["i", "i"] → v` | places the listener on the player |
| `PA3D_Set` | `["i", "i", "i", "i", "i"] → v` | places and plays a channel |
| `PA3D_Master` | `["i"] → v` | master volume |

Each entry point resolves under `rescue`, so a missing dll leaves it `nil`: `available?` requires those five,
while `PA3D_Rate`, `PA3D_Latency`, `PA3D_Occl` and `PA3D_Air` are optional. `boot` runs exactly once, requires
`INIT.call == 1`, reads the device rate and latency and loads the channels; assets already ship at the native
rate (44100 in `accessibility/sounds/`, 48000 in `sounds/48000/`, and `wav(name)` picks).

**`PA3D_Set` has no Z axis.** Its five integers are `(channel, x, y, volume, on)`: the fourth is a 0-100
volume, not a height, and the fifth is 1 to play/position and 0 to silence. Tile coordinates are scaled by
`TILE_UNITS` (100) so the HRTF distance model matches the map:

```ruby
# core/audio/audio3d.rb
SET.call(@ch[t], pos[0] * TILE_UNITS, pos[1] * TILE_UNITS, type_vol(t), 1)
```

### Channels

`CHANNEL_FILES` is the `[symbol, file, 1 when it loops]` list `boot` walks in full, and the answer to "which
file plays for this": the glossary previews those same files and a spec cross-checks both lists.

| Family | Channel and file | Loop |
|---|---|---|
| Emitters | `:npc` `pa3d_npc.wav`, `:object` `pa3d_object.wav`, `:door` `pa3d_door.wav`, `:teleporter` `pa3d_teleporter.wav` | no |
| Puzzles | `:hazard` `pa3d_hazard.wav`, `:control` `pa3d_control.wav`, `:trap` `pa3d_boop.wav`, `:push` `pa3d_boing.wav` | no |
| Bumps | `:wall` `pa3d_wall.wav` (terrain), `:interact` `pa3d_interact.wav` (something interactable) | no |
| Ambience | `:water` `pa3d_water.wav`, `:wind_w/e/n/s` `pa3d_wind_<side>.wav` (one recording per side) | **yes** |
| Footsteps | `:step` `pa_step.wav`, `:grass` `pa_grass.wav`, `:fstep_water` `pa_water.wav` | no |
| Guide | `:guide` `pa_guide_c.wav` | no |

### `sound_nav` modes

| Mode | What plays | How |
|---|---|---|
| `:full` | the whole soundscape | pings, water loop, one wind per wall, footsteps and bumps |
| `:basic` | footsteps and bumps only, still panned | the engine stays alive; `tick` calls `silence_emitters` every frame |
| `:off` | nothing | `tick` returns **before** `boot`, the engine never starts; `Spatial` skips its flat cues too |

`footstep(kind, vol)` centres the step on the player and `bump(dir, interact)` plays at the bumped tile.
`guide(dir, vol)` places the chime `guide_distance` tiles toward the next step (minimum 1); only `@ready`
gates it, so it plays in `:basic`, and only left and right use it (front and back, which HRTF cannot place,
use a flat cue with pitch as the hint).

### The tick

`tick` runs from a `frame_hook` on `Game_Player#update`:

1. No `$game_map`/`$game_player`, or `sound_nav :off`: `silence_all` and return.
2. `boot`, once; the first frame after starting re-runs `$game_map.autoplay`: opening the device mutes the
   game's BGM.
3. `Spatial.busy_reason` (message, menu, battle, foreign scene, forced move route, interpreter):
   `silence_all` and `@scan_pos = nil`, so the soundscape rebuilds on return even if the player never moved.
4. Master volume and air, only when they changed; `PA3D_Listener` on the player. In `:basic` it ends here.
5. Only when `[x, y, map_id]` changed: `rescan` (the `NEAR_MAX` = 3 nearest per type, with `cluster` merging
   touching tiles of the same sprite), `update_walls`, `set_winds` and the water loop; otherwise
   `refresh_movers` every `MOVER_SECONDS` (1.0 s) when the puzzle declares movers.
6. `ping_types`: at most **one** emitter per frame, the most overdue type, round-robin within the type; for
   `PING_GAP` (0.25 s) after a ping, only candidates within `audio3d_alt_dist` tiles are held back.

Each step runs isolated in `step3d`: a failure is logged once (`log3d`) and the rest carry on. `gate(reason)`
tallies why each frame fell silent and `gate_report` summarises it for the diagnostic.

## Settings

**Routes and guide** — `SCHEMA` rows in `core/foundation/config.rb`; ranges come from `KIND_BOUNDS`.

| Key | Default | Range | What it does |
|---|---|---|---|
| `route_reach` | 128 | 32-1024, step 32 | Maximum reach (manhattan diamond) of the search and the flood |
| `astar_max` | 2500 | 1000-10000, step 500 | Node cap, the default cut-off |
| `path_algorithm` | `:astar` | the 8 in `ALGORITHMS` | Search algorithm |
| `straight_routes` / `edge_relax` / `ledge_directions` / `route_cache` | off / off / on / on | on/off | Penalise turns; tolerate the map border; honour the hop direction; memoise passability |
| `guide_refresh` / `guide_distance` | 4 / 3 | 1-10 s; 1-6 tiles | Freshness of the cached route and how far ahead the chime goes |
| `auto_guide` / `hide_unreachable` | off / off | on/off | Guide on target selection; hide targets with no route |
| `route_auto` / `route_budget_ms` | off / 8 | on/off; 2-40 ms, step 2 | Cut on time, and that deadline (Debug menu) |

**Locator and field**

| Key | Default | Range | What it does |
|---|---|---|---|
| `hide_noninteractive` | off | on/off | Skip decorative events with no interaction |
| `fixed_target_number` | on | on/off | Number targets by their fixed position in the list |
| `name_items` | on | on/off | Say which item a poke ball on the ground holds, rather than a generic one |
| `surface_cues` | off | on/off | Announce the terrain underfoot when it changes |
| `puzzle_assist` | off | on/off | Puzzle hints on top of the position and each element's state |
| `transfer_active_page_only` | on | on/off | Only a tile whose ACTIVE page transfers counts as an exit (Debug menu) |

**Menu reading**

| Key | Default | Range | What it does |
|---|---|---|---|
| `auto_detect` | on | on/off | Read menus with no dedicated reader by introspection |
| `read_help` | on | on/off | Read each option's description after its name, where the menu shows one |

**3D audio**

| Key | Default | Range | What it does |
|---|---|---|---|
| `sound_nav` | `:full` | `:off` / `:basic` / `:full` | Soundscape mode |
| `audio3d_volume` | 80 | 0-100, step 10 | Engine master volume |
| `audio3d_npc` / `_object` / `_door` / `_teleporter` | 85 / 85 / 85 / 90 | 0-100, step 10 | Volume per emitter type |
| `audio3d_water` / `audio3d_wind` | 70 / 55 | 0-100, step 10 | Loop volumes |
| `footstep_volume` / `wall_volume` / `event_volume` | 80 / 80 / 70 | 0-100, step 10 | Footsteps, bumps and guide chime |
| `audio3d_freq_npc` / `_object` / `_door` / `guide_freq` | 70 / 70 / 70 / 55 | 0-100, step 10 | Ping and chime cadence |
| `audio3d_occlusion` | `:occlude` | `:hear` / `:occlude` / `:hide` | Emitter behind a wall (`line_clear?` raycast): as-is, muffled 80 of 100, or dropped |
| `audio3d_air` | off | on/off | Air absorption |
| `audio3d_wall_range` / `_wall_falloff` | 3 / 50 | 1-20 tiles; 0-100, step 10 | Wall probe and wind falloff, `v = vol / dist ** (falloff / 50.0)` |
| `audio3d_desk_range` | 2 | 0-3 tiles | Service counters kept audible in `:hide` mode; 0 disables it |
| `audio3d_range` / `audio3d_alt_dist` | 12 / 5 | 1-30; 1-20 tiles | Sonar reach (its own `:sonar` kind) and how close two emitters must be to alternate |
| `sonar_only_locatable` | off | on/off | Limit the pings to what the locator keys can reach |

Cadences are 0-100 values that `PokeAccess.freq_to_seconds` turns into a real interval, from 1.5 s (0) to
0.15 s (100). The puzzle types take volume and frequency from `audio3d_object`.

## References

- [Pathfinder](../../core/nav/pathfinder.rb), [Terrain](../../core/nav/terrain.rb),
  [Locator](../../core/nav/locator.rb), [Surfaces](../../core/nav/locator_surfaces.rb), [Guide](../../core/nav/guide.rb)
- [Audio3D](../../core/audio/audio3d.rb), [Spatial](../../core/audio/spatial.rb),
  [Glossary](../../core/audio/glossary.rb), [PA3D_steam](../../native/_backend.md); live state via
  `diag_pathfinder` and `diag_audio3d` (Ctrl+Alt+F9)
