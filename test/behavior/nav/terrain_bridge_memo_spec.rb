# A bridge tile reads as water while the player is off it and as the bridge while on it, so a memoised terrain answer
# belongs to the bridge state it was asked under.
Suite.define("terrain memo: an answer belongs to the bridge state it was asked under") do
  terrain = PokeAccess::Terrain
  had = ($PokemonGlobal.bridge rescue 0)
  $game_map.load_grid(["########",
                       "#@.....#",
                       "#......#",
                       "########"])
  $game_map.place_bridge(3, 1)
  begin
    eq "off the bridge the tile reads as the water under it", terrain.kind(3, 1), :water
    eq "asked for bridges it reads as the bridge", terrain.kind(3, 1, true), :bridge

    terrain.memoizing do
      eq "the same holds inside a span", terrain.kind(3, 1), :water
      eq "and the two questions do not share one answer", terrain.kind(3, 1, true), :bridge
      $PokemonGlobal.bridge = 2
      eq "stepping onto the bridge changes what the span answers", terrain.kind(3, 1), :bridge
      $PokemonGlobal.bridge = 0
      eq "and stepping off changes it back", terrain.kind(3, 1), :water
    end
    falsy "nothing is kept once the span is over", terrain.instance_variable_get(:@memo)
  ensure
    ($PokemonGlobal.bridge = had) rescue nil
    $game_map.clear_grid
  end
end

# The surf launch finds the same shore with the route cache's map-long terrain memo as without it.
Suite.define("surf launch: the shore is the same with the map memo as without it") do
  pf = PokeAccess::Pathfinder
  with_tile_world(["############",
                   "#@....~~#..#",
                   "#.....~~#..#",
                   "#.......#..#",
                   "#.......~~~#",
                   "#.......~~~#",
                   "############"]) do
    begin
      PokeAccess::Config.route_cache = true
      pf.invalidate_cache(true)
      memoised = pf.surf_launch(10, 1)
      PokeAccess::Config.route_cache = false
      pf.invalidate_cache(true)
      plain = pf.surf_launch(10, 1)
      eq "the memoised shore search answers what the plain one does", memoised, plain
      truthy "and there was a shore to find", !plain.nil?
    ensure
      PokeAccess::Config.route_cache = true
    end
  end
end
