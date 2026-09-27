# The surfaces category is built from the pathfinder's flood: a far surface along the corridor is listed, one in a
# sealed room is not, and water beside walkable ground still is though the flood never enters it.
Suite.define("locator: surfaces are where you can walk to, not what happens to be near") do
  loc = PokeAccess::Locator
  prev = [PokeAccess::Config.route_reach, PokeAccess::Config.route_auto]
  begin
    PokeAccess::Config.route_reach = 128
    PokeAccess::Config.route_auto = false
    World.clear_events
    $game_map.load_grid(["#" * 42,
                         "#@" + ("." * 39) + "#",
                         "#" * 42,
                         "#" + ("." * 40) + "#",
                         "#" * 42])
    PokeAccess::Caches.reset_all

    $game_map.set_terrain(38, 1, 10)
    $game_map.set_terrain(5, 2, 7)
    $game_map.set_terrain(2, 3, 12)

    by_key = {}
    loc.surface_targets.each { |t| by_key[t.key] = [t.x, t.y] }

    eq "grass thirty-seven tiles away is a target, which the old thirty-tile box could not reach",
       by_key[:surf_tallgrass], [38, 1]
    eq "water beside the corridor is still offered, though the flood cannot enter it",
       by_key[:surf_water], [5, 2]
    eq "and the ice in the sealed room is not offered at all", by_key[:surf_ice], nil

    $game_map.clear_grid
    $game_map.load_grid(["#####", "#@..#", "#####"])
    PokeAccess::Caches.reset_all
    eq "a map with no interesting surface yields no targets", loc.surface_targets, []
  ensure
    PokeAccess::Config.route_reach = prev[0]
    PokeAccess::Config.route_auto = prev[1]
    $game_map.clear_grid
    World.clear_events
    PokeAccess::Caches.reset_all
  end
end
