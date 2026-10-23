# HPA* (Pathfinder.hpa_search) routes to beside a target, blocking or not, as near as A* does; none beyond reach or
# needed beside it; :fallback to plain A* for what its graph cannot route (a sealed target, a ledge, ice, a deadline).
class HpaBlockingTargetTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  # The arena's target tile (hpa_arena), 32 tiles from the player at (1,1).
  TX = 22
  TY = 12
  # Two clusters met only at (9,8)-(10,8). The player's, from (1,8), is walled down x=7 but for its top row, so its
  # way out runs up and round: 20 presses to (8,7) beside the wall tile (9,7), 22 to (9,8); 31 to beside (15,4).
  DETOUR = ['####################',
            '#........#.........#',
            '#......#.#.........#',
            '#......#.#.........#',
            '#......#.#.....#...#',
            '#......#.#.........#',
            '#......#.#.........#',
            '#......#.#.........#',
            '#@.....#...........#',
            '####################']

  test "reaches a blocking target from beside it as A* does, by a route that walks and is as short as A*'s" do
    hpa_fresh_grid(hpa_arena("N"))
    target_at(TX, TY).blocking = true
    route = PF.hpa_search(TX, TY)
    PokeAccess::Config.path_algorithm = :astar
    astar = walk_route(TX, TY)
    got = [[walks?(astar), beside?(astar, TX, TY)],
           [walks?(route), beside?(route, TX, TY), ends_on?(route, TX, TY), route.length]]
    assert_equal [[true, true], [true, true, false, astar.length]], got, "A*'s way, then HPA*'s"
  end

  test "reaches a walkable target it comes to from the left and above by ending beside it" do
    hpa_fresh_grid(hpa_arena("G"))
    route = PF.hpa_search(TX, TY)
    assert_equal [true, true, false, 31], [walks?(route), beside?(route, TX, TY), ends_on?(route, TX, TY), route.length]
  end

  test "falls back to plain A* for a target sealed off" do
    hpa_fresh_grid(['###############',
                    '#@....#.......#',
                    '#.....#.......#',
                    '#.....#.......#',
                    '#.....#.....N.#',
                    '#.....#.......#',
                    '#.....#.......#',
                    '#.....#.......#',
                    '#.....#.......#',
                    '###############'])
    target_at(12, 4).blocking = true
    assert_nil walk_route(12, 4), "no walk gets there"
    assert_equal :fallback, PF.hpa_search(12, 4)
  end

  test "gives no route to a target beyond the route's reach, and one to a target at it" do
    hpa_fresh_grid(hpa_arena("N"))
    target_at(TX, TY).blocking = true
    got = [31, 32].map do |reach|
      PokeAccess::Config.route_reach = reach
      route = PF.hpa_search(TX, TY)
      route && route.length
    end
    assert_equal [nil, 31], got, "with a reach of 31, then 32"
  end

  test "needs no presses for a target right beside the player" do
    hpa_fresh_grid(['#####',
                    '#@N.#',
                    '#####'])
    target_at(2, 1).blocking = true
    assert_equal [], PF.hpa_search(2, 1)
  end

  test "reaches a blocking target at a dead end from its one open side" do
    hpa_fresh_grid(['#####',
                    '#@.N#',
                    '#####'])
    target_at(3, 1).blocking = true
    assert_equal [6], PF.hpa_search(3, 1)
  end

  test "routes a player standing on the map's corner tile like any other" do
    hpa_fresh_grid(['@....',
                    '.....',
                    '....N'])
    target_at(4, 2).blocking = true
    route = PF.hpa_search(4, 2)
    assert_equal [true, true, 5], [walks?(route), beside?(route, 4, 2), route.length]
  end

  test "falls back on a map one tile across or down, and routes on one two tiles across or down" do
    { "one across" => [['@', '.', '.', 'N'], 0, 3, :fallback], "one down" => [['@..N'], 3, 0, :fallback],
      "two across" => [['@.', '..', '.N'], 1, 2, [2]], "two down" => [['@..', '..N'], 2, 1, [2]] }.each do |what, (rows, tx, ty, want)|
      hpa_fresh_grid(rows)
      target_at(tx, ty).blocking = true
      got = PF.hpa_search(tx, ty)
      assert_equal want, got.is_a?(Array) ? [got.length] : got, what
    end
  end

  test "routes to a target in the player's own cluster when no opening leads out of it, wherever the cluster lies" do
    { "the cluster on the left" => [['########'] * 11 + ['#@.....#', '#.....N#', '########'], 6, 12, 5],
      "a cluster off both edges" => [['#' * 20] * 11 + ['###########@....####', '###########....N####', '#' * 20], 15, 12, 4]
    }.each do |what, (rows, tx, ty, presses)|
      hpa_fresh_grid(rows)
      target_at(tx, ty).blocking = true
      route = PF.hpa_search(tx, ty)
      assert_equal [true, true, presses], [walks?(route), beside?(route, tx, ty), route.length], what
    end
  end

  test "reaches a target in the player's own cluster by the way round inside it, as short as it goes" do
    with_tile_world(DETOUR) do
      route = PF.hpa_search(9, 7)
      assert_equal [true, true, 20], [walks?(route), beside?(route, 9, 7), route.length]
    end
  end

  test "joins the player to the way out of its cluster however far round inside it that way goes" do
    with_tile_world(DETOUR) do
      route = PF.hpa_search(15, 4)
      assert_equal [true, true, 31], [walks?(route), beside?(route, 15, 4), route.length]
    end
  end

  test "chosen as the search in a game of plain steps, it gives the planner its way, not A*'s" do
    hpa_fresh_grid(hpa_arena("N"))
    target_at(TX, TY).blocking = true
    without_terrain_rules do
      PokeAccess::Config.path_algorithm = :astar
      astar = walk_route(TX, TY).to_a
      PokeAccess::Config.path_algorithm = :hpa
      hpa = PF.hpa_search(TX, TY)
      refute_equal astar, hpa, "HPA* finds another way than A*"
      assert_equal hpa, walk_route(TX, TY).to_a, "and the planner walks it"
    end
  end

  test "falls back to plain A* where an event now stands in a way its kept graph links" do
    hpa_fresh_grid(['##############################',
                    '#@...........................#',
                    '##############################'])
    graph = PF.hpa_graph
    World.event(:id => 70, :x => 15, :y => 1).blocking = true
    World.next_frame
    assert_same graph, PF.hpa_graph, "the graph is kept"
    assert_equal :fallback, PF.hpa_search(28, 1), "its middle cluster's link no longer walks"
  end

  test "gives up for plain A* once the operation's deadline has passed" do
    rows = ['#' * 42] + (1..40).map { '#' + '.' * 40 + '#' } + ['#' * 42]
    rows[1] = '#@' + '.' * 39 + '#'
    rows[40] = '#' + '.' * 39 + 'N#'
    hpa_fresh_grid(rows)
    target_at(40, 40).blocking = true
    PokeAccess::Config.route_reach = 200
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1
    assert_equal :fallback, PF.hpa_search(40, 40)
  end

  test "reads the clock every sixteen states: past the deadline, a shorter search over a whole graph still answers" do
    hpa_fresh_grid(['#######',
                    '#@...N#',
                    '#######'])
    target_at(5, 1).blocking = true
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1
    assert_equal :fallback, PF.hpa_search(5, 1), "past the deadline nothing of the graph is built"
    hpa_whole_graph
    assert_equal [6, 6, 6], PF.hpa_search(5, 1)
  end

  test "falls back where the only way crosses a ledge or ice, and routes the same corridor with neither" do
    { "a plain floor" => nil, "a ledge" => :ledge, "ice" => :ice }.each do |what, kind|
      hpa_fresh_grid(['#######',
                      '#@...N#',
                      '#######'])
      target_at(5, 1).blocking = true
      $game_map.place_ledge(3, 1, 6) if kind == :ledge
      $game_map.set_terrain(3, 1, 12) if kind == :ice
      PF.invalidate_cache(true)
      assert_equal kind ? :fallback : [6, 6, 6], PF.hpa_search(5, 1), what
    end
  end

  test "on random maps, every target the player can get to gets a route that walks there, near the shortest" do
    bad = []
    checked = 0
    [3, 11, 29].each do |seed|
      with_tile_world(random_rows(seed)) do
        brute = brute_best(:shortest, 0)
        pick = Random.new(seed)
        25.times do
          tx = 1 + pick.rand(24)
          ty = 1 + pick.rand(12)
          next if [tx, ty] == [$game_player.x, $game_player.y]
          best = shortest(brute, tx, ty)
          got = PF.hpa_search(tx, ty)
          checked += 1
          ok = if best.nil?
                 got == :fallback
               else
                 got.is_a?(Array) && walks?(got) && beside?(got, tx, ty) && got.length >= best &&
                   got.length <= best * 1.5 + 4
               end
          bad.push([seed, tx, ty, best, got.is_a?(Array) ? got.length : got]) unless ok
        end
      end
    end
    assert_operator checked, :>, 60, "targets checked"
    assert_equal [], bad.first(5), "a reachable one routed, at least as long as brute force's and near it; the rest fall back"
  end

  test "on random maps whose clusters meet only at single tiles, its way to a wall's side is a shortest one" do
    bad = []
    checked = 0
    [3, 4, 11, 29, 47].each do |seed|
      rows = gated_rows(seed)
      walls = (1..18).to_a.product((1..28).to_a).map { |y, x| [x, y] }.select { |x, y| rows[y][x, 1] == "#" }
      with_tile_world(rows) do
        pick = Random.new(seed)
        [[1, 1], [28, 18]].each do |sx, sy|
          $game_player.x = sx
          $game_player.y = sy
          brute = brute_best(:shortest, 0)
          walls.shuffle(random: pick).first(20).each do |tx, ty|
            best = shortest(brute, tx, ty)
            got = PF.hpa_search(tx, ty)
            checked += 1
            ok = if best.nil?
                   got == :fallback
                 else
                   got.is_a?(Array) && walks?(got) && beside?(got, tx, ty) && got.length == best
                 end
            bad.push([seed, [sx, sy], tx, ty, best, got.is_a?(Array) ? got.length : got]) unless ok
          end
        end
      end
    end
    assert_equal 200, checked, "targets checked"
    assert_equal [], bad.first(5), "every opening a portal, the way through them as short as brute force's"
  end

  test "reaches a walkable target by its side, as short as A*, from below and from the right too" do
    with_tile_world(gated_rows(29)) do
      $game_player.x = 28
      $game_player.y = 18
      brute = brute_best(:shortest, 0)
      targets = [[15, 16], [5, 15]]
      got = targets.map do |tx, ty|
        route = PF.hpa_search(tx, ty)
        [route.length, ends_on?(route, tx, ty)]
      end
      assert_equal targets.map { |tx, ty| [shortest(brute, tx, ty), false] }, got, "presses, and whether it ends on it"
    end
  end

  private

  # The map event standing on (x, y).
  def target_at(x, y)
    $game_map.events.values.find { |e| e.x == x && e.y == y }
  end

  # True when every press of route can be taken from the player's tile, replayed as the guide replays it.
  def walks?(route)
    traced($game_player.x, $game_player.y, 0, route).length == route.length
  end

  # The tile route ends on from the player's.
  def end_of(route)
    last = traced($game_player.x, $game_player.y, 0, route).last
    last ? [last.x, last.y] : [$game_player.x, $game_player.y]
  end

  # True when route ends on a tile (tx, ty) is acted on from.
  def beside?(route, tx, ty)
    PF.reach_tiles(tx, ty).include?(end_of(route))
  end

  # True when route ends on (tx, ty) itself.
  def ends_on?(route, tx, ty)
    end_of(route) == [tx, ty]
  end

  # The fewest presses to a tile (tx, ty) is acted on from, from brute force's table (brute_best); nil for none.
  def shortest(brute, tx, ty)
    PF.reach_tiles(tx, ty).map { |t| brute[t] && brute[t][0] }.compact.min
  end

  # A walled 26x14 map with a wall on about one tile in four, the player at (1,1).
  def random_rows(seed)
    rnd = Random.new(seed)
    rows = (0...14).map do |y|
      (0...26).map { |x| (x == 0 || y == 0 || x == 25 || y == 13) ? "#" : (rnd.rand(4) == 0 ? "#" : ".") }.join
    end
    rows[1][1, 1] = "@"
    rows
  end

  # A walled 30x20 map of six clusters, a wall on about one tile in five, its clusters walled apart (at x=10, x=20 and
  # y=10) but for three single tiles in each wall, none beside another; the player at (1,1), (28,18) left open.
  def gated_rows(seed)
    rnd = Random.new(seed)
    rows = (0...20).map do |y|
      (0...30).map { |x| (x == 0 || y == 0 || x == 29 || y == 19) ? "#" : (rnd.rand(5) == 0 ? "#" : ".") }
    end
    [10, 20].each do |x|
      gaps = ([1, 3, 5, 7, 13, 15, 17].shuffle(random: rnd)).first(3)
      (1..18).each { |y| rows[y][x] = gaps.include?(y) ? "." : "#" }
    end
    gaps = ([2, 4, 6, 13, 15, 17, 23, 25, 27].shuffle(random: rnd)).first(3)
    (1..28).each { |x| rows[10][x] = gaps.include?(x) ? "." : "#" }
    rows[1][1] = "@"
    rows[18][28] = "."
    rows.map { |r| r.join }
  end
end
