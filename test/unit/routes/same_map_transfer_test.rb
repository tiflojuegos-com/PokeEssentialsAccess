# A touch event that sends the player to a spot of this map it does not name (a script transfer whose coordinates
# come from variables) is a destination like a doorway, never a tile a route crosses: the game would take the player
# elsewhere. One that names its spot stays a warp to it.

class SameMapTransferTest < PokeAccessTest
  test "takes a transfer by variables to this map for a destination, never a step" do
    with_transfer_script(["$game_temp.player_transferring = true", "$game_temp.player_new_map_id = #{$game_map.map_id}",
                          "$game_temp.player_new_x = $game_variables[10]",
                          "$game_temp.player_new_y = $game_variables[11]"]) do
      assert_equal [:exit], PokeAccess::Routes::Effects.touch_at(3, 1, 6, true)
      assert_equal [], spots(traced(2, 1, 0, [6]))
      refute_equal :found, PokeAccess::Routes::Planner.walk(7, 1).status
    end
  end

  test "takes a pbTransfer to this map with computed coordinates for a destination" do
    with_transfer_script(["pbTransferWithTransition(#{$game_map.map_id}, $game_variables[10], $game_variables[11])"]) do
      assert_equal [], spots(traced(2, 1, 0, [6]))
    end
  end

  test "keeps a transfer to a spot of this map it names a warp to it" do
    with_transfer_script(["pbTransferWithTransition(#{$game_map.map_id}, 8, 1)"]) do
      assert_equal [:warp, 8, 1], PokeAccess::Routes::Effects.touch_at(3, 1, 6, true)
    end
  end

  private

  def with_transfer_script(lines)
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    list = [TestCmd.new(355, [lines[0]])] + lines[1..-1].map { |l| TestCmd.new(655, [l]) }
    World.touch(:id => 66, :x => 3, :y => 1, :list => list)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
