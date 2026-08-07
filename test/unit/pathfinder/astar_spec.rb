# A* over REAL walls via the grid harness: load_grid makes passable?/counter?/events mirror an ASCII map,
# so these exercise the actual flood, reachable? and A* against geometry rather than only in-game.
# '#' wall, '.' floor, 'C' counter, '@' player, a letter = an npc event.
Suite.define("pathfinder: A* and reachability over real walls") do
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000

  use_grid = lambda do |rows|
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.instance_variable_set(:@rs_key, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@pcache_state, nil)
    PokeAccess::Pathfinder.instance_variable_set(:@hpa_sig, nil)
  end

  use_grid.call(["#######", "#..@..#", "#..C..#", "#.#N#.#", "#######"])
  nurse = $game_map.events.values.find { |e| e.x == 3 && e.y == 3 }
  eq "counter NPC is reachable across the counter",
     PokeAccess::Locator.reachable?(nurse), true

  use_grid.call(["#####", "#@###", "#.#X#", "#####"])
  sealed = $game_map.events.values.find { |e| e.x == 3 && e.y == 2 }
  eq "an NPC sealed by walls is not reachable",
     PokeAccess::Locator.reachable?(sealed), false

  use_grid.call(["#####", "#@..#", "##.##", "#...#", "#####"])
  route = PokeAccess::Pathfinder.find_path(1, 3)
  truthy "A* routes around the wall (detours, length >= 3)", route && route.length >= 3

  PokeAccess::Config.route_cache = true
end
