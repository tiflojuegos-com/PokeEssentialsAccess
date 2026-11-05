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

  test "a stair's second step passes over a touch event, on an engine that takes its route's next step on arrival" do
    stair_over_its_way_back do
      assert_equal [[5, 2, 0]], spots(traced(2, 1, 0, [6]))
    end
  end

  test "a touch event on a stair's second step takes over on an engine that asks after every step" do
    with_update_command do
      stair_over_its_way_back do
        assert_equal [], spots(traced(2, 1, 0, [6])), "each bears the player back onto the other"
      end
    end
  end

  test "a route that rests on a tile fires its touch event there" do
    assert PokeAccess::EventPages.rests_after?([TestMoveCmd.new(3), TestMoveCmd.new(16), TestMoveCmd.new(3)], 0)
    assert PokeAccess::EventPages.rests_after?([TestMoveCmd.new(3), TestMoveCmd.new(15, [4]), TestMoveCmd.new(3)], 0)
    assert PokeAccess::EventPages.rests_after?([TestMoveCmd.new(3), TestMoveCmd.new(38), TestMoveCmd.new(0)], 0)
    refute PokeAccess::EventPages.rests_after?([TestMoveCmd.new(3), TestMoveCmd.new(38), TestMoveCmd.new(3)], 0)
  end

  private

  # Z's diagonal stairs: the tile at (3,1) bears the player two tiles on, over (4,2), whose event bears them back.
  def stair_over_its_way_back
    $game_map.load_grid(["##########", "#.@......#", "####.....#", "##########"])
    World.touch(:id => 63, :x => 3, :y => 1, :list => [World.move_player([37, 6, 3, 38])])
    World.touch(:id => 64, :x => 4, :y => 2, :list => [World.move_player([37, 7, 2, 38])])
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  # Runs the block as on an engine from Essentials 19 on, whose Game_Character has update_command.
  def with_update_command
    Object.const_set(:Game_Character, Class.new { define_method(:update_command) {} })
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    Object.send(:remove_const, :Game_Character)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

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
