# Navigation

Two subsystems orient the player around the map: `core/nav/pathfinder.rb` computes the route to a target and
`core/audio/audio3d.rb` builds the soundscape. The locator picks the target; the guides consume the route.

## Pathfinding

| Call | Returns |
|---|---|
| `find_path(tx, ty)` | RPG direction codes (`8` `2` `4` `6`) to a tile **adjacent** to the target; `[]` when already beside it, `nil` when there is no route. A door that only opens walked into from one side is reached on that side |
| `find_path_onto(tx, ty)` | The same, but the route ends **on** the tile: a shore to surf from, a dive spot |
| `gated_path(tx, ty)` | With no walking route, `[steps, gate]` up to the first assisted step (a field-move obstacle, a push, the action button, getting off the bike), or `nil` |
| `surf_launch(tx, ty)` | A route to the shore whose water really leads to the target, or `nil` |
| `path_to_text(path, cut = false)` | The spoken route ("3 up, 2 left"), or the "no route" / "next to it" text; with `cut`, "the route could not be calculated from here" |
| `legs(path)` | The route as `[direction, tiles]` legs; `leg_text(leg)` speaks one |
| `trace(x, y, level, path)` | Where each step of a route leaves the player, with the very moves the search made |
| `reachable_set` | `{ pkey => true }` of reachable tiles, cached per player tile |
| `reach` | The configured manhattan distance cap (`route_reach`) |

The origin is **always** `$game_player`: there is no start parameter. Arrival is `target_reached?` (manhattan
≤ 1), because the typical target -- an NPC, a sign, an item -- stands on a tile nobody walks into.

```ruby
# core/nav/pathfinder.rb
def self.find_path(tx, ty)
  searching do
    approach = door_approaches(tx, ty)
    next approach_path(approach) if approach
    px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
    dist = (px - tx).abs + (py - ty).abs
    next note_cut if dist > reach
    next nil if dist > FLOOD_MIN && blocked_target?(tx, ty)
    find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
  end
end
```

`searching` is the frame of every search: one deadline (`with_budget`), the player's bridge level put back
afterwards (`with_level_kept`) and the terrain asked once per tile (`Terrain.memoizing`). While it runs,
`searching?` is true. `blocked_target?` rejects the target through the cached flood, only beyond `FLOOD_MIN` (24)
tiles, with a complete flood and without `edge_relax`. Two passes: without ledge hops, then with them.

What lasts one search lives in a `SearchContext` (`Pathfinder.context`): the deadline, how deep the searches
nest, the vehicle and bridge level the player started from, whether the map's ramps are live, the touch-event
index at hand, and whether it is an assisted search and with which obstacles set aside. The outermost wrapper
opens it (`with_budget`, `with_level_kept`, `with_gates_open` or `with_rocks_through`), nested searches share it,
and it is dropped when the outermost ends, even when it raises: nothing of one search is left for the next. What
does last between searches (the passability memo, the per-map indexes, the HPA* graph) has its own invalidation.

Files: `pathfinder.rb` is the frame (context, deadline, passability memo, indexes, entry points);
`route_search.rb`, the searches (A* and its variants, the flood); `route_grid.rb`, JPS and HPA*;
`route_terrain.rb`, what one step over the terrain does (`step_target`: ledges, ice, the map's border, arrival
rules); `route_events.rb`, touch events (`move_target`); `route_water.rb`, water; `route_gates.rb`, assisted
routes; and `route_text.rb`, the spoken route.

Passability is the game's own (`$game_player.passable?`), asked **as if the player were not walking through
walls**: games switch their `through` on for scripted moves, and a route asked for in that moment would cross
rock (`player_passable?` sets it aside and puts it back).

### Algorithms

`path_algorithm` picks the frontier; the neighbour expansion and the fewer-turns tiebreak are shared.

