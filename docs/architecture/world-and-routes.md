# World and routes

This page explains how the mod models the map and how it finds, prices and describes a route to a target: the World
layer (terrain, passability, events, puzzle mechanics), moves and searches, regions, the planner with its
[assisted steps](../reference/glossary.md), surfing and transfers, and route text. Read it before changing a search
or giving a [profile](../reference/glossary.md) a terrain, route or puzzle rule.

The settings named here are in the [settings reference](../reference/settings.md), the profile verbs in the
[profile DSL reference](../reference/profile-dsl.md). The step guide, the cane and the sound cues that follow a route
are in [Guide and sound](guide-and-sound.md).

## Layers

Each part of the code has one job:

- `core/world/` reads the game and keeps what it reads. It decides nothing and says nothing.
- `core/routes/` turns the world into moves, searches, plans and route text. The `PokeAccess::Pathfinder` files in
  `core/nav/` (`pathfinder.rb`, `route_search.rb`, `route_grid.rb`, `route_gates.rb`, `route_water.rb`) hold the
  search frame, the algorithm setting, HPA*, the frame of assisted searches and the way across water.
- `core/puzzles/` says what `World::Mechanics` models.
- The locator and the guide get a plan from `Locator.route_plan` and say it through `Routes::Text`.

Dependencies run one way: the World layer never calls a route, and nothing in `core/world/` or `core/routes/` speaks.

The code runs on the mod's two beats ([Loading](loading.md)). Every pulse and every map frame marks the world
unsettled (`Epoch.dirty!`). The map frame's `:world` stage notices the end of a running event
(`Locator.refresh_on_event_end`), and its `:nav` stage runs `Puzzles.tick`, `Routes::Regions.tick` and
`Pathfinder.hpa_tick` (`core/input/frame.rb`).

## The world's memos

Reading the engine is slow, so the World layer keeps what it reads, and no memo expires with time. `World::Epoch`
tells each memo when it stops holding; a memo registers what drops it with `Epoch.on`:

- `:map`: a new map, which is a new map id or a new `$game_map` object (a load rebuilds it on the same id). A new map
  drops the `:tiles` memos too.
- `:tiles`: new tiles, told by a fingerprint of the map's layers and of the tileset's passage, priority and terrain
  tables, name and autotiles.
- `:reset`: everything, on `World.reset!`, which `Caches.reset_all` runs on a map change or a load.
- `:frame`: work taken afresh once a frame.

The first question after a mark settles the world and notices a new map. The fingerprint dumps the whole map with
`Marshal`, so it is compared only when due: after an event's end (`Epoch.tiles_due!`), or when a reader about to
read tiles asks with `Epoch.settle(true)`, and then once per mark at most.

### Map memory

A profile that declares `plain_passability` states that the game's passability reads only the tiles, the events and
the mode. In such a game `World::Visits` keeps the memos of the last `Visits::SIZE` maps as the player leaves each one.
Coming back restores them while the fingerprint matches, minus the passability answers on the tiles the events
covered; a map whose tiles changed is forgotten. The memos kept this way register with `Visits.keeper`: the terrain
classes, the passability answers and the map scan of `Routes::Moves`.

### Terrain

