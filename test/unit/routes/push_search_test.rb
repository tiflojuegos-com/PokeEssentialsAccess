# What the search that moves boulders takes from the assisted regions: no search where no boulder that can move opens the way, the
# presses left walking for its estimate, and past Pushes::EXACT states a hurry that weighs a hard room's estimate.
class PushSearchTest < PokeAccessTest
  Routes = PokeAccess::Routes
  Goal = Routes::Goal
  Pushes = Routes::Pushes
  Regions = Routes::Regions
  RIGHT = 6
  DOWN = 2

  test "answers with no search a way two boulders shut, where a route may move one" do
    rocky(["#########", "#@......#", "#########"], [[3, 1], [5, 1]]) do
      assert_equal [nil, 0], routed(Goal.onto(7, 1))
    end
  end

  test "searches on with the assist, whose route may move them both" do
    rocky(["#########", "#@......#", "#########"], [[3, 1], [5, 1]]) do
      PokeAccess::Config.puzzle_assist = true
      assert_equal [nil, 1], routed(Goal.onto(7, 1))
    end
  ensure
    PokeAccess::Config.puzzle_assist = false
  end

  test "answers with no search a boulder no push moves" do
    rocky(["######", "#@...#", "####.#", "######"], [[4, 1]]) do
      assert_equal [nil, 0], routed(Goal.onto(4, 2))
    end
  end

  test "searches on for a boulder that moves though it never clears the way" do
    rocky(["#######", "#@....#", "#######"], [[3, 1]]) do
      assert_equal [nil, 1], routed(Goal.onto(5, 1))
    end
  end

  test "searches on where a boulder stands beside a tile that moves the player, which the walk never stops at" do
    rocky(["######", "#@...#", "####.#", "######"], [[4, 1]]) do
      $game_map.set_terrain(3, 1, ICE)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal 1, routed(Goal.onto(4, 2))[1]
    end
  end

  test "answers with no search though ice lies off the walk, where no slide can start" do
    rocky(["########", "#@...#.#", "####.#.#", "########"], [[4, 1]]) do
      $game_map.set_terrain(6, 1, ICE)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal [nil, 0], routed(Goal.onto(4, 2))
    end
  end

  test "keeps a route whose boulder stops a slide where a push leaves it, though none stands by the ice yet" do
    rows = ["############",
            "#@.........#",
            "#..........#",
            "#.####.#####",
            "#..........#",
            "#.###.######",
            "#.....######",
            "############"]
    rocky(rows, [[6, 2], [1, 6]]) do
      (2..9).each { |x| $game_map.set_terrain(x, 4, ICE) }
      PokeAccess::Pathfinder.invalidate_cache(true)
      route, gate = Routes::Planner.assisted(5, 5, true)
      assert_equal [[RIGHT] * 5, [6, 2]], [route.to_a, [gate[:x], gate[:y]]]
    end
  end

  test "finds every route the search finds without the walk, in random rooms of ice and ledges" do
    lost = []
    found = 0
    (1..120).each do |seed|
      rng = Random.new(seed)
      rows = (0...7).map { |y| (0...9).map { |x| x == 0 || y == 0 || x == 8 || y == 6 || rng.rand < 0.2 ? "#" : "." }.join }
      rows[1][1] = "@"
      floor = []
      rows.each_with_index { |r, y| r.each_char.with_index { |c, x| floor.push([x, y]) if c == "." } }
      next if floor.length < 8
      rocks = floor.sample(1 + rng.rand(3), :random => rng)
      ice = (floor - rocks).select { rng.rand < 0.2 }
      ledges = (floor - rocks - ice).select { rng.rand < 0.05 }.map { |x, y| [x, y, [2, 4, 6, 8][rng.rand(4)]] }
      assist = rng.rand < 0.5
      goals = (floor - rocks).sample(6, :random => rng)
      rocky(rows, rocks) do
        PokeAccess::Config.puzzle_assist = assist
        ice.each { |x, y| $game_map.set_terrain(x, y, ICE) }
        ledges.each { |x, y, d| $game_map.place_ledge(x, y, d) }
        PokeAccess::Pathfinder.invalidate_cache(true)
        goals.each do |x, y|
          with = Routes::Planner.assisted(x, y, true)
          without = without_walk { Pushes.route(Goal.onto(x, y)) }
          found += 1 if without
          lost.push([seed, x, y]) if without && !with
        end
      end
    end
    assert_operator found, :>, 40, "routes that move boulders"
    assert_equal [], lost.first(5)
  ensure
    PokeAccess::Config.puzzle_assist = false
  end

  test "searches on where a boulder can be pulled, which lands the player where the walk need not" do
    rocky(["######", "#@...#", "####.#", "######"], [[4, 1]]) do
      with_pull_scripts([/pbPushThisBoulder/]) do
        assert_equal 1, routed(Goal.onto(4, 2))[1]
      end
    end
  end

  test "takes a boulder to a box by the pulls that bring it there soonest, its estimate counting them with the pushes" do
    rocky(["#########", "###@.####", "###.....#", "###.....#", "###.....#", "#########"], [[3, 2]]) do
      with_pull_scripts([/pbPushThisBoulder/]) do
        goal = rock_goal(3, 2, [5, 2, 5, 2])
        assert_equal 2 * (1 + PokeAccess::Pathfinder::GATE_COST), goal.bound(0, 0, [])
        route, gate = Pushes.route(rock_goal(3, 2, [5, 2, 5, 2]))
        assert_equal [[6, 2], :pull], [route.to_a, gate[:kind]]
      end
    end
  end

  test "gives no estimate to a box no push or pull takes a boulder to" do
    rocky(["#######", "#@.#..#", "#######"], [[2, 1]]) do
      with_pull_scripts([/pbPushThisBoulder/]) do
        assert_equal Routes::FAR, rock_goal(2, 1, [4, 1, 4, 1]).bound(0, 0, [])
      end
    end
  end

  test "searches on with edge_relax, whose border steps the regions do not take" do
    rocky(["######", "#@...#", "####.#", "######"], [[4, 1]]) do
      PokeAccess::Config.edge_relax = true
      assert_equal [nil, 1], routed(Goal.onto(4, 2))
    end
  ensure
    PokeAccess::Config.edge_relax = false
  end

  test "gets past a boulder as the walk tells: nil once on the tiles, else the boulders it saw could move" do
    rocky(["#########", "#@......#", "#########"], [[3, 1], [5, 1]]) do
      rocks = Routes::Effects.boulder_index
      all = lambda { |_rock, _x, _y, _dir| true }
      none = lambda { |_rock, _x, _y, _dir| false }
      walk = walked
      assert_nil walk.past_boulders([[2, 1]], rocks, {}, false, &none), "short of the boulders"
      assert_equal({}, walk.past_boulders([[4, 1]], rocks, {}, false, &none), "no boulder moves")
      assert_equal [key(3, 1)], walk.past_boulders([[4, 1]], rocks, {}, false, &all).keys, "the first is in the way, and not gone"
      assert_nil walk.past_boulders([[7, 1]], rocks, {}, true, &all), "each goes as it is met"
      assert_nil walk.past_boulders([[4, 1]], rocks, { key(3, 1) => true }, false), "the one gone"
      assert_equal({}, walk.past_boulders([[7, 1]], rocks, { key(3, 1) => true }, false), "the other stays, and nothing asks about it")
    end
  end

  test "gets past along every way the walk goes, with no boulder in front" do
    rocky(["#####", "#...#", "###.#", "#@..#", "#####"], [[1, 1]]) do
      assert_nil walked.past_boulders([[2, 1]], Routes::Effects.boulder_index, {}, false)
    end
  end

  test "asks a boulder from the side the player stands on, along the way to it" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      asked = []
      walked.past_boulders([[7, 1]], Routes::Effects.boulder_index, {}, false) do |rock, x, y, dir|
        asked.push([rock, x, y, dir[2]])
        false
      end
      assert_equal [[key(3, 1), 2, 1, RIGHT]], asked
    end
  end

  test "takes no hop onto a boulder, nor one a boulder stands in front of" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      $game_map.place_ledge(2, 1, RIGHT)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal({}, walked.past_boulders([[5, 1]], Routes::Effects.boulder_index, {}, false), "the landing is the boulder's")
    end
    rocky(["#########", "#@......#", "#########"], [[2, 1]]) do
      $game_map.place_ledge(2, 1, RIGHT)
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal({}, walked.past_boulders([[5, 1]], Routes::Effects.boulder_index, {}, false), "the boulder is on the ledge")
    end
  end

  test "goes straight for the boulder where the distance as the crow flies looks down a dead end" do
    rows = ["####################",
            "#.@................#",
            "#.#................#",
            "#.#................#",
            "#.##################",
            "#..................#",
            "####################"]
    rocky(rows, [[15, 5]]) do
      goal = Goal.onto(15, 5)
      taken = pops { assert Pushes.route(goal) }
      PokeAccess::Config.edge_relax = true
      PokeAccess::Pathfinder.invalidate_cache(true)
      crow = pops { assert Pushes.route(goal) }
      assert_operator taken * 2, :<, crow, "the walk's estimate leaves the room alone"
    end
  ensure
    PokeAccess::Config.edge_relax = false
  end

  test "leaves out a state with no way to the goal, down a ledge there is no coming back up" do
    rows = ["###########",
            "#@........#",
            "#.#########",
            "#.......###",
            "###########"]
    rocky(rows, [[4, 1]]) do
      $game_map.place_ledge(1, 2, DOWN)
      PokeAccess::Pathfinder.invalidate_cache(true)
      tiles = expanded { assert_equal 2, Pushes.route(Goal.onto(8, 1))[0].length }
      assert_equal [], tiles.select { |_x, y| y > 1 }, "never down there, however near it looks"
      tiles = expanded { assert_nil Pushes.route(Goal.onto(9, 1)) }
      assert_equal [], tiles.select { |_x, y| y > 1 }, "not even with nothing else left to look at"
    end
  end

  test "goes by the estimate of the state's own level, off the regions and on the frontier" do
    k = PokeAccess::Pathfinder.skey(3, 3, 0)
    up = PokeAccess::Pathfinder.skey(3, 3, 2)
    goal = Pushes::WalkedGoal.new(Goal.onto(9, 9), { k => 7, up => 2 })
    assert_equal [7, 2, 11], [goal.bound(3, 3, [], 0), goal.bound(3, 3, [], 2), goal.bound(3, 4, [], 2)], "the last as the crow flies"
  end

  test "stays exact while it needs few states: no second look at the regions" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      prices = looked { assert Pushes.route(Goal.onto(6, 1)) }
      assert_equal [0], prices
    end
  end

  test "past its exact states takes the boulders on the way at a push's price" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      with_exact(2) do
        prices = looked { assert Pushes.route(Goal.onto(6, 1)) }
        assert_equal [0, 1 + PokeAccess::Pathfinder::GATE_COST], prices
      end
    end
  end

  test "past its exact states weighs the estimate, for a hard room's route in fewer states" do
    rows = ["#" * 30, "#@" + "." * 27 + "#"] + ["#" + "." * 28 + "#"] * 8 + ["#" * 13 + "." + "#" * 16] + ["#" + "." * 28 + "#"] * 2 + ["#" * 30]
    rocky(rows, [[13, 10], [13, 8], [8, 5], [14, 5], [20, 5]]) do
      PokeAccess::Config.puzzle_assist = true
      goal = Goal.onto(26, 11)
      exact = pops { assert Pushes.route(goal) }
      hurried = with_exact(1) { pops { assert Pushes.route(goal) } }
      assert_operator hurried, :<, exact
    end
  ensure
    PokeAccess::Config.puzzle_assist = false
  end

  test "hurries as well on the goal it has where the regions tell nothing" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      PokeAccess::Config.edge_relax = true
      n = 0
      with_exact(1) do
        wrapping(Pushes, :reweighed, lambda { |*_a| n += 1 }) do
          assert_equal [[RIGHT], 3], Pushes.route(Goal.onto(6, 1)).then { |r, g| [r.to_a, g[:x]] }
        end
      end
      assert_equal 1, n
    end
  ensure
    PokeAccess::Config.edge_relax = false
  end

  test "stays exact all the way for a boulder's goal, whose estimate leaves little to hurry past" do
    rocky(["#########", "#@......#", "#########"], [[3, 1]]) do
      k = key(3, 1)
      goal = Pushes::RockGoal.new(k, 3, 1, [5, 1, 5, 1], Routes::Effects.boulder_index[k])
      n = 0
      with_exact(1) { wrapping(Pushes, :reweighed, lambda { |*_a| n += 1 }) { assert Pushes.route(goal) } }
      assert_equal 0, n
    end
  end

  test "orders the frontier afresh by the goal's estimate at its weight" do
    goal = Object.new
    def goal.bound(x, _y, _moved, lvl); x + lvl; end
    states = { 1 => [9, 0, [], 1], 2 => [1, 0, [], 0], 3 => [3, 0, [], 2] }
    g = { 1 => 0, 2 => 9, 3 => 4 }
    weight = Pushes::WEIGHT
    fresh = Pushes.reweighed([[9, 0, 1], [1, 0, 2], [5, 0, 3]], goal, states, g)
    assert_equal [[4 + 5 * weight, 0, 3], [9 + weight, 0, 2], [10 * weight, 0, 1]].sort_by { |e| e[0] }, fresh
  end

  private

  ICE = 12

  def key(x, y); Routes.pkey(x, y); end

  # The assisted regions, all walked.
  def walked
    walk = Regions.assisted
    walk.status([[0, 0]])
    walk
  end

  # The grid with the player where it has it and a boulder on each of rocks.
  def rocky(rows, rocks)
    $game_map.load_grid(rows)
    rocks.each_with_index { |(x, y), i| boulder(61 + i, x, y) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_ledges
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  def boulder(id, x, y)
    ev = World.touch(:id => id, :name => "Boulder", :x => x, :y => y, :trigger => 0, :sprite => "boulder",
                     :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      !$game_map.blocked?(nx, ny)
    end
    ev
  end

  # The goal to take the boulder on (x, y) into box.
  def rock_goal(x, y, box)
    key = Routes.pkey(x, y)
    Pushes::RockGoal.new(key, x, y, box, Routes::Effects.boulder_index[key])
  end

  # The route to goal, as [the route or nil, the searches made].
  def routed(goal)
    n = 0
    answer = wrapping(Pushes, :search, lambda { |*_a| n += 1 }) { Pushes.route(goal) }
    [answer, n]
  end

  # The block's value with the regions out of the search, as edge_relax has it.
  def without_walk
    PokeAccess::Config.edge_relax = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    PokeAccess::Config.edge_relax = false
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # How many states the block's searches took off their frontiers.
  def pops(&block)
    n = 0
    wrapping(PokeAccess::Pathfinder, :heap_pop, lambda { |*_a| n += 1 }, &block)
    n
  end

  # The tiles the block's searches went on from.
  def expanded(&block)
    tiles = []
    wrapping(Pushes, :moves_from, lambda { |cx, cy, *_a| tiles.push([cx, cy]) }, &block)
    tiles.uniq
  end

  # The prices the block's searches asked the assisted regions the presses left at.
  def looked
    prices = []
    orig = Regions.instance_method(:presses_back)
    Regions.send(:define_method, :presses_back) do |tiles, dear, price|
      prices.push(price)
      orig.bind(self).call(tiles, dear, price)
    end
    yield
    prices
  ensure
    Regions.send(:define_method, :presses_back, orig)
  end

  # Runs the block with singleton method name of mod telling spy of each call; answers the block's value.
  def wrapping(mod, name, spy)
    orig = mod.method(name)
    meta = class << mod; self; end
    meta.send(:define_method, name) do |*args, &blk|
      spy.call(*args)
      orig.call(*args, &blk)
    end
    yield
  ensure
    meta.send(:define_method, name, orig)
  end

  # Runs the block with the search exact for n states.
  def with_exact(n)
    was = Pushes::EXACT
    Pushes.send(:remove_const, :EXACT)
    Pushes.const_set(:EXACT, n)
    yield
  ensure
    Pushes.send(:remove_const, :EXACT)
    Pushes.const_set(:EXACT, was)
  end

  # Runs the block with the scripts that let a boulder be pulled set to patterns.
  def with_pull_scripts(patterns)
    fx = Routes::Effects
    was = fx.instance_variable_get(:@pull_scripts)
    fx.instance_variable_set(:@pull_scripts, patterns)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    fx.instance_variable_set(:@pull_scripts, was)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end
end
