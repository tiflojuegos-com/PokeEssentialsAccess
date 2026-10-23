# The search engine (Routes::Search) against brute force from wherever the player stands: its estimates, goals, costs,
# statuses and frontiers, its answers to a search its budget or deadline cut, and the map's speed (Moves.speed).
class SearchTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Moves = PokeAccess::Routes::Moves
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  K = PokeAccess::Routes::CostModel::K
  STYLES = [:shortest, :balanced, :straightest]

  test "finds in each style a route as short and as straight as brute force's, wherever the player stands" do
    bad = []
    checked = 0
    [3, 11, 29, 47, 53, 71].each do |seed|
      random_route_grid(seed, 12, 9)
      ([[1, 1]] + far_starts(seed)).each do |x, y|
        stand_at(x, y) do
          b, n = mismatches(LEDGE, [seed, x, y])
          bad.concat(b)
          checked += n
        end
      end
    end
    assert_operator checked, :>, 1500, "routes checked"
    assert_equal [], bad.first(5), "every route is as short and as straight as brute force's"
  end

  test "finds them as brute force does through the shortcuts of warp pads, without ice" do
    bad = []
    checked = 0
    bounded = 0
    [5, 17, 23, 41, 59, 83, 97, 101].each do |seed|
      random_route_grid(seed, 14, 10, false, 3)
      bounded += 1 if estimate(Routes::Goal.onto(1, 1)).is_a?(Routes::Bound)
      b, n = mismatches(LEDGE, seed)
      bad.concat(b)
      checked += n
    end
    assert_operator bounded, :>=, 6, "most grids search through shortcuts"
    assert_operator checked, :>, 600, "routes checked"
    assert_equal [], bad.first(5), "every route is as short and as straight as brute force's"
  end

  test "bounds a goal by 0 on it and by no more than brute force's presses from the player" do
    wrong = []
    goals = 0
    by_ways = 0
    bound_grids do |seed, pads, dist, tiles|
      by_ways += 1 if pads == 0 && Moves.strides(LEDGE) != Moves::ONE_STRIDE
      px = $game_player.x
      py = $game_player.y
      tiles.each do |gx, gy|
        b = Routes::Search.bound_for(Routes::Goal.onto(gx, gy), LEDGE)
        next unless b.is_a?(Routes::Bound)
        goals += 1
        wrong.push([seed, gx, gy, :goal]) unless b.at(gx, gy) == 0
        wrong.push([seed, gx, gy, :over]) if b.at(px, py) > dist[[gx, gy]][0]
      end
    end
    assert_operator goals, :>, 800, "goals bounded through shortcuts"
    assert_operator by_ways, :>=, 4, "grids without pads bounded by the ways the ledges hop"
    assert_equal [], wrong.first(5)
  end

  test "bounds a tile by no more than a move's presses over the bound where the move lands" do
    wrong = []
    moves = 0
    bound_grids do |seed, _pads, _dist, tiles|
      lvl = PokeAccess::Pathfinder.bridge_level
      tiles.each_with_index do |(gx, gy), i|
        next unless i % 9 == 0
        b = Routes::Search.bound_for(Routes::Goal.onto(gx, gy), LEDGE)
        next unless b.is_a?(Routes::Bound)
        tiles.each do |nx, ny|
          Routes::DIRS.each do |dir|
            s = Moves.step(nx, ny, lvl, dir, LEDGE)
            next unless s
            moves += 1
            wrong.push([seed, gx, gy, nx, ny, dir[2]]) if b.at(nx, ny) > s.presses + b.at(s.x, s.y)
          end
        end
      end
    end
    assert_operator moves, :>, 20000, "moves checked under a goal's bound"
    assert_equal [], wrong.first(5)
  end

  test "bounds through a pad somewhere tighter than the plain distance" do
    tighter = 0
    bound_grids do |_seed, pads, _dist, tiles|
      next if pads == 0
      tiles.each do |gx, gy|
        b = Routes::Search.bound_for(Routes::Goal.onto(gx, gy), LEDGE)
        next unless b.is_a?(Routes::Bound)
        tighter += 1 if b.at($game_player.x, $game_player.y) < b.plain($game_player.x, $game_player.y)
      end
    end
    assert_operator tighter, :>, 0
  end

  test "takes a ledge hop that lands on a warp pad as a shortcut" do
    hop_onto_pad
    assert_equal [2], searching { Routes::Search.route(Routes::Goal.onto(7, 3), LEDGE, :astar) }.route
  end

  test "bounds a ledge hop that lands on a warp pad by its one press" do
    hop_onto_pad
    goal = Routes::Goal.onto(7, 3)
    assert_equal 1, searching { Routes::Search.lower(goal, Routes::Search.bound_for(goal, LEDGE)) }
  end

  test "goes without an estimate where the shortcuts are too many to bound, and still finds the best route" do
    rows = ["#" * 16] + Array.new(14) { "#" + "." * 14 + "#" } + ["#" * 16]
    rows[1] = "#@" + "." * 13 + "#"
    $game_map.load_grid(rows)
    (0...36).each { |i| pad(70 + i, 2 + 2 * (i % 6), 2 + 2 * (i / 6), 1 + 2 * (i % 7), 1 + 2 * (i / 7)) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    goal = Routes::Goal.onto(13, 13)
    assert_nil estimate(goal), "no estimate"
    r = searching { Routes::Search.run(goal, Routes::CostModel.new(:shortest), LEDGE, :astar, nil) }
    assert_equal brute_best(:shortest, LEDGE)[[13, 13]], [r.route.length, route_turns(r.route)]
  end

  test "lets each style choose its own route down a staircase" do
    staircase
    { :shortest => [8, 6], :balanced => [12, 2], :straightest => [12, 2] }.each do |style, want|
      r = searching { Routes::Search.run(Routes::Goal.onto(5, 5), Routes::CostModel.new(style), 0, :astar, 1) }.route
      assert_equal want, [r.length, route_turns(r)], "the #{style} style"
    end
  end

  test "takes the straightest route in that route style within 5/4 of the distance plus 4 presses" do
    staircase
    PokeAccess::Config.route_style = :straightest
    r = searching { Routes::Search.route(Routes::Goal.onto(5, 5), 0, :astar) }.route
    assert_equal [12, 2], [r.length, route_turns(r)]
  end

  test "keeps the straightest route within 5/4 of the shortest plus 4 presses, though past the distance's" do
    $game_map.load_grid(["#######",
                         "#@#...#",
                         "#...#.#",
                         "#..#..#",
                         "#.....#",
                         "#######"])
    PokeAccess::Config.route_style = :straightest
    r = searching { Routes::Search.route(Routes::Goal.onto(5, 1), 0, :astar) }.route
    assert_equal [10, 2], [r.length, route_turns(r)], "ten presses to the shortest route's six"
  end

  test "gives way past its cap to the balanced route" do
    $game_map.load_grid(["########",
                         "#@.....#",
                         "#...##.#",
                         "#.#..#.#",
                         "#.##...#",
                         "#.###.##",
                         "#.###.##",
                         "#.###.##",
                         "#.###.##",
                         "#.###.##",
                         "#.###.##",
                         "#.....##",
                         "########"])
    goal = Routes::Goal.onto(5, 5)
    assert_equal [[8, 5], [10, 3], [20, 2]], STYLES.map { |s| brute_best(s, 0)[[5, 5]] }, "three routes apart"
    PokeAccess::Config.route_style = :straightest
    r = searching { Routes::Search.route(goal, 0, :astar) }.route
    assert_equal [10, 3], [r.length, route_turns(r)], "twenty presses to the shortest route's eight are too many"
  end

  test "hits a goal of acting on a tile on it, beside it and across a counter, and nowhere else" do
    counter_room
    near = Routes::Goal.near(3, 1)
    { [3, 1] => true, [2, 1] => true, [4, 1] => true, [3, 3] => true, [5, 1] => false, [2, 3] => false,
      [1, 1] => false }.each { |(x, y), want| assert_equal want, near.hit?(x, y), "at (#{x}, #{y})" }
  end

  test "hits a goal of standing on a tile there alone" do
    onto = Routes::Goal.onto(3, 1)
    assert_equal [true, false, false], [[3, 1], [2, 1], [3, 2]].map { |x, y| onto.hit?(x, y) }
  end

  test "bounds a goal by the distance to its nearest tile, one less than to the target for its ring" do
    counter_room
    { [Routes::Goal.near(3, 1), 3, 4] => 1, [Routes::Goal.near(1, 1), 5, 3] => 5, [Routes::Goal.near(1, 1), 1, 1] => 0,
      [Routes::Goal.near(1, 1), 2, 1] => 0, [Routes::Goal.new([[4, 3]], 4, 2), 4, 6] => 3,
      [Routes::Goal.onto(3, 1), 0, 0] => 4 }.each do |(goal, x, y), want|
      assert_equal want, goal.bound(x, y), "from (#{x}, #{y}) to the goal for (#{goal.tx}, #{goal.ty})"
    end
  end

  test "measures the distance to the target itself for the estimate of before" do
    counter_room
    assert_equal [3, 4], [Routes::Goal.near(3, 1).reach(3, 4), Routes::Goal.onto(3, 1).reach(0, 0)]
  end

  test "prices a move by its style: presses then turns, presses and turns then turns, or turns then presses" do
    { [:shortest, 2, false] => 2 * K, [:shortest, 1, true] => K + 1, [:balanced, 2, false] => 2 * K,
      [:balanced, 1, true] => 2 * K + 1, [:straightest, 100, false] => 100,
      [:straightest, 1, true] => K + 1 }.each do |(style, presses, turned), want|
      assert_equal want, Routes::CostModel.new(style).step(presses, turned, false), "#{style}, #{presses}, #{turned}"
    end
  end

  test "prices a gate as its cost in presses more" do
    gate = PokeAccess::Pathfinder::GATE_COST
    { :shortest => (1 + gate) * K, :balanced => (1 + gate) * K, :straightest => 1 + gate }.each do |style, want|
      assert_equal want, Routes::CostModel.new(style).step(1, false, true), "the #{style} style"
    end
  end

  test "tells in each style the least a route of some presses costs and what a turn does" do
    { :shortest => [5 * K, 1], :balanced => [5 * K, K + 1], :straightest => [5, K] }.each do |style, want|
      cost = Routes::CostModel.new(style)
      assert_equal want, [cost.least(5), cost.turn_unit], "the #{style} style"
    end
  end

  test "takes an unknown style as the shortest" do
    assert_equal :shortest, Routes::CostModel.new(:zigzag).style
  end

  test "ends found on a tile it reaches, costing what its route's presses and turns do" do
    status_room
    r = searching { Routes::Search.run(Routes::Goal.onto(7, 4), Routes::CostModel.new(:shortest), 0, :astar, 1) }
    assert_equal [:found, 9 * K + 1, [9, 1]], [r.status, r.cost, [r.route.length, route_turns(r.route)]],
                 "six presses across and three down, one turn"
  end

  test "ends exhausted on a tile walled off" do
    status_room
    r = searching { Routes::Search.run(Routes::Goal.onto(9, 4), Routes::CostModel.new(:shortest), 0, :astar, 1) }
    assert_equal [:exhausted, nil], [r.status, r.route]
  end

  test "ends cut when its budget runs out first, the states it took counted" do
    status_room
    PokeAccess::Config.astar_max = 3
    r = searching { Routes::Search.run(Routes::Goal.onto(7, 4), Routes::CostModel.new(:shortest), 0, :astar, nil) }
    assert_equal [:cut, nil, 4], [r.status, r.route, r.expanded]
  end

  test "answers from the flood kept for the player as they stand, before searching" do
    status_room
    PokeAccess::Config.path_algorithm = :astar
    searching { Routes::Flood.for(Routes::CostModel.new(:shortest), 0) }
    r = searching { Routes::Search.route(Routes::Goal.onto(7, 4), 0, :astar) }
    assert_equal [:found, :flood, 9, 0], [r.status, r.algo, r.route.length, r.expanded]
  end

  test "looks only for routes that cost no more than its cap" do
    status_room
    goal = Routes::Goal.onto(7, 4)
    cost = Routes::CostModel.new(:shortest)
    best = searching { Routes::Search.run(goal, cost, 0, :astar, 1) }
    capped = [best.cost, best.cost - 1].map do |cap|
      searching { Routes::Search.run(goal, cost, 0, :astar, 1, cap) }.status
    end
    assert_equal [:found, :exhausted], capped, "capped at the best route's cost, and one below it"
  end

  test "answers a search its budget cut from the player's flood, counting the cut search's states" do
    status_room
    PokeAccess::Config.path_algorithm = :astar
    PokeAccess::Config.astar_max = 3
    r = searching { Routes::Search.route(Routes::Goal.onto(7, 4), 0, :astar) }
    assert_equal [:found, :flood, 9, 4], [r.status, r.algo, r.route.length, r.expanded]
  end

  test "goes on from its tables where its budget cut it, to the same end as a search at once" do
    status_room
    cost = Routes::CostModel.new(:shortest)
    whole = flood_tables(cost, Routes::Limits.new(:none, 0, 0))
    t = Routes::Tables.new({}, {}, {}, {}, {}, nil, [])
    rounds = 0
    rounds += 1 until flood_round(cost, t, Routes::Limits.new(:effort, 4, 0)) == :exhausted || rounds > 50
    assert_operator rounds, :>, 3, "it took several budgets"
    assert_equal whole.settled, t.settled, "every tile at the cost the search at once gives it"
  end

  test "names the frontier it searched with, A* for those that search as A* where theirs does not apply" do
    status_room
    goal = Routes::Goal.onto(7, 4)
    { [:astar, :shortest] => :astar, [:jps, :shortest] => :jps, [:jps, :balanced] => :astar,
      [:hpa, :shortest] => :astar, [:regions, :shortest] => :astar, [:dijkstra, :shortest] => :dijkstra,
      [:bfs, :shortest] => :bfs, [:dfs, :shortest] => :dfs }.each do |(algo, style), want|
      r = searching { Routes::Search.run(goal, Routes::CostModel.new(style), 0, algo, 1) }
      assert_equal [:found, want], [r.status, r.algo], "#{algo} in the #{style} style"
    end
  end

  test "takes breadth first the fewest presses, and depth first its last way first" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#.....#",
                    "#.....#",
                    "#######"])
    goal = Routes::Goal.onto(5, 3)
    bfs = searching { Routes::Search.run(goal, Routes::CostModel.new(:shortest), 0, :bfs, 1) }
    dfs = searching { Routes::Search.run(goal, Routes::CostModel.new(:shortest), 0, :dfs, 1) }
    assert_equal 6, bfs.route.length, "breadth first: six presses"
    assert_equal [6, 6, 6, 6, 2, 4, 4, 4, 4, 2, 6, 6, 6, 6], dfs.route, "depth first: along each row in turn"
  end

  test "takes on open ground about a state a press, not the whole field" do
    rows = ["#" * 42] + Array.new(20) { "#" + "." * 40 + "#" } + ["#" * 42]
    rows[1] = "#@" + "." * 39 + "#"
    $game_map.load_grid(rows)
    r = searching { Routes::Search.run(Routes::Goal.onto(40, 20), Routes::CostModel.new(:shortest), 0, :astar, 1) }
    assert_equal [58, 1], [r.route.length, route_turns(r.route)], "the far corner, 58 presses and one turn away"
    assert_operator r.expanded, :<, 2 * 58, "taking fewer than two states a press"
  end

  test "under a deadline searches first with the estimate of before, then exactly, capped at its route's cost" do
    calls = spying_runs(false) { searching { Routes::Search.route(Routes::Goal.onto(6, 1), 0, :astar) } }[1]
    assert_equal [[:quick, nil], [:exact, 5 * K]], calls.map { |c| c[0, 2] }
  end

  test "under a deadline keeps the first route when the exact search is cut short, counting both" do
    r, calls = spying_runs(true) { searching { Routes::Search.route(Routes::Goal.onto(6, 1), 0, :astar) } }
    assert_equal [6, 6, 6, 6, 6], r.route, "the quick route"
    assert_equal calls.map { |c| c[2] }.inject(:+), r.expanded, "the states of both searches"
  end

  test "under a deadline answers a goal walled off from the quick search alone" do
    r, calls = spying_runs(false) { searching { Routes::Search.route(Routes::Goal.onto(6, 0), 0, :astar) } }
    assert_equal [:exhausted, [:quick]], [r.status, calls.map { |c| c[0] }]
  end

  test "finds a shortcut backwards through a transfer, its estimate giving way to it" do
    backwards_corridor
    r = searching { Routes::Search.route(Routes::Goal.onto(12, 1), 0, :astar) }
    assert_equal [[4, 4, 6], 1], [r.route, r.route.rooms], "two steps back onto the pad and one on, one transfer"
  end

  test "walks the corridor with the estimate of before, blind to the shortcut behind" do
    backwards_corridor
    cost = Routes::CostModel.new(:shortest)
    quick = searching { Routes::Search.run(Routes::Goal.onto(12, 1), cost, 0, :astar, :reach) }
    assert_equal 9, quick.route.length
  end

  test "takes the shortcut under a deadline too, the exact search after the quick one" do
    backwards_corridor
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = 1000
    r = searching { Routes::Search.route(Routes::Goal.onto(12, 1), 0, :astar) }
    assert_equal [4, 4, 6], r.route
  end

  test "tells the fewest presses a route can take as its estimate does, none without one" do
    counter_room
    goal = Routes::Goal.onto(5, 3)
    $game_player.x = 1
    $game_player.y = 1
    assert_equal [6, nil], [Routes::Search.lower(goal, 1), Routes::Search.lower(goal, nil)]
  end

  test "estimates one tile a press on plain ground" do
    speed_room
    assert_equal 1, Moves.speed(LEDGE)
  end

  test "estimates two tiles a press where a ledge hop counts, one where it does not" do
    speed_room
    $game_map.place_ledge(3, 1, 2)
    assert_equal [2, 1], [Moves.speed(LEDGE), Moves.speed(0)]
  end

  test "has no telling how far a press goes on ice" do
    speed_room
    $game_map.set_terrain(4, 2, 12)
    assert_nil Moves.speed(0)
  end

  test "has no telling once a rule owns a tile of the map by its tag, and none from a rule owning none here" do
    speed_room
    with_arrival_rules do
      Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      assert_equal 1, Moves.speed(0), "owning none of the map's tiles"
      $game_map.set_terrain(5, 2, 88)
      assert_nil Moves.speed(0), "owning one here"
    end
  end

  test "has no telling once a rule's block owns a tile of the map, and none from one owning none here" do
    speed_room
    pits = {}
    with_arrival_rules do
      Moves.arrival_rule(:tiles => lambda { |x, y| pits[[x, y]] }) { |_x, _y, _d| nil }
      assert_equal 1, Moves.speed(0), "owning none of the map's tiles"
      pits[[3, 2]] = true
      Moves.forget_map
      assert_nil Moves.speed(0), "owning one here"
    end
  end

  test "has no telling with an event that carries or sends the player" do
    { "a carry" => [World.move_player([3], 1)], "a transfer" => [TestCmd.new(201, [0, 1, 4, 1])] }.each do |what, list|
      speed_room
      World.touch(:id => 61, :x => 2, :y => 2, :list => list)
      assert_nil Moves.speed(0), "with #{what}"
    end
  end

  private

  # The routes of the three styles to every tile brute force reaches on the map loaded, searched with the search's own
  # estimate (Search.bound_for), that differ from brute force: [mismatches, routes checked].
  def mismatches(mode, tag)
    bad = []
    checked = 0
    STYLES.each do |style|
      cost = Routes::CostModel.new(style)
      brute_best(style, mode).each do |(tx, ty), want|
        next if tx == $game_player.x && ty == $game_player.y
        goal = Routes::Goal.onto(tx, ty)
        r = searching { Routes::Search.run(goal, cost, mode, :astar, Routes::Search.bound_for(goal, mode)) }
        checked += 1
        got = r.route ? [r.route.length, route_turns(r.route)] : nil
        bad.push([tag, style, tx, ty, got, want]) unless got == want
      end
    end
    [bad, checked]
  end

  # Yields, inside one search operation, each of 16 random grids without ice (eight seeds, with three pads and with
  # none): its seed, its pads, brute force's best [presses, turns] to each tile and those tiles in order.
  def bound_grids
    [5, 17, 23, 41, 59, 83, 97, 101].product([3, 0]).each do |seed, pads|
      random_route_grid(seed, 14, 10, false, pads)
      dist = brute_best(:shortest, LEDGE)
      searching { yield seed, pads, dist, dist.keys.sort }
    end
  end

  # The block's value inside one search operation.
  def searching(&blk)
    PokeAccess::Pathfinder.searching(&blk)
  end

  # The search's estimate toward goal on foot (Search.bound_for).
  def estimate(goal)
    searching { Routes::Search.bound_for(goal, LEDGE) }
  end

  # Two tiles the player can get to from the start, picked by seed, below the third row.
  def far_starts(seed)
    srand(seed)
    brute_rooms(LEDGE).keys.select { |_x, y| y >= 3 }.sort.sample(2)
  end

  # The block's value with the player moved to (x, y) for it.
  def stand_at(x, y)
    was = [$game_player.x, $game_player.y]
    $game_player.x = x
    $game_player.y = y
    World.next_frame
    yield
  ensure
    $game_player.x, $game_player.y = was
    World.next_frame
  end

  # A touch event at (x, y) that sends the player to (tx, ty) of the same map.
  def pad(id, x, y, tx, ty)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0, $game_map.map_id, tx, ty])])
  end

  # A room with a ledge at (1, 2) to hop down onto a pad at (1, 3), which sends the player to (7, 3).
  def hop_onto_pad
    $game_map.load_grid(["#########",
                         "#@......#",
                         "#.......#",
                         "#.......#",
                         "#########"])
    $game_map.place_ledge(1, 2, 2)
    pad(63, 1, 3, 7, 3)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A staircase down to (5, 5): 8 presses with 6 turns at the least, or 12 with 2 around its frame.
  def staircase
    $game_map.load_grid(["#######",
                         "#@.####",
                         "#...###",
                         "#.#..##",
                         "#.##..#",
                         "#.###.#",
                         "#.###.#",
                         "#.....#",
                         "#######"])
  end

  # A room with a counter at (3, 2).
  def counter_room
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#..C..#",
                         "#.....#",
                         "#######"])
  end

  # A room with the player at its top left and a tile, (9, 4), walled off at its east end.
  def status_room
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "#........#",
                         "#.......##",
                         "#.......#.",
                         "##########"])
  end

  # A corridor with the player at (3, 1) and a pad at its west end, (1, 1), that sends the player to (11, 1).
  def backwards_corridor
    $game_map.load_grid(["##############",
                         "#..@.........#",
                         "##############"])
    pad(62, 1, 1, 11, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A walled room of 5 x 2 with the player at its top left.
  def speed_room
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#.....#",
                         "#######"])
    World.clear_events
    $game_map.clear_ledges
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # The tables of a flood priced by cost run at once under limits.
  def flood_tables(cost, limits)
    t = Routes::Tables.new({}, {}, {}, {}, {}, nil, [])
    flood_round(cost, t, limits)
    t
  end

  # One round of a flood priced by cost on its tables t under limits: the search's status.
  def flood_round(cost, t, limits)
    searching do
      t.limits = limits
      Routes::Search.run(nil, cost, 0, :dijkstra, nil, nil, t).status
    end
  end

  # The block's value and the searches it ran under a deadline of a second, each as [:quick or :exact, its cap, the
  # states it took]; with cut_exact the exact ones answer cut. Search.run is put back afterwards.
  def spying_runs(cut_exact)
    $game_map.load_grid(["########",
                         "#@.....#",
                         "########"])
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = 1000
    calls = []
    search = Routes::Search
    real = search.method(:run)
    search.define_singleton_method(:run) do |goal, cost, mode, algo, est, cap = nil, t = nil|
      r = real.call(goal, cost, mode, algo, est, cap, t)
      calls.push([est == :reach ? :quick : :exact, cap, r.expanded])
      cut_exact && est != :reach ? Routes::SearchResult.new(:cut, nil, r.expanded, r.algo) : r
    end
    [yield, calls]
  ensure
    search.define_singleton_method(:run, real)
  end

  # Runs the block with the arrival rules registered now put back afterwards, the map's scan dropped both ways.
  def with_arrival_rules
    was = Moves.instance_variable_get(:@arrival_rules).dup
    Moves.forget_map
    yield
  ensure
    Moves.instance_variable_set(:@arrival_rules, was)
    Moves.forget_map
  end
end
