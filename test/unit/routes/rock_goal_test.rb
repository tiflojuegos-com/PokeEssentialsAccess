# A boulder's goal (Routes::Pushes::RockGoal) estimates the pushes the game would make to take it into the box, read
# off a field walked back from the box, not its straight distance; a boulder the game cannot push there gets no
# estimate a search would follow.

class RockGoalTest < PokeAccessTest
  ROOM = ["#########",
          "#.......#",
          "#.......#",
          "#..###..#",
          "#.......#",
          "#.......#",
          "#########"]

  test "estimates the pushes around a wall, not the straight distance" do
    with_boulder(4, 2) do |goal|
      price = 1 + PokeAccess::Pathfinder::GATE_COST
      assert_equal 6 * price, goal.bound(0, 0, [])
    end
  end

  test "gives no estimate to follow for a boulder stuck in a corner" do
    with_boulder(1, 1) do |goal|
      assert_equal PokeAccess::Routes::Pushes::RockGoal::FAR, goal.bound(0, 0, [])
    end
  end

  private

  def with_boulder(x, y)
    $game_map.load_grid(ROOM)
    ev = World.touch(:id => 61, :name => "Boulder", :x => x, :y => y, :trigger => 0, :sprite => "boulder",
                     :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      !$game_map.blocked?(nx, ny)
    end
    PokeAccess::Pathfinder.invalidate_cache(true)
    fx = PokeAccess::Routes::Effects
    key = PokeAccess::Routes.pkey(x, y)
    goal = PokeAccess::Routes::Pushes::RockGoal.new(key, x, y, [4, 4, 4, 4], fx.boulder_index[key])
    PokeAccess::Pathfinder.searching { yield goal }
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
