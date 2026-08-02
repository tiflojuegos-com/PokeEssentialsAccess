# The guide's cached-route consumers must advance TWO tiles over a ledge hop, matching the pathfinder's
# two-tile hop model (a hop is packed as ONE direction whose landing is beyond the ledge). Before the fix
# they advanced one tile per step, so after every hop the cursor desynchronised from the player and the
# guide re-ran the full A* per hop; path_walkable? also validated the post-hop steps from the ledge tile
# instead of the landing, declaring healthy routes broken.
Suite.define("guide: cached-route consumption crosses a ledge hop as two tiles") do
  loc = PokeAccess::Locator
  PokeAccess::Config.route_cache = false
  $game_map.clear_ledges
  $game_map.load_grid(["########", "########", "########", "########", "########",
                       "#####..#", "#####.##", "#####.##", "#####..#", "########"])
  $game_map.place_ledge(5, 7, 2)
  [:@rs_key, :@pcache_state, :@hpa_sig, :@slide_key].each { |s| PokeAccess::Pathfinder.instance_variable_set(s, nil) }

  eq "step_span walks one tile on plain ground", loc.step_span(5, 5, 2), [5, 6]
  eq "step_span lands two tiles past a ledge", loc.step_span(5, 6, 2), [5, 8]

  # A cached route from (5,5): down (plain), down (the hop), right -- as the pathfinder packs it.
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
