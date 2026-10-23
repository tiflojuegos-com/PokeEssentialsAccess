# An arrow floor whose chain ends in a doorway off the map or in a story block cannot be taken: the arrows bear the
# player there, so the first one is no tile to stand on, as a slide over the same chain on ice.

class CarryChainEndTest < PokeAccessTest
  CORRIDOR = ["##########",
              "#@.......#",
              "##########"]
  BRANCH = ["##########",
            "#.@......#",
            "###.######",
            "###.######",
            "##########"]

  test "cannot take an arrow whose chain ends in a doorway off the map" do
    with_arrows_to([TestCmd.new(201, [0, $game_map.map_id + 77, 1, 1])]) do
      assert_equal [], spots(traced(2, 1, 0, [6]))
    end
  end

  test "cannot take an arrow whose chain ends in a story block" do
    with_arrows_to([TestCmd.new(101, ["..."]), World.move_player([2])]) do
      assert_equal [:barrier], PokeAccess::Routes::Effects.touch_at(5, 1, 6, true)
      assert_equal [], spots(traced(2, 1, 0, [6]))
    end
  end

  test "offers no route on foot over an arrow that bears the player out of the map" do
    with_arrows_to([TestCmd.new(201, [0, $game_map.map_id + 77, 1, 1])], BRANCH) do
      assert_nil walk_route(3, 3, true)
    end
  end

  private

  def with_arrows_to(last, rows = CORRIDOR)
    $game_map.load_grid(rows)
    World.touch(:id => 63, :x => 3, :y => 1, :list => [World.move_player([3])])
    World.touch(:id => 64, :x => 4, :y => 1, :list => [World.move_player([3])])
    World.touch(:id => 65, :x => 5, :y => 1, :list => last)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
