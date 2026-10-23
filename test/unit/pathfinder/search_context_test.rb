# The pathfinder's frame: one SearchContext per operation, shared by the searches nested in it with one budget and
# moves mode, gone when the outermost ends; what an event's end drops of the route caches, and a search state's key.
class SearchContextTest < PokeAccessTest
  PF = PokeAccess::Pathfinder
  Routes = PokeAccess::Routes
  Moves = PokeAccess::Routes::Moves
  ROOM = ["#######", "#@....#", "#.....#", "#######"]

  test "no operation is open between searches" do
    assert_nil PF.context
  end

  test "a search nested in another runs in the outer one's context, a level deeper" do
    seen = PF.searching do
      outer = PF.context
      [outer, outer.depth, PF.searching { [PF.context, PF.context.depth] }]
    end
    assert_same seen[0], seen[2][0]
    assert_equal [1, 2], [seen[1], seen[2][1]]
  end

  test "once a nested search ends, the operation is back at its own level" do
    depths = PF.searching { [PF.searching { PF.context.depth }, PF.context.depth, PF.searching { PF.context.depth }] }
    assert_equal [2, 1, 2], depths
  end

  test "the context is gone once the outermost search ends" do
    PF.searching { PF.searching { nil } }
    assert_nil PF.context
  end

  test "each operation opens a context of its own" do
    refute_same PF.searching { PF.context }, PF.searching { PF.context }
  end

  test "a search inside an assisted operation runs in it, assisted, and the operation closes with it" do
    assert_equal [true, 1], PF.with_gates_open { PF.searching { [PF.context.assisting, PF.context.depth] } }
    assert_nil PF.context
  end

  test "the assisted part of an operation leaves the rest of it unassisted" do
    assert_nil PF.searching { PF.with_gates_open { nil }; PF.context.assisting }
  end

  test "a search that raises still closes its operation, and the error reaches the caller" do
    assert_raises(RuntimeError) { PF.with_limits { PF.searching { raise "boom" } } }
    assert_nil PF.context
  end

  test "after a search raised, the next one routes as before" do
    hpa_fresh_grid(ROOM)
    assert_raises(RuntimeError) { PF.searching { raise "boom" } }
    assert_equal [6, 6, 6, 6], walk_route(5, 2)
  end

  test "the searches of one operation share its budget, and outside any each question gets a fresh one" do
    inner = nil
    outer = PF.with_limits { |l| inner = PF.searching { |m| m }; l }
    assert_same outer, inner
    refute_same PF.limits, PF.limits
  end

  test "the budget of the operation in progress is the one its searches get" do
    PF.searching { |l| assert_same l, PF.limits }
  end

  test "the moves mode has ledge hops when asked, the border tiles with relax, and assisted steps when assisted" do
    l = Moves::LEDGE
    r = Moves::RELAX
    { [false, false] => 0, [true, false] => l, [false, true] => r, [true, true] => l | r }.each do |(ledge, relax), mode|
      assert_equal mode, PF.moves_mode(ledge, relax), "outside an operation, ledge #{ledge}, relax #{relax}"
      assert_equal mode, PF.searching { PF.moves_mode(ledge, relax) }, "in a plain one"
      assert_equal mode | Moves::ASSIST, PF.with_gates_open { PF.moves_mode(ledge, relax) }, "in an assisted one"
    end
  end

  test "a route is replayed with ledge hops, and with the border tiles only under edge_relax" do
    PokeAccess::Config.edge_relax = false
    assert_equal Moves::LEDGE, PF.replay_mode
    PokeAccess::Config.edge_relax = true
    assert_equal Moves::LEDGE | Moves::RELAX, PF.replay_mode
  end

  test "a route with no transfers set goes through no rooms and lands nowhere" do
    route = PF::Route.new([6, 6])
    assert_equal [0, []], [route.rooms, route.warps]
    route.rooms = 2
    route.warps = [1]
    assert_equal [2, [1]], [route.rooms, route.warps]
  end

  test "an event's end gives the routes a new event epoch, which holds while nothing ends" do
    before = PF.event_epoch
    assert_equal before, PF.event_epoch, "nothing ended"
    PF.invalidate_cache
    refute_equal before, PF.event_epoch
  end

  test "an event's end ends the lease of what a game's own calls were read as" do
    flags = PokeAccess::World::Flags
    _v, deps = flags.reading { flags.volatile! }
    PF.invalidate_cache
    assert_equal false, flags.current?(deps)
  end

  test "an event's end drops the floods kept" do
    hpa_fresh_grid(ROOM)
    cost = Routes::CostModel.new(:shortest)
    PF.searching { Routes::Flood.for(cost, Moves::LEDGE) }
    PF.invalidate_cache
    assert_nil PF.searching { Routes::Flood.kept(cost, Moves::LEDGE) }
  end

  test "an event's end drops the HPA* graph where the passability is not plain, and keeps it where it is" do
    { false => false, true => true }.each do |plain, kept|
      with_plain(plain) do
        hpa_fresh_grid(ROOM)
        graph = PF.hpa_graph
        PF.invalidate_cache
        assert_equal kept, graph.equal?(PF.hpa_graph), "plain: #{plain}"
      end
    end
  end

  test "with a plain passability an event's end keeps the probe's answers and the regions, a forced one drops them" do
    with_plain(true) do
      hpa_fresh_grid(ROOM)
      foot = Routes::Regions.foot
      PF.invalidate_cache
      assert_same foot, Routes::Regions.foot, "at an event's end"
      PF.invalidate_cache(true)
      refute_same foot, Routes::Regions.foot, "forced"
    end
  end

  test "with a passability that is not plain an event's end drops the probe's answers and the regions" do
    with_plain(false) do
      hpa_fresh_grid(ROOM)
      foot = Routes::Regions.foot
      PF.invalidate_cache
      refute_same foot, Routes::Regions.foot
    end
  end

  test "at an event's end the tiles are compared, and forced the world is read afresh" do
    hpa_fresh_grid(ROOM)
    $game_map.set_terrain(3, 1, 12)
    with_terrain_asks do |asks|
      assert_equal :ice, PokeAccess::World::Terrain.kind(3, 1)
      PF.invalidate_cache
      assert_equal [:ice, 1], [PokeAccess::World::Terrain.kind(3, 1), asks.call], "tiles unchanged, nothing read again"
      $game_map.instance_variable_get(:@terrain)[[3, 1]] = 7
      assert_equal :ice, PokeAccess::World::Terrain.kind(3, 1), "a tile changed under the memo is not seen yet"
      PF.invalidate_cache
      assert_equal [:water, 2], [PokeAccess::World::Terrain.kind(3, 1), asks.call], "until the tiles are compared"
      PF.invalidate_cache(true)
      assert_equal [:water, 3], [PokeAccess::World::Terrain.kind(3, 1), asks.call], "forced, read again"
    end
  end

  test "a search state's key keeps a tile's ground and bridge apart, every height above the ground one" do
    refute_equal PF.skey(3, 4, 0), PF.skey(3, 4, 2), "the ground and the bridge"
    assert_equal [PF.skey(3, 4, 2)] * 2, [PF.skey(3, 4, 1), PF.skey(3, 4, 3)], "any bridge height"
    assert_equal PF.skey(3, 4, 0), PF.skey(3, 4, nil), "no level is the ground"
    refute_equal PF.skey(3, 4, 0), PF.skey(4, 3, 0), "another tile"
  end

  private

  # Runs the block with the game's passability declared plain or not, putting back what it was.
  def with_plain(plain)
    probe = PokeAccess::World::Probe
    was = probe.instance_variable_get(:@plain)
    probe.instance_variable_set(:@plain, plain)
    yield
  ensure
    probe.instance_variable_set(:@plain, was)
  end

  # Runs the block counting the map's terrain questions, which it reads through the lambda it gets.
  def with_terrain_asks
    m = $game_map
    asked = [0]
    tag = Game_Map.instance_method(:terrain_tag)
    m.define_singleton_method(:terrain_tag) { |*a| asked[0] += 1; tag.bind(self).call(*a) }
    yield(lambda { asked[0] })
  ensure
    m.singleton_class.send(:remove_method, :terrain_tag)
  end
end
