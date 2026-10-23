# The HPA* graph (Pathfinder.hpa_graph): portal pairs mid-opening between its 10-tile clusters, linked across at one
# press and within a cluster at the presses between; built a piece at a time within a question's budget, kept per map
# and vehicle with only the clusters a change touches built again, and never changed by a search.
class HpaCacheReadonlyTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  ST = PokeAccess::Routes::PKEY_STRIDE
  C = PokeAccess::Pathfinder::HPA_CLUSTER
  # Four clusters: a wall at x=10 open at y=2..4 above and at y=10 below, and a wall at y=9 open at x=3 on the left and
  # at x=14..16 on the right.
  PORTALS = ['####################',
             '#@........#........#',
             '#..................#',
             '#..................#',
             '#..................#',
             '#.........#........#',
             '#.........#........#',
             '#.........#........#',
             '#.........#........#',
             '###.##########...###',
             '#..................#',
             '####################']
  # Four clusters walled apart but for a gap at x=10 over y=7..12 and one at y=10 over x=7..12, each gap crossing the
  # line between two clusters.
  SPLIT = ['####################',
           '#@........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#..................#',
           '#..................#',
           '#..................#',
           '#######......#######',
           '#..................#',
           '#..................#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '#.........#........#',
           '####################']
  # Two clusters split by a wall at x=10, open at a one-tile door (10,1) and along row 7; a target at (14,1), twelve
  # presses through the door and twenty-four round by row 7.
  DOOR = ['########################',
          '#@............X........#',
          '#.........#............#',
          '#.........#............#',
          '#.........#............#',
          '#.........#............#',
          '#.........#............#',
          '#......................#',
          '########################']
  # Three clusters in a row, one opening between each two.
  ROW = ['##############################',
         '#@...........................#',
         '#............................#',
         '#............................#',
         '#............................#',
         '#............................#',
         '#............................#',
         '#............................#',
         '#............................#',
         '##############################']

  test "puts a portal pair in the middle of each opening between clusters, linked across and within each cluster" do
    with_tile_world(PORTALS) do
      gr = PF.hpa_graph
      adj = { [3, 9] => [[[3, 10], 1], [[9, 3], 12]], [3, 10] => [[[3, 9], 1], [[9, 10], 6]],
              [9, 3] => [[[3, 9], 12], [[10, 3], 1]], [9, 10] => [[[3, 10], 6], [[10, 10], 1]],
              [10, 3] => [[[9, 3], 1], [[15, 9], 11]], [10, 10] => [[[9, 10], 1], [[15, 10], 5]],
              [15, 9] => [[[10, 3], 11], [[15, 10], 1]], [15, 10] => [[[10, 10], 5], [[15, 9], 1]] }
      byc = { [0, 0] => [[3, 9], [9, 3]], [1, 0] => [[10, 3], [15, 9]], [0, 1] => [[3, 10], [9, 10]],
              [1, 1] => [[10, 10], [15, 10]] }
      assert_equal [adj, byc], [links(gr[:adj]), clusters(gr[:byc])]
    end
  end

  test "splits an opening that crosses a cluster's edge, a portal pair in the middle of each side's share" do
    with_tile_world(SPLIT) do
      byc = { [0, 0] => [[8, 9], [9, 8]], [1, 0] => [[10, 8], [11, 9]], [0, 1] => [[8, 10], [9, 11]],
              [1, 1] => [[10, 11], [11, 10]] }
      assert_equal byc, clusters(PF.hpa_graph[:byc])
    end
  end

  test "on random maps, links two portals of a cluster by the fewest presses between them inside it" do
    bad = []
    linked = 0
    [3, 11, 29, 47].each do |seed|
      with_tile_world(random_rows(seed)) do
        gr = hpa_whole_graph
        gr[:byc].each do |cid, keys|
          box = cluster_box(cid, gr)
          keys.combination(2).each do |a, b|
            want = presses_inside(tile(a), tile(b), box)
            got = (gr[:adj][a] || []).select { |k, _cost| k == b }.map { |_k, cost| cost }.min
            linked += 1 if got
            bad.push([seed, tile(a), tile(b), got, want]) unless got == want
          end
        end
      end
    end
    assert_operator linked, :>, 300, "links checked"
    assert_equal [], bad.first(5), "each link as long as the way inside the cluster, and none where it has no way"
  end

  test "searching leaves the cached graph as it was, with no default that writes on a read" do
    hpa_fresh_grid(hpa_arena("."))
    gr = PF.hpa_graph
    before = Marshal.load(Marshal.dump(gr))
    routes = [PF.hpa_search(22, 12), PF.hpa_search(22, 12), PF.hpa_search(5, 5)]
    assert_equal [[31, 31, 7], before, nil, nil],
                 [routes.map { |r| r.length }, gr, gr[:adj].default_proc, gr[:byc].default_proc]
  end

  test "is built once per map and vehicle" do
    hpa_fresh_grid(hpa_arena("."))
    assert_same PF.hpa_graph, PF.hpa_graph
  end

  test "is built anew on another map or on another vehicle" do
    hpa_fresh_grid(hpa_arena("."))
    { "the bike" => lambda { $PokemonGlobal.bicycle = true }, "map 2" => lambda { $game_map.map_id = 2 } }.each do |what, change|
      first = PF.hpa_graph
      change.call
      refute_same first, PF.hpa_graph, what
    end
  end

  test "is built anew once the route caches are dropped by force" do
    hpa_fresh_grid(hpa_arena("."))
    first = PF.hpa_graph
    PF.invalidate_cache(true)
    refute_same first, PF.hpa_graph
  end

  test "by effort a question builds no more than a search's states, the next going on until the graph is whole" do
    rows = random_rows(5)
    hpa_fresh_grid(rows)
    whole = hpa_whole_graph
    want = [links(whole[:adj]), clusters(whole[:byc])]
    hpa_fresh_grid(rows)
    PokeAccess::Config.astar_max = 300
    spent = []
    gr = nil
    while gr.nil? && spent.length < 500
      s0 = PF.hpa_states
      gr = PF.searching { PF.hpa_graph }
      spent.push(PF.hpa_states - s0)
    end
    assert_operator spent.length, :>, 3, "questions the building took"
    assert_operator spent.max, :<=, 300 + C * C * 2 + 1, "the most one question walked: the budget and one local search"
    assert_equal want, [links(gr[:adj]), clusters(gr[:byc])], "the graph as built whole at once"
  end

  test "with HPA* chosen the map frames build the graph until it is whole, a question then walking nothing for it" do
    hpa_fresh_grid(hpa_arena("."))
    PF.hpa_tick
    assert_nil PF.instance_variable_get(:@hpa), "with the regions chosen no frame starts one"
    PokeAccess::Config.path_algorithm = :hpa
    frames = without_terrain_rules { ticks_until_whole }
    s0 = PF.hpa_states
    refute_nil PF.searching { PF.hpa_graph }
    assert_equal [true, 0], [frames < 50, PF.hpa_states - s0], "built by the frames, and nothing left to the question"
  end

  test "with HPA* chosen no frame builds the graph on a map whose ledge hops keep the planner off HPA*" do
    hpa_fresh_grid(hpa_arena("."))
    $game_map.place_ledge(5, 5, 2)
    PokeAccess::Config.path_algorithm = :hpa
    without_terrain_rules { PF.hpa_tick }
    assert_nil PF.instance_variable_get(:@hpa)
  end

  test "a walker that leaves a one-tile door between clusters has the door's portal back at the next question" do
    hpa_fresh_grid(DOOR)
    ev = walker(10, 1)
    before = PF.searching { PF.hpa_search(14, 1) }
    ev.x = 18; ev.y = 6
    World.next_frame
    after = PF.searching { PF.hpa_search(14, 1) }
    assert_equal [24, 12], [before.length, after.length]
    assert_includes clusters(PF.hpa_graph[:byc])[[0, 0]], [9, 1], "the door's portal"
  end

  test "a change inside one cluster builds that cluster again and leaves the others' links as they were" do
    { "a walker's step" => lambda { |ev| ev.x = 4; World.next_frame },
      "a tile turned to ice" => lambda { |_ev| $game_map.set_terrain(3, 4, 12) } }.each do |what, change|
      hpa_fresh_grid(ROW)
      ev = walker(3, 4)
      gr = PF.searching { PF.hpa_graph }
      kept = gr[:adj].dup
      change.call(ev)
      s0 = PF.hpa_states
      again = PF.searching { PF.hpa_graph }
      same = kept.keys.select { |k| again[:adj][k].equal?(kept[k]) }.map { |k| tile(k)[0] / C }.uniq.sort
      assert_equal [gr, [1, 2]], [again, same], "#{what}: the graph kept, and the links of clusters 1 and 2"
      assert_operator PF.hpa_states - s0, :<, C * C, what
    end
  end

  test "a tile changed beside a built cluster, in one not built yet, builds the built one again as a fresh map would" do
    hpa_fresh_grid(ROW)
    PF.searching do
      gr = PF.hpa_current
      PF.hpa_step(gr) until gr[:tiles].key?(0)
    end
    $game_map.place_ledge(10, 4, 2)
    built = hpa_whole_graph
    hpa_fresh_grid(ROW)
    $game_map.place_ledge(10, 4, 2)
    fresh = hpa_whole_graph
    assert_equal [links(fresh[:adj]), clusters(fresh[:byc])], [links(built[:adj]), clusters(built[:byc])],
                 "the step from (9,4) shut splits the opening between clusters 0 and 1"
  end

  test "there is one for a map two tiles across or down, and none for one under that" do
    { "one across" => [['@', '.', '.'], nil], "one down" => [['@..'], nil],
      "two across" => [['@.', '..', '..'], [2, 3]], "two down" => [['@..', '...'], [3, 2]] }.each do |what, (rows, want)|
      hpa_fresh_grid(rows)
      gr = PF.hpa_graph
      got = gr && [gr[:w], gr[:h]]
      want.nil? ? assert_nil(got, what) : assert_equal(want, got, what)
    end
  end

  private

  # Runs map frames' building (Pathfinder.hpa_tick) until the graph is whole, 50 at most; the frames run.
  def ticks_until_whole
    n = 0
    until n >= 50 || ((gr = PF.instance_variable_get(:@hpa)) && PF.hpa_ready?(gr))
      PF.hpa_tick
      World.next_frame
      n += 1
    end
    n
  end

  # A character that walks about by itself on (x, y), in the way, the world a frame on; the event.
  def walker(x, y)
    ev = TestGameEvent.new(:id => 40, :x => x, :y => y, :pages => [TestPage.new(:move_type => 1, :sprite => "npc")])
    ev.blocking = true
    $game_map.events[40] = ev
    World.next_frame
    ev
  end

  # A graph's adjacency as { [x, y] => [[[x, y], presses], ...] }, each list sorted.
  def links(adj)
    out = {}
    adj.each { |k, edges| out[tile(k)] = edges.map { |nk, cost| [tile(nk), cost] }.sort }
    out
  end

  # A graph's cluster index as { [cluster column, cluster row] => [[x, y], ...] }, each list sorted.
  def clusters(byc)
    out = {}
    byc.each { |cid, keys| out[[cid / ST, cid % ST]] = keys.map { |k| tile(k) }.sort }
    out
  end

  # The tile a packed key stands for.
  def tile(k)
    [k / ST, k % ST]
  end

  # The tiles a cluster of the graph spans, as [x0, y0, x1, y1].
  def cluster_box(cid, gr)
    cx = (cid / ST) * C
    cy = (cid % ST) * C
    [cx, cy, [cx + C - 1, gr[:w] - 1].min, [cy + C - 1, gr[:h] - 1].min]
  end

  # The fewest presses from tile a to tile b by steps that stay inside box, by breadth-first search; nil for no way.
  def presses_inside(a, b, box)
    dist = { a => 0 }
    queue = [a]
    until queue.empty?
      x, y = queue.shift
      return dist[[x, y]] if [x, y] == b
      PokeAccess::Routes::DIRS.each do |dx, dy, d|
        n = [x + dx, y + dy]
        next if dist.key?(n) || n[0] < box[0] || n[1] < box[1] || n[0] > box[2] || n[1] > box[3]
        next unless PokeAccess::World::Probe.step?(x, y, d)
        dist[n] = dist[[x, y]] + 1
        queue.push(n)
      end
    end
    nil
  end

  # A walled 26x24 map with a wall on about one tile in four, the player at (1,1).
  def random_rows(seed)
    rnd = Random.new(seed)
    rows = (0...24).map do |y|
      (0...26).map { |x| (x == 0 || y == 0 || x == 25 || y == 23) ? "#" : (rnd.rand(4) == 0 ? "#" : ".") }.join
    end
    rows[1][1, 1] = "@"
    rows
  end
end
