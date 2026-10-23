# Routes::Planner: the kind of plan a target gets and what it reports, a plan kept while nothing it depends on changes
# (the last 16, each the caller's own), doorways, the searches the regions spare, and the walkers it goes through.
class PlannerTest < PokeAccessTest
  Planner = PokeAccess::Routes::Planner
  Pathfinder = PokeAccess::Pathfinder
  Config = PokeAccess::Config
  # A walled room two rows high with the player at its top left.
  ROOM = ["########",
          "#@.....#",
          "#......#",
          "########"].freeze
  # A corridor of five floor tiles with the player at its left end.
  CORRIDOR = ["#######",
              "#@....#",
              "#######"].freeze
  # A corridor from the player to (27,1), a pocket at (29,1) walled off from it and a tile (1,3) walled off from both.
  POCKETS = ["#" * 31,
             "#@" + "." * 26 + "#.#",
             "#" * 31,
             "#.#" + "#" * 28].freeze
  # A corridor whose only way down to (1,3) passes (7,2).
  NARROW = ["#########",
            "#@......#",
            "#######.#",
            "#.......#",
            "#########"].freeze
  # A shore three tiles from the player, two tiles of water, and land beyond.
  STRAIT = ["#########",
            "#@..~~..#",
            "#########"].freeze
  # A setting each search reads, and another value for it.
  SETTINGS = { :route_style => :straightest, :path_algorithm => :astar, :edge_relax => true, :route_reach => 64,
               :route_limit => :none, :astar_max => 1000, :puzzle_assist => true, :astar_weight => :w300,
               :hpa_cluster => 6 }.freeze

  test "asked again from the same tile, it searches nothing and hands out the same plan" do
    room
    counting_walks do |n|
      first = Planner.plan(6, 2)
      again = Planner.plan(6, 2)
      assert_equal [:walk, 5], [first.kind, first.route.length], "a plan on foot"
      assert_equal [first.route, 1], [again.route, n[0]], "the same route, one search"
    end
  end

  test "from another tile it searches anew, and back on the first the plan made there stands" do
    room
    counting_walks do |n|
      Planner.plan(6, 2)
      $game_player.x = 2
      Planner.plan(6, 2)
      assert_equal 2, n[0], "from (2, 1)"
      $game_player.x = 1
      Planner.plan(6, 2)
      assert_equal 2, n[0], "back on (1, 1)"
    end
  end

  test "a setting the searches read, once changed, has the plan made afresh" do
    room
    SETTINGS.each do |key, value|
      Planner.forget
      counting_walks do |n|
        Planner.plan(6, 2)
        was = Config.send(key)
        Config.send("#{key}=", value)
        Planner.plan(6, 2)
        Config.send("#{key}=", was)
        assert_equal 2, n[0], "#{key} set to #{value.inspect}"
      end
    end
  end

  test "an event come or gone since the plan was made has it made afresh, and nothing changed keeps it" do
    {
      "an event come" => lambda { World.touch(:id => 70, :x => 3, :y => 2, :list => [World.move_player([2])]) },
      "an event gone" => lambda do
        $game_map.events.delete(1)
        World.next_frame
      end
    }.each do |what, change|
      $game_map.load_grid(["########",
                           "#@...N.#",
                           "#......#",
                           "########"])
      Pathfinder.invalidate_cache(true)
      counting_walks do |n|
        counts = []
        [nil, nil, change].each do |c|
          c.call if c
          Planner.plan(6, 2)
          counts.push(n[0])
        end
        assert_equal [1, 1, 2], counts, "#{what}: searched, kept, searched again"
      end
    end
  end

  test "new tiles drop every plan" do
    room
    counting_walks do |n|
      Planner.plan(6, 2)
      Planner.plan(5, 1)
      PokeAccess::World::Epoch.touch(:tiles)
      Planner.plan(6, 2)
      Planner.plan(5, 1)
      assert_equal 4, n[0]
    end
  end

  test "tiles changed unannounced are found out at the next frame, and the plan made afresh" do
    room
    counting_walks do |n|
      Planner.plan(6, 2)
      $game_map.instance_variable_get(:@terrain)[[3, 2]] = 12
      World.next_frame
      Planner.plan(6, 2)
      assert_equal 2, n[0]
    end
  end

  test "the route a plan hands out is the caller's own" do
    corridor
    mine = Planner.plan(5, 1)
    mine.route.shift
    again = Planner.plan(5, 1)
    assert_equal [6, 6, 6], again.route, "consuming it as the guide does leaves the kept plan whole"
    refute_same mine.route, again.route, "each caller gets a route of its own"
  end

  test "keeps the last 16 plans, dropping the oldest" do
    $game_map.load_grid(["#####################",
                         "#@..................#",
                         "#####################"])
    Pathfinder.invalidate_cache(true)
    counting_walks do |n|
      (3..19).each { |x| Planner.plan(x, 1) }
      counts = [n[0]]
      [19, 4, 3].each do |x|
        Planner.plan(x, 1)
        counts.push(n[0])
      end
      assert_equal [17, 17, 17, 18], counts, "17 searched; the latest and the 16th back kept; the 17th back dropped"
    end
  end

  test "tells the tiles a one-sided doorway is walked into from, and none for any other target" do
    doorway_room
    assert_equal [[[3, 3], [4, 2]], nil], [Planner.doorways(3, 2).sort, Planner.doorways(2, 2)]
  end

  test "a doorway walked into from two sides is reached on the nearer" do
    doorway_room
    { [5, 2] => [4, 2], [2, 4] => [3, 3] }.each do |(x, y), side|
      $game_player.x = x
      $game_player.y = y
      assert_equal side, traced(x, y, 0, Planner.plan(3, 2).route).last.tile, "from (#{x}, #{y})"
    end
  end

  test "a target beyond reach is out of range, with nothing more looked for" do
    room
    Config.route_reach = 3
    plan, assisted = counting(Planner, :assisted) { Planner.plan(4, 2) }
    assert_equal [:far, 1], [plan.kind, plan.stats[:cuts]], "three tiles right and one down"
    assert_equal 0, assisted, "no assisted route looked for"
  end

  test "a target just within reach is walked to" do
    corridor
    Config.route_reach = 3
    plan = Planner.plan(4, 1)
    assert_equal [:walk, [6, 6]], [plan.kind, plan.route], "three tiles off"
  end

  test "a target just within reach that no way gets to has no plan, not a cut one" do
    $game_map.load_grid(["##########",
                         "#....@.#.#",
                         "##########"])
    Pathfinder.invalidate_cache(true)
    Config.route_reach = 3
    assert_equal :none, Planner.plan(8, 1).kind
  end

  test "under a deadline a plan beyond reach is kept, the distance having decided it" do
    corridor
    Config.route_reach = 3
    Config.route_limit = :time
    counting_walks do |n|
      2.times { Planner.plan(5, 1) }
      assert_equal 1, n[0]
    end
  end

  test "by effort a plan beyond reach is kept" do
    corridor
    Config.route_reach = 3
    counting_walks do |n|
      2.times { Planner.plan(5, 1) }
      assert_equal 1, n[0]
    end
  end

  test "a target beside the player needs no steps" do
    corridor
    plan = Planner.plan(2, 1)
    assert_equal [:walk, []], [plan.kind, plan.route]
  end

  test "walks to act on a target unless asked to stand on it" do
    corridor
    assert_equal [[6, 6, 6], [6, 6, 6, 6]], [Planner.walk(5, 1).route, Planner.walk(5, 1, true).route]
  end

  test "a target walking cannot get to but an assisted step can is planned up to that step" do
    with_tile_world(['#######',
                     '#@.gg.#',
                     '#######']) do
      $PokemonGlobal.bicycle = true
      plan = Planner.plan(5, 1)
      off = { :kind => :dismount, :face => 6, :x => 2, :y => 1 }
      assert_equal [:assisted, [6], off], [plan.kind, plan.route, plan.gate], "off the bike before the grass"
    end
  end

  test "looks for an assisted route only when something could assist, such as a registered assisted step" do
    corridor
    searches = lambda { counting(PokeAccess::Routes::Search, :route) { Planner.assisted(5, 1) } }
    got = [with_assist_sources { searches.call }, with_assist_sources(88) { searches.call }]
    assert_equal [[nil, 0], [nil, 1]], got,
                 "nothing on the map nor registered; then an assisted step registered, though it owns no tile here"
  end

  test "a target only water reaches is planned onto the shore, with the way to push off" do
    with_tile_world(STRAIT) do
      plan = Planner.plan(7, 1)
      assert_equal [:surf, [6, 6], nil, 6], [plan.kind, plan.route, plan.gate, plan.launch]
    end
  end

  test "someone joining or leaving the player has the way by water planned afresh, from the same tile" do
    with_tile_world(STRAIT) do
      along = true
      $game_player.define_singleton_method(:can_ride_vehicle_with_follower?) { !along }
      kinds = [Planner.plan(7, 1).kind]
      along = false
      kinds.push(Planner.plan(7, 1).kind)
      along = true
      kinds.push(Planner.plan(7, 1).kind)
      assert_equal [:company, :surf, :company], kinds, "someone along, then gone, then back"
    end
  end

  test "a plan goes on to the way by water past an assisted search or a controls route that raises" do
    Config.puzzle_assist = true
    {
      "the assisted search" => [PokeAccess::Routes::Regions, :assisted],
      "the controls route" => [PokeAccess::Routes::Controls, :route]
    }.each do |what, (mod, name)|
      Planner.forget
      with_tile_world(STRAIT) do
        plan, calls = with_assist_sources(88) { raising(mod, name) { Planner.plan(7, 1) } }
        assert_equal [:surf, [6, 6], 1], [plan.kind, plan.route, calls], what
      end
    end
  end

  test "a plan whose way by water raises has none" do
    with_tile_world(STRAIT) do
      plan, calls = raising(Pathfinder, :surf_plan) { Planner.plan(7, 1) }
      assert_equal [:none, 1], [plan.kind, calls]
    end
  end

  test "a plan the budget runs out on before telling is cut" do
    $game_map.load_grid(["##############################",
                         "#@...........................#",
                         "#............................#",
                         "#............................#",
                         "##############################"])
    Pathfinder.invalidate_cache(true)
    Config.route_limit = :time
    Config.route_budget_ms = -1
    plan = Planner.plan(28, 3)
    assert_equal :cut, plan.kind
    assert_operator plan.stats[:cuts], :>, 0, "the searches it stopped short"
  end

  test "a target only water reaches, whose way by water the deadline stops short, is cut" do
    with_tile_world(["#" * 30, "#@..~~" + "." * 23 + "#", "#" * 30]) do
      Config.route_limit = :time
      Config.route_budget_ms = -1
      plan = Planner.plan(28, 1)
      assert_equal [:cut, 1], [plan.kind, plan.stats[:cuts]], "no way on foot, and the search by water stopped"
    end
  end

  test "a target the regions rule out after a search was cut short has no plan, not a cut one" do
    hpa_fresh_grid(POCKETS)
    Config.astar_max = 3
    plan = Planner.plan(29, 1)
    assert_equal [:none, 1], [plan.kind, plan.stats[:cuts]], "its first search stopped short, then the regions told"
  end

  test "a plan reports the search that answered on foot, its states, its cuts, whether it was left unsettled " \
       "and its time to a tenth of a ms" do
    corridor
    plan = with_plan_taking(0.0123) { Planner.plan(5, 1) }
    assert_equal({ :algo => :astar, :expanded => 4, :cuts => 0, :unsettled => false, :ms => 12.3 }, plan.stats,
                 "A* to (4, 1), beside the target, through four states")
  end

  test "a target the regions cannot tell yet, once the search finds it, is answered without walking them on" do
    hpa_fresh_grid(POCKETS)
    w = Planner.walk(20, 1, true)
    assert_equal [:found, :astar], [w.status, w.algo]
    assert_equal false, PokeAccess::Routes::Regions.foot.done?, "the regions are not walked for it"
  end

  test "a target the regions cannot tell yet is searched, and as that search fails they are walked on" do
    hpa_fresh_grid(POCKETS)
    w = Planner.walk(29, 1)
    assert_equal [:exhausted, :astar], [w.status, w.algo]
    assert_equal true, PokeAccess::Routes::Regions.foot.done?, "the regions walked"
  end

  test "a target the walked regions tell cannot be got to is not searched, and has no plan" do
    hpa_fresh_grid(POCKETS)
    Planner.walk(29, 1)
    got = counting(PokeAccess::Routes::Search, :route) do
      w = Planner.walk(1, 3)
      [w.status, w.algo, w.expanded, Planner.plan(1, 3).kind]
    end
    assert_equal [[:exhausted, :regions, 0, :none], 0], got, "told by the regions, with no search on foot or assisted"
  end

  test "with edge_relax on, a target the regions rule out is searched still" do
    hpa_fresh_grid(POCKETS)
    Planner.walk(29, 1)
    Config.edge_relax = true
    w = Planner.walk(29, 1)
    assert_equal [:exhausted, :astar], [w.status, w.algo]
  end

  test "a search cut short for a target the regions then rule out answers no way, not a cut" do
    $game_map.load_grid(["############",
                         "#@........##",
                         "#.........#.",
                         "############"])
    Pathfinder.invalidate_cache(true)
    Config.path_algorithm = :astar
    Config.astar_max = 3
    with_flood_nodes(3) do
      w = Planner.walk(11, 2)
      assert_equal [:exhausted, :astar], [w.status, w.algo]
    end
  end

  test "a walker in the only way is gone through by any algorithm, lent through only while searching" do
    [:regions, :astar, :jps].each do |algo|
      walker = narrow_with_walker
      Config.path_algorithm = algo
      w = Planner.walk(1, 3, true)
      assert_equal [:found, 14], [w.status, w.route && w.route.length], "#{algo}: the route goes through the walker"
      assert_nil walker.through, "#{algo}: the walker is as solid as before"
    end
  end

  test "a walker's route reports the states of the search without it and the one through it" do
    walker = narrow_with_walker
    goal = PokeAccess::Routes::Goal.onto(1, 3)
    alone = Pathfinder.searching { Planner.searched(goal, false) }
    through = Pathfinder.searching { PokeAccess::World::Probe.lend_through([walker]) { Planner.searched(goal, false) } }
    narrow_with_walker
    w = Planner.walk(1, 3, true)
    assert_equal [:exhausted, :found], [alone.status, through.status], "the two searches"
    assert_equal [7, 15, 22], [alone.expanded, through.expanded, w.expanded], "without it, through it, and their sum"
  end

  test "a walker lent through whose way the budget cuts short leaves the first search's answer" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "###.....#",
                    "#.......#",
                    "#########"])
    walker(3, 1)
    Config.path_algorithm = :astar
    Config.astar_max = 3
    with_flood_nodes(3) do
      w = Planner.walk(1, 3, true)
      assert_equal [:exhausted, 2], [w.status, w.expanded], "the two tiles before the walker"
    end
  end

  test "while the regions cannot tell yet, a search that ran out of ways is not tried again through a walker" do
    hpa_fresh_grid(["############",
                    "#@.........#",
                    "###........#",
                    "###........#",
                    "###........#",
                    "############"])
    walker(3, 1)
    Config.route_limit = :time
    Config.route_budget_ms = -1
    w, searches = counting(PokeAccess::Routes::Search, :route) { Planner.walk(6, 3, true) }
    assert_equal [:exhausted, nil, 1], [w.status, w.route, searches],
                 "one search; the deadline stopped the regions short of the target"
  end

  test "one standing still in the only way is a wall" do
    hpa_fresh_grid(NARROW)
    still = TestGameEvent.new(:id => 41, :x => 7, :y => 2, :pages => [TestPage.new(:sprite => "npc")])
    still.blocking = true
    $game_map.events[41] = still
    World.next_frame
    assert_equal :none, Planner.plan(1, 3, true).kind
  end

  test "with a way around a walker, the route goes around it" do
    hpa_fresh_grid(["#########",
                    "#@......#",
                    "#.#####.#",
                    "#.......#",
                    "#########"])
    walker(7, 2)
    w = Planner.walk(7, 3, true)
    assert_equal [:found, [2, 2]], [w.status, w.route && w.route[0, 2]]
  end

  test "with HPA* chosen, the way through a walker is the engine's search, never HPA*'s, whose graph is kept" do
    narrow_with_walker
    Config.path_algorithm = :hpa
    w = without_terrain_rules { Planner.walk(1, 3) }
    assert_equal [:found, :astar, 13], [w.status, w.algo, w.route && w.route.length], "acting on (1, 3) from beside it"
  end

  test "HPA* answers a target acted on, when chosen, on a map whose moves are all plain steps" do
    [
      ["chosen, a target acted on", :hpa, false, false, false, :hpa],
      ["A* chosen", :astar, false, false, false, :astar],
      ["a spot to stand on", :hpa, true, false, false, :astar],
      ["a terrain rule registered", :hpa, false, true, false, :astar],
      ["a ledge to hop", :hpa, false, false, true, :astar]
    ].each do |what, chosen, onto, rule, ledge, want|
      Config.path_algorithm = chosen
      $game_map.clear_ledges
      corridor
      $game_map.place_ledge(3, 1, 6) if ledge
      w = without_terrain_rules do
        PokeAccess::Routes::Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil } if rule
        Planner.walk(5, 1, onto)
      end
      assert_equal [:found, want], [w.status, w.algo], what
    end
  end

  test "by effort, building HPA*'s graph may take half the question's states" do
    Config.route_limit = :effort
    Config.astar_max = 1000
    assert_equal [500, nil], Pathfinder.hpa_allowance
  end

  test "by effort, the search HPA* falls back to takes the states the question has left, half at the least" do
    hpa_fresh_grid(hpa_arena("."))
    Config.path_algorithm = :hpa
    Config.route_limit = :effort
    Config.astar_max = 400
    caps = []
    search = PokeAccess::Routes::Search
    real = search.method(:route)
    search.define_singleton_method(:route) { |*a| caps.push(Pathfinder.limits.key); real.call(*a) }
    without_terrain_rules { Planner.walk(22, 12) }
    assert_equal [[:effort, 200]], caps
  ensure
    search.define_singleton_method(:route, real) if real
  end

  test "by effort, the search HPA* falls back to takes the question's states less those HPA* spent" do
    hpa_fresh_grid(hpa_arena("."))
    Config.path_algorithm = :hpa
    Config.route_limit = :effort
    Config.astar_max = 400
    caps = []
    search = PokeAccess::Routes::Search
    real = search.method(:route)
    hpa = Pathfinder.method(:hpa_search)
    Pathfinder.define_singleton_method(:hpa_search) { |*_a| @hpa_states += 120; nil }
    search.define_singleton_method(:route) { |*a| caps.push(Pathfinder.limits.key); real.call(*a) }
    without_terrain_rules { Planner.walk(22, 12) }
    assert_equal [[:effort, 280]], caps
  ensure
    search.define_singleton_method(:route, real) if real
    Pathfinder.define_singleton_method(:hpa_search, hpa) if hpa
  end

  test "HPA* finding no way leaves the target to the search" do
    $game_map.load_grid(["########",
                         "#@...#.#",
                         "########"])
    Pathfinder.invalidate_cache(true)
    Config.path_algorithm = :hpa
    w = without_terrain_rules { Planner.walk(6, 1) }
    assert_equal [:exhausted, :astar], [w.status, w.algo]
  end

  private

  # Runs the block counting the planner's walks (each a search on foot), the count passed in to read along the way.
  def counting_walks
    n = [0]
    real = Planner.method(:walk)
    Planner.define_singleton_method(:walk) { |*a| n[0] += 1; real.call(*a) }
    yield n
  ensure
    Planner.define_singleton_method(:walk, real)
  end

  # [the block's value, how many times it called mod.name], the method put back afterwards.
  def counting(mod, name)
    n = 0
    real = mod.method(name)
    mod.define_singleton_method(name) { |*a| n += 1; real.call(*a) }
    [yield, n]
  ensure
    mod.define_singleton_method(name, real)
  end

  # [the block's value, how many times it called mod.name], which raises each time; the method put back afterwards.
  def raising(mod, name)
    n = 0
    real = mod.method(name)
    mod.define_singleton_method(name) do |*_a|
      n += 1
      raise ArgumentError, "#{name} broke"
    end
    [yield, n]
  ensure
    mod.define_singleton_method(name, real)
  end

  # The block's value as in a game whose only registered assisted steps are one per terrain number in tags (none
  # without them), each owning the tiles in front of that number and answering no step; the loaded ones put back.
  def with_assist_sources(*tags)
    moves = PokeAccess::Routes::Moves
    saved = moves.instance_variable_get(:@assist_sources)
    moves.instance_variable_set(:@assist_sources, [])
    tags.each { |t| moves.assist_source(:front_tags => [t]) { |_x, _y, _dir, _lvl| nil } }
    moves.forget_map
    yield
  ensure
    moves.instance_variable_set(:@assist_sources, saved)
    moves.forget_map
  end

  # The block's value with the clock still but for seconds passing during the planner's walk.
  def with_plan_taking(seconds)
    now = [100.0]
    clock = PokeAccess.method(:clock)
    walk = Planner.method(:walk)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    Planner.define_singleton_method(:walk) { |*a| now[0] += seconds; walk.call(*a) }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, clock)
    Planner.define_singleton_method(:walk, walk)
  end

  # Runs the block with the flood's budget per round set to nodes states.
  def with_flood_nodes(nodes)
    flood = PokeAccess::Routes::Flood
    was = flood::NODES
    flood.send(:remove_const, :NODES)
    flood.const_set(:NODES, nodes)
    yield
  ensure
    flood.send(:remove_const, :NODES)
    flood.const_set(:NODES, was)
  end

  # Loads ROOM, the caches fresh.
  def room
    $game_map.load_grid(ROOM)
    Pathfinder.invalidate_cache(true)
  end

  # Loads CORRIDOR, the caches fresh.
  def corridor
    $game_map.load_grid(CORRIDOR)
    Pathfinder.invalidate_cache(true)
  end

  # A room with a doorway at (3,2) that leaves the map walked into upward or leftward.
  def doorway_room
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#.....#",
                         "#.....#",
                         "#.....#",
                         "#######"])
    warp = TestCmd.new(201, [0, 55, 1, 1], 1)
    World.touch(:id => 71, :x => 3, :y => 2,
                :list => [World.if_facing(8), warp, World.end_, World.if_facing(4), warp, World.end_])
    Pathfinder.invalidate_cache(true)
  end

  # A character on (x,y) that walks about by itself and blocks the tile it stands on.
  def walker(x, y)
    ev = TestGameEvent.new(:id => 40, :x => x, :y => y, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    ev.blocking = true
    $game_map.events[40] = ev
    World.next_frame
    ev
  end

  # NARROW with a walker on its only way down, the caches fresh; the walker.
  def narrow_with_walker
    hpa_fresh_grid(NARROW)
    walker(7, 2)
  end
end
