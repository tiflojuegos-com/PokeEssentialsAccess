# The guide's cached-route consumers advance two tiles over a ledge hop, packed as one direction landing beyond the
# ledge; path_walkable? checks the steps after a hop from the landing.
Suite.define("guide: cached-route consumption crosses a ledge hop as two tiles") do
  loc = PokeAccess::Locator
  PokeAccess::Config.route_cache = false
  $game_map.clear_ledges
  $game_map.load_grid(["########", "########", "########", "########", "########",
                       "#####..#", "#####.##", "#####.##", "#####..#", "########"])
  $game_map.place_ledge(5, 7, 2)
  [:@rs_key, :@pcache_state, :@hpa_sig, :@event_indexes].each { |s| PokeAccess::Pathfinder.instance_variable_set(s, nil) }
  pf = PokeAccess::Pathfinder

  eq "a route step walks one tile on plain ground", spots(pf.trace(5, 5, 0, [2])), [[5, 6, 0]]
  eq "and lands two tiles past a ledge", spots(pf.trace(5, 6, 0, [2])), [[5, 8, 0]]

  loc.instance_variable_set(:@guide_from, [5, 5])
  loc.instance_variable_set(:@guide_path, [2, 2, 6])

  truthy "the player standing one plain step in still matches the route", loc.advance_guide_path(5, 6)
  eq "the walked step was consumed", loc.instance_variable_get(:@guide_path), [2, 6]

  truthy "after the hop the player at the LANDING still matches the route", loc.advance_guide_path(5, 8)
  eq "the hop consumed one step and left the tail", loc.instance_variable_get(:@guide_path), [6]

  falsy "a tile off the route still fails (deviation is detected)", loc.advance_guide_path(9, 9)

  loc.instance_variable_set(:@guide_from, nil)
  loc.instance_variable_set(:@guide_path, nil)

  truthy "path_walkable? validates the post-hop steps from the landing (right of the LEDGE is a wall)",
         loc.path_walkable?(5, 5, [2, 2, 6])

  $game_map.clear_ledges
  PokeAccess::Config.route_cache = true
end