| Value | Frontier | Priority | Note |
|---|---|---|---|
| `:astar` (default) | binary heap | `2g + 2h` | optimal route; also where an unknown value falls |
| `:weighted` | heap | `2g + 3h` | doubled weights express 1.5x in pure integers |
| `:greedy` | heap | `2h` | straight at the target, prone to detours |
| `:dijkstra` | heap | `2g` | optimal without heuristic, explores more |
| `:bfs` / `:dfs` | queue / stack | — | no heap; DFS only for experiments |
| `:jps` | jump points | `g + h` | a straight corridor costs one expansion |
| `:hpa` | cluster graph | `g + h` | hierarchical, for large maps |

`straight_routes` adds +1 to the cost of each turn. JPS and HPA* assume a uniform grid (`uniform_grid?`), so a map
with touch events that move the player (see below), terrain a game or plugin registers, or the player surfing, is
searched with A*. JPS also falls back to A* (its scan's `fallback` flag, `JpsScan`) on ice,
ledges, recursion deeper than 80 levels or an exhausted step budget (`[astar_max * 8, 20000]`). HPA* tiles the map
into `HPA_CLUSTER` (10) clusters and routes portal to portal to a synthetic sink (`HPA_SINK`), refining each hop
with a **live** local A*: a stale graph can only yield `:fallback`, never a wrong route. Both only in the first pass.

### One step, as the game plays it

`move_target(cx, cy, dir, allow_ledge, edge_relax, level)` is the one place a step is composed, and the search,
the flood and the guide all use it, so they cannot disagree. It answers a `Pathfinder::Step`: the tile it leaves
the player on, the bridge level there, the presses it takes (more than one only for a run) and, for an assisted
step, its gate. First `step_target` resolves the tile:

| Terrain | Resulting neighbour |
|---|---|
| Ledge (tag 1) | Never a standable node: checked **before** passability, because the modern engines declare it passable from the high side. Crossing it is always the two-tile hop (`ledge_jump`), with `allow_ledge`, a real landing and the passage bit of the opposite side open (`LEDGE_OPP_BIT`; permissive when the tileset cannot be read) |
| Ice (tag 12) | Where the slide **ends** (`ice_slide`), not the adjacent tile; capped at 200 steps |
| Map edge | With `edge_relax`, a passable edge tile counts as a neighbour even if the directional step fails. Off the map there is no neighbour, even when the engine lets the player walk into a connected map |

Then whatever the touch event of that tile does (or, when the step bumps, the event of the tile it bumps), read
by `core/nav/route_events.rb`:

| Effect | What it is | On the route |
|---|---|---|
| `:carry` | A move route on the player with nothing around it: a slide across a gap, a hop over a hedge, a diagonal staircase, an arrow floor | Lands where the move leaves the player. When the page does not wait for the move, every tile on the way fires its own event, as in the game: that is how arrow floors chain (cap `CARRY_HOPS`) |
| `:warp` | A transfer to another tile of the **same** map (floors, rooms, holes, `pbTransferWithTransition` with coordinates) | Lands on the destination |
| `:exit` | A transfer to **another** map, or one that cannot be read (behind a question) | Never stepped on midway; it can only be the target |
| `:barrier` | A scene that talks and shoves the player back or aside without setting anything that stays: a story block | A wall from that side for as long as its page stands |
| `:ramp` | A bridge ramp (`pbBridgeOn` / `pbBridgeOff`) | Changes the search's bridge level |
| `:run` | A fixed stretch of presses armed by arriving on the tile (the end of a side staircase) | From it, one search step counting all its presses |
| `:hold` | Ground the page lets the player onto only with the direction key held: its condition reads `Input.press?` and the branch it takes depends on it (Emerald's cracked floors, on the bike) | A plain step; the guides say to keep the key held (`held_key_at?`) |

Whether the event fires when the player **arrives** on it or **bumps** into it is the engine's own
`over_trigger?`: a sprite-less (or through) event on a tile anyone can stand on is walked onto; on a solid tile it
fires by bump from the neighbour, in both eras. A `size(w,h)` event occupies and fires from all of its tiles.

`core/nav/event_pages.rb` reads the **active** page the way the interpreter would run it, for each entry facing,
running nothing: it follows the `111/411/412` branches (the else included), steps into common events (`117`)
and simulates the route (steps, diagonals, forward/backward, jumps by their distance, turns, direction fix).
Conditions are answered from live state (switches, variables, self switches, the facing, the key held) and a
small script grammar (`$PokemonGlobal.bicycle`, the bag, `pbGet`, `visitedMaps`, `$game_map.map_id`, the
interpreter's `get_character(0)` and `(-1)`, `&&`, `||`, `!`, comparisons, short-circuiting over what it does not
know). A page that asks where the player stands (`$game_player.x`, `.y`: the scene strips
that move the player one way or another by the tile stepped on) is read tile by tile, from where the player
would be when it fires. What it cannot answer it does not guess: the page stays unknown.

### Bridges: two levels

A bridge map is two maps laid over each other: the deck, walkable with the bridge level up, and the ground under
it at level 0. The search state is `(x, y, level)` (`skey`), starts at the engine's bridge height
(`Terrain.bridge_height`: `$PokemonGlobal.bridge` from v16, `$PokemonMap.bridge` in the copies before) and only
changes on a ramp. Before a node is expanded the engine is pointed at its level (`use_level`), and `with_level_kept` puts the
player's own back afterwards whatever happens. Maps without ramps are not touched.

### Water

With no walking route, `surf_plan` runs the flood again allowing surfing (`water_step`): pushing off only from a
shore whose own tile is open toward the water (the engine's rule), water to water, and coming ashore on land open
on that side with nothing solid on it; a waterfall is ridden down from its crest and climbed with Waterfall
when the party may be able to. Each tile remembers the **first** launch on its way,
and the target's is the shore to take the player to (`surf_launch`), not the one nearest as the crow flies, which
is often a pond that leads nowhere. It is not offered when the party is known not to be able to surf
(`FieldMoves.can?(:SURF) == false`), nor on a map that keeps the player on the bike, where the engine refuses it.

`FieldMoves.can?` answers the way the game does: the engine's own finder (`get_pokemon_with_move` /
`Kernel.pbCheckMove`, which compare ids and never English names), the items a profile declares
(`field_move_item`: the Surf mount in Z, the surfboard and scuba gear in Infinite Fusion, Soulstones' PokeGear
apps, which still want the badge), Marin's HM Items, the
Advanced Items plugin (its own `pbCanUseItem`) and the badge. `nil` (could not read) never counts as no.

### Assisted routes

With no walking route, `gated_path` searches again allowing what the player can **do** to get past
(`with_gates_open`), and cuts the route short of the first such step; on a map with nothing of the kind
(`assist_possible?`) it answers `nil` without searching. Each step carries its gate:

| Step | What it is | The guide says |
|---|---|---|
| Cuttable tree, smashable rock | `GATES`, by the name the locator already recognises; made `through` during the search, and the passability cache stores nothing meanwhile | "Cuttable tree up, use Cut" or "you need Cut" |
| Strength boulder, cart or statue | Events whose script pushes (`pbPushThisBoulder`, `pbPushThisEvent`, `pbMoverEstatuas`) or named Boulder. When the assisted route does not reach, `push_route` searches the player together with where each moved boulder is left (only the moved ones; the one that blocks the way, pushed as often as it takes, or with the puzzle assist, `puzzle_assist`, up to `PUSH_LIMIT` boulders; at most `PUSH_NODES` states), the boulders `through` for the engine; a push holds when nothing is where it would go and the boulder itself could move there from where it stands (strict `passable?` or `passableStrict?`, asked with its `through` off) | "Strength boulder up, use Strength"; with no move, "push it by walking into it" |
| Action button | Action events whose page, answering **yes** to its question, carries the player with Through (climbing gear, Z's Gogoat mount, Royal's rock climbing, lifts) or moves them within the same map. Read by `EventPages` in interaction mode: each question's first option, confirmations accepted, the answer kept in a variable. Nothing that fights or changes anything that stays | "face up and press the action button" |
| Waterfall | Surfing, facing up into the fall: up to the first tile above that is neither fall nor crest | "Waterfall up, use Waterfall" |
| Getting off the bike | Tall grass or ice the bike cannot enter (the engine's own passability, asked on foot). Never on a map that keeps the player on the bike (`MapMeta.always_bicycle?`) | "get off the bike and continue right" |
| What a game or plugin adds | `assist_source` (the `assisted_step` DSL): Añil's Rock Climb on climbable rock, Infinite Fusion's Rock Climb on a ledge (with climbing gear), getting onto IF Hoenn's rails on the bike | by its label |

An assisted step costs `GATE_COST` (8) steps more than a plain one: a short detour is preferred, and one obstacle
to two. In interaction mode `EventPages.outcome(ev, d, at, true)` takes the first option of `102`/`402`, reads
`pbConfirmMessage` as yes and records the answer of `$game_variables[n] = pbMessage(..., [options])`.

### Terrain that moves the player

`step_target` puts every arrival through `arrive`: the engine's waterfall descent (surfing, moving down onto the
crest) and the rules each terrain's owner registers (`arrival_rule`, the `terrain_rule` DSL), since tag numbers
collide from game to game:

| Terrain | Where | Rule |
|---|---|---|
| Slides and currents (tags with `slide_up`...) | Directional Sliding plugin (Soulstones 2) | On in the tile's direction while the player can move and stands on sliding ground or ice; a sliding tile met on the way starts a slide of its own, and when it stops the first one carries on if it can |
| Spin tiles (`PBTerrain::SpinTile*`) | Spin Tiles plugin (Ópalo, Realidea) | Spins the way the arrow points and on, off the arrows too, until blocked; each arrow turns it. Realidea's copy also stops on plain ground in map 323 (`extra_stop?`, through `override`) |
| Current (`waterCurrent`, tag 6) | Infinite Fusion and IF Hoenn | Surfing, pushes up, else left, right or down, while still on the current and able to go the way it came in |
| Slope 42 and currents 44-47 (with switch 182) | Realidea | After every step of the player onto it, one tile down (or the current's way), with Through |
| Floor trap (tag 17) | Awakening | After every step onto it, one tile down unless right, left or up is held: walking across stays put, walking down falls to its end. The guides say "keep the key held down" (`held_key_rule`) |

Some terrain is **left** by a move of its own: `leave_rule` (the `terrain_exit` DSL) answers where the player
comes off it even where the next tile would not allow it, like the hop off IF Hoenn's rails.

Marin's **side stairs** (the plugin in Añil and Royal, and its v17 original in Realidea) are `Slope` events one
tile out from each end: stepping on one arms the stair, and from there `|A|` sideways presses cross whatever the
tiles say and leave the player `B` rows up or down. For a route that is a **run** (`:run`, registered with
`touch_source`): one search step counting `|A|` presses, which `trace` replays tile by tile, marking the ones in
between (`mid`). Royal's staircases by common event (`Escaleras size(3,3)`) ask with functions of their own where the
player stands against the event; the profile declares them (`script_condition`) and they are read tile by tile.

An ice slide that passes over an event fires it as if it were stepped on: cracked ice gives way, a hole drops the
player through, and a slide that would cross an exit is not taken. The tile it ends on does not go through
`arrive`: SS2's plugin would start there, but the gen-6 spin tiles ignore steps taken while sliding, and none of
the 16 games it was checked on puts ice next to such terrain.

### Caches and budget

`$game_player.passable?` is costly and a search calls it thousands of times. With `route_cache` it is memoised per
`vehicle_state` (the map and whether the player surfs, dives or rides the bike, in one Integer), with the tile, the direction and the bridge level in the key. At the start
of every search `sync_event_memo` compares the events with the last search's: for one that moved, went through
or solid or changed sprite (a wandering NPC, a pushed boulder, what the Lens of Truth reveals) it forgets the
steps into its old tile and its new one, and when it starts with the action button or a touch and turned a
page, it drops the indexes of what events do to a route. Nothing is memoised with the obstacles set aside or with the player partway up a
side staircase (`on_middle_of_stair?`: Marin's plugin then answers with the staircase for any tile; neither the
flood nor the guide's route is rebuilt meanwhile). On its end tile, the stair armed but not climbed, the
answers are the map's own. `invalidate_cache(force = false)` drops passability, reachable tiles, the HPA* graph,
the water flood, the surf route, and the touch-event, action, obstacle and pushable indexes; it is throttled to 2 s, and
`Caches` registers it with `force = true` (no throttle) for map changes and loading a save. The event
indexes are built per `vehicle_state`, since a page may ask whether the player rides the bike; a search takes
it once at its start (`index_vehicle`), as it asks them thousands of times. Every time they
are dropped it is counted (`event_epoch`, with the vehicle state): the guide does not trust a stored route
planned under another count, replays it and requires it to still end where it was planned; otherwise it
searches again.

The terrain has its own memo (`Terrain.memoizing`): inside a search each tile is asked of the engine once, with
the bridge state in the key. With `route_cache` the memo lasts the whole map (`Terrain.map_memo`): the sonar's
water ring and the next search read it too, and it goes with the same things as the passability cache (a new map,
an event end, switching the cache off). With the cache on the sonar also stops rescanning on every tile of an ice
slide, only where it stops (`Audio3D.slide_hold?`).

`flood` is a BFS with the search's expansion (hops allowed, touch events, `edge_relax` off), bounded by `reach`,
10,000 nodes (20,000 with water) and the same deadline; it returns `[tiles, complete]`. When it is cut short,
`blocked_target?` stops rejecting anything. `reachable_set` caches it per `[x, y, map_id]` and it is shared by
`hide_unreachable`, the surface list and the sonar.

By default the search stops on **nodes** (`astar_max`, 2500); with `route_auto` it stops on **time**
(`route_budget_ms`, 8 ms) and `over_budget?` checks the clock every `BUDGET_CHECK` (256) nodes. The deadline is one
per **`find_path` call**, not per search: the up to three a route can start share it and nesting `with_budget`
keeps the outer one. All honour it except `hpa_low`'s local A*. Once it runs out, a **partial route** is still
returned when the best node ended within 2 tiles of the target.

### The two guides

Both consume the SAME cached route -- `refresh_guide_path` computes it once and `advance_guide_path` spends it as
the player walks, replaying it with `trace` -- and differ only in what they emit:

| Guide | Key | Emits | Cadence |
|---|---|---|---|
| Cane (`toggle_guide`) | Shift+I | A panned chime toward the next step; over ground where the key has to be held, that same sound held | Clock (`guide_freq`), spaced out with distance; on a leg over such ground, tile by tile as well |
| Step by step (`toggle_steps`) | Ctrl+I | The current leg spoken, "6 up" | On a tile change, and only when the leg is new |

`Pathfinder.legs` splits the route into `[direction, tiles]` legs: `path_to_text` joins them all (key I) and
`announce_leg` reads only the first. It speaks when the direction changes, or when the same leg GROWS after a
wrong turn; while it only shrinks, it stays quiet. Before a step that is a jump (a ledge or an event that hops the
player) it says "jump" and the direction. They share the "no route" latch and the end of the journey
(`stop_guides`), so arriving is not announced twice with both on. Partway along a run (a side staircase) the
guide stays on the route without spending any of it until the run ends. Where the key has to be kept held down,
the step guide says so with the leg and the cane once, before its next step onto that ground (with both on, only
the step guide). With 3D audio the cane also swaps the chime for that same sound held (`:guide_hold`, a loop
that moves without restarting) while its next step lands on such ground, and on a leg across it follows the
player tile by tile. The check replays the leg as the search made it, so a step the terrain carries further is
judged where it ends.

The steps the guides count are steps of movement. On a change of direction, or after letting go and pressing
again, the first short press only turns the character (the engine waits more than 2 frames on gen-6 and
0.075 s on v21 before stepping); holding the key, it goes unnoticed.

With no walking route the guide first tries the assisted route, then the one to the shore. In
both the end of the route is **not** the arrival: the guides stay on and say once per tile what to do there
("Cuttable tree up, use Cut", "face up and press the action button", "surf right"); as soon as the player does
it, the new route exists and they carry on by themselves. At a dive spot the route ends on it and says what the action button
does there; one chosen on foot first holds on the shore with the way to surf. While an event carries the player (a
slide, a warp), the step guide keeps quiet and speaks again from where it lands.

## Locator categories

Shift + arrow changes category; the arrow alone walks the list, sorted by distance. The spoken name comes
from the matching `tcat_*` key.

| Symbol | What it lists |
|---|---|
| `:all` | Everything the keys can reach: character sprites and examinable events |
| `:people` / `:objects` | The `event_category` split: whoever moves or talks, and the rest |
| `:exits` | Map transfers, with wide doorways collapsed into one. Named "exit to X", or "entrance to X" from outdoors into an interior (map metadata); when the destination bears the current map's name, "Pokémon Center" (the map declares its healing spot), "building" or "another part of X" |
| `:signs` | Signs and events that only show text |
| `:extras` | Hazards, traps, controls, push tiles and teleporters |
| `:surfaces` | Synthetic targets: the nearest tile of each surface the player can walk to |
| `:puzzles` | Cells a profile declared through the puzzle API |
| `:lens` | Lens of Truth (`#EOT`) tiles, only where the map has any |
| `:marks` | The player's own markers (`Ctrl`+`G`), only on maps where they set one |

The first seven are `Config.categories` and persist in `settings.ini`. `:puzzles`, `:lens` and `:marks` do
not: they are inserted only where the map has them, so no empty category is ever offered.

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
while `PA3D_Rate`, `PA3D_Latency`, `PA3D_Occl`, `PA3D_Air` and `PA3D_Pitch` (per-channel pitch as a percentage of the recording; the tones menu) are optional. `boot` runs exactly once, requires
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
| Markers | `:mark` `pa3d_mark.wav` — the player's markers; tiles, not events, so `rescan` adds them separately (`mark_emitters`) | no |
| Bumps | `:wall` `pa3d_wall.wav` (terrain), `:interact` `pa3d_interact.wav` (something interactable) | no |
| Ambience | `:water` `pa3d_water.wav`, `:wind_w/e/n/s` `pa3d_wind_<side>.wav` (one recording per side) | **yes** |
| Footsteps | `:step` `pa_step.wav`, `:grass` `pa_grass.wav`, `:fstep_water` `pa_water.wav` | no |
| Guide | `:guide` `pa_guide_c.wav` | no |
| Guide, keep the key held | `:guide_hold` `pa3d_guide_hold.wav` — the chime's timbre (E5 with its 2nd and 3rd harmonics), held | **yes** |

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
3. `Spatial.busy_reason` (message, menu, battle, foreign scene, the map's mini update, forced move route,
   interpreter):
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
| `straight_routes` / `edge_relax` / `ledge_directions` / `route_cache` | off / off / on / on | on/off | Penalise turns; tolerate the map border; honour the hop direction; memoise the map's passability and terrain, and hold the sonar's rescan through a slide |
| `guide_refresh` / `guide_distance` | 1 / 3 | 1-10 s; 1-6 tiles | Freshness of the cached route and how far ahead the chime goes |
| `auto_guide` / `auto_steps` / `hide_unreachable` | off / off / off | on/off | Start the cane and the step guide on target selection; hide targets with no route |
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
| `defer_target_rebuild` | on | on/off | When an event ends, the target list is marked stale and rebuilt when next used (J/L or where) instead of at once (Debug menu) |

**General**

| Key | Default | Range | What it does |
|---|---|---|---|
| `language` | `:auto` | `:auto`, or a code with a file in `lang/` | The mod voice language. `:auto` takes the system's (Catalan, Basque and Galician count as Spanish); if the mod lacks that one, the language the game declares; failing that, English. Updating from an older version turns the ini to `auto` once (`settings_version`); after that the menu choice is kept |

**Menu reading**

| Key | Default | Range | What it does |
|---|---|---|---|
| `auto_detect` | on | on/off | Read menus with no dedicated reader by introspection |
| `read_help` | on | on/off | Read each option's description after its name, where the menu shows one |
| `dialogue_pages` | off | on/off | Read dialogue page by page as the box shows it, cutting the previous page on moving on, instead of the whole message queued (`core/dialogue/pages.rb`) |

**3D audio**

| Key | Default | Range | What it does |
|---|---|---|---|
| `sound_nav` | `:full` | `:off` / `:basic` / `:full` | Soundscape mode |
| `audio3d_volume` | 80 | 0-100, step 10 | Engine master volume |
| `audio3d_npc` / `_object` / `_door` / `_teleporter` / `_mark` | 85 / 85 / 85 / 90 / 85 | 0-100, step 10 | Volume per emitter type |
| `audio3d_water` / `audio3d_wind` | 70 / 55 | 0-100, step 10 | Loop volumes |
| `footstep_volume` / `wall_volume` / `event_volume` | 80 / 80 / 70 | 0-100, step 10 | Footsteps, bumps and guide chime |
| `audio3d_freq_npc` / `_object` / `_door` / `_mark` / `guide_freq` | 90 / 10 / 70 / 80 / 75 | 0-100, step 10 | Ping and chime cadence |
| `audio3d_occlusion` | `:hide` | `:hear` / `:occlude` / `:hide` | Emitter behind a wall (`line_clear?` raycast): as-is, muffled 80 of 100, or dropped |
| `audio3d_air` | off | on/off | Air absorption |
| `audio3d_wall_range` / `_wall_falloff` | 3 / 50 | 1-20 tiles; 0-100, step 10 | Wall probe and wind falloff, `v = vol / dist ** (falloff / 50.0)` |
| `audio3d_desk_range` | 2 | 0-3 tiles | Service counters kept audible in `:hide` mode; 0 disables it |
| `audio3d_range` / `audio3d_alt_dist` | 12 / 5 | 1-30; 1-20 tiles | Sonar reach (its own `:sonar` kind) and how close two emitters must be to alternate |
| `sonar_only_locatable` | off | on/off | Limit the pings to what the locator keys can reach |
| `game_bump` | off | on/off | Also play the game's own bump; off, only the mod's wall cue is heard while that cue is on |

Cadences are 0-100 values that `PokeAccess.freq_to_seconds` turns into a real interval, from 1.5 s (0) to
0.15 s (100). The puzzle types take volume and frequency from `audio3d_object`.

## References

- [Pathfinder](../../core/nav/pathfinder.rb), [Terrain](../../core/nav/terrain.rb),
  [Locator](../../core/nav/locator.rb), [Surfaces](../../core/nav/locator_surfaces.rb), [Guide](../../core/nav/guide.rb)
- [Audio3D](../../core/audio/audio3d.rb), [Spatial](../../core/audio/spatial.rb),
  [Glossary](../../core/audio/glossary.rb), [PA3D_steam](../../native/_backend.md); live state via
  `diag_pathfinder` and `diag_audio3d` (Ctrl+Alt+F9)
