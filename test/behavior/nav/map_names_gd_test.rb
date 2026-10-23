# A map is named as the game itself names it from v19 (pbGetMapNameFromId: the metadata's name, the translation in
# the language chosen), the player's own name for it first and the MapInfos one where the game gives none.
class MapNamesGdTest < PokeAccessTest
  Loc = PokeAccess::Locator

  test "names a map as the game paints it, the player's own name for it still first" do
    GameFunctions.with(:pbGetMapNameFromId => lambda { |id| id == 35 ? "Ruta 1" : "" }) do
      assert_equal ["Ruta 1", "Mapa 40"], [Loc.map_name(35), Loc.map_name(40)]
      with_map_names(35 => "Mi ruta") { assert_equal "Mi ruta", Loc.map_name(35) }
    end
  end

  test "names a door by the name the game gives the map it leads to" do
    GameFunctions.with(:pbGetMapNameFromId => lambda { |id| id == 35 ? "Centro Pokémon de Ciudad Cedolan" : "" }) do
      door = World.touch(:id => 48, :x => 3, :y => 3, :list => [TestCmd.new(201, [0, 35, 1, 1])])
      assert_equal PokeAccess::I18n.t(:loc_exit_to, :map => "Centro Pokémon de Ciudad Cedolan"), Loc.target_name(door)
    end
  end

  private

  # Runs the block with the player's names for maps given (map id => name), their own put back after and the names
  # of maps that had none deleted.
  def with_map_names(names)
    was = names.keys.map { |m| [m, PokeAccess::MapNames.get(m)] }
    names.each { |m, n| PokeAccess::MapNames.set(m, n) }
    yield
  ensure
    was.each { |m, n| n ? PokeAccess::MapNames.set(m, n) : PokeAccess::MapNames.delete(m) }
  end
end
