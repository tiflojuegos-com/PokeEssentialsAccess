# Jump point search (Routes::Jumps, Search.run with :jps): brute force's fewest presses on random grids and on cases
# they rarely draw (a hop back, a special move out of a scan's stop), few states, its scan budget, and A* elsewhere.
class JumpsTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Pathfinder = PokeAccess::Pathfinder
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  # For each way a ledge is hopped: a corridor, the player's tile on the ledge (its step that way shut), the goal at
  # the corridor's far end, and the route there: a step back, the hop over the ledge, then on.
  HOP_BACK = {
    6 => [["########", "#.@....#", "########"], [2, 1], [6, 1], [4, 6, 6, 6, 6]],
    4 => [["########", "#....@.#", "########"], [5, 1], [1, 1], [6, 4, 4, 4, 4]],
    2 => [["###", "#.#", "#@#", "#.#", "#.#", "#.#", "###"], [1, 2], [1, 5], [8, 2, 2, 2]],
    8 => [["###", "#.#", "#.#", "#.#", "#@#", "#.#", "###"], [1, 4], [1, 1], [2, 8, 8, 8]]
  }.freeze

  test "its route to every tile brute force reaches is as short, and ends on that tile" do
    bad = []
    checked = 0
    [3, 11, 29, 47, 53, 71, 89, 97].each do |seed|
      random_route_grid(seed, 13, 10, true, 2)
      srand(seed * 7)
      8.times { $game_map.block_step(1 + rand(11), 1 + rand(8), [2, 4, 6, 8][rand(4)]) }
      Pathfinder.invalidate_cache(true)
      b, n = mismatches(seed)
      bad.concat(b)
      checked += n
    end
    assert_operator checked, :>, 400, "routes checked"
    assert_equal [], bad.first(5), "every route is JPS's own, as short as brute force's, and ends on its goal"
  end

  test "on open ground it takes far fewer states than A* for a route as short" do
    open_field
    goal = Routes::Goal.onto(40, 18)
    astar = search(goal, :astar)
    jps = search(goal, :jps)
    assert_equal [56, 56], [astar.route.length, jps.route.length], "both find the shortest route"
    assert_operator jps.expanded * 4, :<, astar.expanded, "JPS's states against A*'s"
  end

  test "steps back off a ledge it cannot leave forward and hops over it, as A* does, whichever way the ledge faces" do
    HOP_BACK.each do |hop, (rows, (x, y), goal, want)|
      $game_map.clear_ledges
      $game_map.load_grid(rows)
      $game_map.place_ledge(x, y, hop)
      $game_map.block_step(x, y, hop)
      Pathfinder.invalidate_cache(true)
      g = Routes::Goal.onto(*goal)
      assert_equal [want, want], [search(g, :astar).route, search(g, :jps).route], "a ledge hopped toward #{hop}"
    end
  end

  test "takes a special move out of a tile its scan stops at, though the way round that tile is open" do
    routes = without_terrain_rules do
      $game_map.load_grid(["#######",
                           "#....@#",
                           "#.....#",
                           "#.....#",
                           "#.....#",
                           "#######"])
      $game_map.set_terrain(5, 3, 89)
      Routes::Moves.leave_rule(:tags => [89]) { |_x, y, dir| dir[2] == 4 ? [1, y] : nil }
      Pathfinder.invalidate_cache(true)
      goal = Routes::Goal.onto(1, 4)
      [search(goal, :astar).route, search(goal, :jps).route]
    end
    assert_equal [[2, 2, 4, 2], [2, 2, 4, 2]], routes, "down onto the rail, along it in one press, then down"
  end

  test "is A* with another route style, with assisted steps or a planned surf, or with no goal" do
    open_field
    goal = Routes::Goal.onto(40, 18)
    shortest = Routes::CostModel.new(:shortest)
    {
      "the balanced style" => [goal, Routes::CostModel.new(:balanced), LEDGE],
      "the straightest style" => [goal, Routes::CostModel.new(:straightest), LEDGE],
      "assisted steps" => [goal, shortest, LEDGE | Routes::Moves::ASSIST],
      "a planned surf" => [goal, shortest, LEDGE | Routes::Moves::SURF_PLAN],
      "no goal" => [nil, shortest, LEDGE]
    }.each do |what, (g, cost, mode)|
      est = g ? Routes::Search.bound_for(g, mode) : nil
      assert_equal :astar, Pathfinder.searching { Routes::Search.run(g, cost, mode, :jps, est) }.algo, what
    end
  end

  test "its scans may take eight times the search's node budget, and never fewer than 20000, under its limits" do
    { 2500 => 20000, 1000 => 20000, 5000 => 40000 }.each do |nodes, scans|
      PokeAccess::Config.astar_max = nodes
      assert_equal [0, scans, nil], Routes::Jumps.budget, "with a node budget of #{nodes}"
    end
    limits = Object.new
    assert_same limits, Routes::Jumps.budget(limits)[2], "the limits whose deadline the scans read"
  end

  test "cuts a search whose scans pass their budget, and counts the cut" do
    $game_map.load_grid(["####",
                         "#@.#",
                         "##.#",
                         "##.#",
                         "####"])
    Pathfinder.invalidate_cache(true)
    with_scans(2) do
      assert_equal [:cut, nil, :jps, 1], jps_outcome(Routes::Goal.onto(2, 3)),
                   "cut in the scan down from the tile right of the start, not left to run dry"
    end
  end

  test "a search whose scans just fit their budget is not cut" do
    $game_map.load_grid(["######",
                         "#@...#",
                         "######"])
    Pathfinder.invalidate_cache(true)
    with_scans(3) do
      assert_equal [:found, [6, 6, 6], :jps, 0], jps_outcome(Routes::Goal.onto(4, 1)),
                   "three steps of scan, three allowed"
    end
  end

  private

  # The JPS routes to every tile brute force reaches on the map loaded that another algorithm answered, that are
  # longer than brute force's or that do not end on their tile: [mismatches, routes checked].
  def mismatches(tag)
    cost = Routes::CostModel.new(:shortest)
    bad = []
    checked = 0
    brute_best(:shortest, LEDGE).each do |(tx, ty), (presses, _turns)|
      next if tx == $game_player.x && ty == $game_player.y
      goal = Routes::Goal.onto(tx, ty)
      r = Pathfinder.searching { Routes::Search.run(goal, cost, LEDGE, :jps, Routes::Search.bound_for(goal, LEDGE)) }
      checked += 1
      last = r.route ? traced($game_player.x, $game_player.y, 0, r.route).last : nil
      ends = r.route && (r.route.empty? || (last && last.tile == [tx, ty]))
      ok = r.algo == :jps && r.route && r.route.length == presses && ends
      bad.push([tag, tx, ty, r.algo, r.route && r.route.length, presses]) unless ok
    end
    [bad, checked]
  end

  # A walled 40x18 field with the player at its top left, crossed halfway down by a wall ten tiles long.
  def open_field
    rows = ["#" * 42, "#@" + "." * 39 + "#"]
    18.times { |i| rows.push("#" + (i == 9 ? "." * 20 + "#" * 10 + "." * 10 : "." * 40) + "#") }
    rows.push("#" * 42)
    $game_map.load_grid(rows)
    Pathfinder.invalidate_cache(true)
  end

  # One search toward goal in the shortest style with ledge hops, by algo.
  def search(goal, algo)
    est = Routes::Search.bound_for(goal, LEDGE)
    Pathfinder.searching { Routes::Search.run(goal, Routes::CostModel.new(:shortest), LEDGE, algo, est) }
  end

  # A JPS search toward goal as [status, route, algorithm, the cuts its operation counted].
  def jps_outcome(goal)
    Pathfinder.searching do |lim|
      r = Routes::Search.run(goal, Routes::CostModel.new(:shortest), LEDGE, :jps, Routes::Search.bound_for(goal, LEDGE))
      [r.status, r.route, r.algo, lim.cuts]
    end
  end

  # Runs the block with the scans of one search budgeted at steps, whatever the node budget.
  def with_scans(steps)
    jumps = Routes::Jumps
    was = [jumps::SCANS, jumps::SCANS_MIN]
    [:SCANS, :SCANS_MIN].each { |c| jumps.send(:remove_const, c) }
    jumps.const_set(:SCANS, 0)
    jumps.const_set(:SCANS_MIN, steps)
    yield
  ensure
    [:SCANS, :SCANS_MIN].each { |c| jumps.send(:remove_const, c) if jumps.const_defined?(c, false) }
    jumps.const_set(:SCANS, was[0])
    jumps.const_set(:SCANS_MIN, was[1])
  end
end
