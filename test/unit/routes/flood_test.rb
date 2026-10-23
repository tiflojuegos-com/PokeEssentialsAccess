# The player's flood (Routes::Flood): its ways and their cost match brute force in every style, a flood its budget
# stops goes on where it stopped, and the last few floods are kept apart by everything they depend on.
class FloodTest < PokeAccessTest
  Routes = PokeAccess::Routes
  LEDGE = PokeAccess::Routes::Moves::LEDGE

  test "its way to every tile matches brute force in each style, and a wall has none" do
    bad = []
    checked = 0
    [3, 11, 29, 47].each do |seed|
      random_route_grid(seed, 12, 9, true, 3)
      [:shortest, :balanced, :straightest].each do |style|
        f = flood_for(Routes::CostModel.new(style))
        assert f.done?, "seed #{seed}, #{style}: the flood ran to the end"
        brute = brute_best(style, LEDGE)
        brute.each do |(tx, ty), want|
          next if [tx, ty] == [$game_player.x, $game_player.y]
          checked += 1
          got = shape(f.route_to(Routes::Goal.onto(tx, ty)))
          bad.push([seed, style, tx, ty, got, want]) unless got == want
          next unless style == :shortest
          near = Routes::Goal.near(tx, ty).tiles.map { |g| brute[g] }.compact.min
          got = shape(f.route_to(Routes::Goal.near(tx, ty)))
          bad.push([seed, :near, tx, ty, got, near]) unless got == near
        end
        assert_equal :exhausted, f.route_to(Routes::Goal.onto(0, 0)).status, "seed #{seed}, #{style}: a wall"
      end
    end
    assert_operator checked, :>, 300, "routes checked"
    assert_equal [], bad.first(5), "each way is as short and as straight as brute force's"
  end

  test "the cost it reports is the presses and turns of its way, as the style prices them" do
    random_route_grid(11, 12, 9, true, 3)
    cost = Routes::CostModel.new(:shortest)
    f = flood_for(cost)
    wrong = brute_best(:shortest, LEDGE).reject do |(tx, ty), (presses, turns)|
      [tx, ty] == [$game_player.x, $game_player.y] ||
        f.route_to(Routes::Goal.onto(tx, ty)).cost == presses * Routes::CostModel::K + turns
    end
    assert_equal [], wrong.first(5), "every tile's cost"
  end

  test "stopped by its budget, it goes on where it stopped and ends exact" do
    with_nodes(15) do
      random_route_grid(29, 12, 9, true, 3)
      cost = Routes::CostModel.new(:shortest)
      f = flood_for(cost)
      refute f.done?, "a budget of 15 states stops it short"
      rounds = 0
      until f.done? || rounds > 100
        rounds += 1
        assert_same f, flood_for(cost), "asked again, the same flood goes on"
      end
      assert_operator rounds, :>, 2, "it took several more budgets"
      bad = brute_best(:shortest, LEDGE).reject do |(tx, ty), want|
        [tx, ty] == [$game_player.x, $game_player.y] || shape(f.route_to(Routes::Goal.onto(tx, ty))) == want
      end
      assert_equal [], bad.first(5), "once finished, its ways are brute force's"
    end
  end

  test "asked again as the player stands, it answers with the same flood" do
    random_route_grid(3, 12, 9, true, 3)
    cost = Routes::CostModel.new(:shortest)
    assert_same flood_for(cost), flood_for(cost)
  end

  test "keeps the last four floods, dropping the oldest" do
    open_room
    cost = Routes::CostModel.new(:shortest)
    floods = (1..5).map { |x| stand_at(x, 1) { flood_for(cost) } }
    assert_nil stand_at(1, 1) { kept(cost) }, "the first was dropped when the fifth came"
    (2..5).each { |x| assert_same floods[x - 1], stand_at(x, 1) { kept(cost) }, "the flood from (#{x}, 1) is kept" }
  end

  test "keeps one flood per style and per standing place" do
    open_room
    shortest = flood_for(Routes::CostModel.new(:shortest))
    straightest = flood_for(Routes::CostModel.new(:straightest))
    refute_same shortest, straightest, "another style floods anew"
    assert_same shortest, kept(Routes::CostModel.new(:shortest)), "and the first style's stays kept"
  end

  test "forgets every flood it kept" do
    open_room
    cost = Routes::CostModel.new(:shortest)
    flood_for(cost)
    Routes::Flood.forget
    assert_nil kept(cost)
  end

  test "new tiles drop the floods kept" do
    open_room
    cost = Routes::CostModel.new(:shortest)
    flood_for(cost)
    PokeAccess::World::Epoch.touch(:tiles)
    assert_nil kept(cost)
  end

  test "gives no flood partway up a side stair, where every step is answered from the stair" do
    open_room
    def $game_player.on_middle_of_stair?; true; end
    World.next_frame
    assert_nil flood_for(Routes::CostModel.new(:shortest))
  ensure
    $game_player.singleton_class.send(:remove_method, :on_middle_of_stair?)
    World.next_frame
  end

  test "gives no flood once the operation's deadline has passed" do
    open_room
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1
    assert_nil flood_for(Routes::CostModel.new(:shortest))
  end

  test "one made with events lent is kept apart from one made without" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#######.#",
                    "#.......#",
                    "#########"])
    walker = TestGameEvent.new(:id => 40, :x => 7, :y => 2, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    walker.blocking = true
    $game_map.events[40] = walker
    World.next_frame
    cost = Routes::CostModel.new(:shortest)
    goal = Routes::Goal.onto(1, 3)
    shut = flood_for(cost)
    assert_equal :exhausted, shut.route_to(goal).status, "made with the walker as a wall, it reaches no way past it"
    lent = PokeAccess::Pathfinder.searching do
      PokeAccess::World::Probe.lend_through([walker]) { [Routes::Flood.kept(cost, LEDGE), Routes::Flood.for(cost, LEDGE)] }
    end
    assert_nil lent[0], "while it is lent, that flood is not the one kept"
    assert_equal 14, lent[1].route_to(goal).route.length, "the one made then goes past it"
    assert_same shut, kept(cost), "without lending, the first is kept still"
  end

  private

  # The flood for the player as they stand, asked as a search operation asks it.
  def flood_for(cost)
    PokeAccess::Pathfinder.searching { Routes::Flood.for(cost, LEDGE) }
  end

  # The flood kept for the player as they stand, or nil.
  def kept(cost)
    PokeAccess::Pathfinder.searching { Routes::Flood.kept(cost, LEDGE) }
  end

  # A way's presses and turns, or nil for no way.
  def shape(result)
    result && result.route ? [result.route.length, route_turns(result.route)] : nil
  end

  # A walled room with the player at its top left.
  def open_room
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#.......#",
                    "#########"])
  end

  # The block's value with the player moved to (x, y) for it.
  def stand_at(x, y)
    was = [$game_player.x, $game_player.y]
    $game_player.x = x
    $game_player.y = y
    yield
  ensure
    $game_player.x, $game_player.y = was
  end

  # Runs the block with the flood's budget per round set to nodes states.
  def with_nodes(nodes)
    was = Routes::Flood::NODES
    Routes::Flood.send(:remove_const, :NODES)
    Routes::Flood.const_set(:NODES, nodes)
    yield
  ensure
    Routes::Flood.send(:remove_const, :NODES)
    Routes::Flood.const_set(:NODES, was)
  end
end
