# The regions as a router (Regions.searched, asked first by Search.best) and the fewest presses they tell
# (presses_to), against brute force; the cases it leaves to the search, and the planner's choice of it.
class RegionsRouterTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Regions = PokeAccess::Routes::Regions
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  STYLES = [:shortest, :balanced, :straightest]

  test "costs what brute force's best route does in each style, with no route where there is none" do
    bad = []
    checked = 0
    [3, 11, 29, 47, 53, 71, 89, 97].each do |seed|
      one_way_grid(seed, true)
      Regions.foot.status([[0, 0]])
      STYLES.each do |style|
        b, n = mismatches(style, seed)
        bad.concat(b)
        checked += n
      end
    end
    assert_equal 3 * 8 * 87, checked, "every tile but the start, in each style"
    assert_equal [], bad.first(5), "every answer is brute force's"
  end

  test "costs what brute force's best route does from wherever the player stands after the walk" do
    bad = []
    checked = 0
    [3, 29, 71].each do |seed|
      one_way_grid(seed, true)
      Regions.foot.status([[0, 0]])
      far_starts(seed).each do |x, y|
        stand_at(x, y) do
          STYLES.each do |style|
            b, n = mismatches(style, [seed, x, y])
            bad.concat(b)
            checked += n
          end
        end
      end
    end
    assert_operator checked, :>, 1000, "answers checked"
    assert_equal [], bad.first(5), "every answer is brute force's"
  end

  test "costs what brute force's best route does without ice, its estimate through the pads' shortcuts" do
    bad = []
    guided = 0
    [5, 17, 23, 41, 59, 83].each do |seed|
      one_way_grid(seed, false)
      Regions.foot.status([[0, 0]])
      guided += 1 unless estimate_for(Routes::Goal.onto(11, 8)).nil?
      STYLES.each { |style| bad.concat(mismatches(style, seed)[0]) }
    end
    assert_operator guided, :>=, 4, "most grids have an estimate"
    assert_equal [], bad.first(5), "every answer is brute force's"
  end

  test "answers an empty route to the tile the player stands on" do
    corridor
    Regions.foot.status([[0, 0]])
    r = searched(Routes::Goal.onto(1, 1))
    assert_equal [:found, :regions, []], [r.status, r.algo, r.route]
  end

  test "tells the rooms of a route through a transfer, and the press that warps" do
    hpa_fresh_grid(["##############",
                    "#..@.........#",
                    "##############"])
    pad(62, 1, 1, 11, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    Regions.foot.status([[0, 0]])
    r = searched(Routes::Goal.onto(12, 1))
    assert_equal [[4, 4, 6], 1, [1]], [r.route, r.route.rooms, r.route.warps]
  end

  test "takes the way through a pad that lands the player farther from the goal, when it is shorter" do
    hpa_fresh_grid(["#" * 22,
                    "#" + "." * 5 + "@" + "." * 14 + "#",
                    "#" * 20 + ".#",
                    "#" + "." * 20 + "#",
                    "#" * 22])
    pad(60, 3, 1, 20, 1)
    PokeAccess::Pathfinder.invalidate_cache(true)
    Regions.foot.status([[0, 0]])
    r = searched(Routes::Goal.onto(1, 3))
    assert_equal [:found, [24, 2]], [r.status, [r.route.length, route_turns(r.route)]],
                 "three presses back onto the pad, then down at the far end and back: not the 35 of walking to that end"
  end

  test "leaves to the search a player standing where the walk never reached" do
    hpa_fresh_grid(["#########",
                    "#@..#...#",
                    "#########"])
    Regions.foot.status([[0, 0]])
    $game_player.x = 5
    World.next_frame
    assert_nil searched(Routes::Goal.onto(7, 1)), "the router cannot tell"
    w = Routes::Planner.walk(7, 1, true)
    assert_equal [:found, :astar, [6, 6]], [w.status, w.algo, w.route], "the search answers"
  end

  test "answers nothing while the regions are not all walked" do
    corridor
    assert_nil searched(Routes::Goal.onto(10, 1))
  end

  test "answers nothing for other moves than the walk's" do
    corridor
    Regions.foot.status([[0, 0]])
    assert_nil searched(Routes::Goal.onto(10, 1), LEDGE | Routes::Moves::RELAX)
  end

  test "leaves to the search a route the replay does not end on the goal, past a walker it lent through" do
    corridor
    walker = TestGameEvent.new(:id => 40, :x => 5, :y => 1, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    walker.blocking = true
    $game_map.events[40] = walker
    World.next_frame
    assert_equal [:yes, 0], Regions.foot.status([[10, 1]]), "the regions reach past the walker"
    assert_nil searched(Routes::Goal.onto(10, 1)), "but its route stops at it"
  end

  test "routes the planner by default, in any route style" do
    corridor
    Regions.foot.status([[0, 0]])
    STYLES.each do |style|
      PokeAccess::Config.route_style = style
      w = Routes::Planner.walk(10, 1, true)
      assert_equal [:regions, 9], [w.algo, w.route.length], "in the #{style} style"
    end
  end

  test "leaves the planner to the search with edge_relax on" do
    corridor
    Regions.foot.status([[0, 0]])
    PokeAccess::Config.edge_relax = true
    w = Routes::Planner.walk(10, 1, true)
    assert_equal [:astar, 9], [w.algo, w.route.length]
  end

  test "answers a search its budget cut once the regions are walked on" do
    corridor
    PokeAccess::Config.astar_max = 1
    with_flood_nodes(3) do
      refute Regions.foot.done?, "the regions start unwalked"
      w = Routes::Planner.walk(10, 1, true)
      assert_equal [:found, :regions, 9], [w.status, w.algo, w.route && w.route.length]
      assert Regions.foot.done?, "having walked the regions on"
    end
  end

  test "is not asked after a cut search with A* chosen" do
    corridor
    PokeAccess::Config.astar_max = 1
    PokeAccess::Config.path_algorithm = :astar
    with_flood_nodes(3) do
      w = Routes::Planner.walk(10, 1, true)
      assert_equal [:cut, :astar], [w.status, w.algo]
    end
  end

  test "indexes each way by its place in DIRS" do
    assert_equal({ 8 => 0, 2 => 1, 4 => 2, 6 => 3 }, Regions::DIR_INDEX, "up, down, left and right")
  end

  test "tells the fewest presses to each tile as brute force does, none to a tile out of reach" do
    bad = []
    [3, 11, 29, 47].each do |seed|
      one_way_grid(seed, true)
      Regions.foot.status([[0, 0]])
      best = brute_best(:shortest, LEDGE)
      (0...13).each do |x|
        (0...10).each do |y|
          want = best[[x, y]] && best[[x, y]][0]
          got = Regions.foot.presses_to([[x, y]])
          bad.push([seed, x, y, got, want]) unless got == want
        end
      end
    end
    assert_equal [], bad.first(5)
  end

  test "tells the fewest presses to any of the tiles asked about" do
    corridor
    assert_equal 3, Regions.foot.presses_to([[9, 1], [4, 1], [0, 0]])
  end

  test "tells no presses without a player" do
    corridor
    Regions.foot.status([[0, 0]])
    without_player { assert_nil Regions.foot.presses_to([[4, 1]]) }
  end

  test "tells no presses while the regions are not all walked" do
    with_share(4) do
      corridor
      assert_nil Regions.foot.presses_to([[2, 1]])
    end
  end

  test "tells the presses from a dropped one as the regions walked anew on the map as it is now" do
    corridor
    old = Regions.foot
    old.status([[0, 0]])
    $game_map.block_step(5, 1, 6)
    assert_equal [nil, 3], [old.presses_to([[10, 1]]), old.presses_to([[4, 1]])], "the corridor shut past (5, 1)"
  end

  private

  # The router's answers in style to every inner tile of the 13 x 10 map loaded that differ from brute force (presses
  # and turns, a route where there is none, or no answer at all): [mismatches, answers checked].
  def mismatches(style, tag)
    best = brute_best(style, LEDGE)
    cost = Routes::CostModel.new(style)
    bad = []
    checked = 0
    (1...12).each do |tx|
      (1...9).each do |ty|
        next if tx == $game_player.x && ty == $game_player.y
        r = searched(Routes::Goal.onto(tx, ty), LEDGE, cost)
        checked += 1
        b = best[[tx, ty]]
        got = r ? [r.status, r.route && [r.route.length, route_turns(r.route)]] : nil
        want = b ? [:found, b] : [:exhausted, nil]
        bad.push([tag, style, tx, ty, got, want]) unless got == want
      end
    end
    [bad, checked]
  end

  # The router's answer to goal with the moves of mode, priced in cost, with the search's own estimate.
  def searched(goal, mode = LEDGE, cost = Routes::CostModel.new(:shortest))
    PokeAccess::Pathfinder.searching { Regions.searched(goal, cost, mode, Routes::Search.bound_for(goal, mode)) }
  end

  # The search's estimate toward goal on foot (Search.bound_for).
  def estimate_for(goal)
    PokeAccess::Pathfinder.searching { Routes::Search.bound_for(goal, LEDGE) }
  end

  # A 13 x 10 random grid (random_route_grid with two pads, ice or not) with eight steps shut one way at random.
  def one_way_grid(seed, ice)
    random_route_grid(seed, 13, 10, ice, 2)
    srand(seed * 7)
    8.times { $game_map.block_step(1 + rand(11), 1 + rand(8), [2, 4, 6, 8][rand(4)]) }
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Two tiles the player can get to from the start, picked by seed, below the third row.
  def far_starts(seed)
    srand(seed)
    brute_rooms(LEDGE).keys.select { |_x, y| y >= 3 }.sort.sample(2)
  end

  # A corridor of ten tiles with the player at its west end, (1, 1).
  def corridor
    hpa_fresh_grid(["#" * 12, "#@" + "." * 9 + "#", "#" * 12])
  end

  # A touch event at (x, y) that sends the player to (tx, ty) of the same map.
  def pad(id, x, y, tx, ty)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0, $game_map.map_id, tx, ty])])
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

  # Runs the block with no player on the map, the player put back afterwards.
  def without_player
    was = $game_player
    $game_player = nil
    yield
  ensure
    $game_player = was
  end

  # Runs the block with the flood's budget per round set to nodes states.
  def with_flood_nodes(nodes)
    fl = Routes::Flood
    was = fl::NODES
    fl.send(:remove_const, :NODES)
    fl.const_set(:NODES, nodes)
    yield
  ensure
    fl.send(:remove_const, :NODES)
    fl.const_set(:NODES, was)
  end

  # Runs the block with the regions on foot sharing share states out to their questions, dropped before and after.
  def with_share(share)
    was = Regions::VARIANTS
    Regions.send(:remove_const, :VARIANTS)
    Regions.const_set(:VARIANTS, was.merge(:foot => [was[:foot][0], share]))
    Regions.forget
    yield
  ensure
    Regions.send(:remove_const, :VARIANTS)
    Regions.const_set(:VARIANTS, was)
    Regions.forget
  end
end
