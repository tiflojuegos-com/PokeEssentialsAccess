# Routes::Moves: fast answers a move only where step makes it plain or none, in every mode, and most moves itself;
# rules asked on their owners' tiles, edge_relax border steps, and what the search estimate reads of the map, fresh.
class MovesTest < PokeAccessTest
  Moves = PokeAccess::Routes::Moves
  Pathfinder = PokeAccess::Pathfinder
  DIR_OF = PokeAccess::Routes::DIR_OF
  LEDGE = PokeAccess::Routes::Moves::LEDGE
  ASSIST = PokeAccess::Routes::Moves::ASSIST
  RELAX = PokeAccess::Routes::Moves::RELAX
  SURF_PLAN = PokeAccess::Routes::Moves::SURF_PLAN
  SPECIAL = PokeAccess::Routes::Moves::SPECIAL
  RULE_LISTS = [:@arrival_rules, :@held_rules, :@leave_rules, :@assist_sources].freeze
  # A walled 6x5 room for warp pads, the player at its top left.
  PAD_ROWS = ["########",
              "#@.....#",
              "#......#",
              "#......#",
              "#......#",
              "#......#",
              "########"].freeze
  # A walled room with water, falling water, a bridge, a ledge, ice, tiles three rules own and events of every kind,
  # its player at the top left (see on_rich_map).
  RICH_ROWS = ["##########",
               "#@.......#",
               "#..~~~...#",
               "#..~~~...#",
               "#........#",
               "#........#",
               "#........#",
               "##########"].freeze
  # What fast answers on that room (on_rich_map says what stands where): [x, y, way, mode, vehicle] => its answer.
  # true is a plain step, nil no move, SPECIAL a move only step can tell.
  FAST = {
    [2, 1, 6, 0, :foot] => true,
    [1, 1, 8, 0, :foot] => nil,
    [1, 1, 4, 0, :foot] => nil,
    [9, 1, 6, 0, :foot] => SPECIAL,
    [1, 7, 2, 0, :foot] => SPECIAL,
    [7, 4, 4, 0, :foot] => true,
    [7, 3, 2, 0, :foot] => SPECIAL,
    [2, 3, 2, 0, :foot] => SPECIAL,
    [4, 3, 6, 0, :foot] => SPECIAL,
    [5, 3, 6, 0, :foot] => SPECIAL,
    [1, 5, 6, 0, :foot] => SPECIAL,
    [2, 5, 6, 0, :foot] => true,
    [6, 6, 4, 0, :foot] => SPECIAL,
    [5, 6, 6, 0, :foot] => true,
    [7, 1, 6, 0, :foot] => SPECIAL,
    [0, 1, 4, 0, :foot] => SPECIAL,
    [1, 1, 4, RELAX, :foot] => SPECIAL,
    [3, 2, 6, 0, :foot] => nil,
    [3, 2, 6, 0, :afloat] => SPECIAL,
    [3, 3, 8, 0, :afloat] => true,
    [7, 5, 6, 0, :foot] => nil,
    [7, 5, 6, RELAX, :foot] => nil,
    [7, 5, 6, ASSIST, :foot] => SPECIAL,
    [8, 5, 8, ASSIST, :foot] => true,
    [5, 5, 6, 0, :foot] => true,
    [5, 5, 6, ASSIST, :foot] => SPECIAL,
    [6, 5, 8, ASSIST, :foot] => SPECIAL,
    [2, 6, 6, 0, :foot] => true,
    [2, 6, 6, ASSIST, :foot] => SPECIAL,
    [1, 1, 8, ASSIST, :foot] => nil,
    [1, 1, 8, ASSIST, :bike] => SPECIAL,
    [3, 3, 8, SURF_PLAN, :foot] => true,
    [2, 2, 6, SURF_PLAN, :foot] => SPECIAL,
    [3, 2, 6, SURF_PLAN, :foot] => SPECIAL
  }.freeze
  # A shore, four tiles of water and land beyond, the player at the shore's back (see on_currents).
  CURRENTS = ["#########",
              "#@.~~~~.#",
              "#########"].freeze

  # A 5x3 map whose floor is its middle row, and whose engine refuses any step onto x = 0, a border tile anyone may
  # stand on (a connection the game moves the player across itself).
  class EdgeMap
    attr_accessor :map_id, :events

    def initialize; @map_id = 779; @events = {}; end
    def data; TileWorld::Data.new; end
    def terrain_tag(*_); 0; end
    def valid?(x, y); x >= 0 && y >= 0 && x < 5 && y < 3; end
    def width; 5; end
    def height; 3; end
    def floor?(x, y); y == 1 && x >= 0 && x <= 4; end

    def passable?(x, y, d)
      delta = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }[d]
      return floor?(x, y) if delta.nil?
      nx = x + delta[0]
      ny = y + delta[1]
      floor?(nx, ny) && nx > 0
    end
  end

  # The player on an EdgeMap, at (2,1), moving where the map lets them.
  class EdgePlayer
    attr_accessor :x, :y, :through

    def initialize; @x = 2; @y = 1; end
    def passable?(x, y, d); $game_map.passable?(x, y, d); end
  end

  test "a rule's owner takes in a tile by its terrain number, its kind, a flag of its tag or a block's yes" do
    flagged = Struct.new(:id_number, :slippery)
    $game_map.load_grid(["######",
                         "#....#",
                         "######"])
    $game_map.set_terrain(1, 1, 88)
    $game_map.set_terrain(2, 1, 4)
    $game_map.set_terrain(3, 1, flagged.new(50, true))
    [
      [{ :tags => [88] }, 1, true],
      [{ :tags => [88] }, 2, false],
      [{ :kinds => [:rock] }, 2, true],
      [{ :kinds => [:rock] }, 1, false],
      [{ :flags => [:slippery] }, 3, true],
      [{ :flags => [:slippery] }, 1, false],
      [{ :tiles => lambda { |x, _y| x == 4 } }, 4, true],
      [{ :tiles => lambda { |x, _y| x == 4 } }, 3, false],
      [{ :tiles => lambda { |_x, _y| 1 } }, 4, true],
      [{ :tiles => lambda { |_x, _y| raise ArgumentError, "unreadable" } }, 4, false],
      [{ :tags => lambda { [88] } }, 1, true],
      [{ :kinds => [:ice], :tags => [7] }, 4, false],
      [nil, 4, true]
    ].each do |owner, x, want|
      assert_equal want, Moves.owns?(owner, x, 1), "#{owner.inspect} at (#{x}, 1)"
    end
  end

  test "a rule is asked on its owner's tiles alone" do
    with_rules_kept do
      corridor
      $game_map.set_terrain(3, 1, 88)
      asked = []
      Moves.arrival_rule(:tags => [88]) { |x, y, _d| asked.push([x, y]); nil }
      traced(1, 1, 0, [6, 6, 6])
      assert_equal [[3, 1]], asked.uniq
    end
  end

  test "a rule without an owner is asked on every tile walked onto" do
    with_rules_kept do
      corridor
      asked = []
      Moves.arrival_rule { |x, y, _d| asked.push([x, y]); nil }
      traced(1, 1, 0, [6, 6, 6])
      assert_equal [[2, 1], [3, 1], [4, 1]], asked.uniq
    end
  end

  test "an owner key it does not know is an error, so a misspelt one cannot silence a rule" do
    with_rules_kept do
      [[:arrival_rule, { :tag => [88] }],
       [:arrival_rule, { :front_tags => [88] }],
       [:held_key_rule, { :kind => [:ice] }],
       [:leave_rule, { :tile => lambda { |_x, _y| true } }],
       [:assist_source, { :tags => [88] }]].each do |register, owner|
        assert_raises(ArgumentError, "#{register} #{owner.inspect}") { Moves.send(register, owner) { nil } }
      end
    end
  end

  test "a rule registered once the tiles were classed is seen by fast" do
    with_rules_kept do
      corridor
      $game_map.set_terrain(2, 1, 88)
      before = Pathfinder.searching { Moves.fast(1, 1, DIR_OF[6], 0) }
      Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      after = Pathfinder.searching { Moves.fast(1, 1, DIR_OF[6], 0) }
      assert_equal [true, SPECIAL], [before, after]
    end
  end

  test "an assisted step's source is asked of the move into the tile in front it owns alone" do
    with_rules_kept do
      wall_ahead
      asked = []
      Moves.assist_source(:front_tags => [88]) { |x, y, dir, _lvl| asked.push([x, y, dir[2]]); nil }
      Pathfinder.with_gates_open do
        Pathfinder.searching { PokeAccess::Routes::DIRS.each { |dir| Moves.step(1, 1, 0, dir, ASSIST) } }
      end
      assert_equal [[1, 1, 6]], asked
    end
  end

  test "an assisted step a source answers is taken as an assist with its gate, past a source that raises" do
    with_rules_kept do
      wall_ahead
      Moves.assist_source(:front_tags => [88]) { |_x, _y, _dir, _lvl| raise ArgumentError, "broken source" }
      Moves.assist_source(:front_tags => [88]) do |x, y, dir, lvl|
        Moves::Step.new(x + 2 * dir[0], y + 2 * dir[1], lvl, 1, { :kind => :climb })
      end
      step = Pathfinder.searching { Moves.step(1, 1, 0, DIR_OF[6], ASSIST) }
      assert_equal [[3, 1], :assist, { :kind => :climb }], [step.tile, step.kind, step.gate]
      assert_nil Pathfinder.searching { Moves.step(1, 1, 0, DIR_OF[6], 0) }, "outside an assisted search it is no move"
    end
  end

  test "where fast answers a move, step answers the same, in every mode and vehicle" do
    on_rich_map do
      {
        "walking" => lambda { disagreements(0) },
        "with ledges" => lambda { disagreements(LEDGE) },
        "with the border" => lambda { disagreements(LEDGE | RELAX) },
        "assisted" => lambda { Pathfinder.with_gates_open { disagreements(Pathfinder.moves_mode(true, false)) } },
        "assisted on the bike" => lambda do
          riding(:bike) { Pathfinder.with_gates_open { disagreements(Pathfinder.moves_mode(true, false)) } }
        end,
        "afloat" => lambda { riding(:afloat) { disagreements(LEDGE) } },
        "planning a surf" => lambda { disagreements(LEDGE | SURF_PLAN) }
      }.each { |what, run| assert_equal [], run.call[0], what }
    end
  end

  test "fast answers most moves of the map itself, and a planned surf's water onto water" do
    on_rich_map do
      [0, LEDGE].each do |mode|
        _bad, counts = disagreements(mode)
        assert_operator counts[:plain] + counts[:none], :>, counts[:special], "mode #{mode}: #{counts.inspect}"
      end
      _bad, counts = disagreements(LEDGE | SURF_PLAN)
      assert_operator counts[:plain], :>, 0, "planning a surf: #{counts.inspect}"
    end
  end

  test "fast leaves to step every move that may be more than a plain one, and answers the rest" do
    on_rich_map do
      FAST.each do |(x, y, d, mode, vehicle), want|
        got = riding(vehicle) { Pathfinder.searching { Moves.fast(x, y, DIR_OF[d], mode) } }
        what = "(#{x}, #{y}) toward #{d}, mode #{mode}, #{vehicle}"
        want.nil? ? assert_nil(got, what) : assert_equal(want, got, what)
      end
    end
  end

  test "a rule without an owner leaves every move into a tile to step" do
    on_rich_map do
      Moves.arrival_rule { |_x, _y, _d| nil }
      bad, counts = disagreements(LEDGE)
      assert_equal [[], 0], [bad, counts[:plain]]
    end
  end

  test "a planned surf onto a current ends where it carries the surfer, as a move afloat does, and fast leaves it " \
       "to step" do
    on_currents do
      planned = lambda { |x| Pathfinder.searching { Moves.step(x, 1, 0, DIR_OF[6], LEDGE | SURF_PLAN) }.tile }
      afloat = riding(:afloat) { Pathfinder.searching { Moves.step(4, 1, 0, DIR_OF[6], LEDGE) }.tile }
      fast = Pathfinder.searching { Moves.fast(4, 1, DIR_OF[6], LEDGE | SURF_PLAN) }
      assert_equal [[4, 1], [4, 1], [4, 1], SPECIAL], [planned.call(2), planned.call(4), afloat, fast]
      assert_equal :none, PokeAccess::Routes::Planner.plan(7, 1).kind, "the shore past the current"
    end
  end

  test "a slope's run takes the player along it in one move of its presses" do
    on_rich_map do
      run = Pathfinder.searching { Moves.step(1, 6, 0, DIR_OF[6], 0) }
      assert_equal [4, 5, 3, :run], [run.x, run.y, run.presses, run.kind]
    end
  end

  test "on the bike, an assisted search gets off it in front of tall grass, and fast agrees with step there" do
    with_tile_world(["######",
                     '#@gg.#',
                     "######"]) do
      $PokemonGlobal.bicycle = true
      step = Pathfinder.with_gates_open { Pathfinder.searching { Moves.step(1, 1, 0, DIR_OF[6], ASSIST) } }
      assert_equal [[2, 1], :assist, :dismount], [step.tile, step.kind, step.gate[:kind]], "off the bike onto the grass"
      bad = Pathfinder.with_gates_open { disagreements(Pathfinder.moves_mode(true, false), 6, 3)[0] }
      assert_equal [], bad, "no answer of fast differs from step's"
    end
  end

  test "without edge_relax a border tile the engine keeps the player off is out of reach" do
    on_edge_map do
      assert_nil walk_route(0, 1, true)
    end
  end

  test "with edge_relax a search steps onto that border tile, and the guide replays the route to its end" do
    PokeAccess::Config.edge_relax = true
    on_edge_map do
      route = walk_route(0, 1, true)
      assert_equal [4, 4], route, "the route onto the border tile"
      assert_equal [[1, 1, 0], [0, 1, 0]], spots(traced(2, 1, 0, route)), "replayed to its end"
      assert_equal true, Moves.ok?(1, 1, 4, Pathfinder.replay_mode), "its last step can be taken now"
    end
  end

  test "on the border with edge_relax, where fast answers a move step answers the same" do
    on_edge_map do
      assert_equal [], disagreements(LEDGE | RELAX, 5, 3)[0]
    end
  end

  test "a tile on or beside ice or a rule's tile moves the player by itself; by a ledge, a bridge or the edge not" do
    with_rules_kept do
      $game_map.load_grid(["#######",
                           "#.....#",
                           "#.....#",
                           "#.....#",
                           "#######"])
      $game_map.set_terrain(3, 2, 12)
      $game_map.set_terrain(1, 3, 88)
      $game_map.set_terrain(5, 1, 89)
      $game_map.place_ledge(2, 1, 4)
      $game_map.place_bridge(5, 3)
      Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      Moves.leave_rule(:tags => [89]) { |_x, _y, _d| nil }
      {
        [3, 2] => true, [3, 1] => true, [3, 3] => true, [2, 2] => true, [4, 2] => true,
        [4, 3] => false, [1, 3] => true, [1, 2] => true, [2, 3] => true, [5, 1] => true, [5, 2] => true,
        [2, 1] => false, [1, 1] => false, [5, 3] => false, [0, 2] => false
      }.each do |(x, y), want|
        assert_equal want, Pathfinder.searching { Moves.forcing?(x, y) }, "(#{x}, #{y})"
      end
    end
  end

  test "an event placed since the tiles were classed is seen, whichever question comes first" do
    [:fast, :forcing?].each do |first|
      corridor
      assert_equal true, Pathfinder.searching { Moves.fast(1, 1, DIR_OF[6], 0) }, "#{first}: plain before the event"
      World.touch(:id => 50, :x => 2, :y => 1, :list => [World.move_player([4], 1)])
      got = Pathfinder.searching do
        Moves.forcing?(1, 1) if first == :forcing?
        Moves.fast(1, 1, DIR_OF[6], 0)
      end
      assert_equal SPECIAL, got, "#{first} asked first: a touch event in front"
    end
  end

  test "an action-button event placed since the tiles were classed is seen by an assisted search" do
    corridor
    before = Pathfinder.searching { Moves.fast(1, 1, DIR_OF[6], ASSIST) }
    World.touch(:id => 66, :x => 2, :y => 1, :trigger => 0, :list => [World.move_player([37, 3, 3, 38], 1)])
    after = Pathfinder.searching { Moves.fast(1, 1, DIR_OF[6], ASSIST) }
    assert_equal [true, SPECIAL], [before, after]
  end

  test "a new map is classed afresh, its size included" do
    small = lambda do
      corridor
      Pathfinder.searching { [Moves.fast(5, 1, DIR_OF[6], 0), Moves.fast(1, 2, DIR_OF[2], 0)] }
    end
    first = small.call
    $game_map.load_grid(["#" * 50] + ["#@" + "." * 47 + "#"] + ["#" + "." * 48 + "#"] * 22 + ["#" * 50])
    Pathfinder.invalidate_cache(true)
    big = Pathfinder.searching { [Moves.fast(45, 1, DIR_OF[6], 0), Moves.fast(1, 22, DIR_OF[2], 0)] }
    assert_equal [[SPECIAL, SPECIAL], [true, true], [SPECIAL, SPECIAL]], [first, big, small.call],
                 "off a 6x3 map's right and bottom edges; near a 50x25 map's; off the 6x3 map's again"
  end

  test "a press covers one tile, with no telling by falling water afloat or planning a surf, or with an assisted step" do
    source = lambda { Moves.assist_source(:front_tags => [88]) { |_x, _y, _dir, _lvl| nil } }
    owning = lambda { source.call; $game_map.set_terrain(3, 2, 88) }
    falls = lambda { $game_map.set_terrain(4, 2, 9) }
    [
      ["on foot, nothing registered", nil, :foot, [1, 1, 1]],
      ["an assisted step registered that owns no tile here", source, :foot, [1, 1, 1]],
      ["an assisted step registered that owns a tile here", owning, :foot, [1, 1, nil]],
      ["afloat, no falling water", nil, :afloat, [1, 1, 1]],
      ["falling water, on foot", falls, :foot, [1, nil, 1]],
      ["falling water, afloat", falls, :afloat, [nil, nil, nil]]
    ].each do |what, change, vehicle, want|
      without_rules do
        open_room
        change.call if change
        assert_equal want, speeds(vehicle), "#{what}: walking, planning a surf, assisted"
      end
    end
  end

  test "a press may cover two tiles the way a ledge is hopped and one any other way, asked again the same" do
    ledge_room
    2.times do |i|
      strides = Moves.strides(LEDGE)
      { [0, 6] => 3, [0, -6] => 6, [6, 0] => 6, [-6, 0] => 6, [1, 0] => 1, [0, 1] => 1, [0, 0] => 0,
        [3, 4] => 5 }.each do |(dx, dy), want|
        assert_equal want, strides.presses(dx, dy), "asked #{i + 1}: (#{dx}, #{dy})"
      end
    end
  end

  test "without ledge hops a press covers one tile whichever way, though the map has a ledge" do
    ledge_room
    assert_equal true, Moves.strides(0).plain?
  end

  test "planning a surf a press covers two tiles the way a ledge is hopped, as on foot, with no fall on the map" do
    ledge_room
    ways = [[0, 6], [0, -6], [6, 0], [-6, 0]]
    foot = Moves.strides(LEDGE)
    surf = Moves.strides(LEDGE | SURF_PLAN)
    assert_equal ways.map { |dx, dy| foot.presses(dx, dy) }, ways.map { |dx, dy| surf.presses(dx, dy) }
  end

  test "the strides are taken afresh once the tiles change" do
    ledge_room
    down = Moves.strides(LEDGE).presses(0, 6)
    $game_map.clear_ledges
    $game_map.place_ledge(3, 2, 6)
    right = Moves.strides(LEDGE)
    assert_equal [3, 6, 3], [down, right.presses(0, 6), right.presses(6, 0)], "a ledge hopped down, then right"
  end

  test "a ledge on the map's outer row or column counts too" do
    { [3, 0, 6] => [[6, 0], 3], [0, 3, 2] => [[0, 6], 3] }.each do |(x, y, hop), ((dx, dy), want)|
      open_room
      $game_map.place_ledge(x, y, hop)
      Pathfinder.invalidate_cache(true)
      assert_equal want, Moves.strides(LEDGE).presses(dx, dy), "a ledge at (#{x}, #{y}) hopped toward #{hop}"
    end
  end

  test "with ledge hops a press may cover two tiles on a map with a ledge, and one without them" do
    ledge_room
    assert_equal [2, 1], [Moves.speed(LEDGE), Moves.speed(0)]
  end

  test "a touch event that takes the player elsewhere leaves no telling how far a press goes" do
    open_room
    warp_pad(64, 3, 2)
    Pathfinder.invalidate_cache(true)
    assert_equal [nil, nil], [Moves.speed(LEDGE), Moves.speed(0)]
  end

  test "a rule that may move the player on a tile here leaves no telling how far a press goes" do
    [
      ["an arrival rule without an owner", lambda { Moves.arrival_rule { |_x, _y, _d| nil } }],
      ["a leave rule, on a map with a bridge", lambda do
        Moves.leave_rule(:tags => [88]) { |_x, _y, _d| nil }
        $game_map.place_bridge(5, 3)
      end],
      ["an arrival rule owning a terrain number here", lambda do
        $game_map.set_terrain(3, 2, 88)
        Moves.arrival_rule(:tags => [88]) { |_x, _y, _d| nil }
      end],
      ["an arrival rule whose block owns one tile here", lambda do
        Moves.arrival_rule(:tiles => lambda { |x, y| [x, y] == [4, 2] }) { |_x, _y, _d| nil }
      end],
      ["an arrival rule whose block owns a tile of the map's top row", lambda do
        Moves.arrival_rule(:tiles => lambda { |x, y| [x, y] == [3, 0] }) { |_x, _y, _d| nil }
      end],
      ["an arrival rule whose block owns a tile of the map's left column", lambda do
        Moves.arrival_rule(:tiles => lambda { |x, y| [x, y] == [0, 2] }) { |_x, _y, _d| nil }
      end]
    ].each do |what, setup|
      without_rules do
        open_room
        setup.call
        Pathfinder.invalidate_cache(true)
        assert_nil Moves.speed(LEDGE), what
      end
    end
  end

  test "a rule that owns no tile here leaves a press one tile" do
    [
      ["a terrain number not on the map", lambda { Moves.arrival_rule(:tags => [77]) { |_x, _y, _d| nil } }],
      ["a block that owns no tile", lambda do
        Moves.arrival_rule(:tiles => lambda { |_x, _y| false }) { |_x, _y, _d| nil }
      end],
      ["a block that raises on every tile", lambda do
        Moves.arrival_rule(:tiles => lambda { |_x, _y| raise ArgumentError, "unreadable" }) { |_x, _y, _d| nil }
      end]
    ].each do |what, setup|
      without_rules do
        open_room
        setup.call
        Pathfinder.invalidate_cache(true)
        assert_equal 1, Moves.speed(LEDGE), what
      end
    end
  end

  test "on a map with bridges a press may cover two tiles whichever way, and no shortcut is listed" do
    without_rules do
      open_room
      $game_map.place_ledge(3, 2, 2)
      $game_map.place_bridge(5, 3)
      Pathfinder.invalidate_cache(true)
      strides = Moves.strides(LEDGE)
      assert_equal [3, 3, 3, 3], [[6, 0], [-6, 0], [0, 6], [0, -6]].map { |dx, dy| strides.presses(dx, dy) }
      assert_nil Moves.shortcuts(0, LEDGE)
    end
  end

  test "lists every way into a warp pad as a shortcut: a step from each side and a ledge hop two tiles off" do
    $game_map.load_grid(PAD_ROWS)
    $game_map.place_ledge(4, 2, 4)
    $game_map.place_ledge(3, 3, 8)
    warp_pad(63, 3, 2)
    World.touch(:id => 68, :x => 6, :y => 5, :list => [TestCmd.new(201, [0, 999, 1, 1])])
    steps = [[3, 1, 1, 1, 1], [3, 3, 1, 1, 1], [2, 2, 1, 1, 1], [4, 2, 1, 1, 1]]
    hops = [[5, 2, 1, 1, 1], [3, 4, 1, 1, 1]]
    Pathfinder.invalidate_cache(true)
    2.times { |i| assert_equal (steps + hops).sort, shortcut_list, "asked #{i + 1}; the doorway out gives none" }
  end

  test "the shortcuts are listed afresh once the events or the tiles change" do
    $game_map.load_grid(PAD_ROWS)
    warp_pad(63, 3, 2)
    Pathfinder.invalidate_cache(true)
    first = shortcut_list
    warp_pad(67, 5, 4)
    second = shortcut_list
    $game_map.place_ledge(4, 2, 4)
    third = shortcut_list
    pad = [[2, 2, 1, 1, 1], [3, 1, 1, 1, 1], [3, 3, 1, 1, 1], [4, 2, 1, 1, 1]]
    other = [[4, 4, 1, 1, 1], [5, 3, 1, 1, 1], [5, 5, 1, 1, 1], [6, 4, 1, 1, 1]]
    assert_equal [pad, (pad + other).sort, (pad + other + [[5, 2, 1, 1, 1]]).sort], [first, second, third],
                 "one pad; a second one; a ledge hopped onto the first"
  end

  test "tells, asked again, whether a touch event of the map moves the player elsewhere" do
    open_room
    assert_equal [false, false], Pathfinder.searching { [Moves.relocating?, Moves.relocating?] }, "no such event"
    World.touch(:id => 64, :x => 3, :y => 2, :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 1])])
    Pathfinder.invalidate_cache(true)
    assert_equal [true, true], Pathfinder.searching { [Moves.relocating?, Moves.relocating?] }, "a warp pad"
  end

  private

  # Every move of the map loaded in mode, fast against step inside a search frame: [the moves fast answered and step
  # answered otherwise, how many fast answered as a plain step, as no move, and left to step]. A plain step of a
  # planned surf is step's surf of one press.
  def disagreements(mode, w = 10, h = 8)
    bad = []
    counts = Hash.new(0)
    kind = (mode & SURF_PLAN) != 0 ? :surf : :walk
    Pathfinder.searching do
      lvl = Pathfinder.bridge_level
      (0...h).each do |y|
        (0...w).each do |x|
          PokeAccess::Routes::DIRS.each do |dir|
            f = Moves.fast(x, y, dir, mode)
            s = Moves.step(x, y, lvl, dir, mode)
            if f == true
              counts[:plain] += 1
              plain = s && [s.x, s.y, s.level, s.presses, s.gate, s.warp, s.kind] ==
                           [x + dir[0], y + dir[1], lvl, 1, nil, false, kind]
              bad.push([x, y, dir[2], s && [s.x, s.y, s.kind]]) unless plain
            elsif f.nil?
              counts[:none] += 1
              bad.push([x, y, dir[2], [s.x, s.y, s.kind]]) if s
            else
              counts[:special] += 1
            end
          end
        end
      end
    end
    [bad, counts]
  end

  # Runs the block with the registered rules put back afterwards, the tiles classed afresh.
  def with_rules_kept
    saved = RULE_LISTS.map { |v| [v, Moves.instance_variable_get(v).dup] }
    yield
  ensure
    saved.each { |v, list| Moves.instance_variable_set(v, list) }
    Moves.forget_map
  end

  # Runs the block as in a game that registers no rules, the loaded ones put back afterwards.
  def without_rules
    with_rules_kept do
      RULE_LISTS.each { |v| Moves.instance_variable_set(v, []) }
      Moves.forget_map
      yield
    end
  end

  # Runs the block on RICH_ROWS: a ledge hopped down at (7,4), ice at (2,4), a waterfall's crest at (4,2), a bridge
  # at (5,3), an arrival rule's tile at (2,5) moving the player on, a leave rule's tile at (6,6), the tile in front of
  # a registered assisted step at (3,6), a touch event that carries (8,1), a doorway out of the map (1,4), a climb
  # with the action button (6,5), a cuttable tree (8,5) and a slope's run (1,6).
  def on_rich_map
    without_rules do
      $game_map.load_grid(RICH_ROWS)
      $game_map.place_ledge(7, 4, 2)
      $game_map.set_terrain(2, 4, 12)
      $game_map.set_terrain(4, 2, 9)
      $game_map.place_bridge(5, 3)
      $game_map.set_terrain(2, 5, 88)
      $game_map.set_terrain(6, 6, 89)
      $game_map.set_terrain(3, 6, 87)
      Moves.arrival_rule(:tags => [88]) { |x, y, _d| [x + 1, y] }
      Moves.leave_rule(:tags => [89]) { |_x, _y, _d| nil }
      Moves.assist_source(:front_tags => [87]) { |_x, _y, _dir, _lvl| nil }
      World.touch(:id => 91, :x => 8, :y => 1, :list => [World.move_player([4], 1)])
      World.touch(:id => 92, :x => 1, :y => 4, :list => [TestCmd.new(201, [0, 999, 1, 1])])
      World.touch(:id => 93, :x => 6, :y => 5, :trigger => 0, :list => [World.move_player([37, 3, 3, 38], 1)])
      tree = World.event(:kind => :npc, :id => 94, :x => 8, :y => 5, :name => "Tree")
      tree.blocking = true
      World.touch(:id => 95, :name => "Slope", :x => 1, :y => 6, :trigger => 2,
                  :list => [TestCmd.new(108, ["Slope: 3x-1"]), TestCmd.new(108, ["Width: 0/1"])])
      Pathfinder.invalidate_cache(true)
      yield
    end
  end

  # Runs the block on CURRENTS with currents on (3,1) and (5,1) that carry a surfer to (4,1), as the only rule.
  def on_currents
    with_tile_world(CURRENTS) do
      without_rules do
        Moves.arrival_rule(:tiles => lambda { |x, y| y == 1 && (x == 3 || x == 5) }) do |_x, _y, _d|
          ($PokemonGlobal.surfing rescue false) ? [4, 1] : nil
        end
        yield
      end
    end
  end

  # Runs the block on a 5x3 map whose border tile (0,1) the engine keeps the player off, though anyone may stand on
  # it, with the player at (2,1); the real map and player put back afterwards.
  def on_edge_map
    old_map = $game_map
    old_player = $game_player
    $game_map = EdgeMap.new
    $game_player = EdgePlayer.new
    PokeAccess::World.reset!
    Pathfinder.invalidate_cache(true)
    yield
  ensure
    $game_map = old_map
    $game_player = old_player
    PokeAccess::World.reset!
    Pathfinder.invalidate_cache(true)
  end

  # What a press may cover on the map loaded, ridden as vehicle: [walking with ledge hops, planning a surf, assisted].
  def speeds(vehicle)
    riding(vehicle) do
      Pathfinder.invalidate_cache(true)
      [Moves.speed(LEDGE), Moves.speed(LEDGE | SURF_PLAN), Moves.speed(LEDGE | ASSIST)]
    end
  end

  # Runs the block on foot, afloat or on the bike (vehicle :foot, :afloat or :bike), the player put back on foot.
  def riding(vehicle)
    $PokemonGlobal.surfing = vehicle == :afloat
    $PokemonGlobal.bicycle = vehicle == :bike
    yield
  ensure
    $PokemonGlobal.surfing = false
    $PokemonGlobal.bicycle = false
  end

  # A corridor of four floor tiles with the player at its left end.
  def corridor
    $game_map.load_grid(["######",
                         "#@...#",
                         "######"])
    Pathfinder.invalidate_cache(true)
  end

  # The player before a wall tile of terrain 88, floor beyond it.
  def wall_ahead
    $game_map.load_grid(["#####",
                         "#@#.#",
                         "#####"])
    $game_map.set_terrain(2, 1, 88)
    Pathfinder.invalidate_cache(true)
  end

  # The ways into the map's warp pads as Moves.shortcuts lists them on foot, sorted.
  def shortcut_list
    Pathfinder.searching { Moves.shortcuts(0, LEDGE) }.sort
  end

  # A warp pad on (x,y) back to (1,1), placed as an event that comes during play.
  def warp_pad(id, x, y)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(201, [0, $game_map.map_id, 1, 1])])
  end

  # A walled 5x3 room with the player at its top left, with no ledge, terrain or bridge left from before.
  def open_room
    $game_map.clear_ledges
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#.....#",
                         "#.....#",
                         "#######"])
    Pathfinder.invalidate_cache(true)
  end

  # open_room with a ledge at (3,2) hopped down, the caches fresh.
  def ledge_room
    open_room
    $game_map.place_ledge(3, 2, 2)
    Pathfinder.invalidate_cache(true)
  end
end
