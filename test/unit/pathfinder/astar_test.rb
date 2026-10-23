# The route on foot to act on a target (Routes::Planner.walk) and whether it can be got to (Locator.reachable?):
# it ends beside the target, across a counter from it, or beside any tile of an event wider than one.
class AstarTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Routes = PokeAccess::Routes
  NURSE_ROOM = ["#######", "#..@..#", "#..C..#", "#.#N#.#", "#######"]
  # A target two tiles past the last floor the player reaches, walled in on every side.
  WALLED_OFF = ["######", "#@.#X#", "######"]

  test "a target across a counter can be got to" do
    hpa_fresh_grid(NURSE_ROOM)
    assert_equal true, Loc.reachable?(event_at(3, 3))
  end

  test "a target walled in on every side cannot be got to" do
    hpa_fresh_grid(["#####", "#@###", "#.#X#", "#####"])
    assert_equal false, Loc.reachable?(event_at(3, 2))
  end

  test "a sprite-less action-button event on open ground, which the engine starts only from its tile, is walked onto" do
    hpa_fresh_grid(["########", "#@.....#", "########"])
    World.event(:id => 70, :kind => :sign, :x => 6, :y => 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [6, 6, 6, 6, 6], walk_route(6, 1)
  end

  test "a sprite-less action-button event on a tile no one stands on is acted on from beside it" do
    hpa_fresh_grid(["########", "#@....##", "########"])
    World.event(:id => 70, :kind => :sign, :x => 6, :y => 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [6, 6, 6, 6], walk_route(6, 1)
  end

  test "the route goes round a wall the shortest way" do
    hpa_fresh_grid(["#####", "#@..#", "##.##", "#...#", "#####"])
    assert_equal [6, 2, 2], walk_route(1, 3)
  end

  test "standing across the counter from the target there is nothing to walk, and no route note" do
    hpa_fresh_grid(NURSE_ROOM)
    assert_equal [], walk_route(3, 3)
    assert_equal [[], ""], Loc.route_phrase(event_at(3, 3))
  end

  test "from further off, the route ends across the counter and is said in steps" do
    hpa_fresh_grid(NURSE_ROOM)
    $game_player.x = 1
    $game_player.y = 1
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal [[6, 6], ", " + PokeAccess::I18n.t(:loc_steps, :n => 2)], Loc.route_phrase(event_at(3, 3))
  end

  test "a target behind a counter on any side is acted on from across it" do
    {
      ["######", "#@.CN#", "######"] => [6],
      ["######", "#NC.@#", "######"] => [4],
      ["###", "#@#", "#.#", "#C#", "#N#", "###"] => [2],
      ["###", "#N#", "#C#", "#.#", "#@#", "###"] => [8]
    }.each do |rows, route|
      hpa_fresh_grid(rows)
      nurse = $game_map.events.values.first
      assert_equal route, walk_route(nurse.x, nurse.y), "for #{rows.inspect}"
    end
  end

  test "an event wider than one tile is acted on from beside any of its tiles" do
    hpa_fresh_grid(["########", "#.....@#", "########"])
    statue = World.event(:id => 7, :x => 2, :y => 1, :name => "Estatua size(2,1)")
    assert_equal [4, 4], walk_route(statue.x, statue.y)
  end

  test "a target no tile in reach of has no route however near" do
    hpa_fresh_grid(WALLED_OFF)
    assert_nil walk_route(4, 1)
  end

  test "an A* search that runs to the end leaves no flood behind" do
    PokeAccess::Config.path_algorithm = :astar
    hpa_fresh_grid(WALLED_OFF)
    r = Routes::Planner.walk(4, 1)
    assert_equal [:exhausted, nil, :astar], [r.status, r.route, r.algo], "A* searched every way there is"
    cost = Routes::CostModel.new(:shortest)
    assert_nil PokeAccess::Pathfinder.searching { Routes::Flood.kept(cost, Routes::Moves::LEDGE) }, "and ran no flood"
  end

  private

  # The event the grid placed at (x, y).
  def event_at(x, y)
    $game_map.events.values.find { |e| e.x == x && e.y == y }
  end
end
