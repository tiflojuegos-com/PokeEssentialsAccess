# World::Probe: the engine's answer per step, kept per mode, dropped with a changed event's tiles, never kept off the
# map, mid-stair, in debug walk-through or lent through; pushes ask the event; loans put back; sessions settle once.
class ProbeTest < PokeAccessTest
  Probe = PokeAccess::World::Probe
  # A walled corridor, the player at its west end.
  CORRIDOR = ["#####",
              "#@..#",
              "#####"].freeze
  # The corridor flooded east of the player: from (2, 1) east, a wall on foot and open afloat (afloat, a step from
  # the land the player stands on is asked on foot).
  WATER = ["#####",
           "#@~~#",
           "#####"].freeze
  # The vehicles of four modes: on foot, afloat, on the bike and under the sea.
  MODES = [{}, { :surfing => true }, { :bicycle => true }, { :diving => true }].freeze
  # The steps into and out of (2, 2) and (4, 2): each tile's four ways out, and the step into it from each side.
  TOUCHING = [[2, 2, 2], [2, 2, 4], [2, 2, 6], [2, 2, 8], [2, 1, 2], [2, 3, 8], [1, 2, 6], [3, 2, 4],
              [4, 2, 2], [4, 2, 4], [4, 2, 6], [4, 2, 8], [4, 1, 2], [4, 3, 8], [3, 2, 6], [5, 2, 4]].freeze

  # The player of an engine that gives it readers only (the Reborn engine's), noting each passability question with
  # where it stood and faced then.
  class ReadersOnlyPlayer
    attr_reader :x, :y, :direction

    def initialize(x, y, direction, seen)
      @x = x
      @y = y
      @direction = direction
      @seen = seen
    end

    def passable?(x, y, d)
      @seen.push([x, y, d, @x, @y, @direction])
      true
    end
  end

  test "keeps each mode's answers apart, the mode checked at each question outside a search" do
    hpa_fresh_grid(WATER)
    with_engine do |asked|
      got = [false, true, false].map do |afloat|
        $PokemonGlobal.surfing = afloat
        Probe.step?(2, 1, 6)
      end
      assert_equal [false, true, false], got, "a wall on foot, open afloat in the same frame, a wall again"
      assert_equal 2, asked.length, "on foot again, the answer kept on foot"
    end
  end

  test "keeps the answers of the last three modes, dropping the oldest" do
    hpa_fresh_grid(WATER)
    with_engine do |asked|
      MODES.each { |m| in_mode(m) { Probe.step?(2, 1, 6) } }
      asked.clear
      MODES.drop(1).each { |m| in_mode(m) { Probe.step?(2, 1, 6) } }
      kept = asked.length
      in_mode(MODES[0]) { Probe.step?(2, 1, 6) }
      assert_equal [0, 1], [kept, asked.length], "the three last modes kept, the first asked again"
    end
  end

  test "a mode asked again counts as the newest when the oldest is dropped" do
    hpa_fresh_grid(WATER)
    with_engine do |asked|
      [0, 1, 0, 2, 3].each { |m| in_mode(MODES[m]) { Probe.step?(2, 1, 6) } }
      asked.clear
      in_mode(MODES[0]) { Probe.step?(2, 1, 6) }
      kept = asked.length
      in_mode(MODES[1]) { Probe.step?(2, 1, 6) }
      assert_equal [0, 1], [kept, asked.length], "on foot, asked again after afloat, kept; afloat dropped as the oldest"
    end
  end

  test "a game's mode reader keeps the answers under each of its values apart" do
    hpa_fresh_grid(CORRIDOR)
    with_mode_reader(lambda { $game_switches[815] ? true : false }) do
      with_engine(lambda { |_x, _y, _d| $game_switches[815] ? true : false }) do |asked|
        got = [false, true, false].map do |on|
          $game_switches[815] = on
          Probe.step?(1, 1, 6)
        end
        assert_equal [false, true, false], got, "each value's own answer"
        assert_equal 2, asked.length, "the first value's answer kept for its return"
      end
    end
  end

  test "an event that moves drops the answers into and out of the tiles it left and reached, and only those" do
    hpa_fresh_grid(["#######",
                    "#@....#",
                    "#.....#",
                    "#.....#",
                    "#######"])
    rock = World.event(:id => 5, :x => 2, :y => 2)
    rock.blocking = true
    floor = (1..5).to_a.product((1..3).to_a).product([2, 4, 6, 8]).map { |(x, y), d| [x, y, d] }
    with_engine do |asked|
      floor.each { |x, y, d| Probe.step?(x, y, d) }
      asked.clear
      rock.x = 4
      World.next_frame
      floor.each { |x, y, d| Probe.step?(x, y, d) }
      assert_equal TOUCHING.sort, asked.sort, "asked again: the steps touching where it stood and where it stands"
    end
    assert_equal [true, false], [Probe.step?(1, 2, 6), Probe.step?(3, 2, 6)], "open where it left, shut where it went"
  end

  test "an event that moves drops the answers kept at each bridge height around it" do
    hpa_fresh_grid(["#####",
                    "#@..#",
                    "#...#",
                    "#####"])
    $game_map.place_bridge(3, 1)
    rock = World.event(:id => 5, :x => 3, :y => 2)
    rock.blocking = true
    with_engine do |asked|
      got = [0, 1].map do |height|
        $PokemonGlobal.bridge = height
        Probe.step?(2, 1, 6)
      end
      rock.y = 1
      World.next_frame
      got += [1, 0].map do |height|
        $PokemonGlobal.bridge = height
        Probe.step?(2, 1, 6)
      end
      assert_equal [[true, true, false, false], 4], [got, asked.length],
                   "the step onto the bridge asked again at both heights once the rock rolled onto it"
    end
  end

  test "events lent through are walked into, never kept, and put back" do
    hpa_fresh_grid(CORRIDOR)
    tree = World.event(:id => 6, :x => 2, :y => 1)
    tree.blocking = true
    tree.through = false
    with_engine do |asked|
      before = Probe.step?(1, 1, 6)
      lent = Probe.lend_through([tree]) { [Probe.lending?, Probe.step?(1, 1, 6)] }
      after = [Probe.lending?, tree.through, Probe.step?(1, 1, 6)]
      assert_equal [false, [true, true], [false, false, false]], [before, lent, after],
                   "blocked, then lent through and open, then put back and blocking again"
      assert_equal 2, asked.length, "the step asked while lent was not kept over the answer kept before"
    end
  end

  test "while events are lent, a step clear of their tiles still answers from the memo" do
    hpa_fresh_grid(["######",
                    "#@...#",
                    "######"])
    tree = World.event(:id => 6, :x => 4, :y => 1)
    tree.blocking = true
    with_engine do |asked|
      kept = Probe.step?(1, 1, 6)
      lent = Probe.lend_through([tree]) { Probe.step?(1, 1, 6) }
      assert_equal [true, true, 1], [kept, lent, asked.length], "the engine asked once"
    end
  end

  test "an event lent whose through cannot be read is given back not through" do
    tree = World.event(:id => 6, :x => 2, :y => 1)
    def tree.through; raise "unreadable"; end
    lent = Probe.lend_through([tree]) { Probe.lending? }
    assert_equal [true, false], [lent, tree.instance_variable_get(:@through)]
  end

  test "lending no events runs the block as it is, lending nothing" do
    assert_equal [false, nil], Probe.lend_through([]) { [Probe.lending?, Probe.lent_tiles] }
  end

  test "the tiles lent are every lent event's, sorted, and none once given back" do
    tree = World.event(:id => 6, :x => 2, :y => 1)
    cart = World.event(:id => 7, :x => 4, :y => 1, :name => "Cart size(2,1)")
    inside = Probe.lend_through([cart]) { Probe.lend_through([tree]) { Probe.lent_tiles } }
    assert_equal [[2, 1], [4, 1], [5, 1]].map { |x, y| PokeAccess::Routes.pkey(x, y) }, inside, "both lendings' tiles"
    assert_nil Probe.lent_tiles, "given back"
  end

  test "a lending inside another lends both, and gives back only its own as it ends" do
    hpa_fresh_grid(["######",
                    "#@...#",
                    "######"])
    tree = World.event(:id => 6, :x => 2, :y => 1)
    rock = World.event(:id => 7, :x => 4, :y => 1)
    [tree, rock].each do |e|
      e.blocking = true
      e.through = false
    end
    got = Probe.lend_through([tree]) do
      inner = Probe.lend_through([rock]) { [Probe.step?(1, 1, 6), Probe.step?(3, 1, 6)] }
      [inner, Probe.lending?, Probe.step?(1, 1, 6), Probe.step?(3, 1, 6)]
    end
    assert_equal [[true, true], true, true, false], got, "both open inside; the rock given back, the tree still lent"
    assert_equal false, Probe.step?(1, 1, 6), "nothing kept while either was lent"
  end

  test "an engine error is kept as such, closed to a route and open to the sonar" do
    with_engine(lambda { |x, _y, _d| x == 1 ? raise("broken") : false }) do |asked|
      got = [Probe.step?(1, 1, 6), Probe.step?(1, 1, 6, true), Probe.step?(2, 1, 6, true)]
      assert_equal [false, true, false], got, "the error closed to a route, open to the sonar; a wall closed to both"
      assert_equal [[1, 1, 6], [2, 1, 6]], asked, "the error asked of the engine once"
    end
  end

  test "a step refused into the player's own tile is asked again with the player on its origin, then put back" do
    $game_player.x = 4
    $game_player.y = 1
    $game_player.direction = 2
    seen = []
    refuses_the_player = lambda do |x, y, d|
      seen.push([$game_player.x, $game_player.y, $game_player.direction])
      dd = PokeAccess::DIR_DELTA[d]
      [x + dd[0], y + dd[1]] != [$game_player.x, $game_player.y]
    end
    with_engine(refuses_the_player) do
      assert_equal true, Probe.step?(3, 1, 6)
    end
    assert_equal [[4, 1, 2], [3, 1, 6]], seen, "refused where the player stands, asked again from the step's origin"
    assert_equal [4, 1, 2], [$game_player.x, $game_player.y, $game_player.direction], "where the player stood"
  ensure
    $game_player.direction = 2
  end

  test "a jump's landing is asked of the engine every time, from the jump's origin, the player put back" do
    $game_player.x = 7
    $game_player.y = 4
    $game_player.direction = 2
    seen = []
    lands_on_three = lambda do |x, y, d|
      seen.push([x, y, d, $game_player.x, $game_player.y, $game_player.direction])
      x == 3
    end
    with_engine(lands_on_three) do
      got = [Probe.lands?(1, 2, 6, 3, 2), Probe.lands?(1, 2, 6, 3, 2), Probe.lands?(1, 2, 6, 4, 2)]
      assert_equal [true, true, false], got
    end
    assert_equal [[3, 2, 0, 1, 2, 6], [3, 2, 0, 1, 2, 6], [4, 2, 0, 1, 2, 6]], seen,
                 "passable? of the landing facing nowhere, with the player on the origin facing the jump, each time"
    assert_equal [7, 4, 2], [$game_player.x, $game_player.y, $game_player.direction], "where the player stood"
  ensure
    $game_player.direction = 2
  end

  test "while a game asks for it, a step is asked with the player on its origin facing its way, then put back" do
    $game_player.direction = 2
    { "a game's block saying so" => [lambda { true }, [1, 2, 6]],
      "a game's block saying not" => [lambda { false }, [5, 5, 2]],
      "a game's block that fails" => [lambda { raise "broken" }, [5, 5, 2]] }.each do |what, (block, where)|
      PokeAccess::World.reset!
      seen = []
      with_placer(block) do
        with_engine(lambda { |_x, _y, _d| seen.push([$game_player.x, $game_player.y, $game_player.direction]) }) do
          Probe.step?(1, 2, 6)
        end
      end
      assert_equal [[where], [5, 5, 2]], [seen, [$game_player.x, $game_player.y, $game_player.direction]], what
    end
  ensure
    $game_player.direction = 2
  end

  test "a player walking through walls is asked with that lent off, and given it back" do
    seen = []
    with_player_through(true) do
      with_engine(lambda { |_x, _y, _d| seen.push($game_player.through); false }) do
        Probe.step?(1, 1, 6)
      end
      assert_equal [[false], true], [seen, $game_player.through]
    end
  end

  test "a player with readers only, as the Reborn engine's, is placed through its fields and put back" do
    seen = []
    with_player(ReadersOnlyPlayer.new(7, 4, 2, seen)) do
      assert_equal [true, [[3, 2, 0, 1, 2, 6]], [7, 4, 2]],
                   [Probe.lands?(1, 2, 6, 3, 2), seen, [$game_player.x, $game_player.y, $game_player.direction]]
    end
  end

  test "never keeps a step off the map or in no direction" do
    with_engine do |asked|
      2.times do
        Probe.step?(0, 1, 4)
        Probe.step?(1, 0, 8)
        Probe.step?(1, 1, 0)
      end
      assert_equal [[0, 1, 4], [1, 0, 8], [1, 1, 0]] * 2, asked
    end
  end

  test "keeps no answer partway up a stair, and keeps them off it or when the stair cannot tell" do
    { "partway up a side stair" => [{ :on_middle_of_stair? => lambda { true } }, 2],
      "off the side stair" => [{ :on_middle_of_stair? => lambda { false } }, 1],
      "a side stair that cannot tell" => [{ :on_middle_of_stair? => lambda { raise "unreadable" } }, 1],
      "on an older plugin's stair" => [{ :on_stair? => lambda { true } }, 2],
      "off the side stair, whatever an older plugin's says" =>
        [{ :on_middle_of_stair? => lambda { false }, :on_stair? => lambda { true } }, 1] }.each do |where, (methods, want)|
      PokeAccess::World.reset!
      with_player_methods(methods) do
        with_engine do |asked|
          2.times { Probe.step?(1, 1, 6) }
          assert_equal want, asked.length, where
        end
      end
    end
  end

  test "keeps no answer in a debug build while Ctrl walks through walls" do
    ctrl = lambda { |key| key == Input::CTRL }
    { "a debug build with Ctrl held" => [true, ctrl, 2],
      "a debug build without Ctrl" => [true, lambda { |_key| false }, 1],
      "Ctrl held outside a debug build" => [false, ctrl, 1],
      "a debug build whose keys cannot be read" => [true, lambda { |_key| raise "unreadable" }, 1] }.each do |what, (debug, keys, want)|
      PokeAccess::World.reset!
      with_engine do |asked|
        with_debug_build(debug, keys) { 2.times { Probe.step?(1, 1, 6) } }
        assert_equal want, asked.length, what
      end
    end
  end

  test "takes the stair state once a frame, as the world settles" do
    with_engine do |asked|
      Probe.step?(1, 1, 6)
      with_player_methods(:on_middle_of_stair? => lambda { true }) do
        Probe.step?(1, 1, 6)
        mid_frame = [Probe.stable?, asked.length]
        World.next_frame
        next_frame = [Probe.stable?, Probe.step?(1, 1, 6), Probe.step?(1, 1, 6), asked.length]
        assert_equal [[true, 1], [false, true, true, 3]], [mid_frame, next_frame],
                     "a stair stepped on mid-frame keeps the answers until the next, which asks every step"
      end
    end
  end

  test "with no player, every step is closed and every landing refused" do
    with_player(nil) do
      assert_equal [false, false, false], [Probe.step?(1, 1, 6), Probe.step?(1, 1, 6, true), Probe.lands?(1, 1, 6, 3, 1)]
    end
  end

  test "puts back the answers saved with a map, over those of the map it left" do
    hpa_fresh_grid(CORRIDOR)
    open = true
    with_engine(lambda { |_x, _y, _d| open }) do |asked|
      first = Probe.step?(1, 1, 6)
      saved = Probe.saved
      Probe.forget
      open = false
      other = Probe.step?(1, 1, 6)
      Probe.restore(saved)
      assert_equal [true, false, true, 2], [first, other, Probe.step?(1, 1, 6), asked.length],
                   "the saved answer back, not asked again"
    end
  end

  test "a session compares the tiles as it opens, where a question outside a search does not" do
    hpa_fresh_grid(CORRIDOR)
    first = Probe.step?(1, 1, 6)
    $game_map.instance_variable_get(:@ledges)[[2, 1]] = 2
    World.next_frame
    outside = Probe.step?(1, 1, 6)
    assert_equal [true, true, false], [first, outside, Probe.session { Probe.step?(1, 1, 6) }],
                 "a ledge laid where no one is told: kept outside a search, seen as a session opens"
  end

  test "a session reads the events as it opens, even within the frame they were read in" do
    hpa_fresh_grid(CORRIDOR)
    rock = World.event(:id => 5, :x => 3, :y => 2)
    rock.blocking = true
    before = Probe.step?(1, 1, 6)
    rock.x = 2
    rock.y = 1
    assert_equal [true, false], [before, Probe.session { Probe.step?(1, 1, 6) }], "the rock rolled in front is seen"
  end

  test "afloat, a step out of a tile that is not water is asked on foot, as the engine has ended the surf there" do
    hpa_fresh_grid(WATER)
    $PokemonGlobal.surfing = true
    assert_equal [false, true], [Probe.step?(1, 1, 6), Probe.step?(2, 1, 6)], "from the land a wall, on the water open"
  end

  test "a session takes the mode as it opens, even within the frame" do
    hpa_fresh_grid(WATER)
    on_foot = Probe.step?(2, 1, 6)
    $PokemonGlobal.surfing = true
    assert_equal [false, true], [on_foot, Probe.session { Probe.step?(2, 1, 6) }], "a wall on foot, open afloat"
  end

  test "a nested session shares the outer one, and a question after both brings the world level again" do
    hpa_fresh_grid(CORRIDOR)
    rock = World.event(:id => 5, :x => 3, :y => 2)
    rock.blocking = true
    inside = Probe.session do
      before = Probe.step?(1, 1, 6)
      rock.x = 2
      rock.y = 1
      [before, Probe.session { Probe.step?(1, 1, 6) }]
    end
    World.next_frame
    assert_equal [[true, true], false], [inside, Probe.step?(1, 1, 6)],
                 "the rock rolled in front unseen by the nested session, seen once both closed"
  end

  test "forgets every answer kept, even inside a session" do
    { "a step" => lambda { Probe.step?(1, 1, 6) },
      "a flat step" => lambda { Probe.flat_step?(1, 1, 6, 2, 1) } }.each do |what, ask|
      hpa_fresh_grid(CORRIDOR)
      with_engine do |asked|
        Probe.session do
          Probe.step?(1, 1, 6)
          Probe.forget
          ask.call
        end
        assert_equal [[1, 1, 6], [1, 1, 6]], asked, "#{what} asked again"
      end
    end
  end

  test "a tile is a landing when any one step out of it is open, and none when all are shut" do
    [2, 4, 6, 8].each do |open|
      Probe.forget
      with_engine(lambda { |x, y, d| [x, y, d] == [3, 3, open] }) do
        assert_equal [3, 3], Probe.landing(3, 3), "the step toward #{open} alone open"
      end
    end
    Probe.forget
    with_engine(lambda { |_x, _y, _d| false }) { assert_nil Probe.landing(3, 3), "every step shut" }
  end

  test "a tile off the map, or on a map that cannot tell, is no landing and asks nothing" do
    with_engine do |asked|
      off = Probe.landing(-1, 0)
      $game_map.define_singleton_method(:valid?) { |_x, _y| raise "unreadable" }
      unknown = Probe.landing(3, 3)
      assert_nil off, "off the map"
      assert_nil unknown, "a map that cannot tell"
      assert_equal [], asked, "the engine never asked"
    end
  ensure
    $game_map.singleton_class.send(:remove_method, :valid?) if $game_map.singleton_methods.include?(:valid?)
  end

  test "a flat step in a search answers from the memo every step shares" do
    hpa_fresh_grid(CORRIDOR)
    with_engine do |asked|
      got = Probe.session do
        [Probe.step?(1, 1, 6), Probe.flat_step?(1, 1, 6, 2, 1), Probe.flat_step?(2, 1, 6, 3, 1),
         Probe.step?(2, 1, 6), Probe.flat_step?(3, 1, 6, 4, 1), Probe.flat_step?(3, 1, 2, 3, 2)]
      end
      assert_equal [true, true, true, true, false, false], got
      assert_equal [[1, 1, 6], [2, 1, 6], [3, 1, 6], [3, 1, 2]], asked, "each step asked of the engine once"
    end
  end

  test "a flat step's answer goes with the tiles of an event that moves onto it" do
    hpa_fresh_grid(CORRIDOR)
    rock = World.event(:id => 5, :x => 3, :y => 2)
    rock.blocking = true
    before = Probe.session { Probe.flat_step?(2, 1, 6, 3, 1) }
    rock.y = 1
    World.next_frame
    assert_equal [true, false], [before, Probe.session { Probe.flat_step?(2, 1, 6, 3, 1) }]
  end

  test "a flat step outside a search checks the mode first, as any step" do
    hpa_fresh_grid(WATER)
    on_foot = Probe.flat_step?(2, 1, 6, 3, 1)
    $PokemonGlobal.surfing = true
    assert_equal [false, true], [on_foot, Probe.flat_step?(2, 1, 6, 3, 1)]
  end

  test "a flat step partway up a stair is asked of the engine every time, even in a search" do
    hpa_fresh_grid(CORRIDOR)
    with_player_methods(:on_middle_of_stair? => lambda { true }) do
      with_engine do |asked|
        Probe.session { 2.times { Probe.flat_step?(1, 1, 6, 2, 1) } }
        assert_equal 2, asked.length
      end
    end
  end

  test "a flat step touching events lent in a search answers as lent, and is not kept" do
    hpa_fresh_grid(CORRIDOR)
    tree = World.event(:id => 6, :x => 2, :y => 1)
    tree.blocking = true
    with_engine do |asked|
      got = Probe.session do
        [Probe.lend_through([tree]) { Probe.flat_step?(1, 1, 6, 2, 1) }, Probe.flat_step?(1, 1, 6, 2, 1)]
      end
      assert_equal [[true, false], 2], [got, asked.length], "open while lent, blocked once given back"
    end
  end

  test "a step touching a bridge is kept apart by the bridge height, any other step is not" do
    hpa_fresh_grid(["#####",
                    "#@..#",
                    "#...#",
                    "#####"])
    $game_map.place_bridge(3, 1)
    onto_bridge = lambda { |x, y, d| [x, y, d] == [2, 1, 6] ? $PokemonGlobal.bridge > 0 : true }
    with_engine(onto_bridge) do |asked|
      got = [0, 1, 0].map do |height|
        $PokemonGlobal.bridge = height
        [Probe.step?(2, 1, 6), Probe.step?(1, 2, 6)]
      end
      assert_equal [[false, true], [true, true], [false, true]], got
      assert_equal [[2, 1, 6], [1, 2, 6], [2, 1, 6]], asked, "the step onto the bridge asked at each height, once each"
    end
  end

  test "is quiet while it asks the engine, and only then" do
    heard = []
    with_engine(lambda { |_x, _y, _d| heard.push(Probe.quiet?); true }) { Probe.step?(1, 1, 6) }
    ev, _calls = pushable(:plain, lambda { heard.push(Probe.quiet?); true })
    Probe.event_movable?(ev, 4, 3, 6)
    assert_equal [[true, true], false], [heard, Probe.quiet?], "while a step and a push are asked, not after"
  end

  test "on foot, the engine is asked with the player off the bike, its answer kept on foot and the bike put back" do
    hpa_fresh_grid(CORRIDOR)
    $PokemonGlobal.bicycle = true
    riding = []
    with_engine(lambda { |_x, _y, _d| riding.push($PokemonGlobal.bicycle); true }) do |asked|
      answer = Probe.on_foot { Probe.step?(1, 1, 6) }
      back = $PokemonGlobal.bicycle
      $PokemonGlobal.bicycle = false
      Probe.step?(1, 1, 6)
      assert_equal [true, [false], true, 1], [answer, riding, back, asked.length]
    end
  end

  test "on foot already, on_foot only runs the block" do
    assert_equal [:asked, false], [Probe.on_foot { :asked }, $PokemonGlobal.bicycle]
  end

  test "a push is asked of the event by the check its engine's own push makes, its answer as a boolean" do
    { "an engine with can_move_in_direction?, by passable? with its strict flag" =>
        [:strict_flag, [:passable?, 4, 3, 6, true]],
      "an engine with passableStrict?, by it" => [:strict_method, [:passableStrict?, 4, 3, 6]],
      "an engine with passable? alone, by it" => [:plain, [:passable?, 4, 3, 6]] }.each do |what, (kind, call)|
      [["yes", true], [nil, false]].each do |said, want|
        World.clear_events
        ev, calls = pushable(kind, lambda { said })
        assert_equal [want, [call]], [Probe.event_movable?(ev, 4, 3, 6), calls.map { |c| c[0] }],
                     "#{what}, the check answering #{said.inspect}"
      end
    end
  end

  test "a push check lends the event's through off meanwhile and gives it back" do
    { "an event through" => [lambda { |e| e.through = true }, true],
      "an event not through" => [lambda { |e| e.through = false }, false],
      "an event whose through cannot be read" => [lambda { |e| def e.through; raise "unreadable"; end }, false]
    }.each do |what, (make, after)|
      World.clear_events
      ev, calls = pushable(:plain, lambda { true })
      make.call(ev)
      Probe.event_movable?(ev, 4, 3, 6)
      assert_equal [[false], after], [calls.map { |c| c[1][0] }, ev.instance_variable_get(:@through)], what
    end
  end

  test "a push asked from a stand puts the event and the player there meanwhile, and both back after" do
    $game_player.direction = 8
    ev, calls = pushable(:plain, lambda { true })
    Probe.event_movable?(ev, 6, 2, 6, [6, 2, 7, 1])
    assert_equal [[false, 6, 2, 7, 1, 8]], calls.map { |c| c[1] },
                 "meanwhile the event on its stand, the player on theirs facing as before"
    assert_equal [3, 3, 5, 5, 8], [ev.x, ev.y, $game_player.x, $game_player.y, $game_player.direction],
                 "after, both where they stood"
  ensure
    $game_player.direction = 2
  end

  test "a push check that fails is refused, the event and the player put back" do
    ev, _calls = pushable(:plain, lambda { raise "broken" })
    ev.through = true
    got = Probe.event_movable?(ev, 6, 2, 6, [6, 2, 7, 1])
    assert_equal [false, [3, 3, true], [5, 5]], [got, [ev.x, ev.y, ev.through], [$game_player.x, $game_player.y]]
  end

  test "a game declaring its passability plain is told so" do
    was = Probe.plain?
    Probe.instance_variable_set(:@plain, false)
    before = Probe.plain?
    Probe.plain!
    assert_equal [false, true], [before, Probe.plain?]
  ensure
    Probe.instance_variable_set(:@plain, was)
  end

  private

  # Runs the block with the engine's answer (the player's passable?) noting each question in the list the block
  # gets, and given by answer when there is one, else as the map gives it.
  def with_engine(answer = nil)
    asked = []
    pl = $game_player
    plain = Game_Player.instance_method(:passable?)
    pl.define_singleton_method(:passable?) do |x, y, d|
      asked.push([x, y, d])
      answer ? answer.call(x, y, d) : plain.bind(self).call(x, y, d)
    end
    yield asked
  ensure
    pl.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the player in the mode these vehicles make (each one left out is off).
  def in_mode(vehicles)
    [:surfing, :diving, :bicycle].each { |v| $PokemonGlobal.send("#{v}=", vehicles.fetch(v, false)) }
    yield
  end

  # Runs the block with a game's mode reader registered, taken out after.
  def with_mode_reader(reader)
    Probe.mode_reader(&reader)
    yield
  ensure
    Probe.instance_variable_get(:@readers).delete(reader)
    Probe.forget
  end

  # Runs the block with a game's block saying when the player is placed on each step's origin, taken out after.
  def with_placer(block)
    Probe.place_player_when(&block)
    yield
  ensure
    Probe.instance_variable_get(:@placers).delete(block)
  end

  # Runs the block with the player answering each named method by its block; the methods are taken away after.
  def with_player_methods(methods)
    methods.each { |name, body| $game_player.define_singleton_method(name, &body) }
    yield
  ensure
    methods.each_key { |name| $game_player.singleton_class.send(:remove_method, name) }
  end

  # Runs the block with pl as the game's player (nil for none, as before a save is loaded); the player is put back
  # after.
  def with_player(pl)
    had = $game_player
    $game_player = pl
    yield
  ensure
    $game_player = had
  end

  # Runs the block with the player walking through walls or not (through, a field of its own as a debug build gives
  # it); the field, its reader and its writer are taken away after.
  def with_player_through(value)
    pl = $game_player
    pl.singleton_class.send(:attr_accessor, :through)
    pl.through = value
    yield
  ensure
    pl.singleton_class.send(:remove_method, :through, :through=)
    pl.remove_instance_variable(:@through) if pl.instance_variable_defined?(:@through)
  end

  # Runs the block as a build whose debug flag is debug and whose keys answer press? by keys; the flag, the keys and
  # the error stream (where a debug build reports every error raised) are put back after.
  def with_debug_build(debug, keys)
    was = [$DEBUG, $stderr]
    press = Input.singleton_class.instance_method(:press?)
    Input.define_singleton_method(:press?) { |*k| keys.call(k[0]) }
    $stderr = StringIO.new
    $DEBUG = debug
    yield
  ensure
    $DEBUG, $stderr = was
    Input.singleton_class.send(:define_method, :press?, press)
  end

  # An event on (3, 3) with the push check of an engine of this kind (:strict_flag, passable? taking a strict flag
  # beside can_move_in_direction?; :strict_method, passableStrict?; :plain, passable? alone), answering by answer.
  # Answers [the event, its calls], each call as [the check and its arguments, [the event's through field, its
  # place, the player's place and facing]].
  def pushable(kind, answer)
    calls = []
    ev = World.event(:id => 8, :x => 3, :y => 3)
    seen = lambda do |call|
      pl = $game_player
      calls.push([call, [ev.instance_variable_get(:@through), ev.x, ev.y, pl.x, pl.y, pl.direction]])
      answer.call
    end
    case kind
    when :strict_flag
      ev.define_singleton_method(:can_move_in_direction?) { |*_a| raise "not the push check" }
      ev.define_singleton_method(:passable?) { |x, y, d, strict = false| seen.call([:passable?, x, y, d, strict]) }
    when :strict_method
      ev.define_singleton_method(:passableStrict?) { |x, y, d| seen.call([:passableStrict?, x, y, d]) }
      ev.define_singleton_method(:passable?) { |*_a| raise "not the push check" }
    else
      ev.define_singleton_method(:passable?) { |x, y, d| seen.call([:passable?, x, y, d]) }
    end
    [ev, calls]
  end
end
