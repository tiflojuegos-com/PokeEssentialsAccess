# The walkable part of an assisted route, cut at its first assisted step, is still a route that answers the transfers
# along it: a slice of an Array subclass is a plain Array from Ruby 3 on, and the step guide reads them every frame.

class RouteCutTest < PokeAccessTest
  test "keeps the presses before an assisted step as a route with its transfers" do
    with_climb_one_step_away do
      cut = PokeAccess::Routes::Planner.assisted(3, 1)
      assert_equal [[6], [], 0], [cut[0].to_a, cut[0].warps, cut[0].rooms]
    end
  end

  test "keeps only the transfers before the cut" do
    route = PokeAccess::Pathfinder::Route.new.concat([2, 2, 6, 6, 8])
    route.warps = [1, 3]
    route.rooms = 2
    head = PokeAccess::Pathfinder.head_of(route, 3)
    assert_equal [PokeAccess::Pathfinder::Route, [2, 2, 6], [1], 1], [head.class, head.to_a, head.warps, head.rooms]
  end

  private

  def with_climb_one_step_away
    $game_map.load_grid(["#####",
                         "#...#",
                         "#####",
                         "#####",
                         "#@..#",
                         "#####"])
    World.touch(:id => 90, :x => 2, :y => 3, :trigger => 0,
                :list => [TestCmd.new(101, ["¿Quieres usar el Equipo de Escalada?"]),
                          TestCmd.new(102, [["Sí", "No"], 2]), TestCmd.new(402, [0, "Sí"]),
                          World.move_player([37, 4, 4, 4, 38], 1), TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])])
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_grid
  end
end
