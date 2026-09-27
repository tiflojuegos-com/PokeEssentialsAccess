# Inside a search span each tile's terrain is asked once (nested spans share the answers) and the flood is unchanged;
# with the route cache off the memo lasts one search.
Suite.define("terrain memo: a flood asks each tile's terrain once, and floods exactly as without it") do
  pf = PokeAccess::Pathfinder
  terrain = PokeAccess::Terrain
  PokeAccess::Config.route_cache = false
  $game_map.load_grid(["##########", "#@.......#", "#........#", "#........#", "##########"])
  $game_map.place_ledge(4, 2, 2)
  $game_map.set_terrain(6, 1, 12)
  $game_map.instance_variable_set(:@tt_calls, 0)
  class << $game_map
    alias_method :memo_spec_terrain_tag, :terrain_tag
    def terrain_tag(*a); @tt_calls += 1; memo_spec_terrain_tag(*a); end
  end
  begin
    plain = pf.flood(false)[0]
    without = $game_map.instance_variable_get(:@tt_calls)
    $game_map.instance_variable_set(:@tt_calls, 0)
    memo = terrain.memoizing { pf.flood(false)[0] }
    with = $game_map.instance_variable_get(:@tt_calls)
    eq "the same tiles are reachable either way", memo.keys.sort, plain.keys.sort
    truthy "the engine is asked far less with it (#{with} calls against #{without})", with * 3 < without
    falsy "nothing is kept once the search is over", terrain.instance_variable_get(:@memo)

    $game_map.instance_variable_set(:@tt_calls, 0)
    terrain.memoizing do
      terrain.ledge_at?(4, 2)
      terrain.memoizing { terrain.ice_at?(4, 2) }
      terrain.ledge_at?(4, 2)
    end
    eq "a nested search shares the outer one's answers", $game_map.instance_variable_get(:@tt_calls), 1
    eq "and the answers are the engine's", [terrain.ledge_at?(4, 2), terrain.ice_at?(6, 1), terrain.ice_at?(5, 1)],
       [true, true, false]
  ensure
    class << $game_map
      remove_method :terrain_tag
      remove_method :memo_spec_terrain_tag
    end
    $game_map.instance_variable_set(:@terrain, {})
    $game_map.clear_ledges
    $game_map.clear_grid
  end
end

# The pathfinder's own entry points (reachable_set, find_path) search inside a span.
Suite.define("terrain memo: the pathfinder's own entry points search inside a span") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_cache = false
  $game_map.load_grid(["##########",
                       "#@.......#",
                       "#........#",
                       "#........#",
                       "##########"])
  $game_map.place_ledge(4, 2, 2)
  $game_map.instance_variable_set(:@tt_calls, 0)
  class << $game_map
    alias_method :wiring_spec_terrain_tag, :terrain_tag
    def terrain_tag(*a); @tt_calls += 1; wiring_spec_terrain_tag(*a); end
  end
  begin
    plain = pf.flood(false)[0]
    without = $game_map.instance_variable_get(:@tt_calls)
    pf.invalidate_cache(true)
    $game_map.instance_variable_set(:@tt_calls, 0)
    through_set = pf.reachable_set
    with = $game_map.instance_variable_get(:@tt_calls)
    eq "the cached flood covers the same tiles", through_set.keys.sort, plain.keys.sort
    truthy "and it asked the engine far less (#{with} against #{without})", with * 3 < without

    pf.invalidate_cache(true)
    $game_map.instance_variable_set(:@tt_calls, 0)
    pf.find_path(8, 3)
    route_calls = $game_map.instance_variable_get(:@tt_calls)
    truthy "a route search is inside a span too (#{route_calls} calls)", route_calls < without
  ensure
    class << $game_map
      remove_method :terrain_tag
      remove_method :wiring_spec_terrain_tag
    end
    pf.invalidate_cache(true)
    $game_map.clear_ledges
    $game_map.clear_grid
  end
end