`World::Terrain` classes each terrain tag once, into a stable kind (`:ledge`, `:ice`, `:still_water`...) and a set of
cell bits (`SURF`, `LEDGE`, `ICE`, `DEEP`, `GRASS`, `FALLING`). The kind comes from the tag's GameData id or
`PBTerrain` name first, since games renumber the standard tags; lava has no standard number and is found by name only.
The layer asks the engine for the tag once per kind of tile (the tile ids on the map's layers) and shares it among
every tile of that kind.

A bridge tile reads as the water below while the player is off the bridge, so it is kept per bridge height.
`World::Engine` hides where the eras differ: the Reborn engine's `terrain_tag` takes no bridge argument, and copies
older than v16, such as Insurgence, keep the bridge height on `$PokemonMap` instead of `$PokemonGlobal`
([Engine eras](engine-eras.md)).

A profile changes the terrain with two rules. `Terrain.label_rule` names a game's own surfaces, and
`Terrain.surf_rule` decides where the player can surf now. `Terrain.flag?` reads the flags a plugin adds to the modern
tag object, such as a current or a slide.

### Passability probe

`World::Probe`, the [passability probe](../reference/glossary.md), is the one place that asks the engine whether the
player can take a step (`$game_player.passable?`). Its answer is `OPEN`, `CLOSED` or `ERROR`. A search asks it
thousands of times, so it keeps its answers per mode: surfing, diving, the bike, and what a profile or a plugin adds
with `Probe.mode_reader`, such as a lava surf or a mount. It keeps at most `Probe::MODES_KEPT` modes at once. The memo
key is the step's origin and direction, and whether the bridge is up when either end is a bridge tile.

It never keeps three kinds of answer: a step off the map, a step touching a tile lent through, and every step while
the answers are unstable. They are unstable partway up Marin's side stairs, whose plugin answers every question from
the stair, and while a debug build walks through walls.

The passability probe asks the way the game would:

- The player's `through` flag is lent off for the question.
- A step into the player's own tile, which every engine refuses, is asked again with the player placed on the step's
  origin. `Probe.place_player_when` has every step asked that way while its block holds; Insurgence needs it afloat,
  as its passability answers from where the player stands.
- Afloat, a step out of a tile that is not water is asked on foot, since the engine ends the surf there
  (`Probe.ashore?`). `Probe.afloat` runs a block afloat and `Probe.on_foot` runs one off the bike.
- An engine error is `ERROR`. A route takes it as closed and the sound cues as open (`Probe.step?` and its
  `on_error`).

A search opens one `Probe.session`, which settles the world once for all its questions: the tiles compared, the events
synced, the mode taken.

`Probe.lend_through` makes events passable for the engine while a block runs, keeps their tiles out of the memo
meanwhile and puts every event back afterwards. Assisted searches lend obstacles and boulders through, and the regions
lend walkers through. `Probe.event_movable?` asks the engine's strict check, where it has one, whether a boulder can
move, or the plain check where the profile declares `loose_pushes` (the Reborn engine, Sevii, Infinite Fusion).

The answers go with new tiles, a reset and the tiles of any event that changes. At an event's end they all go, unless
the profile declares `plain_passability`.

### Events and facets

`World::Events` keeps one record per map event: its page, trigger, graphic, `through` flag, name and the tiles it
covers. The area is the size the engine keeps (v19 and later) or the `size(w,h)` in the event's name (gen 6). Records
are synced with the engine at most once a frame, and always as a search starts. Each change bumps `Events.gen` and tells
the `Events.on_change` listeners the tiles it left or reached and how: `:come`, `:go`, `:move` or `:change`. The
passability probe, the regions, HPA*, the water launches, the guide and the sound scene listen.

A facet is a meaning of an event, computed from its record on first use and registered with `Events.facet_provider`.
`Routes::Effects` registers four: `:touch`, `:act`, `:gate` and `:push`. While a facet is computed, `World::Flags`
notes each piece of live state it reads (switches, variables, self switches, the bag, visited maps, the vehicle, a
facing), and the facet is kept while every noted read gives the same value. A read nothing can watch, such as a game's
script call, makes the facet volatile: it lasts until the next event's end.

`Events.turns` counts the changes that may change a route: a touch or action page that turns, such an event coming or
going, a facet whose reads changed. `Pathfinder.event_epoch` joins it with `Pathfinder.vehicle_state` (the map, the
probe's mode and what the party may do on water) and the count of event ends; a route planned under another epoch is
checked again before it is trusted. `Events.walkers` lists the events that walk
about by themselves (at random, toward the player, or along a route that steps) and block the way.

### Reading event pages

`EventPages.outcome` walks an event's active page as the interpreter would run it for one facing, without running
it. Its `EventPages::Outcome` tells whether the page moves the player, transfers them, sets a bridge height,
talks or fights, changes something that stays, or stopped at something it could not answer. A page with a script
condition is walked tile by tile, since the script may ask where the player stands, and a profile tells the walk what
such a script returns with `script_condition`. When the page is started with the action button (`act`), the walk
answers yes to its questions.

`Routes::Effects` turns outcomes into what an event does to a move:

| Effect | Meaning |
|---|---|
| `:carry` | A Set Move Route on the player and nothing else, landing them elsewhere |
| `:warp` | A transfer to another spot of the same map |
| `:exit` | A transfer off the map, or to a spot of it the page does not name |
| `:barrier` | A page that talks, sets nothing and moves the player back or aside |
| `:ramp` | A bridge ramp, which changes the bridge level |
| `:run` | Presses across impassable tiles, armed on arrival (side stairs) |
| `:hold` | Ground the player stays on only with the direction key held |

Action-button events that carry the player (a climb) or move them within the map, field-move obstacles and pushables
are indexed apart (`Effects.act_index`, `gate_index`, `boulder_index`). Each index is built from the facets and kept
until an event changes.

## Moves

`Routes::Moves.step` makes one move from a search state as the game plays it. It answers a `Moves::Step`: the
tile and bridge level the press ends on, its presses, an assisted step's gate, whether it crossed a transfer, and its
kind (`:walk`, `:jump`, `:slide`, `:carry`, `:warp`, `:run`, `:ramp`, `:assist` or `:surf`). The mode bits choose what
a press may do: `LEDGE` hops ledges, `ASSIST` allows assisted steps, `RELAX` takes a passable border tile as a step
(`edge_relax`), and `SURF_PLAN` allows surfing.

A press resolves in the game's order:

1. A run armed on the tile takes over (side stairs).
2. A rule that owns the tile being left decides.
3. A ledge ahead is hopped with `LEDGE`. The landing is asked of the engine with the player placed on the origin, as a
   jump asks it.
4. An open step lands on the next tile. Ice slides the player on, a surfer moving down onto a waterfall's crest is
   carried down the fall, and a rule that owns the tile moves the player as it says.
5. The touch event on the landing tile fires: an exit or a barrier refuses the move, a ramp changes the level, and a
   carry or a warp lands the player elsewhere.
6. A closed step bumps the event in front, which may carry or warp the player. With `ASSIST`, an assisted step may get
   past it.

`Moves.trace` replays a route press by press with the same moves, and `Moves.one_way` marks the presses that cannot be
undone the same way, a jump or a slide. The guide follows a route through `trace`, and route text names those presses.

`Moves.fast` answers most moves without `step`. It keeps a class per tile (ledge, ice, falling water, a rule's tile, an
event's tile, a bridge tile, the border) and answers a plain step from the classes and the passability probe alone;
any other move goes to `step`. It drops the classes whenever `Events.gen` changes.

### Rules a profile adds

Tag numbers collide between games, so terrain that moves the player belongs to the profile or plugin that knows it.
Each rule has an owner, the tiles it may answer for: terrain numbers (`:tags`), kinds (`:kinds`), tag flags (`:flags`)
or a block over the map's tiles and events (`:tiles`). An unknown owner key raises `ArgumentError`, so a misspelt owner
cannot silence a rule. The profile verbs are these:

- `terrain_rule`: where a step that arrives on the tile ends (a slope, a current, a spin tile).
- `held_key_ground`: tiles where the direction key has to stay held.
- `terrain_exit`: terrain the player leaves by a move of its own (a rail hopped off).
- `assisted_step`: something the player can do where walking stops, owned by the tiles in front.

```ruby
# games/infinitefusion_common/water_current.rb
PokeAccess::Game.define("infinitefusion_common") do
  terrain_rule(:flags => [:waterCurrent]) do |x, y, d|
    next nil unless ($PokemonGlobal.surfing rescue false) && PokeAccess::IFWaterCurrent.current?(x, y)
    PokeAccess::IFWaterCurrent.carry(x, y, d)
  end
end
```

A map is uniform (`Moves.uniform?`) only while the player is not surfing, no touch event of the map changes a move and
the game registers no rule that moves the player. HPA* runs only on a uniform map.

### Bridge levels

On a bridge map the same tile is a floor on one level and a wall on the other. A search state therefore packs the tile
with whether the bridge is up (`Pathfinder.skey`). The level is carried only on a map with a ramp
(`Effects.ramp_map?`). Before expanding a state the search points the engine at that state's level
(`Pathfinder.use_level`), and `Pathfinder.with_level_kept` puts the player's own level back whatever happens.

## Searches

### Goals, cost and states

A `Routes::Goal` holds the tiles that count as getting there. Acting on a target (`Goal.near`) ends on it, beside it
or across a counter from it, over the whole area of a wide event (`Pathfinder.reach_tiles`); an action event that
fires only with the player on it is reached on its own tiles. Standing on a tile (`Goal.onto`) is for a shore to push
off from or a spot to dive at. A one-sided doorway is reached from the tiles it is walked into from.

A route costs key presses, the steps the mod says. `Routes::CostModel` packs presses and turns into one Integer by the
route style (`route_style`):

- `:shortest`: the fewest presses, then the fewest turns.
- `:balanced`: a turn costs a press, then the fewest turns.
- `:straightest`: the fewest turns, then the fewest presses. `Search.route` keeps it within five quarters of the
  shortest route plus four presses, and takes the balanced route past that.

A ledge hop is one press over two tiles and a slide one press over many. An assisted step costs
`Pathfinder::GATE_COST` presses more than its own, so a detour of up to that many presses is taken before stopping to
clear something, and one obstacle before two.

A search state is a tile, a bridge bit and the direction it was entered from. A state that costs a turn or more above
the best one closed on its tile cannot do better and is pruned. A later state on a settled tile expands only straight
on, the one move where its direction can save a turn, which keeps the fewest turns exact.

The estimate never overstates, so A* stays exact. It is the presses the Manhattan distance needs at the most tiles one
press covers (`Moves.strides`), or a `Routes::Bound` that also follows the shortcuts of touch events that carry, warp
or run the player. Where no bound can be told, such as with ice, a rule that may move the player, or shortcuts on a
bridge map or past `Bound::WORK`, the estimate is zero.

`Routes::SearchResult` reports `:found` with the route, `:exhausted` when no route exists within the moves, or `:cut`
when the budget ran out first. It also carries the tiles examined and the algorithm that answered.

### One engine for every algorithm

`Search.run` is the one best-first search from the player's state to a goal. `path_algorithm` chooses its frontier
from `Pathfinder::ALGORITHMS`:

- `:astar`, `:weighted` (the estimate times `astar_weight`), `:greedy` and `:dijkstra` order a binary heap by
  `Pathfinder.algo_weights`.
- `:bfs` takes a queue and `:dfs` a stack.
- `:jps` is jump point search (`Routes::Jumps`): scans run straight along plain steps, horizontal first, up to jump
  points, such as the goal, a special move or a forced turn. The scans of one search take at most `Jumps::SCANS`
  times `astar_max` steps (at least `Jumps::SCANS_MIN`). JPS gives the fewest presses but not always the fewest turns,
  and it runs only toward a goal, in the shortest style, without assisted steps or a planned surf; anywhere else the
  search runs as A*.
- `:regions` (the default) and `:hpa` answer first when they can, as described below, and the search runs as A*
  otherwise.

`Search.best` tries the cheaper answers first:

1. With `:regions`, the regions router.
2. A kept flood that already reached the goal.
3. Under a time limit, in place of the next two steps: a quick search steered by the distance to the target tile,
   which may overstate, then, when it found a route, an exact one capped at that route's cost, in the time left.
4. The search itself.
5. When the budget cut it: the regions walked on (with `:regions`, on foot), a flood advanced by one more budget, or
   the search again steered by the distance to the target tile.

### Budget and reach

`Routes::Limits` is one route operation's budget, from `route_limit`:

- `:effort`: at most `astar_max` tiles examined per search.
- `:time`: one deadline of `route_budget_ms` for the whole operation, checked every `Limits::CHECK` tiles.
- `:none`: no limit.

`Pathfinder.searching` opens one budget for the outermost call, and every nested search shares it. Each stop is
counted (`Limits#cuts`), and the planner tells a cut from no route by those counts. A target farther than `route_reach`
tiles (Manhattan) is never searched.

### The flood

`Routes::Flood` is a Dijkstra from the player with no goal, the least cost to every state it reaches. A search cut short
asks it, and each ask floods on for one more budget (`Flood::NODES` tiles by effort). The last `Flood::SIZE` floods
are kept while the player's tile and level, the events, the pricing and the limit stand.

## Regions

`Routes::Regions` tells whether the player can get to a tile at all, without a search. It walks every state the moves
reach, breadth first. States that a plain step joins both ways are united into a region (union-find); every other move,
such as a ledge hop, a slide, a carry or a transfer, is a directed edge between regions. A region's rooms away are the
fewest transfers within the map from the player's region, found by a breadth-first search in which only a transfer
edge counts.

Each variant has its own walk, kept per map, mode of the passability probe and what the party may do on water
(`Pathfinder.vehicle_state`):

- `:foot`: walking, ledge hops included.
- `:assist`: with the assisted steps, obstacles and boulders lent through.
- `:water`: with surfing allowed.

`Regions#status` answers `:yes` with the rooms away, `:no` once the walk is whole and reached none of the tiles, or
`:unknown`. A question walks on only within its allowance. By effort that is the variant's share, then a tenth of it
each frame; under a time limit, until the frame's deadline; with no limit, all of it. With `regions_background` on,
each map frame also walks the first variant with states left for `Regions::SLICE_MS`.

The regions lend walkers through, so a walking character is no wall to them, unless its touch does something or it
stands where it would stop a slide. A walker that comes, goes or steps keeps the walk; any other change of the events
drops it.

The regions give three answers the rest of the mod relies on:

- `Planner.reach` is the answer by which the target list hides a target (`hide_unreachable`) and the planner gives up
  on one. It is never `:no` with `edge_relax` on, since the walk takes no border steps.
- `Regions#presses_to` gives the fewest presses to a tile by the walk's moves; `target_order` `:walk` orders the list
  by it.
- The rooms away feed the room note ([Transfers](#transfers)).

### The regions router

The default `path_algorithm`, `:regions`, routes over the walk itself. Once the walk on foot is whole, an A* over the
moves it kept, priced as `Search.run` prices its own, finds the route without asking the engine again. The route is
replayed with `Moves.trace` and taken only if it ends on the goal, since a walker the regions lend through may stand in
the way.

## HPA* over clusters

`:hpa` cuts the map into square clusters of `hpa_cluster` tiles (`Pathfinder::HPA_CLUSTER` unless set). A portal sits
at the middle of each opening between two clusters, and a bounded A* inside each cluster links its portals. The search
joins the player's tile and the tiles the target is acted on from to their clusters' portals, runs A* over the portals
to whichever of those tiles costs least and refines each hop with a local A* bounded to the hop's two clusters.

HPA* holds only where every move is one plain tile: its local searches take ice and ledges as walls. The planner uses
it to act on a target on a uniform map where a press covers one tile, and A* answers anywhere else. While the graph is
not whole, or when HPA* finds no route, A* answers with the budget HPA* left. While `:hpa` is chosen on such a map, the
graph is built a cluster at a time, for `Pathfinder::HPA_SLICE_MS` each map frame, and a question spends at most half
its budget on it. A change of tiles or of an event rebuilds the clusters around it.

## The planner

`Routes::Planner` holds the route policies. `Planner.plan` answers a `Routes::Plan`, whose kind is one of these:

- `:walk`: a route on foot.
- `:assisted`: a route on foot up to the first assisted step, with that step's gate.
- `:surf`: a route on foot to the shore, and the way to push off.
- `:company`: a way by water the game bars while someone walks along.
- `:none`: no way.
- `:cut`: a search stopped short before it could tell.
- `:far`: beyond `route_reach`, not searched.

A plan is made in this order:

1. On foot. The search keeps off the tiles where a step would change the map's puzzle, and crosses them only when
   their presses leave the rest of the route open. When it finds nothing while the regions say the target can be
   reached, it runs again with the walkers lent through.
2. A target beyond `route_reach` is `:far`.
3. Assisted, unless the search on foot was cut ([Assisted steps](#assisted-steps)).
4. Through a puzzle's controls, with the puzzle assist on ([Puzzles](#puzzles)).
5. By water ([Water and surfing](#water-and-surfing)).
6. Otherwise `:cut` if a search stopped short and `:none` if none did. The stops on foot do not count once the regions
   tell the target cannot be reached on foot.

`Plan#stats` records how the search went: the algorithm that answered on foot, the states, the cuts and the time.
Route text says them with `route_stats` on.

The planner keeps its last `Planner::SIZE` plans. The key (`Planner.key_for`) holds everything a plan depends on
besides the tiles: the map, the vehicle and the events, the player's tile and bridge level, the target, the route
settings, the puzzle assist, whether Strength is in use and whether the player may surf with company. A cut is not
kept when asking again would go on where the regions and the flood stopped, nor under a time limit, where the clock
decided it.

## Assisted steps

An assisted step is what the player does where walking stops. Each carries a gate, a hash that names what stands
there and how to get past:

- `:field`: an obstacle cleared with a field move or an item (a tree for Cut, a waterfall climbed with Waterfall), or
  a boulder pushed out of the way.
- `:pull`: a pushable pulled with the action button.
- `:act`: the action button pressed at an event that carries the player (a climb) or moves them within the map.
- `:dismount`: off the bike where it cannot go on, such as tall grass or ice.
- `:control`: a puzzle's control, stepped onto or pressed ([Puzzles](#puzzles)).

`Planner.assisted` first asks the `:assist` regions whether the goal can be reached at all (not with `edge_relax`
on). It then searches with
`ASSIST` and every obstacle lent through (`Pathfinder.with_gates_open`), and cuts the route at its first gate
(`Pathfinder.cut_at_gate`). When the way past that gate reaches the target with nothing more to clear, the gate also
carries the presses left after it, with their jumps and slides. When no such route exists, `Routes::Pushes` looks for
one that moves boulders. `Pathfinder.assist_possible?` skips all of it on a map with nothing that could assist.

The planner recognizes an obstacle by the name the locator gives it (`Effects::GATES`) or by the field move its script
calls (`Effects::SCRIPT_GATES`). A profile adds an obstacle its game clears with an item of its own with `field_gate`.
`FieldMoves.can?` answers whether the player can use a move now, as the game checks it: a party Pokémon that knows it,
an item that stands in (`field_move_item`, `field_move_tool`), the badge. It answers `nil` when it cannot tell, and
`nil` never counts as no. Route text names what clears the obstacle, or that it is needed; under the
[generic profile](../reference/glossary.md) it names the obstacle alone (`field_moves_unnamed`).

### Pushes and pulls

`Routes::Pushes` searches over the player's tile and where each moved boulder was left, packed into one Integer. A
boulder moves as the game moves it: one tile per push, on over ice in a game whose pushed boulders slide
(`Pushes.sliding_rocks!`, the Reborn engine), or onto the player's tile on a pull, the player stepping back. Without
the puzzle assist a route may move only the boulder that cuts the path, as often as it takes; with it, up to
`Pushes::LIMIT` boulders. The search is an A* priced in presses, each push, pull or other assisted step costing
`Pathfinder::GATE_COST` more, and it stops as a cut past `Pushes::NODES` states.

A pushable is found by the script its page runs (a profile's `push_script` first, then `Effects::PUSH_SCRIPTS`), by a
touch page that steps the event the way the player faces (Insurgence's rolling boulders), or by the locator's name
for a Strength boulder. `pull_script` marks the scripts that also let the player pull.

## Water and surfing

When the plans before it find no way, `Pathfinder.surf_plan` looks for one across water. It finds nothing while
the player already surfs, when the party surely cannot use Surf (`FieldMoves.can?(:SURF)` is `false`), on a map that
keeps the player on the bike (`MapMeta.always_bicycle?`), or when the `:water` regions tell the target cannot be
reached.

`Routes::Launch` runs one search from the player with `SURF_PLAN`, toward the target and the four tiles beside it. On
that way it takes the last tile walked before the water, with its facing, as the launch. A tile counts as walked when
the regions on foot reach it, or, while they are not whole, when it is not water. The plan is the route on foot onto
the launch tile and the way to push off from it. Launches are kept per target, player tile, events and route style
(`Pathfinder.launch_key`).

The water moves follow the engine:

- Pushing off asks whether the shore tile lets the player out that way and whether the jump lands afloat.
- Water to water is a step asked afloat, after which a current or a touch event moves the surfer as it would on
  foot. Coming ashore needs an open tile with nothing solid on it.
- A planned surf never stops on falling water (`Moves.surf_water?`). Moving down onto a waterfall's crest carries the
  surfer down the fall; where a game's falls have no crest, any of their tiles carries (`Moves.crestless_falls!`,
  Insurgence). Moving up into a fall climbs it unless the party surely cannot use Waterfall; while the player
  already surfs, that climb is an assisted step.

### Surfing with company

Many games refuse Surf while someone walks along. `Pathfinder.surf_with_company?` follows each game's own `pbSurf`, as
its profile or a plugin reader declares it with `surf_company`:

- `:anyone`: the game asks nothing of who walks along.
- `:dependents`: it refuses while any dependent event walks along, unless the block answers true.

A game whose profile declares nothing is asked through the engine's `can_ride_vehicle_with_follower?` (Essentials
v20 and later), and one without that method lets the player surf. Where the game would refuse, the plan is
`:company` and the target list says so (`loc_surf_company`). The plan's key holds the answer, so a plan made alone is
not reused with company.

```ruby
# games/armonia/follower.rb
surf_company(:dependents) { $PokemonGlobal.dependentEvents.all? { |e| e.nil? || e[8] == FOLLOW_EVENTNAME } }
```

## Transfers

A transfer is an event that moves the player elsewhere: a Transfer Player command, or a script call the locator knows
as one (a profile adds its game's own with `transfer_script`). `Routes::Effects` sorts them in two:

- A transfer to another spot of the same map is a `:warp`. Routes cross it, and it divides the map into rooms.
- A transfer off the map, or to a spot of it the page does not name, is an `:exit`. A route ends on it and never
  crosses it.

A one-sided doorway leaves the map from some sides only (`Effects.door_facings`). Its route ends on a tile from which a
step into the doorway leaves the map.

A route keeps the presses after which a transfer lands (`Pathfinder::Route#warps`) and how many it crosses
(`Route#rooms`). With the `:route_transfers` reading, the route's legs end at each transfer ("3 up, warp"). With the
`:room_note` reading ([Verbosity and readings](readers.md#verbosity-and-readings)), the target list adds how many
rooms away a target is. The note comes from the regions while the list hides unreachable targets on a map with warps
(`Locator.rooms_apart?`), and from the route about to be said otherwise. While rooms are told apart, the list puts
the player's own room first, except in the fixed order.

## Puzzles

A profile models a map's puzzle with `mechanic(kind, maps)`. The block's verbs (`World::Mechanics::Builder`) declare
the watched switches and variables, the controls, the obstacles by their graphic, the win, a hint and named points.
Three types are registered with `Mechanics.register_type`:

- `:state`: watched flags, phases each live while its test holds, an info line and a win.
- `:grid`: floor cells the game lights, a letter to form, and the cell under the player.
- `:facing`: statues the player turns, each with the facing the game checks.

```ruby
# games/pokemon_z/puzzles.rb
mechanic(:state, [143, 144, 145]) do
  watch :var => 132, :label => :ship_crank_red, :on => :ship_crank_on, :off => :ship_crank_off
  watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
  controls
  obstacle(/humo/i, :label => :ship_steam)
  obstacle(/sharpedo/i, :moving => true)
  solved(:ship_solved) { $game_switches[312] && $game_switches[313] }
  hint :ship_hint
end
```

The model says nothing. On the first look at a declaring map, `Mechanics.instance` finds the pieces: obstacles and
statues by their graphic, and controls by the pages the player fires that write a watched flag. Each map frame,
`Puzzles.tick` runs `Mechanics.update`, which compares the state with the last frame's and queues the changes, and then
says them. `Puzzles` also answers the [info key](../reference/glossary.md) and lists the locator's puzzles category.
`World::Mechanics::Links` reads the obstacles' own pages to tell what flipping a control would do to the walls.

Spoilers follow one policy, `Puzzles.assist?`, the only code that reads `puzzle_assist`. With it off, the mod
describes the room and its state; with it on, it adds the hints and plans the puzzle for the player.

### Routes through a puzzle

A route on foot keeps off the tiles where a step would change the puzzle: the plates some wall reads, and a grid's
cells while a letter is being formed (`Controls.keep_off`). It crosses a plate only when each press it makes leaves
the rest of the route clear of the walls it raises (`Controls.open_past?`).

With the puzzle assist on, two more plans exist:

- `Routes::Controls` finds the fewest control presses, up to `Controls::DEPTH`, that open the walls between the player
  and the target, read off the controls' and the walls' pages. It reads the floor with every wall set aside, up to
  `Controls::TILES` tiles, and stops as a cut once the presses tried have walked `Controls::VISITS` tiles or the
  deadline has passed. The route walks to the first control and is cut there, and its gate names every press in turn.
- `Planner.carry` plans the pushes that take a phase's tracked piece into its goal box, with the same search
  `Routes::Pushes` runs for a boulder.

## Route text

`Routes::Text` turns a plan into words, all of them from `lang/` ([Speech and languages](speech-and-languages.md)).
Its functions read the plan and the settings and speak nothing.

- `Text.listing` is the suffix the target list adds: the steps away, what stands in an assisted route's way, "by
  water", or why there is no route (`:far`, `:cut`, `:company` or none).
- `Text.line` is what the route key (`:route`, I by default) says: the legs ("3 up, 2 left"), jumps and slides as legs
  of their own, the transfers, what to do at a gate and, on a surf route, the way to push off.
- `Text.moved` and `Text.moved_path` say where a forced move left the player, for `ForcedMove` and the info key.
- `Text.stats` says how the plan's search went, with `route_stats` on.

## Memos and what drops them

| Memo | Kept under | Dropped by |
|---|---|---|
| Terrain classes (`World::Terrain`) | Kind of tile, bridge height | New tiles, a reset |
| Passability answers (`World::Probe`) | Mode, step, bridge bit | New tiles, a reset, an event's change or end |
| Event records (`World::Events`) | Event | A new map, a reset |
| Event facets | Record, the reads noted | A change of the record or of a read |
| Tile classes (`Routes::Moves`) | Tile | New tiles, a reset, any event change |
| Regions (`Routes::Regions`) | Variant, `vehicle_state` | New tiles, a reset, an event's change or end |
| Floods (`Routes::Flood`) | Events, player's tile, style, moves, limit | New tiles, a reset, an event's end |
| HPA* graph | Map, mode, cluster side | A reset, an event's end; clusters rebuilt around a change |
| Launches | `Pathfinder.launch_key` | New tiles, a reset |
| Plans (`Routes::Planner`) | `Planner.key_for` | New tiles, a reset; the oldest past `Planner::SIZE` |

With `plain_passability`, an event's end keeps the passability answers, the regions and the HPA* graph.
