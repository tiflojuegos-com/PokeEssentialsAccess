# The pathfinder must CROSS ledges, which the ledge_stub_spec deliberately does not assert (it only proves
# the stub's engine surface). The real engines (v21/v22 and the gen-6 games: verified in Pokemon Z's
# Game_Player and Relict/Reminiscencia) make a ledge PASSABLE from the high side and decide the hop inside
# the "can move" branch, so a plain passability check walks into the ledge tile as a dead-end step and never
# reaches the jump branch. These specs pin the crossing, its one-way direction, the reachability flood, the
# hide-unreachable filter, the ledge_directions=off behaviour, and the guide's jump cue -- and the walk-only
# first pass, which is the sharpest case of the lot (it MUST refuse the ledge).

# Resets the pathfinder's per-map caches so a fresh grid/ledge layout is searched from scratch within a suite.
def ledge_fresh
  [:@rs_key, :@pcache_state, :@hpa_sig, :@slide_key, :@rs, :@rs_full].each do |s|
    PokeAccess::Pathfinder.instance_variable_set(s, nil)
  end
end

# Loads an ASCII grid and places ledges [[x,y,dir], ...] on top of it, then clears the caches.
def ledge_grid(rows, ledges)
  $game_map.clear_ledges
  $game_map.load_grid(rows)
  ledges.each { |x, y, d| $game_map.place_ledge(x, y, d) }
  ledge_fresh
end

# A downward ledge at (3,2) whose whole row is walled otherwise, so the only way from the top area (player at
# (3,1)) to the bottom area is the two-tile hop -- no walking route exists across it.
SEALED_DOWN_HIGH = ["#######", "#..@..#", "###.###", "#..T..#", "#######"]
# The same map mirrored so the player stands on the LOW side and the free area is above the ledge.
SEALED_DOWN_LOW  = ["#######", "#..T..#", "###.###", "#..@..#", "#######"]

Suite.define("pathfinder: a route crosses a ledge from the high side") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true

  ledge_grid(SEALED_DOWN_HIGH, [[3, 2, 2]])
  route = pf.find_path(3, 3)
  truthy "find_path returns a route across the sealed ledge", route && !route.empty?
  eq "the route is the single downward hop over the ledge", route, [2]

  PokeAccess::Config.route_cache = true
end

Suite.define("pathfinder: the walk-only first pass refuses the ledge, the ledge pass takes it") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true

  ledge_grid(SEALED_DOWN_HIGH, [[3, 2, 2]])
  eq "the walking-only pass (allow_ledge false) cannot cross the ledge", pf.find_path_to(3, 3, false), nil
  eq "the ledge pass (allow_ledge true) crosses with the hop", pf.find_path_to(3, 3, true), [2]

  PokeAccess::Config.route_cache = true
end

Suite.define("pathfinder: a ledge is one-way -- no route from the low side back over it") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true

  ledge_grid(SEALED_DOWN_LOW, [[3, 2, 2]])
  eq "no walking route up over the ledge", pf.find_path_to(3, 1, false), nil
  eq "no ledge route up over it either (the hop is downward only)", pf.find_path_to(3, 1, true), nil
  eq "find_path finds nothing back over the one-way ledge", pf.find_path(3, 1), nil

  PokeAccess::Config.route_cache = true
end

Suite.define("pathfinder: reachable_tiles crosses the ledge but never stands on it") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true

  ledge_grid(SEALED_DOWN_HIGH, [[3, 2, 2]])
  rs = pf.reachable_tiles
  truthy "the landing on the far side of the ledge is reachable", rs[pf.pkey(3, 3)]
  falsy "the ledge tile itself is never a reachable standable tile", rs[pf.pkey(3, 2)]

  ledge_grid(SEALED_DOWN_LOW, [[3, 2, 2]])
  low = pf.reachable_tiles
  falsy "from the low side the high side is NOT reachable through the one-way ledge", low[pf.pkey(3, 1)]

  PokeAccess::Config.route_cache = true
end

Suite.define("locator: hide_unreachable does not hide a target reachable via a ledge hop") do
  loc = PokeAccess::Locator
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true
  PokeAccess::Config.hide_unreachable = true

  # The grid auto-creates an NPC event (any letter) on its tile; N sits on the far side of the ledge.
  ledge_grid(["#######", "#..@..#", "###.###", "#..N..#", "#######"], [[3, 2, 2]])
  npc = $game_map.events.values.find { |e| e.x == 3 && e.y == 3 }
  truthy "the far-side NPC exists in the grid", !npc.nil?
  eq "an NPC across a ledge is reachable (not hidden) via the hop", loc.reachable?(npc), true

  # A genuinely sealed NPC stays unreachable, so the filter is not simply always-true.
  ledge_grid(["#####", "#@###", "#.#N#", "#####"], [])
  sealed = $game_map.events.values.find { |e| e.x == 3 && e.y == 2 }
  eq "an NPC boxed in by walls is still unreachable", loc.reachable?(sealed), false

  PokeAccess::Config.hide_unreachable = false
  PokeAccess::Config.route_cache = true
end

Suite.define("pathfinder: with ledge_directions off the hop is permissive but still a real hop") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = false

  ledge_grid(SEALED_DOWN_HIGH, [[3, 2, 2]])
  eq "high->low still crosses when directions are off", pf.find_path(3, 3), [2]

  # With the directional guard off, ledge_dir_ok? is permissive, so the otherwise one-way ledge may now be
  # hopped from the low side too -- but as a genuine two-tile hop, not a phantom walk onto the ledge tile.
  ledge_grid(SEALED_DOWN_LOW, [[3, 2, 2]])
  truthy "ledge_dir_ok? is permissive for the reverse direction when off", pf.ledge_dir_ok?(3, 2, 8)
  eq "low->high crosses as a hop only because directions are off", pf.find_path(3, 1), [8]

  PokeAccess::Config.ledge_directions = true
  PokeAccess::Config.route_cache = true
end

Suite.define("guide: a ledge-crossing route still fires the jump cue") do
  loc = PokeAccess::Locator
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.ledge_directions = true

  ledge_grid(SEALED_DOWN_HIGH, [[3, 2, 2]])
  route = pf.find_path(3, 3)
  truthy "the crossing route exists for the guide to announce", route && !route.empty?
  truthy "the guide detects the first step as a ledge hop", loc.ledge_step?(route[0])

  SpeakCapture.clear
  loc.instance_variable_set(:@jump_at, nil)
  loc.announce_jump_step(route[0])
  spoke "announce_jump_step speaks the jump cue on a ledge-crossing route", /salta/i

  # A plain (non-ledge) step must not trigger the jump cue.
  ledge_grid(["#####", "#@..#", "#####"], [])
  SpeakCapture.clear
  loc.instance_variable_set(:@jump_at, nil)
  loc.announce_jump_step(6)
  not_spoke "a normal walking step does not speak the jump cue", /salta/i

  PokeAccess::Config.route_cache = true
end
