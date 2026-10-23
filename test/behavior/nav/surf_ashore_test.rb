# Afloat, a route that comes ashore goes on foot from there, as the game ends the surf on landing (pbEndSurf): it
# reaches the land, and never walks back onto water, which needs Surf again.

class SurfAshoreTest < PokeAccessTest
  ROW = "#.~~.~~#"

  test "reaches the land a surfer comes ashore on" do
    surfing_from(2) do
      assert_equal [6, 6], walk_route(4, 1, true)
    end
  end

  test "keeps to the water it can surf across" do
    surfing_from(5) do
      assert_equal [6], walk_route(6, 1, true)
    end
  end

  test "never walks back onto water after coming ashore" do
    surfing_from(2) do
      assert_nil walk_route(6, 1, true)
    end
  end

  private

  def surfing_from(x)
    was = $PokemonGlobal.surfing
    with_tile_world(["########", ROW.sub("#.", "#@"), "########"]) do
      $game_player.x = x
      $game_player.y = 1
      $PokemonGlobal.surfing = true
      PokeAccess::Pathfinder.invalidate_cache(true)
      yield
    end
  ensure
    $PokemonGlobal.surfing = was
  end
end
