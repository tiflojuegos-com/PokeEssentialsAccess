# What watchers see (Routes::Sight): the events a profile declares and, with avoid_trainers, the trainers still to battle.
# Walks keep off the tiles they see while another way exists, through the poses a patrol takes them to; a sight stops
# where they could not walk on unless they walk through or the declaration says so; the guide plans again when what they
# see changes, and the free camera says who sees a tile.
class RouteSightTest < PokeAccessTest
  Sight = PokeAccess::Routes::Sight
  Route = Struct.new(:list, :repeat)
  # Three rows: a walk along the middle one from (1,2) to (7,2) is six presses, round by the top or the bottom eight.
  ROOM = ["#########",
          "#.......#",
          "#@......#",
          "#.......#",
          "#########"]
  # One corridor, a niche below its middle.
  CORRIDOR = ["#######",
              "#@....#",
              "###.###",
              "#######"]

  test "a walk goes round the tiles a declared watcher sees while another way exists" do
    room(ROOM) do
      watcher(4, 3, 8, "Trainer(1)")
      Sight.declare(nil)
      r = PokeAccess::Routes::Planner.walk(7, 2, true)
      tiles = spots(traced(1, 2, 0, r.route.to_a)).map { |x, y, _l| [x, y] }
      assert_equal [:found, 8, false], [r.status, r.route.to_a.length, tiles.include?([4, 2])]
    end
  end

  test "with no way round, the walk crosses the sight" do
    room(CORRIDOR) do
      watcher(3, 2, 8, "Trainer(2)")
      Sight.declare(nil)
      assert_equal [true, [6, 6, 6, 6]], [Sight.seen?(3, 1), walk_route(5, 1, true).to_a]
    end
  end

  test "the sight stops where the watcher could not walk on, unless it walks through or is declared to see through" do
    walled = ROOM.dup
    walled[2] = "#@..#...#"
    [[{}, false, false], [{}, true, true], [{ :through => true }, false, true], [{ :through => false }, true, false]].each do |opts, through, far|
      room(walled) do
        watcher(4, 3, 8, "Trainer(3)").through = through
        Sight.declare([$game_map.map_id], opts)
        assert_equal [true, far], [Sight.seen?(4, 2), Sight.seen?(4, 1)], "#{opts.inspect}, through #{through}"
      end
    end
  end

  test "range, events and maps of a declaration pick who watches and how far" do
    room(ROOM) do
      watcher(1, 1, 6, "Guard")
      watcher(7, 3, 4, "Trainer(4)")
      Sight.declare($game_map.map_id + 1, :events => [1])
      assert_equal({}, Sight.seen, "on another map")
      Sight.declare(nil, :events => /Guard/, :range => 2)
      assert_equal [true, true, false, false], [Sight.seen?(2, 1), Sight.seen?(3, 1), Sight.seen?(4, 1), Sight.seen?(6, 3)]
      assert_raises(ArgumentError) { Sight.declare(nil, :sight => 2) }
    end
  end

  test "a patrol is gone round on every pose of its round, which stays read while it walks it" do
    room(ROOM) do
      ev = watcher(2, 3, 2, "Trainer(1)", :move_type => 3, :move_route => Route.new(codes(3, 3, 2, 2, 0), true))
      Sight.declare(nil)
      seen = [[5, 3], [1, 3], [4, 3], [2, 3], [6, 3]].map { |x, y| Sight.seen?(x, y) }
      stamp = Sight.stamp
      ev.x = 3
      ev.direction = 6
      next_frame
      assert_equal [[true, true, true, true, false], stamp], [seen, Sight.stamp]
      assert_equal [[3, 3], [4, 3]], Sight.seen_now.keys.sort.map { |k| [k / PokeAccess::World::Events::STRIDE, k % PokeAccess::World::Events::STRIDE] },
                   "where it stands and faces now"
    end
  end

  test "a watcher that turns off its poses is read again, and the plan with it" do
    room(ROOM) do
      ev = watcher(4, 3, 8, "Trainer(1)")
      Sight.declare(nil)
      before = [Sight.stamp, PokeAccess::Routes::Planner.key_for(:probe)]
      ev.direction = 2
      next_frame
      assert_equal [false, false, true], [Sight.seen?(4, 2), before[1] == PokeAccess::Routes::Planner.key_for(:probe),
                                          Sight.stamp > before[0]]
    end
  end

  test "moves and turns at random or by the player see every way from where the watcher stands" do
    room(ROOM) do
      watcher(4, 2, 2, "Trainer(1)", :move_type => 3, :move_route => Route.new(codes(25, 0), true))
      watcher(7, 1, 2, "Trainer(1)", :move_type => 1)
      Sight.declare(nil)
      assert_equal [true] * 6, [[4, 1], [3, 2], [5, 2], [4, 3], [6, 1], [7, 2]].map { |x, y| Sight.seen?(x, y) }
    end
  end

  test "a watcher at random is read on where it may roam: a step there changes nothing, one past it reads it again" do
    room(["###########", "#.........#", "#@........#", "#.........#", "###########"]) do
      ev = watcher(5, 2, 2, "Trainer(1)", :move_type => 1)
      Sight.declare(nil)
      stamp = Sight.stamp
      ev.x = 6
      next_frame
      inside = Sight.stamp
      ev.x = 8
      next_frame
      assert_equal [stamp, true, true], [inside, Sight.stamp > stamp, Sight.seen?(9, 1)]
    end
  end

  test "a route an event command forces is the watcher's round while it walks it, and forgotten as it ends" do
    room(ROOM) do
      ev = watcher(2, 3, 8, "Trainer(1)")
      ev.instance_variable_set(:@move_route_forcing, true)
      ev.instance_variable_set(:@move_route, Route.new(codes(3, 3, 2, 2, 0), true))
      ev.instance_variable_set(:@move_route_index, 0)
      Sight.declare(nil)
      stamp = Sight.stamp
      far = Sight.seen?(5, 3)
      ev.x = 3
      ev.direction = 6
      next_frame
      walking = Sight.stamp
      ev.instance_variable_set(:@move_route_forcing, false)
      next_frame
      assert_equal [true, stamp, false], [far, walking, Sight.seen?(5, 3)]
    end
  end

  test "before GameData a slide across a tile seen is gone round, the engine checking each tile it passes" do
    room(ROOM) do
      (2..6).each { |x| $game_map.set_terrain(x, 2, 12) }
      watcher(4, 3, 8, "Trainer(1)")
      PokeAccess::Pathfinder.invalidate_cache(true)
      plain = walk_route(7, 2, true).to_a
      Sight.declare(nil)
      r = PokeAccess::Routes::Planner.walk(7, 2, true)
      crossed = PokeAccess::Routes::Planner.crosses?(r.route, Sight.seen, PokeAccess::Routes::Planner.goal_for(7, 2, true))
      assert_equal [[6], :found, false], [plain, r.status, crossed]
    end
  end

  test "no way round the sight is looked for again only once what the watchers see changes" do
    room(CORRIDOR) do
      ev = watcher(3, 2, 8, "Trainer(2)")
      Sight.declare(nil)
      planner = PokeAccess::Routes::Planner
      calls = []
      planner.singleton_class.send(:alias_method, :closed_search_unspied, :closed_search)
      planner.define_singleton_method(:closed_search) { |*a| calls.push(1); closed_search_unspied(*a) }
      2.times { walk_route(5, 1, true) }
      $game_player.x = 2
      walk_route(5, 1, true)
      once = calls.length
      ev.direction = 2
      next_frame
      Sight.stamp
      ev.direction = 8
      next_frame
      walk_route(5, 1, true)
      assert_equal [1, 2], [once, calls.length]
    end
  ensure
    sc = PokeAccess::Routes::Planner.singleton_class
    if sc.method_defined?(:closed_search_unspied)
      sc.send(:alias_method, :closed_search, :closed_search_unspied)
      sc.send(:remove_method, :closed_search_unspied)
    end
  end

  test "a way round cut by its budget is looked for again at the next ask" do
    room(CORRIDOR) do
      watcher(3, 2, 8, "Trainer(2)")
      Sight.declare(nil)
      planner = PokeAccess::Routes::Planner
      calls = []
      planner.singleton_class.send(:alias_method, :closed_search_unspied, :closed_search)
      planner.define_singleton_method(:closed_search) do |*a|
        calls.push(1)
        r = closed_search_unspied(*a)
        PokeAccess::Routes::SearchResult.new(:cut, nil, r.expanded, r.algo)
      end
      2.times { walk_route(5, 1, true) }
      assert_equal 2, calls.length
    end
  ensure
    sc = PokeAccess::Routes::Planner.singleton_class
    if sc.method_defined?(:closed_search_unspied)
      sc.send(:alias_method, :closed_search, :closed_search_unspied)
      sc.send(:remove_method, :closed_search_unspied)
    end
  end

  test "the way round runs on a budget of its own: no cut of the plan's, and the deadline moves on by its time" do
    PokeAccess::Config.route_limit = :time
    PokeAccess::Pathfinder.searching do |limits|
      before = limits.instance_variable_get(:@deadline)
      PokeAccess::Routes::Planner.aside do
        PokeAccess::Pathfinder.limits.cut!
        t = PokeAccess.clock
        nil while PokeAccess.clock - t < 0.01
      end
      assert_equal [0, true], [limits.cuts, limits.instance_variable_get(:@deadline) - before >= 0.01]
    end
  end

  test "a counter with no graphic, on a tile no one stands on, watches and sees past what stands between" do
    walled = ROOM.dup
    walled[1] = "#...#...#"
    room(walled) do
      watcher(4, 0, 2, "Counter(3)", :sprite => "")
      Sight.declare(nil)
      assert_equal [true, true, true], [Sight.seen?(4, 1), Sight.seen?(4, 2), Sight.seen?(4, 3)]
    end
  end

  test "an event with no graphic the player walks onto watches not, whatever its name" do
    room(ROOM) do
      watcher(4, 3, 8, "Counter(2)", :sprite => "")
      watcher(6, 3, 8, "Trainer(2)", :sprite => "")
      Sight.declare(nil)
      assert_equal [false, false], [Sight.seen?(4, 2), Sight.seen?(6, 2)]
    end
  end

  test "picked by its name, a battled trainer of a declared map watches no more; picked by id, it does while drawn" do
    room(ROOM) do
      watcher(4, 3, 8, "Trainer(1)", :trigger => 0)
      watcher(6, 3, 8, "Cultist Trainer(1)")
      Sight.declare(nil)
      by_name = [Sight.seen?(4, 2), Sight.seen?(6, 2)]
      Sight.declare(nil, :events => [1])
      assert_equal [[false, false], true], [by_name, Sight.seen?(4, 2)], "before GameData, the name is Trainer(n) alone"
      assert_raises(ArgumentError) { Sight.declare(:events => [1]) }
    end
  end

  test "the guide plans again when what the watchers see changes under its route" do
    room(ROOM) do
      target = TestGameEvent.new(:id => 9, :x => 7, :y => 2, :name => "Vecino",
                                 :pages => [TestPage.new(:sprite => "npc", :list => [TestCmd.new(101, ["Hola"])])])
      $game_map.events[9] = target
      ev = watcher(4, 3, 2, "Trainer(1)")
      Sight.declare(nil)
      with_guide_state do |loc|
        steps_aim(loc, target)
        walk_to(loc, 1, 2)
        before = PokeAccess::Guide.instance_variable_get(:@plan).route.to_a.length
        ev.direction = 8
        guide_frame
        after = PokeAccess::Guide.instance_variable_get(:@plan).route.to_a.length
        assert_equal [5, 7], [before, after]
      end
    end
  end

  test "a move route's turns, diagonals, jumps and fixed direction take the poses RPG Maker gives" do
    poses = Sight.walk(codes(6, 20, 35, 1, 36, 14, 0), false, 0, [5, 5, 8], false)
    list = codes(14, 0)
    list[0].parameters = [-2, 1]
    assert_equal [[[5, 5, 8], [6, 6, 2], [6, 6, 4], [6, 7, 4]], [[5, 5, 2], [3, 6, 4]]],
                 [poses, Sight.walk(list, false, 0, [5, 5, 2], false)]
  end

  test "with avoid_trainers, the trainers still to battle are gone round; one battled, or with the option off, not" do
    room(ROOM) do
      watcher(4, 3, 8, "Trainer(1)")
      watcher(2, 1, 2, "Trainer(1)", :trigger => 0)
      off = Sight.seen?(4, 2)
      PokeAccess::Config.avoid_trainers = true
      assert_equal [false, true, false, 8], [off, Sight.seen?(4, 2), Sight.seen?(2, 2), walk_route(7, 2, true).to_a.length]
      PokeAccess::Config.avoid_trainers = false
      assert_equal 6, walk_route(7, 2, true).to_a.length, "the plan made with the option on is not kept once it is off"
    end
  end

  test "the free camera says who sees a tile now, by the locator's name, and nothing on the watcher's own tile" do
    room(ROOM) do
      ev = watcher(2, 3, 6, "Trainer(1)", :move_type => 3, :move_route => Route.new(codes(3, 3, 2, 2, 0), true))
      Sight.declare(nil)
      tags = PokeAccess::Tags.singleton_class
      tags.send(:alias_method, :get_unspied, :get)
      PokeAccess::Tags.define_singleton_method(:get) { |m, id| id == ev.id ? "Guardia" : get_unspied(m, id) }
      said = [Sight.camera_line(3, 3), Sight.camera_line(1, 3), Sight.camera_line(2, 3), Sight.seen?(1, 3)]
      assert_equal ["A la vista de Guardia", nil, nil, true], said
      assert PokeAccess::Camera.tile_lines(3, 3).include?("A la vista de Guardia")
    end
  ensure
    tags = PokeAccess::Tags.singleton_class
    if tags.method_defined?(:get_unspied)
      tags.send(:alias_method, :get, :get_unspied)
      tags.send(:remove_method, :get_unspied)
    end
  end

  # Runs the block on rows, declarations and avoid_trainers put back after.
  def room(rows)
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    Sight.clear
    PokeAccess::Config.avoid_trainers = false
    $game_map.clear_grid
  end

  # An event at (x,y) facing d, named name, drawn unless :sprite says, its page started by event touch unless :trigger
  # says, moving as :move_type and :move_route say.
  def watcher(x, y, d, name, opts = {})
    id = $game_map.events.length + 1
    page = TestPage.new(:trigger => opts.fetch(:trigger, 2), :sprite => opts.fetch(:sprite, "trainer"), :direction => d,
                        :move_type => opts.fetch(:move_type, 0), :move_route => opts[:move_route])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    ev.direction = d
    $game_map.events[id] = ev
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end

  # Move route commands of codes.
  def codes(*list); list.map { |c| TestCmd.new(c) }; end

  # A new frame, as the world reads one.
  def next_frame; PokeAccess::World::Epoch.dirty!; end
end
