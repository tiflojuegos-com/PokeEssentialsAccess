# The surfaces category answers "where can I go", so it is built from the pathfinder's own flood rather than
# from a 61-tile box drawn around the player. A box is wrong in both directions at once, and this pins both
# corrections plus the one thing that must NOT change.
#
# Too small: grass thirty-seven tiles down a corridor did not exist, even though the guide would have
# walked there without complaint. Too big: a sealed room's floor was offered as a target and the guide
# then said there was no route, because a box knows nothing about walls. And water must survive the
# change -- you cannot stand on it, so the flood never enters it, and dropping it would take the
# most useful surface on the map off the list.
Suite.define("locator: surfaces are where you can walk to, not what happens to be near") do
  loc = PokeAccess::Locator
  prev = [PokeAccess::Config.route_reach, PokeAccess::Config.route_auto]
  begin
    PokeAccess::Config.route_reach = 128
    PokeAccess::Config.route_auto = false
    World.clear_events
    # A 39-tile corridor with the player at one end, and a second corridor below sealed off by a solid row.
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

    # The category must not simply list everything either: with the corridor's surfaces gone, so are its
    # targets. A list that survives having nothing to list was never really looking.
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
