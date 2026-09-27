# How exits and shop attendants are named: entrances, empty "Exit" placeholders, unnamed shopkeepers, and map-edge
# exits aimed at a stretch of the edge the player can reach.
def exit_naming_door(id, dest)
  World.touch(:id => id, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, dest, 1, 1])])
end

Suite.define("exit naming: a door from outdoors into a named interior is an entrance") do
  loc = PokeAccess::Locator
  class Object
    private
    def pbGetMetadata(mid, idx); idx == 1 && [1, 40].include?(mid) ? true : nil; end
  end
  begin
    loc.clear_verdicts
    shop = exit_naming_door(90, 35)
    eq "outdoors into an interior", loc.target_name(shop), PokeAccess::I18n.t(:loc_entrance_to, :map => "Mapa 35")
    route = exit_naming_door(91, 40)
    eq "outdoors to outdoors stays an exit", loc.target_name(route), PokeAccess::I18n.t(:loc_exit_to, :map => "Mapa 40")
  ensure
    class Object; remove_method :pbGetMetadata; end
    loc.clear_verdicts
    World.clear_events
  end
  loc.clear_verdicts
  plain = exit_naming_door(92, 35)
  eq "an engine with no map metadata keeps the plain exit", loc.target_name(plain),
     PokeAccess::I18n.t(:loc_exit_to, :map => "Mapa 35")
  World.clear_events
end

Suite.define("exit naming: an empty event named Exit is not one") do
  loc = PokeAccess::Locator
  loc.clear_verdicts
  empty = World.touch(:id => 93, :name => "Salida", :x => 2, :y => 2, :list => [])
  falsy "an empty placeholder named Salida leads nowhere", loc.transfer_event?(empty)
  busy = World.touch(:id => 94, :name => "Salida", :x => 4, :y => 2, :list => [TestCmd.new(355, ["pbCaveExit"])])
  truthy "one that does something is still an exit by its name", loc.transfer_event?(busy)
  World.clear_events
  loc.clear_verdicts
end

Suite.define("exit naming: an unnamed shop attendant is a shopkeeper") do
  loc = PokeAccess::Locator
  loc.clear_verdicts
  page = TestPage.new(:trigger => 0, :sprite => "HGSS_008", :list => [TestCmd.new(355, ["pbPokemonMart([:POTION, :REPEL])"])])
  clerk = TestGameEvent.new(:id => 95, :x => 3, :y => 3, :name => "EV095", :pages => [page])
  eq "the mart's attendant", loc.target_name(clerk), PokeAccess::I18n.t(:loc_shopkeeper)
  cup = TestPage.new(:trigger => 0, :sprite => "HGSS_008", :list => [TestCmd.new(355, ["pbStoreItem(:POTION)"])])
  other = TestGameEvent.new(:id => 96, :x => 4, :y => 3, :name => "EV096", :pages => [cup])
  falsy "an item on a counter is no shop", loc.target_name(other) == PokeAccess::I18n.t(:loc_shopkeeper)
  named = TestGameEvent.new(:id => 97, :x => 5, :y => 3, :name => "Dependienta", :pages => [page])
  eq "and a named one keeps her name", loc.target_name(named), "Dependienta"
  loc.clear_verdicts
end

Suite.define("exit naming: a map-edge exit is aimed where the edge can be reached") do
  loc = PokeAccess::Locator
  pf = PokeAccess::Pathfinder
  $game_map.load_grid(["##.###.##",
                       "#@..#...#",
                       "#...#...#",
                       "#########"])
  begin
    pf.invalidate_cache(true)
    loc.instance_variable_set(:@conn_edges, { [6, 0] => [[2, 0], [6, 0]], [2, 0] => [[2, 0], [6, 0]] })
    t = loc.aim_connection(loc::SurfaceTarget.new(6, 0, "salida a Ruta 3", nil))
    eq "the reachable stretch of the edge", [t.x, t.y], [2, 0]
    eq "under the same name", t.name, "salida a Ruta 3"
    kept = loc.aim_connection(loc::SurfaceTarget.new(2, 0, "salida a Ruta 3", nil))
    eq "a reachable representative is left as it is", [kept.x, kept.y], [2, 0]
  ensure
    loc.instance_variable_set(:@conn_edges, nil)
    $game_map.clear_grid
  end
end

Suite.define("exit naming: a door to a place named like this one says what it leads to") do
  loc = PokeAccess::Locator
  class Object
    private
    def pbGetMetadata(mid, idx)
      return [1, 5, 5] if idx == 5 && mid == 36
      idx == 1 && [1, 40].include?(mid) ? true : nil
    end
  end
  [35, 36, 40].each { |m| PokeAccess::MapNames.set(m, "Mapa 1") }
  begin
    loc.clear_verdicts
    eq "indoors, from the town, it is a building", loc.target_name(exit_naming_door(93, 35)), PokeAccess::I18n.t(:loc_building)
    eq "a Pokemon Centre when the map says where Teleport lands", loc.target_name(exit_naming_door(94, 36)),
       PokeAccess::I18n.t(:loc_pokecenter)
    eq "out to more of the same place, another part of it", loc.target_name(exit_naming_door(95, 40)),
       PokeAccess::I18n.t(:loc_area_other, :map => "Mapa 1")
  ensure
    [35, 36, 40].each { |m| PokeAccess::MapNames.delete(m) }
    class Object; remove_method :pbGetMetadata; end
    loc.clear_verdicts
    World.clear_events
  end
end
