# When the regions (Routes::Regions) are kept and when they are walked again: an event's end that leaves every facet
# as it was keeps them on a plain map, and a walker they walk as a wall (its touch warps) drops them as it steps aside,
# so the way it was blocking is found.

class RegionsUpkeepTest < PokeAccessTest
  ROOM = ["############", "#@.........#", "#..........#", "#..........#", "#..........#", "#..........#",
          "#..........#", "############"].freeze

  GUARDED = ["#########",
             "#@......#",
             "#####.###",
             "#####..##",
             "#####.###",
             "#.......#",
             "#########"].freeze

  test "keeps the regions past an event's end that changes nothing, a touch door on the map" do
    hpa_fresh_grid(ROOM.dup)
    World.touch(:id => 30, :x => 10, :y => 6, :list => [TestCmd.new(201, [0, 7, 3, 3, 2, 0])])
    with_plain do
      reg = walked
      PokeAccess::Routes::Effects.touch_index
      PokeAccess::Pathfinder.invalidate_cache
      World.next_frame
      PokeAccess::World::Events.sync

      assert_same reg, PokeAccess::Routes::Regions.foot
    end
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  test "drops the regions when a walker they walk as a wall steps out of the only way" do
    hpa_fresh_grid(GUARDED.dup)
    guard = warping_guard(5, 3)
    with_plain do
      assert_equal [:no], walked.status([[1, 5]])
      guard.x = 6
      World.next_frame

      assert_equal :found, PokeAccess::Routes::Planner.walk(1, 5, true).status
    end
  ensure
    World.clear_events
    $game_map.clear_grid
  end

  private

  def walked
    reg = PokeAccess::Routes::Regions.foot
    reg.slice(100_000) until reg.done?
    reg
  end

  def warping_guard(x, y)
    page = TestPage.new(:trigger => 2, :sprite => "npc", :move_type => 1,
                        :list => [TestCmd.new(201, [0, 1, 1, 1]), TestCmd.new(0, [])])
    g = TestGameEvent.new(:id => 41, :x => x, :y => y, :pages => [page])
    g.blocking = true
    $game_map.events[41] = g
    World.next_frame
    g
  end

  def with_plain
    probe = PokeAccess::World::Probe
    was = probe.instance_variable_get(:@plain)
    probe.instance_variable_set(:@plain, true)
    yield
  ensure
    probe.instance_variable_set(:@plain, was)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end
end
