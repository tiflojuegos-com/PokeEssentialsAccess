# A game may read more than RMXP's three tile layers (Game_Map::LAYERS_COUNT, Essentials after 21.1): the terrain
# reads as many as the game does, and no more.

class TerrainLayersTest < PokeAccessTest
  test "finds a bridge on a fourth layer when the game reads four" do
    with_fourth_layer_bridge(4) do
      assert_equal true, PokeAccess::World::Terrain.bridge_at?(2, 1)
      assert_equal false, PokeAccess::World::Terrain.bridge_at?(3, 1)
    end
  end

  test "leaves a fourth layer alone when the game reads three" do
    with_fourth_layer_bridge(nil) do
      assert_equal false, PokeAccess::World::Terrain.bridge_at?(2, 1)
    end
  end

  private

  def with_fourth_layer_bridge(count)
    Game_Map.const_set(:LAYERS_COUNT, count) if count
    $game_map.load_grid(["#####",
                         "#@..#",
                         "#####"])
    data = $game_map.data
    def data.[](x, y, layer); layer == 3 && x == 2 && y == 1 ? TestMapData::BRIDGE_TILE : super; end
    $game_map.instance_variable_get(:@terrain_tags)[TestMapData::BRIDGE_TILE] = 15
    PokeAccess::World::Terrain.forget
    yield
  ensure
    Game_Map.send(:remove_const, :LAYERS_COUNT) if count
    $game_map.clear_grid
    PokeAccess::World::Terrain.forget
  end
end
