# World and routes

This page explains how the mod models the map and how it finds, prices and describes a route to a target: the World
layer (terrain, passability, events, puzzle mechanics), moves and searches, regions, the planner with its
[assisted steps](../reference/glossary.md), surfing and transfers, route text, the routes from the free camera and the
way along its trail. Read it before changing a search or giving a [profile](../reference/glossary.md) a terrain, route
or puzzle rule.

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
`Pathfinder.hpa_tick` and `World::Neighbours.warm` (`core/input/frame.rb`).

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
`PBTerrain` name first, since games renumber the standard tags; lava, snow, mud and cliffs have no standard number and are
found by name only (`Snow`, `Mud`, `Cliff`: Infinite Fusion's tag ids, Uranium's and Xenoverse's 16). Where two names share a
number, the one of its standard kind wins, else the first that names a kind.
The layer asks the engine for the tag once per kind of tile (the tile ids on the map's layers) and shares it among
every tile of that kind. A map whose file holds more than RPG Maker XP's own fields, as the extra layers an editor keeps
there, is read tile by tile (`Terrain.extra_fields?`): its three layers may not tell what is on a tile, and only the game's
own `terrain_tag` knows how to read the rest. The same goes for its bridge tiles.

A bridge tile reads as the water below while the player is off the bridge, so it is kept per bridge height.
`World::Engine` hides where the eras differ: the Reborn engine's `terrain_tag` takes no bridge argument, and copies
older than v16, such as Insurgence, keep the bridge height on `$PokemonMap` instead of `$PokemonGlobal`
([Engine eras](engine-eras.md)).

A profile changes the terrain with two rules. `Terrain.label_rule` names a game's own surfaces, or with `false` names
none where a tag would give a look away (Opalo's trap floor, drawn as the floor round it, is no rock), and
`Terrain.surf_rule` decides where the player can surf now. `Terrain.flag?` reads the flags a plugin adds to the modern
tag object, such as a current or a slide.

`Terrain.water_on_map?` tells whether any tile of the map is water, asking about each kind of tile once. With the player up
on a bridge, which hides the water below from the engine, any bridge tile counts as water. The answer is kept until new
tiles or a reset, and `World::Visits` keeps it with the map left; a map whose tiles it cannot read counts as having water. Given a deadline, it stops between rows, answers `nil` and goes on from that row on the next
call.

### Passability probe

`World::Probe`, the [passability probe](../reference/glossary.md), is the one place that asks the engine whether the
player can take a step (`$game_player.passable?`). Its answer is `OPEN`, `CLOSED` or `ERROR`. A search asks it
thousands of times, so it keeps its answers per mode: surfing, diving, the bike, and what a profile or a plugin adds
with `Probe.mode_reader`, such as a lava surf or a mount. It keeps at most `Probe::MODES_KEPT` modes at once. The memo
key is the step's origin and direction, and whether the bridge is up when either end is a bridge tile.

It never keeps three kinds of answer: a step off the map, which it asks with the [neighbouring map](#neighbouring-maps)
lent to the factory, a step touching a tile lent through, and every step while the answers are unstable. They are
unstable partway up Marin's side stairs, whose plugin answers every question from the stair, and while a debug build walks
through walls.

The passability probe asks the way the game would:

- The player's `through` flag is lent off for the question.
- At a stair's end, a game that looks for events by the stair too (`is_event_at_target?`) sees none outside the stair's
  columns, so the question is asked with the player's stair lent off (`Probe.stair_end_now?`).
- A step into the player's own tile, which every engine refuses, is asked again with the player placed on the step's
  origin. `Probe.place_player_when` has every step asked that way while its block holds; Insurgence needs it afloat,
  as its passability answers from where the player stands.
- Afloat, a step out of a tile that is not water is asked on foot, since the engine ends the surf there
  (`Probe.ashore?`). `Probe.afloat` runs a block afloat and `Probe.on_foot` runs one off the bike.
- An engine error is `ERROR`. A route takes it as closed and the sound cues as open (`Probe.step?` and its
  `on_error`).
- While the Lens of Truth is in use, the events it marks on the step's two tiles are asked as a route meets them
  (`Lens.posed`, [The Lens of Truth](#the-lens-of-truth)), and its state is one of the probe's modes.

A search opens one `Probe.session`, which settles the world once for all its questions: the tiles compared, the events
synced, the mode taken.

The game goes over its events on every `passable?`, which on a large map with many events takes most of what a walk
costs. So `Probe.ask_near`, with `near_events` on, lends the map a `World::NearEvents` for the question
(`Events.near_step`): a copy of the map's Hash whose `values` and `each_value`, the two ways the games go over their
events, give only those within a tile of the step. The tile of margin is what a `sizeC` event needs, which blocks the
tile to the left of those its record covers. Any other read sees every event, so a game that reads them otherwise gets
the same answer without the saving. The map has its own list back whatever happens.

Every event stays on show where the step alone does not tell which events matter: a question with no direction; a step
off the map, as the records only cover this map's events; any question while the answers are unstable (both through
`Probe.all_events`); a list that is not a plain Hash or not read yet; and, until the next map, once an event stands on a
stair in a game that looks for events by the stair, or has the game's `at_coordinate?` true on a tile two away from those
its record covers (`Events.reaches_past?`), as the hitboxes of Events Utilities do. Changing `near_events` drops every answer, the regions and the maps `World::Visits` keeps, since the setting
is there to rule out how the game was asked.

`Probe.lend_through` makes events passable for the engine while a block runs, keeps their tiles out of the memo
meanwhile and puts every event back afterwards; `Probe.lend` does the same with each event's own flag. Assisted searches lend obstacles and boulders through, and the regions
lend walkers through. Nothing read meanwhile is kept, so what each step of a walk looks up is read before the outermost
lend: `Probe.before_lending` registers it, which `Routes::Effects.read_ahead` does for its indexes. `Probe.event_movable?` asks the engine's strict check, where it has one, whether a boulder can
move, or the plain check where the profile declares `loose_pushes` (the Reborn engine, Sevii, Infinite Fusion).

The answers go with new tiles, a reset and the tiles of any event that changes. At an event's end they all go, unless
the profile declares `plain_passability`.

### Neighbouring maps

A step off the map is the neighbouring map's to answer, through the engine's map factory. A neighbour in range of the
screen is loaded, and answers for itself. For one that is not, every engine builds a copy, with its file read and all
its events created: in the newer engines `isPassableFromEdge?` builds one to find the tile and `isPassable?` another to
ask it; older ones build one per neighbour and add it to the factory's maps until the next frame takes it out. The locator
asks about every border tile of every connection on each press, so this took seconds on a connected map.

`World::Neighbours` keeps the last `neighbour_cache_size` copies instead, 16 by default. `Probe.answer` lends the one a step needs to the
factory for the question (`Neighbours.lending`): the factory looks among its maps before building one, so the engine's
own code runs and finds the copy, and nothing of the game is hooked. The tile across comes from `Engine.across`, the
engine's own connection math; where it finds nothing to lend, the engine answers as ever.

A kept copy answers as a fresh one would:

- Its events stand where the map places them, as the game never updates a copy.
- Its events' pages are taken afresh once a frame, by the game's own `Game_Event#refresh`, the first time the copy is
  used in that frame. The switches, variables and scripts their conditions read are read as they stand.

Copies are built and refreshed apart from the game (`Neighbours.apart`). `$scene` is nil meanwhile, as a plugin that
draws from an event's refresh, such as Event Indicators, would otherwise put a copy's events on the screen in the place
of the map's own. The switches and variables are put back afterwards, as a map's setup may set them as if the player had
come in: Rejuvenation's sets `AtebitDesire`.

Nothing in a copy hangs on the map left, so the copies outlive a map change and a reset, and go only by age. A copy that
fails to build or refresh is dropped and the engine answers by itself. `neighbour_cache` turns the lending off. With
`neighbours_background` on, the `:neighbours` step builds this map's neighbours ahead of any question, one every
`Neighbours::WARM_GAP` map frames while the player stands still, each tried once per stay on the map.
`Neighbours.map` gives a map as the engine would read it, the one it has loaded or a copy; `MapMeta.terrain_on` reads a
surf across a seam from it.

Stock Essentials 20.1 has a bug in `calculate_bush_depth`, which looks behind every event as its map is set up: two
events on connected maps with their backs to each other rebuild each other's map until the stack runs out. The official
hotfix fixes this. No surveyed game reaches it: Keishou ships the hotfix, Emerald has the fix in its scripts, and the
engines up to v19 that make this lookup ask `$map_factory`, which they never assign. For a game that does reach it,
`Neighbours` catches `SystemStackError`, which `rescue StandardError` lets through from Ruby 1.9 on: the step answers
`Probe::CLOSED`, and the game goes on.

A game has nothing to declare for this. A copy keeps the tiles its setup left, so a game whose setup rewrites a
connected map's tiles from the game's state would call `Neighbours.forget` when that state changes.

### Events and facets

`World::Events` keeps one record per map event: its page, trigger, graphic, `through` flag, name and the tiles it
covers. The area is the size the engine keeps (v19 and later) or the `size(w,h)` or `sizeC(w,h)` in the event's name
(gen 6). Records
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

A move route on the player stops the walk at a step it cannot measure: a random one, one toward someone, or a script
that moves the character itself (`EventPages::MOVING_SCRIPT`: a move call bare, on `self` or on `$game_player`, or its
`@x` or `@y` set). A script that moves another character, such as Z's `dependentEvents.remove_sprite`, or sets the
route's speed is walked past. A Control Variables command keeps the value it sets: a constant, another variable, the map's
id, a character's place or facing where the walk knows it (`EventPages.character_value`: the player's from the tile the
page starts on, an event's where it stands unless the page moved it), worked into a known value. Anything else, a
random number among them, is kept as `EventPages::UNKNOWN`, and so is what is worked out of it. The branches and a
Transfer Player by variables after it read that value; one that rests on an unknown value stops the walk. Variables a
transfer reads and lands by are its own, so setting them is no lasting change: the 25 Quantum Leap spots of Uranium's
Foundation are warps within the map. A page that sets a variable to where the player stands is walked tile by tile.

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

A reader a plugin or profile registers (`Effects.touch_source`) answers an event's effect before the outcome is walked. It
may answer `:unseen` for one a sighted player cannot see, such as the gusts of Realidea's Temple of Mesprit, hidden by a
sandstorm: without the puzzle assist the walks step on it as plain ground and the player meets it as anyone would.

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
   carry or a warp lands the player elsewhere. The Step then keeps the tile stepped on (`Step#entry`). A route to a
   target on that very tile (`Goal#entry`) ends on that press, in every search: A*, the flood, the regions and their
   router, and the pushes.
6. A closed step bumps the event in front, which may carry or warp the player. With `ASSIST`, an assisted step may get
   past it.

A carry can land on another touch event, which takes over (arrow floors), and the steps that ask for one depend on the
engine. From Essentials 19 on, `Game_Character#update_command` takes a route's next command a frame after the player
arrives, so every step asks. Before it, the next step starts the frame they arrive, so only a step the route rests after
asks (`EventPages.every_step_fires?`, `Outcome#stops`): Z's diagonal stairs carry the player over the tile of the event
that brings them back. A page that waits for its route asks on none of them.

`Moves.trace` replays a route press by press with the same moves, and `Moves.one_way` marks the presses that cannot be
undone the same way: a jump, a slide, or a landing afloat (`:land`, a press from water onto dry ground,
`Probe.dry?`). The guide follows a route through `trace`, and route text names those presses.

`Moves.try(x, y, lvl, d, mode)` answers the `Step` one press from any tile and bridge level makes now, or nil where it
cannot be taken, in a search of its own with the engine pointed at that level. `Moves.ok?`, the free camera's moves
and the trail ([The free camera's trail](#the-free-cameras-trail)) ask it.

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
- `terrain_exit`: terrain the player leaves by a move of its own (a rail hopped off, a side stair walked a row up or
  down).
- `assisted_step`: something the player can do where walking stops, owned by the tiles in front.
- `tile_cost`: what stepping on or across a tile costs a route beyond its presses (`Moves.tile_cost_rule`).

An owner with `:assist => true` counts with the puzzle assist alone (`Moves.live?`), on its other keys' tiles or on any.
An owner with `:maps` counts on those maps alone (`Moves.on_map?`), so none of its tiles is asked on any other, and its
`:tiles` block is not called there. Both keys go unprefixed beside the tile keys (`Moves::OWNER_KEYS`). `Moves.owns?`
asks all of it, and `Moves.covers?` the map and the tiles, whatever the assist. Turning `puzzle_assist` or `avoid_grass` drops every route
memo (`Pathfinder.invalidate_cache(true)`), so no route of the other setting is kept.

```ruby
# games/infinitefusion_common/water_current.rb
PokeAccess::Game.define("infinitefusion_common") do
  terrain_rule(:flags => [:waterCurrent]) do |x, y, d|
    next nil unless ($PokemonGlobal.surfing rescue false) && PokeAccess::IFWaterCurrent.current?(x, y)
    PokeAccess::IFWaterCurrent.carry(x, y, d)
  end
end
```

`Moves.map_scan` lists, once per map, with its events synced and whatever the assist, the rules whose owner takes in
some tile of the map, a bridge's tiles at either height (`Moves.owned_across`). A rule with no owner counts on every
map, and one whose `:maps` leave this map out counts on none of its tiles. `Moves.ruled_terrain?` is true when one of
those that moves the player counts now, and `Moves.costed?` when one of the `tile_cost` rules does, or `avoid_grass` is on
and the map's own encounters put wild Pokémon on its grass (`Moves.wild_grass_map?`: `has_land_encounters?` from
Essentials 19 on, `isGrass?` before).

A map is uniform (`Moves.uniform?`) only while the player is not surfing, no touch event of the map changes a move, no
rule that moves the player counts there and no tile costs more. HPA* runs only on a uniform map.

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

On a map where tiles cost more (`Moves.costed?`), each move also pays `Moves.crossed_extra` presses: every tile it
crosses when it ends straight along its way (a step, a hop, a slide, a run), else the tile it lands on. A move that
puts the player down without a walk (`Moves.relocated?`: a carry, a transfer, the action button's climb) pays its
landing alone. `Moves.tile_extra` keeps each tile's cost with the tile classes; on a bridge tile above, the ground
below costs nothing. Costs only add, so the estimate in presses still never
overstates, and the pruning by a turn above the best state on a tile holds, since what a tile costs is the same from any
direction. `Search.run`, the regions router, the flood and the search that moves boulders pay them; JPS gives way to A*
there and HPA* is not asked, since both take every step as the same.

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

`Search.run` is the one best-first search to a goal, from the player's state or from an origin `[x, y, level]` its
caller gives; `Search.fresh` runs it as A* in the route style, past the regions router and the kept floods.
`path_algorithm` chooses its frontier from `Pathfinder::ALGORITHMS`:

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

- `:effort`: at most `astar_max` tiles examined per search, with more and a clock for the search that moves boulders
  ([Pushes and pulls](#pushes-and-pulls)).
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
`:unknown`, which is also the `:assist` walk's answer for `:no` where a boulder may stop a slide (`sure_no?`,
[Pushes and pulls](#pushes-and-pulls)). A question walks on only within its allowance. By effort that is the variant's share, then a tenth of it
each frame; under a time limit, until the frame's deadline; with no limit, all of it. With `regions_background` on,
each map frame also walks the first variant with states left: for `regions_slice_ms` once the player has stood still for
`Regions::STILL_FRAMES` map frames in a row, and no more than `Regions::SLICE_MS` till then, as the frame between two steps
has the player still too (`Regions.slice_ms`). That time goes first to telling whether the map has water
(`Terrain.water_on_map?`), and `:water` is passed over on a map with none.

The regions lend walkers through, so a walking character is no wall to them, unless its touch does something or it
stands where it would stop a slide. A walker that comes, goes or steps keeps the walk; any other change of the events
drops it.

The regions give four answers the rest of the mod relies on:

- `Planner.reach` is the answer by which the target list hides a target (`hide_unreachable`) and the planner gives up
  on one. It is never `:no` with `edge_relax` on, since the walk takes no border steps.
- `Regions#presses_to` gives the fewest presses to a tile by the walk's moves; `target_order` `:walk` orders the list
  by it.
- The rooms away feed the room note ([Transfers](#transfers)).
- `Regions#presses_back` and `Regions#past_boulders` start the search that moves boulders
  ([Pushes and pulls](#pushes-and-pulls)).

### The regions router

The default `path_algorithm`, `:regions`, routes over the walk itself. Once the walk on foot is whole, an A* over the
moves it kept, priced as `Search.run` prices its own (with what the tiles cost), finds the route without asking the
engine again. The route is
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
- `:surf`: a route to the shore, on foot or, afloat, over the water and ashore first, and the way to push off.
- `:company`: a way by water the game bars while someone walks along.
- `:none`: no way.
- `:cut`: a search stopped short before it could tell.
- `:far`: beyond `route_reach`, not searched.

A plan is made in this order:

1. On foot. The search keeps off the tiles where a step would change the map's puzzle, and crosses them only when
   their presses leave the rest of the route open. When it finds nothing while the regions say the target can be
   reached, it runs again with the walkers lent through. A way that steps where watchers see gives way to one round
   them, when there is one ([Watchers](#watchers)).
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
settings, the puzzle assist, whether Strength is in use, whether the player may surf with company and what the
watchers see (`Sight.stamp`). A cut is not kept when asking again would go on where the regions and the flood stopped,
nor under a time limit, where the clock decided it. What the clock of `Limits#wider` cut is kept: asking again from
that tile would hold the game as long for the same answer.

### Watchers

`Routes::Sight` knows what the map's watchers see. They are the events a profile declares with `watchers`, and, with
`avoid_trainers` on, the trainers still to battle. A trainer still to battle is named for its sight, is drawn, has a
page started by event touch, and is not an event the player would stand over (`over_trigger?`), as the engine starts
one. A battled trainer's page has another trigger, so it drops out. The name is read as each era reads it: before the
GameData era only a name that is `Trainer(n)` alone, from it on `trainer(n)` or `sight(n)` anywhere in the name,
whatever the case. A declared watcher counts while it is drawn, and one picked by the name alone also needs a page
started by event touch.

A watcher sees its own tiles and up to its range ahead. Each tile ahead is seen while the watcher could walk on to the
one before it, as `pbEventCanReachPlayer?` asks. That needs the map's passability both ways, through
`Game_Map#passable?` with the watcher where the engine takes it, and no other event that keeps still and blocks. A
watcher that walks through sees past everything. Walkers do not cut a sight, because their place changes, and neither
does the player, who is the one it looks for.

A watcher is read from every pose its moves take it to (`Sight.poses`):

- One that keeps still has its own pose.
- One an event command moves with a forced route (a parallel event's patrol, or a scene) follows that route, as
  below, while it walks it. The round goes as the forcing ends.
- One that moves at random or by the player sees the four ways from every tile it can stand on within
  `Sight::ROAM` steps of where it was read.
- One with a move route on its page, or forced, is followed from the command it is on, for one round and two at most, as RPG
  Maker turns it (steps, diagonals, jumps, the fixed direction). The route walks it whatever stands in the way. A
  move at random or by the player ends the round with where it may roam from there, and a turn at random or by the
  player adds the four ways.

The round is kept while the watcher stands on one of its poses with the same page and the same forced route, or none,
so a patrol walking its round, or a watcher roaming the tiles it was read with, changes nothing. `Sight.seen` is read at most once a frame. It is taken again when a watcher leaves its poses, turns
off them, comes or goes, or when an event's end, the vehicle or the tiles may have changed what stops a sight.
`Sight.stamp` counts the times the tiles seen changed: the planner keys on it, and the guide plans again when it moves.
`Sight.seen_now` holds what the watchers see from where they stand and face, for a profile's hints by the frame where a
round is crossed in time. The free camera reads it, as a sighted player sees: on a tile a watcher sees now it says *in
sight of* it, by the name the locator gives it (`Locator.target_name`, the player's tag first), and nothing on the
watcher's own tiles.

A search on foot runs first as with no watcher, with all its memos. Only when its way steps on a tile seen, other than
the goal's, does an A* that reads each step afresh look for one that keeps off what the watchers see and the plates
(`Planner.closed_search`). That A* runs under a budget of its own (`Planner.aside`): what it stops short is no cut of
the plan, and the plan's deadline moves on by the time it took (`Limits#postpone`). Its way is taken when it finds one,
and the first one otherwise. A way round found wanting is not looked for again under the same map, regions, sight
(`Sight.stamp`) and goal, wherever the player stands, since the guide asks again at each step.

A tile counts as crossed where a press ends. Before the GameData era the engine also checks trainers on each tile of an
ice slide (its scene map update runs the player's step checks while it slides), so there the tiles a slide passes count
too, and the A* keeps off slides that pass a tile seen (`Moves.with_closed` with `passing`). From the GameData era on,
the checks wait for the slide to stop. A carry runs under the interpreter, which checks no trainer. A patrol whose round
closes every way, as the termites and the Hippopotas of Pokémon Armonía, leaves the route as it was, and only the
timing is left to the player.

### Routes from another tile

The regions, the floods and HPA* are walked from the player. `Planner.plan_from(fx, fy, lvl, tx, ty, onto)` answers the
way on foot from any tile and bridge level, which the route key asks while the free camera is open:

- A goal that already holds the tile is an empty `:walk`.
- When the tile lies in the player's zone on foot and the regions tell the goal cannot be reached, the answer is
  `:none` with no search.
- Otherwise one A* runs from that tile (`Search.fresh` with the origin), and again through the walkers in the way when
  it ran out of ways while the regions tell the goal can be reached.

It answers `:walk`, `:none` or `:cut`: no assisted steps, no surf and no puzzle controls. Its plans are kept with the
others, under the tile, the level and the target.

## Assisted steps

An assisted step is what the player does where walking stops. Each carries a gate, a hash that names what stands
there and how to get past:

- `:field`: an obstacle cleared with a field move or an item (a tree for Cut, a waterfall climbed with Waterfall), or
  a boulder pushed out of the way.
- `:pull`: a pushable pulled with the action button.
- `:act`: the action button pressed at an event that carries the player (a climb) or moves them within the map.
- `:dismount`: off the bike where it cannot go on, such as tall grass or ice.
- `:control`: a puzzle's control, stepped onto or pressed ([Puzzles](#puzzles)).
- `:lens`: the Lens of Truth used where the route stands, to cross what it opens or, with `:show`, before the thing
  it shows ([The Lens of Truth](#the-lens-of-truth)).

`Planner.assisted` first asks the `:assist` regions whether the goal can be reached at all (not with `edge_relax`
on). It then searches with
`ASSIST` and every obstacle lent through (`Pathfinder.with_gates_open`), and cuts the route at its first gate
(`Pathfinder.cut_at_gate`). When the way past that gate reaches the target with nothing more to clear, the gate also
carries the presses left after it, with their jumps and slides. When no such route exists, `Routes::Pushes` looks for
one that moves boulders. `Pathfinder.assist_possible?` skips all of it on a map with nothing that could assist. A
registered assisted step counts on every map, whatever tiles it owns, unless its owner names `:maps`: then only there
(`Moves.assist_here?`), so a profile's step for a few maps does not send every unreachable target elsewhere through
the assisted search and the assisted regions.

The planner recognizes an obstacle by the name the locator gives it (`Effects::GATES`) or by the field move its script
calls (`Effects::SCRIPT_GATES`). A profile adds an obstacle its game clears with an item of its own with `field_gate`.
`FieldMoves.can?` answers whether the player can use a move now, as the game checks it: a party Pokémon that knows it,
an item that stands in (`field_move_item`, `field_move_tool`), the badge. It answers `nil` when it cannot tell, and
`nil` never counts as no. Route text names what clears the obstacle, or that it is needed; under the
[generic profile](../reference/glossary.md) it names the obstacle alone (`field_moves_unnamed`).

### The Lens of Truth

Drimer's "Eye/Lens of Truth for Essentials" turns the events it marks as the player comes within its `RANGE` with the
lens in use, and back again out of reach or with it down: a HIDE one goes through and a SHOW one stops being through. A
SHOW event drawn as a tile then lays its tile's passage over the map's (a bridge across a gap), and one with a sprite
stops the way. `World::Lens` reads each copy: Z's on a timer (`Scene_Map#eye_of_truth_time`), Edas' and Perseida's on a
flag of the scene (`eye_of_truth`), Vitro's by `LensOfTruth.active?`; "#EOT" in the name for Z's (and in a game without
the script), "EOT" for the others, then HIDE in it or a `hideEvent` comment before SHOW or a `showEvent` one, the comments
read as `pbEventCommentInput` reads them where the copy does (Vitro's, and one a profile declares, `Lens.declare`).

A route passes beside every event it crosses, so with the lens in use the routes take it as reaching them all: the
probe asks each step with the marked events on its two tiles as the lens leaves them in reach (`Lens.posed`), whatever
the game shows from where the player stands now, and `Effects.fires_on_arrival?` reads them so too (`Lens.met`). The
lens's state is a mode of the probe (`Probe.mode_reader`), so the answers, the regions and HPA* keep one set for each,
and a facet that read a marked event is taken again when the lens turns (`Flags.lens`). With the lens down nothing is
posed, the engine already answering as the game does. A walk taken with the lens in use is cut before the first press
onto what only the lens lets it take once the lens is down again, with the `:lens` gate there to use it again
(`Lens.renew_cut`): past what is left of Z's timer, at `Lens::FRAMES_PER_TILE` frames a press, or after a press onto a
touch event that runs, in a copy any running event puts down (Vitro's `AUTO_DEACTIVATE_ON_EVENTS`, or
`:ends_on_events`).

With the puzzle assist on and the lens down, an assisted search lends the events the lens opens as it in use leaves
them (`Lens.lent`, through `Pathfinder.with_gates_open`): each HIDE one through, and a SHOW one not through only where it
is a bridge, the map's own tile beneath taking no step (`Lens.bridge?`); any other SHOW one stays through, since the way up
to the lens is walked with it down. A step onto a marked event, from the player's tile or from ground the lens does not
lay, that the engine refuses with the lens down carries the `:lens` gate (`Lens.gate_at`): a row of them costs one use. A route walked
to a SHOW event with the lens down is cut before the press that would step onto it, with the same gate and `:show`
(`Lens.show_cut`, `Planner.walked`). Route text names the lens as the game does (`Lens.item_name`: the item that works
it, or the core's word), or that it is needed where the item is not in the bag. Without the assist none of this is
offered.

### Pushes and pulls

`Routes::Pushes` searches over the player's tile and where each moved boulder was left, packed into one Integer. A
boulder moves as the game moves it: one tile per push, on over ice in a game whose pushed boulders slide
(`Pushes.sliding_rocks!`, the Reborn engine), onto the player's tile on a pull, the player stepping back, or by a long
push, once, through whatever lies between, to where its route ends or nowhere once its page stops nobody. Without
the puzzle assist a route may move only the boulder that cuts the path, as often as it takes; with it, up to
`Pushes::LIMIT` boulders. The search is an A* priced in presses, each push, pull or other assisted step costing
`Pathfinder::GATE_COST` more, and it stops as a cut past `Pushes::NODES` states. By effort it gets `Pushes::WIDER` times
`astar_max` and `Pushes::SECONDS` at most (`Limits#wider`): a state is cheap on Ruby 3.1 and six to eight times dearer on 1.8.7
and on some games' 3.0 and 3.1 builds, where the same states would hold the game for seconds.

A route for the player starts from what the assisted regions walked, once they are all walked. `sure_no?` fails with boulders
about on a walk that meets a tile that moves the player: a boulder may stop a slide wherever a push leaves it, and the walk,
which lends them through, never takes those slides.

- With `sure_no?`, `Pushes.sealed?` answers with no search when no route can exist. The player goes along the walk's moves with
  the boulders as walls (`Regions#past_boulders`), and one the game can move, the others aside, stops being one; where a route
  may move only one, each of them in turn. Not getting to the goal even so is the proof. A boulder that can be pulled rules this
  out, as a pull lands the player on a tile the walk need not reach.
- The estimate is the presses left walking with the boulders lent through (`Regions#presses_back`, the walk's moves taken
  backward). It never overstates, so the plan found first is a cheapest one, and with `sure_no?` a state with no way to the goal
  is left out.
- Past `Pushes::EXACT` states a hard room stops looking for the cheapest plan and hurries: the estimate takes each boulder on the
  way at a push's price and weighs `Pushes::WEIGHT` times the presses already made (`Pushes.reweighed` orders the frontier afresh,
  nothing walked is lost). A route may then take a few more presses or pushes.

A route for a boulder (`RockGoal`) stays an A* throughout, on its own field of pushes: with a weight, the longest carry of Ashen
Frost's Well Temple stops reaching its spot within the cap. The field walks back from the box as the game moves the boulder: a
push or pull of one tile, or all a long push sends it as one push, whatever lies between and however its route turns.

A pushable is found by the script its page runs (a profile's `push_script` first, then `Effects::PUSH_SCRIPTS`), by a
touch page that steps the event the way the player faces (Insurgence's rolling boulders), by a touch page that sends it
off with Through on depending on the player's facing (`Effects.long_pushes`: the crystals of Z and Realidea, the Staryu of
Soulstones 1), or by the locator's name for a Strength boulder. `pull_script` marks the scripts that also let the player
pull. `long_pushes` walks the page as the interpreter would (`EventPages`), so a self switch that has spent the push reads
as no push, and a page the push opens that stops nobody (`Mechanics::Links.live_page`) reads as the boulder gone. A move of
the player, a battle or a condition it cannot answer on the way rules it out, and so does a page with no branch on the
facing, which is someone walking off in a scene.

A long push has to land on the map. One that sets nothing that stays leaves its page live, so a route may make it again from
where it lands. One that sets anything is the last push a route gives that boulder, whichever came before it: what the page
it opens does is read when the push has been made, by the next plan. To carry a piece through several pages this way, as the
ball of Opalo's map 67 goes, a puzzle declares one phase per page, each with its own box.

## Water and surfing

When the plans before it find no way, `Pathfinder.surf_plan` looks for one across water. It finds nothing when the
party surely cannot use Surf (`FieldMoves.can?(:SURF)` is `false`), on a map that keeps the player on the bike
(`MapMeta.always_bicycle?`; both are `Pathfinder.surf_allowed?`), on a map known to have no water
(`Terrain.water_on_map?`, which a plan reads for `Pathfinder::WATER_READ` at most and the map frames finish), or when
the `:water` regions tell the target cannot be reached.

`Routes::Launch` runs one search from the player with `SURF_PLAN`, toward the target and the four tiles beside it. That
search may come ashore and push off again as often as the way needs. On that way it takes the last tile walked before
the water, with its facing, as the launch. A tile counts as walked when the regions on foot reach it, or, while they
are not whole, when it is not water. The plan is the route onto the launch tile and the way to push off from it.
Launches are kept per target, player tile, events and route style (`Pathfinder.launch_key`).

The same holds afloat. There the regions on foot are the water the player floats on and the ground it comes ashore on,
so the launch is the first push-off after a landing. The plan is then the route over the water, ashore and on foot to
that shore. A way that alternates ground and water is thus planned one crossing at a time: on each shore the guide asks
for Surf, and once afloat it plans the next crossing. Each plan costs what one crossing does on foot, one launch search
and one route to its shore.

The water moves follow the engine:

- Pushing off asks whether the shore tile lets the player out that way and whether the jump lands afloat.
- Water to water is a step asked afloat, after which a current or a touch event moves the surfer as it would on
  foot. Coming ashore needs an open tile with nothing solid on it, and the step afloat that way open, as the engine
  checks it before it ends the surf.
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
the watched switches and variables, counts, the controls, the obstacles, names, the win, a hint and named points. A map
may take several, each a part with its own instance. Three types are registered with `Mechanics.register_type`:

- `:state`: watched flags, counts, phases each live while its test holds, an info line and a win.
- `:grid`: floor cells the game lights, a letter to form, and the cell under the player; or the map's own events laid out
  in rows and columns, each with a state of its own.
- `:facing`: statues the player turns, each with the facing the game checks.

```ruby
# games/pokemon_z/puzzles/ship.rb
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

The model says nothing. On the first look at a declaring map, `Mechanics.instances` finds the pieces: obstacles by their
graphic, tile, id or name, statues by their graphic, and controls by the pages the player fires that write a watched flag.
Each map frame,
`Puzzles.tick` runs `Mechanics.update`, which compares the state with the last frame's and queues the changes, and then
says them. `Puzzles` also answers the [info key](../reference/glossary.md) and lists the locator's puzzles category.
`World::Mechanics::Links` reads the obstacles' own pages to tell what flipping a control would do to the walls.

Spoilers follow one policy, `Puzzles.assist?`, the only code that reads `puzzle_assist`. With it off, the mod
describes the room and its state; with it on, it adds the hints and plans the puzzle for the player.

### Routes through a puzzle

A route on foot keeps off the tiles where a step would change the puzzle: the plates some wall reads, every tile of
the events a declaration asks to `avoid` (those it asks to avoid with `:assist => true` only with the assist on), and a
grid's cells while a letter is being formed (`Controls.keep_off`). It crosses a plate only when each press it makes
leaves the rest of the route clear of the walls it raises (`Controls.open_past?`).

With the puzzle assist on, three more plans exist:

- `Routes::Controls` finds the fewest control presses, up to `Controls::DEPTH`, that open the walls between the player
  and the target, read off the controls' and the walls' pages. It reads the floor with every wall set aside, up to
  `Controls::TILES` tiles, and stops as a cut once the presses tried have walked `Controls::VISITS` tiles or the
  deadline has passed. The route walks to the first control and is cut there, and its gate names every press in turn.
- `Planner.carry` plans the pushes that take a phase's tracked piece into its goal box, with the same search
  `Routes::Pushes` runs for a boulder.
- A mechanic's `way` block plans the route to a target itself, for a puzzle whose floor changes with state the
  routes do not model (`Puzzles.way_plan`, asked by `Locator.route_plan` before the planner). Xenoverse's evil mirrors
  use it: in a zone, or on a walk into one, the route takes the presses the zone's own search plays and walks on
  past it, and it stops after a send-back. The guides plan such a route again at each new tile.

### The Tile Puzzle's next move

The Tile Puzzle minigame of stock Essentials (`TilePuzzleScene`, `core/field/minigames.rb`) follows the same policy:
with the puzzle assist on, the line of the cursor's cell also says where its piece goes and the next move toward the
solution, where the cursor goes for it and with which key. Each of the seven modes (`@game`) gets it its own way:

- Modes 1 and 2 (pieces off the board) and 4 and 5 (swapping pieces) go piece by piece: the lowest piece not home is
  taken or swapped toward its square, then turned straight in the modes that turn pieces. No search.
- Modes 3 (sliding into the hole) and 6 (shifting a row or a column) run `TpSearch`, an A* over the board's states.
  Each frame gives it `TP_FRAME_BUDGET` seconds, so the minigame keeps its pace while it runs. Past `TP_NODE_CAP`
  states it starts again weighted by the next of `TP_WEIGHTS` (1, 3, 9), which finds a longer path sooner.
- Mode 7 (a press turns a square and its neighbours) runs `TpChase`: each choice of presses along the shorter side
  fixes the rest row by row, within `TP_CHASE_CAP` choices, and the one with the fewest presses is kept.

The search is kept on the scene until a piece moves or turns. In mode 6 the path found is followed to the end: once the
board takes its first move, the rest of the path is the next search's answer, with no search again. When no search
finds a way, the line says so.

## Route text

`Routes::Text` turns a plan into words, all of them from `lang/` ([Speech and languages](speech-and-languages.md)).
Its functions read the plan and the settings and speak nothing.

- `Text.listing` is the suffix the target list adds: the steps away, what stands in an assisted route's way, "by
  water", or why there is no route (`:far`, `:cut`, `:company` or none).
- `Text.line` is what the route key (`:route`, I by default) says: the legs ("3 up, 2 left"), jumps, slides and
  landings ("go ashore up") as legs of their own, the transfers, what to do at a gate and, on a surf route, the way to
  push off.
- `Text.moved` and `Text.moved_path` say where a forced move left the player, for `ForcedMove` and the info key.
- `Text.stats` says how the plan's search went, with `route_stats` on.

## The free camera's trail

The free camera ([Guide and sound](guide-and-sound.md#free-camera)) records a trail as the tiles it walks, each
`[x, y, level]`, none twice: going back over a tile cuts the trail back to it. `Routes::Trail` turns those tiles into
the player's presses. The camera moves by the same rules (`Moves.try` with `Pathfinder.replay_mode`, Surf where the
party may use it), so a trail drawn on foot is almost always one the player can take.

`Trail.convert(tiles, from)` walks the trail from the state `from` in one search operation, one budget for all of it:

- A press is taken when it lands further along the trail in a straight line: a ledge hop covers two tiles with one
  press, and an ice slide the tiles it slides over.
- On the shore of a water tile the trail goes on to, where the player may surf, the conversion stops there with the way
  to push off; with company the game's Surf refuses, it is cut as `:company`. Afloat, a trail that comes ashore stops
  so on the shore where it heads for the water again (`Pathfinder.may_surf?` of that tile), as the camera itself may
  push off only from ground it came ashore on.
- Elsewhere a press that does not land on the trail is gone round: an A* from where the player stands
  (`Search.fresh` with that origin) to the next trail tile the player can stop on, ice and ledges aside, and to the one
  after it, up to `REJOIN_TRIES` (3) tiles. A tile the regions rule out is skipped with no search, and a search that
  finds nothing ends the tries, since it went through all the player can get to. A way round is a `:detour`.
- With no way round, the trail is cut there, as `:blocked` (a wall, an event, a ledge against it, water with no Surf),
  `:exit` (an exit or a barrier), `:warp` (a teleport off the trail), `:carried` (a move that lands off the trail, such
  as a slide past the tile where it turns) or `:cut` (the search ran out of budget).

The result is a `Trail::Conversion`: the route, its `Trail::Break` entries, the trail index reached and the state it
ends in.

`Trail.plan(tiles, progress, id)` gives the guides the way along a fixed trail. The camera keeps the progress, the
farthest trail tile the player has stood on, on every map frame where the player's state changed (`Camera.track`); it
is nil until the player stands on the trail's first tile:

- Before that, the way is the planner's route to the first tile, where the trail begins, then the trail from there.
- With the player on the trail, the way is the trail converted from their tile.
- Off it, the way is the planner's route to the trail tile, from the progress on, the fewest presses from the player
  on foot (`Trail.nearest_ahead`, by `Regions#presses_to`), then the trail from there: a tile across a wall is as far
  as the walk round it. While the regions reach none of them, it is the progress's own tile. A way to that tile that is no plain walk (assisted, by water, none) is that plan as it is.

A trail plan is a `:walk`, or a `:surf` that stops on the shore to push off. Its stats tell the trail index reached,
why it is cut and how many stretches are gone round; the camera says them when the trail is fixed and when the player
arrives. Plans are kept with the planner's (`Planner.kept`), under the trail and the player's place on it or the tile
it joins, so a trail is converted again only when the player, the world or the settings change.

## Memos and what drops them

| Memo | Kept under | Dropped by |
|---|---|---|
| Terrain classes (`World::Terrain`) | Kind of tile, bridge height | New tiles, a reset |
| Water on the map (`World::Terrain`) | Map | New tiles, a reset |
| Passability answers (`World::Probe`) | Mode, step, bridge bit | New tiles, a reset, an event's change or end |
| Neighbouring maps (`World::Neighbours`) | Map id | The oldest past `neighbour_cache_size`; pages taken afresh once a frame |
| Event records (`World::Events`) | Event | A new map, a reset |
| Event facets | Record, the reads noted | A change of the record or of a read |
| Tile classes (`Routes::Moves`) | Tile | New tiles, a reset, any event change |
| Regions (`Routes::Regions`) | Variant, `vehicle_state` | New tiles, a reset, an event's change or end |
| Floods (`Routes::Flood`) | Events, player's tile, style, moves, limit | New tiles, a reset, an event's end |
| HPA* graph | Map, mode, cluster side | A reset, an event's end; clusters rebuilt around a change |
| Launches | `Pathfinder.launch_key` | New tiles, a reset |
| Plans (`Routes::Planner`) | `Planner.key_for` | New tiles, a reset; the oldest past `Planner::SIZE` |
| Watchers' sight (`Routes::Sight`) | Frame; each watcher's round, the event epoch | New tiles, a reset |

With `plain_passability`, an event's end keeps the passability answers, the regions and the HPA* graph.

## Puzzles with no declaration

`Puzzles::Auto` serves the maps no mechanic is declared on, reading the events alone:

- The player's use of an event reaches it through `Interpreter#setup`, on the map's interpreter and for a page fired by the
  action button or a touch. It then watches what `World::Events` reports. Once the interpreter has stood idle for a few
  frames it says what opened or closed, by groups of touching tiles, at the `:map_changes` reading's level: nothing at
  brief, what happened at medium, and where the nearest one is in full. What only flickers, the event's own change and
  what walks about do not count. A person's talk or a scene of several messages starts no watch. A silent control worked
  by the action button that changed no wall says that it worked.
- A silent control is an event whose page says nothing and writes a flag another event of the map reads, in a page
  condition or a branch, worked by the action button, or stepped on when drawn and no person. These go to the locator's
  puzzles category, by the name the lists give them, or as a mechanism. One with no graphic on a tile the player can walk
  on is hidden to anyone looking at the screen too, so it is listed with the puzzle assist alone. A declaration can say an
  event is none (`not_control`).

`Puzzles::Answers`, on every map, says with the assist the answer a number or text entry asks for, when the commands after
the one that opens it, up to the next entry, compare the variable it keeps what was entered in with a single fixed value. A
menu says its right option by the rule a declaration gives (`right_choice`). The game takes a menu or a number
entry right after a Show Text into the same message, in `command_101`, so what they ask goes after that text. A menu held in
a message's own words (`\ch[...]`) is read from those words, and its branches are the comparisons of its variable that meet
its answer: those after it at its level or nested in another comparison's else, before another menu or command writes that
variable again (`asked_by`), as the seal of Uranium's Route 15 starts its second sequence in the first comparison's else;
a place compared more than once is one option, doing what all its comparisons hold. A branch is judged by what it runs:
the menus nested in it and, for each jump to a label in it, what the game runs from that label up to the next menu, a
jump or an exit of the event that nothing before skips (`reached`), as the koan of Uranium's Lost Seas wins after a label.
From a label inside a branch the game goes on out of its block at the branch's end, past the other options or the else
(`block_end`), as the stock scripts that put a failure's label in one option jump there from the others.

`Puzzles::Reach` says what a declaration has for a point inside a page (`on_reach`), from `command_402` for a menu's branch and
`command_101` for a message. `sent_back` is answered by `Locator`: within the map through `teleport_cause`, and through
`move_cause` for a transfer from another map and, from `ForcedMove`, for the end of a move route.

The routes read two more things from any game's events. An action page whose commands all hang from branches on the
player's facing is only reached from those sides (`Effects.act_sides`), and one whose single branch on a facing only ends
the event, with an else that acts, from the other three (Desolation's Keneph lever). And what steps away from the player when walked into
or used, a page's route on its own event as it would run now, is pushed like a boulder (`Effects.self_push_dirs`).
