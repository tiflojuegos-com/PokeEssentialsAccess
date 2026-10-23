# The opt-in grid searches (path_algorithm :jps and :hpa) through the planner: JPS as short as brute force on random
# grids and mazes, HPA* crossing the 10-tile clusters near the shortest length where every move is a plain step.
class JpsTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Routes = PokeAccess::Routes
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  # Corridor mazes with one shortest way from '@' to act on 'G', and that way.
  MAZES = {
    ["#######", "#@....#", "#.###.#", "#.#...#", "#.#.#.#", "#...#G#", "#######"] => [6, 6, 6, 6, 2, 2, 2],
    ["#########", "#@......#", "#######.#", "#.......#", "#.#####.#", "#.#G....#", "#########"] =>
      [6, 6, 6, 6, 6, 6, 2, 2, 2, 2, 4, 4, 4]
  }
  # The floor tiles beside the target hpa_arena drops at (22, 12): where a route to act on it ends.
  BESIDE_TARGET = [[21, 12], [22, 11]]
  # Seeds of random grids (random_grid); the ledges of 6, 14, 47 and 72 shorten the way to many tiles or open one.
  SEEDS = [5, 6, 13, 14, 47, 72]

  test "through a corridor maze A* and JPS both take its one shortest way" do
    MAZES.each do |rows, route|
      [:astar, :jps].each do |algo|
        PokeAccess::Config.path_algorithm = algo
        hpa_fresh_grid(rows)
        goal = $game_map.events.values.first
        r = Routes::Planner.walk(goal.x, goal.y)
        assert_equal [algo, route], [r.algo, r.route], "#{algo} through #{rows.inspect}"
      end
    end
  end

  test "on random grids, JPS's route onto each tile and to act on it is as short as brute force's and gets there" do
    PokeAccess::Config.path_algorithm = :jps
    bad = []
    checked = 0
    SEEDS.product([true, false]).each do |seed, ledges|
      random_grid(seed, ledges)
      brute = brute_best(:shortest, LEDGE)
      brute.each do |(tx, ty), (presses, _turns)|
        next if [tx, ty] == [$game_player.x, $game_player.y]
        checked += 1
        got = walked(Routes::Goal.onto(tx, ty), true)
        bad.push([seed, ledges, :onto, tx, ty, got, presses]) unless got == [:jps, presses, true]
        near = Routes::Goal.near(tx, ty)
        least = near.tiles.map { |g| brute[g] }.compact.min.first
        next if least == 0
        checked += 1
        got = walked(near, false)
        bad.push([seed, ledges, :near, tx, ty, got, least]) unless got == [:jps, least, true]
      end
    end
    assert_operator checked, :>, 1000, "routes checked"
    assert_equal [], bad.first(5), "each JPS route is brute force's length and ends on a tile of its goal"
  end

  test "on random grids, JPS searches the way to a tile brute force cannot reach and finds none" do
    PokeAccess::Config.path_algorithm = :jps
    found = []
    checked = 0
    SEEDS.each do |seed|
      random_grid(seed, true)
      brute = brute_best(:shortest, LEDGE)
      (0...$game_map.height).each do |ty|
        (0...$game_map.width).each do |tx|
          next if $game_map.cell(tx, ty) == "#" || brute.key?([tx, ty])
          checked += 1
          r = searched_afresh(tx, ty)
          got = [r.status, r.route, r.algo]
          found.push([seed, tx, ty, got]) unless got == [:exhausted, nil, :jps]
        end
      end
    end
    assert_operator checked, :>, 12, "tiles out of reach checked"
    assert_equal [], found.first(5), "JPS ran out of ways with no route"
  end

  test "HPA* crosses the clusters with a route that walks to the target, near the shortest length" do
    hpa_fresh_grid(hpa_arena("G"))
    brute = brute_best(:shortest, LEDGE)
    shortest = BESIDE_TARGET.map { |t| brute[t].first }.min
    route = PF.hpa_search(22, 12)
    steps = traced(1, 1, 0, route)
    assert_equal route.length, steps.length, "every press of it is taken"
    assert_includes BESIDE_TARGET, [steps.last.x, steps.last.y], "and it ends beside the target"
    assert_operator route.length, :>=, shortest, "never shorter than brute force's"
    assert_operator route.length, :<=, shortest * 1.5 + 4, "near brute force's #{shortest}"
  end

  test "chosen, HPA* answers the planner where every move is a plain step" do
    without_terrain_rules do
      hpa_fresh_grid(hpa_arena("G"))
      r = with_algorithm(:hpa) { Routes::Planner.walk(22, 12) }
      steps = traced(1, 1, 0, r.route)
      assert_equal :hpa, r.algo
      assert_equal r.route.length, steps.length, "every press of its route is taken"
      assert_includes BESIDE_TARGET, [steps.last.x, steps.last.y], "and it ends beside the target"
    end
  end

  test "where a touch event moves the player, the planner searches with A* though HPA* is chosen" do
    without_terrain_rules do
      hpa_fresh_grid(hpa_arena("G"))
      World.touch(:id => 60, :x => 5, :y => 5, :list => [TestCmd.new(201, [0, $game_map.map_id, 6, 6])])
      assert_equal :astar, with_algorithm(:hpa) { Routes::Planner.walk(22, 12) }.algo
    end
  end

  test "a way HPA* would have to cross ice on is left to plain A*" do
    hpa_fresh_grid(hpa_arena("G"))
    $game_map.set_terrain(8, 3, 12)
    assert_equal :fallback, PF.hpa_search(22, 12)
  end

  test "HPA* has no route beyond route_reach, and an empty one beside the target" do
    hpa_fresh_grid(hpa_arena("G"))
    PokeAccess::Config.route_reach = 10
    assert_nil PF.hpa_search(22, 12)
    PokeAccess::Config.route_reach = 128
    $game_player.x = 21
    $game_player.y = 12
    assert_equal [], PF.hpa_search(22, 12)
  end

  test "the HPA* graph is kept while the map and the vehicle stand, and built anew when either changes" do
    hpa_fresh_grid(hpa_arena("G"))
    graph = PF.hpa_graph
    assert_same graph, PF.hpa_graph, "asked again"
    $PokemonGlobal.surfing = true
    afloat = PF.hpa_graph
    refute_same graph, afloat, "surfing"
    $PokemonGlobal.surfing = false
    $game_map.map_id = 7
    refute_same afloat, PF.hpa_graph, "on another map"
  end

  private

  # The block's value with path_algorithm set to algo, put back after.
  def with_algorithm(algo)
    was = PokeAccess::Config.path_algorithm
    PokeAccess::Config.path_algorithm = algo
    yield
  ensure
    PokeAccess::Config.path_algorithm = was
  end

  # A random grid of random_route_grid's with no ice or pads, its ledges cleared unless ledges: with plain steps only
  # the searches estimate by the distance to the goal, with ledges by the most a press may cover.
  def random_grid(seed, ledges)
    random_route_grid(seed, 12, 9, false, 0)
    return if ledges
    $game_map.clear_ledges
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # What the planner answers to goal, standing on its target with onto: [the search that answered, its route's
  # presses, whether that route, replayed from the player, ends on one of goal's tiles].
  def walked(goal, onto)
    px = $game_player.x
    py = $game_player.y
    r = Routes::Planner.walk(goal.tx, goal.ty, onto)
    last = r.route && traced(px, py, 0, r.route).last
    [r.algo, r.route && r.route.length, !last.nil? && goal.tiles.include?([last.x, last.y])]
  end

  # The planner's walk onto (tx, ty) with the regions forgotten, so the search answers it, not the regions an
  # earlier walk had walked on.
  def searched_afresh(tx, ty)
    Routes::Regions.forget
    Routes::Planner.walk(tx, ty, true)
  end
end