# With the route cache on the terrain memo lasts the map, and is dropped when the cache is: a new map, the end of an
# event, the cache switched off.
Suite.define("terrain memo: with the route cache on it lasts the map, and goes where the cache goes") do
  terrain = PokeAccess::Terrain
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#......#",
                       "########"])
  $game_map.set_terrain(4, 2, 7)
  $game_map.instance_variable_set(:@tt_calls, 0)
  class << $game_map
    alias_method :map_memo_spec_terrain_tag, :terrain_tag
    def terrain_tag(*a); @tt_calls += 1; map_memo_spec_terrain_tag(*a); end
  end
  calls = lambda { $game_map.instance_variable_get(:@tt_calls) }
  had_id = $game_map.map_id
  begin
    PokeAccess::Config.route_cache = true
    eq "the tile reads as water", terrain.kind(4, 2), :water
    first = calls.call
    terrain.kind(4, 2)
    eq "and the second time the engine is not asked", calls.call, first

    near = PokeAccess::Audio3D.nearest_water(1, 1, 6)
    after_ring = calls.call
    eq "the sonar's water ring finds it", near, [4, 2]
    PokeAccess::Audio3D.nearest_water(1, 1, 6)
    eq "and walks the same ring again for free", calls.call, after_ring

    pf.invalidate_cache(true)
    terrain.kind(4, 2)
    eq "the end of an event drops it: the tile is asked again", calls.call, after_ring + 1

    $game_map.map_id = had_id + 1
    terrain.kind(4, 2)
    eq "so does a new map", calls.call, after_ring + 2
    $game_map.map_id = had_id

    PokeAccess::Config.route_cache = false
    before_off = calls.call
    terrain.kind(4, 2)
    terrain.kind(4, 2)
    eq "with the cache off every lookup asks the engine", calls.call, before_off + 2
    falsy "and nothing is kept for when it comes back on", terrain.instance_variable_get(:@map_memo)
  ensure
    class << $game_map
      remove_method :terrain_tag
      remove_method :map_memo_spec_terrain_tag
    end
    $game_map.map_id = had_id
    pf.invalidate_cache(true)
    $game_map.clear_grid
  end
end

# The sonar's water ring keeps its answers for as long as the terrain memo they are read from: walking the same ring
# again asks nothing, and a fresh terrain memo (an event's end, a new map) means fresh answers.
Suite.define("terrain memo: the sonar's water answers live exactly as long as the terrain memo") do
  a3d = PokeAccess::Audio3D
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#......#",
                       "########"])
  $game_map.set_terrain(4, 2, 7)
  $game_map.instance_variable_set(:@water_asks, 0)
  class << a3d
    alias_method :water_spec_water_at?, :water_at?
    def water_at?(x, y); $game_map.instance_variable_set(:@water_asks, $game_map.instance_variable_get(:@water_asks) + 1); water_spec_water_at?(x, y); end
  end
  asks = lambda { $game_map.instance_variable_get(:@water_asks) }
  begin
    PokeAccess::Config.route_cache = true
    pf.invalidate_cache(true)
    eq "the ring finds the water", a3d.nearest_water(1, 1, 6), [4, 2]
    first = asks.call
    truthy "asking each tile on the way", first > 0
    eq "the same ring again finds the same water", a3d.nearest_water(1, 1, 6), [4, 2]
    eq "without asking any tile again", asks.call, first

    $game_map.instance_variable_get(:@terrain).delete([4, 2])
    $game_map.instance_variable_get(:@terrain)[[2, 1]] = 7
    pf.invalidate_cache(true)
    eq "once the terrain memo is dropped the ring reads the map as it is now", a3d.nearest_water(1, 1, 6), [2, 1]

    PokeAccess::Config.route_cache = false
    before = asks.call
    a3d.nearest_water(1, 1, 6)
    a3d.nearest_water(1, 1, 6)
    truthy "with the route cache off every walk asks again", asks.call - before >= 2
  ensure
    class << a3d
      remove_method :water_at?
      alias_method :water_at?, :water_spec_water_at?
      remove_method :water_spec_water_at?
    end
    PokeAccess::Config.route_cache = true
    pf.invalidate_cache(true)
    $game_map.clear_grid
  end
end
