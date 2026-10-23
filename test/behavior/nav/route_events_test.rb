# What the map's touch events do to a route on the grid stub (slides, hops, warps, doorways, story blocks, arrow
# floors), and the steps no event explains: off the map, partway up a side stair, through walls for a cutscene.
class RouteEventsTest < PokeAccessTest
  test "a slide carries the player past a wall the way its branch faces" do
    slides_map
    assert_equal [6, 6, 6], walk_route(7, 2), "stepping onto the slide lands across the wall"
  end

  test "a slide takes the branch of the way it is walked into, and is plain floor a way it has none for" do
    slides_map
    {
      [2, 2, 6] => [[5, 2, :carry]],
      [3, 1, 2] => [[3, 2, :walk]],
      [6, 1, 4] => [[3, 1, :carry]],
      [5, 2, 8] => [[6, 1, :carry]]
    }.each do |(x, y, d), want|
      assert_equal want, moved(traced(x, y, 0, [d])), "from (#{x}, #{y}) pressing #{d}"
    end
  end

  test "the step guide keeps quiet while a slide carries the player, and goes on from where it lands" do
    with_forced_moves do
      with_guide_state do |loc|
        $game_map.load_grid(["##########",
                             "#........#",
                             "#@..#....#",
                             "##########"])
        World.touch(:id => 50, :x => 3, :y => 2, :list => [World.if_facing(6), World.move_player([3, 3], 1), World.end_])
        target = World.event(:id => 90, :x => 8, :y => 2, :sprite => "npc")
        steps_aim(loc, target)
        assert_equal [leg(4, :dir_right)], walk_to(loc, 1, 2), "aimed past the slide, it says the whole way"
        walk_to(loc, 2, 2)
        SpeakCapture.clear
        $game_player.move_route_forcing = true
        [3, 4].each do |x|
          $game_player.x = x
          guide_frame
        end
        assert_nothing_spoken "carried across the slide, it says nothing"
        $game_player.move_route_forcing = false
        assert_equal [], walk_to(loc, 5, 2), "landed, it goes on with the leg it said"
      end
    end
  end

  test "a hedge bumped into hops the player over it" do
    hedge_map
    assert_equal [6, 6], walk_route(5, 1), "the route hops the hedge"
    assert_equal [[2, 1, :walk], [4, 1, :carry]], moved(traced(1, 1, 0, [6, 6])), "a walk, then the hop"
  end

  test "a hedge hops the player back by its other branch" do
    hedge_map
    assert_equal [[2, 1, :carry]], moved(traced(4, 1, 0, [4]))
  end

  test "a hedge hops the player when touched, drawn or not, never by the action button" do
    cases = { ["", 1] => [6, 6], ["seto", 1] => [6, 6], ["", 2] => [6, 6], ["", 0] => nil }
    got = cases.keys.each_with_object({}) do |(sprite, trigger), out|
      hedge_map(sprite, trigger)
      out[[sprite, trigger]] = walk_route(5, 1)
    end
    assert_equal cases, got, "[sprite, trigger] => the route past the hedge"
  end

  test "the step into a hedge is a jump, a step onto plain floor is not" do
    hedge_map
    { [2, 1, 6] => true, [4, 1, 4] => true, [1, 1, 6] => false }.each do |(x, y, d), want|
      assert_equal want, PokeAccess::Routes::Moves.jump?(x, y, d), "from (#{x}, #{y}) pressing #{d}"
    end
  end

  test "the cane says the hop over a hedge as a jump" do
    hedge_map
    $game_player.x = 2
    with_guide_state do |loc|
      guide_aim(loc, PokeAccess::Locator::SurfaceTarget.new(5, 1, "seto", :spot))
      SpeakCapture.clear
      guide_frame
      assert_equal [[PokeAccess::I18n.t(:loc_jump, :dir => PokeAccess::I18n.t(:dir_right)), false]], SpeakCapture.log
    end
  end

  test "a route to the hedge itself ends beside it" do
    hedge_map
    assert_equal [6], walk_route(3, 1)
  end

  test "a hop inside a cutscene is no way over" do
    $game_map.load_grid(["#######",
                         "#@.#..#",
                         "#######"])
    World.touch(:id => 53, :x => 3, :y => 1, :list => [TestCmd.new(101, ["¡Alto!"]), World.move_player([[14, [2, 0]]])])
    assert_nil walk_route(5, 1)
  end

  test "a tile that talks and moves the player back the way they came is a wall from that side" do
    cases = { [[13], 1, 6] => nil, [[13], 6, 1] => nil, [[2], 1, 6] => nil, [[2], 6, 1] => [4, 4, 4, 4] }
    got = cases.keys.each_with_object({}) do |(moves, from, to), out|
      $game_map.load_grid(["########",
                           "#......#",
                           "########"])
      World.touch(:id => 54, :x => 4, :y => 1, :list => [TestCmd.new(101, ["No puedes pasar"]), World.move_player(moves)])
      $game_player.x = from
      $game_player.y = 1
      out[[moves, from, to]] = walk_route(to, 1)
    end
    assert_equal cases, got, "[its move, from x, to x] => the route along the corridor"
  end

  test "a tile that talks and walks the player on is plain floor" do
    $game_map.load_grid(["########",
                         "#@.....#",
                         "########"])
    World.touch(:id => 55, :x => 4, :y => 1, :list => [TestCmd.new(101, ["¡Mira!"]), World.move_player([3])])
    assert_equal [6, 6, 6, 6], walk_route(6, 1), "the route walks across it"
    assert_equal [[4, 1, :walk]], moved(traced(3, 1, 0, [6])), "a step onto it is a walk"
  end

  test "a pad that transfers within the map lands the player where it sends them" do
    pad_map(:id => 56, :x => 3, :y => 1, :list => [transfer_to(6, 1)])
    assert_equal [6, 6], walk_route(7, 1), "stepping on the pad lands across the wall"
    assert_equal [[6, 1, 0, 1, nil, false, true, :warp]], whole(traced(2, 1, 0, [6])), "a warp, through a transfer"
  end

  test "an event bumped into that transfers within the map takes the player across" do
    pad_map(:id => 57, :x => 4, :y => 1, :sprite => "escalera", :list => [transfer_to(6, 1)])
    assert_equal [6, 6, 6], walk_route(7, 1), "the bump lands across the wall"
    assert_equal [[6, 1, 0, 1, nil, false, true, :warp]], whole(traced(3, 1, 0, [6])), "a warp, through a transfer"
  end

  test "a pad that sends the player where nobody can stand is plain floor" do
    $game_map.load_grid(["#########",
                         "#@..##.##",
                         "#########"])
    World.touch(:id => 58, :x => 3, :y => 1, :list => [transfer_to(6, 1)])
    assert_equal [[3, 1, 0, 1, nil, false, false, :walk]], whole(traced(2, 1, 0, [6])), "the step stays on the pad"
    assert_nil walk_route(6, 1), "and the closet stays out of reach"
  end

  test "a pad that fires only walked into upward is plain floor from the side" do
    pad_map(:id => 59, :x => 3, :y => 1, :list => [World.if_facing(8), transfer_to(6, 1, 1), World.end_])
    assert_equal [[3, 1, :walk]], moved(traced(2, 1, 0, [6])), "walked into sideways, it is a step"
    assert_nil walk_route(7, 1), "so the wall stays in the way"
  end

  test "an event the engine says fires underfoot works on arrival, drawn or not" do
    cases = { ["escalera", nil] => [[3, 1, :walk]], ["escalera", true] => [[6, 1, :warp]], ["", false] => [[3, 1, :walk]] }
    got = cases.keys.each_with_object({}) do |(sprite, underfoot), out|
      pad = pad_map(:id => 56, :x => 3, :y => 1, :sprite => sprite, :list => [transfer_to(6, 1)])
      pad.define_singleton_method(:over_trigger?) { underfoot } unless underfoot.nil?
      out[[sprite, underfoot]] = moved(traced(2, 1, 0, [6]))
    end
    assert_equal cases, got, "[sprite, the engine's over_trigger? or nil without one] => the step onto the pad"
  end

  test "a pad on a tile the map fails to answer for is taken to fire by bumping, so a step onto it is a walk" do
    pad_map(:id => 56, :x => 3, :y => 1, :list => [transfer_to(6, 1)])
    with_standing_check_failing(3, 1) do
      assert_equal [[3, 1, :walk]], moved(traced(2, 1, 0, [6]))
    end
  end

  test "a pad whose page only plays a sound is plain floor, with no key to hold on it" do
    pad_map(:id => 56, :x => 3, :y => 1, :list => [TestCmd.new(355, ["pbSEPlay('Door exit')"])])
    assert_equal [[3, 1, :walk]], moved(traced(2, 1, 0, [6])), "a step onto it is a walk"
    assert_equal false, PokeAccess::Routes::Moves.held?(3, 1), "and no key need be held there"
  end

  test "a page that cannot be read on is a doorway if it may transfer past that point, else plain floor" do
    { [TestCmd.new(103, [1, 2]), leave_map] => [2, 6, 6, 6, 6],
      [TestCmd.new(103, [1, 2]), World.move_player([3])] => [6, 6, 6] }.each do |list, want|
      room_with_door(list)
      assert_equal want, walk_route(5, 1), "a number input, then #{list[1].code == 201 ? 'a transfer' : 'a move'}"
    end
  end

  test "a route somewhere else goes round a doorway out of the map" do
    room_with_door([leave_map])
    assert_equal [2, 6, 6, 6, 6], walk_route(5, 1)
  end

  test "a doorway that leaves only walked into upward is plain floor crossed sideways" do
    room_with_door([World.if_facing(8), leave_map(1), World.end_])
    assert_equal [6, 6, 6], walk_route(5, 1)
  end

  test "a route to a one-sided doorway ends on the tile it is walked into from" do
    one_sided_door
    assert_equal [6, 6, 8], walk_route(3, 1), "it ends below the door, at (3, 2)"
  end

  test "standing below a one-sided doorway, its route has arrived" do
    one_sided_door
    $game_player.x = 3
    $game_player.y = 2
    assert_equal [], walk_route(3, 1)
  end

  test "past the search's node budget, the way to a one-sided doorway still ends below it" do
    one_sided_door
    PokeAccess::Config.astar_max = 1
    assert_equal [6, 6, 8], walk_route(3, 1)
  end

  test "an arrow floor hands the player on from arrow to arrow, to the tile past the last" do
    {
      :across => [["##########",
                   "#@.......#",
                   "##########"], [[3, 1], [4, 1], [5, 1]], 3, [2, 1, 6], [[6, 1, :carry]]],
      :down => [["####",
                 "#@.#",
                 "#..#",
                 "#..#",
                 "#..#",
                 "#..#",
                 "####"], [[1, 2], [1, 3], [1, 4]], 1, [1, 1, 2], [[1, 5, :carry]]]
    }.each do |name, (rows, arrows, code, (x, y, d), want)|
      $game_map.load_grid(rows)
      arrows.each_with_index do |(ax, ay), i|
        World.touch(:id => 60 + i, :x => ax, :y => ay, :list => [World.move_player([code])])
      end
      assert_equal want, moved(traced(x, y, 0, [d])), "arrows #{name}"
    end
  end

  test "an arrow whose page waits for its move is not handed on" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "##########"])
    World.touch(:id => 63, :x => 3, :y => 1, :list => [World.move_player([3]), TestCmd.new(210, [])])
    World.touch(:id => 64, :x => 4, :y => 1, :list => [World.move_player([3])])
    assert_equal [[4, 1, :carry]], moved(traced(2, 1, 0, [6]))
  end

  test "arrows that would hand the player back and forth forever are no step" do
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    World.touch(:id => 63, :x => 3, :y => 1, :list => [World.move_player([3])])
    World.touch(:id => 64, :x => 4, :y => 1, :list => [World.move_player([2])])
    assert_equal [], moved(traced(2, 1, 0, [6]))
  end

  test "an arrow floor that ends on a pad lands the player where the pad sends them" do
    $game_map.load_grid(["##########",
                         "#@...#...#",
                         "##########"])
    World.touch(:id => 65, :x => 3, :y => 1, :list => [World.move_player([3])])
    World.touch(:id => 66, :x => 4, :y => 1, :list => [transfer_to(7, 1)])
    assert_equal [[7, 1, 0, 1, nil, false, true, :carry]], whole(traced(2, 1, 0, [6])), "a carry, through a transfer"
    assert_equal [6, 6], walk_route(8, 1), "and the route takes it"
  end

  test "a story block drawn across a path closes all of it" do
    story_block("Vuelve size(5,1)", [])
    assert_nil walk_route(3, 1)
  end

  test "a story scene that switches itself off is walked into, as the story needs" do
    story_block("Escena size(5,1)", [TestCmd.new(121, [5, 5, 0])])
    assert_equal [8, 8, 8], walk_route(3, 1)
  end

  test "a block that sends the player back by where they stepped on it reads each of its tiles" do
    block_by_tile
    { [1, 5] => [[1, 6, :carry]], [2, 5] => [[1, 6, :carry]] }.each do |(x, y), want|
      assert_equal want, moved(traced(x, y, 0, [8])), "stepped on from (#{x}, #{y})"
    end
  end

  test "no way runs past a block that sends the player back from each of its tiles" do
    block_by_tile
    assert_nil walk_route(1, 1)
  end

  test "an event bumped into that asks where the player stands reads the tile they bump from" do
    $game_map.load_grid(["#######",
                         "#@.#..#",
                         "#######"])
    World.touch(:id => 73, :x => 3, :y => 1, :list => [TestCmd.new(111, [12, "$game_player.x == 2"]),
                                                       World.move_player([[14, [2, 0]]], 1), World.end_])
    assert_equal [6, 6], walk_route(5, 1), "bumped from x 2, the hop runs"
    assert_equal [], moved(traced(4, 1, 0, [4])), "bumped from x 4, it does not"
  end

  test "a step off the map is no step, and the engine is not asked of the map next door" do
    with_tile_world(["#####",
                     "@...#",
                     "#####"]) do
      asked = []
      own = $game_player.method(:passable?)
      $game_player.define_singleton_method(:passable?) do |x, y, d|
        asked.push([x, y, d])
        d == 4 && x == 0 ? true : own.call(x, y, d)
      end
      assert_equal [], moved(traced(0, 1, 0, [4])), "the connected map beyond the edge is not walked into"
      assert_equal [], asked, "nor asked about"
    end
  end

  test "partway up a side stair each question is the engine's to answer, none kept" do
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    with_stair do
      World.next_frame
      answers = []
      asked = engine_asks { 2.times { answers.push(PokeAccess::World::Probe.step?(1, 1, 6)) } }
      assert_equal [true, true], answers, "the step is open"
      assert_equal [[1, 1, 6], [1, 1, 6]], asked, "and the engine is asked it each time"
    end
  end

  test "partway up a side stair the regions walk nowhere, and walk on once off it" do
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    with_stair do
      World.next_frame
      assert_equal [:unknown], PokeAccess::Routes::Regions.foot.status([[5, 1]]), "on the stair they cannot tell"
    end
    World.next_frame
    assert_equal [:yes, 0], PokeAccess::Routes::Regions.foot.status([[5, 1]]), "off it, the far end is reached"
  end

  test "partway up a side stair the regions from before it still answer" do
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    before = PokeAccess::Routes::Regions.foot
    before.tiles
    with_stair do
      World.next_frame
      $game_player.x = 3
      assert_same before, PokeAccess::Routes::Regions.foot, "the regions stand"
      assert_equal true, reached?(5, 1), "answering from the stair"
    end
  end

  test "a player walking through walls for a cutscene is routed around them" do
    with_through_walls do
      assert_equal [2, 6, 6, 6], walk_route(4, 1)
    end
  end

  test "a route searched for a player walking through walls leaves them doing so" do
    with_through_walls do
      walk_route(4, 1)
      assert_equal true, $game_player.through
    end
  end

  private

  # A replay's Steps as [x, y, kind].
  def moved(steps)
    steps.map { |s| [s.x, s.y, s.kind] }
  end

  # A replay's Steps whole: [x, y, level, presses, gate, mid, warp, kind].
  def whole(steps)
    steps.map { |s| s.to_a }
  end

  # A leg as the step guide says it: n presses toward the direction of dir_key.
  def leg(n, dir_key)
    PokeAccess::I18n.t(:loc_leg, :n => n, :dir => PokeAccess::I18n.t(dir_key))
  end

  # A Transfer Player command to (x, y) of this map.
  def transfer_to(x, y, indent = 0)
    TestCmd.new(201, [0, $game_map.map_id, x, y], indent)
  end

  # A Transfer Player command to another map.
  def leave_map(indent = 0)
    TestCmd.new(201, [0, 55, 1, 1], indent)
  end

  # Two rooms split by a wall at x 4: a slide at (3, 2) carrying the player two tiles right when walked into facing
  # right, and a two-way one at (5, 1), two tiles left facing left, one right any other way. The player at (1, 2).
  def slides_map
    $game_map.load_grid(["#########",
                         "#...#...#",
                         "#@..#...#",
                         "#########"])
    World.touch(:id => 50, :x => 3, :y => 2, :list => [World.if_facing(6), World.move_player([3, 3], 1), World.end_])
    World.touch(:id => 51, :x => 5, :y => 1, :list => [World.if_facing(4), World.move_player([2, 2], 1), World.else_,
                                                       World.move_player([3], 1), World.end_])
  end

  # A corridor cut by a hedge on its wall tile (3, 1), the player at (1, 1): touched facing right it hops them two
  # tiles right, any other way two tiles left.
  def hedge_map(sprite = "", trigger = 1)
    $game_map.load_grid(["#######",
                         "#@.#..#",
                         "#######"])
    hop = [World.if_facing(6), World.move_player([[14, [2, 0]]], 1), World.else_, World.move_player([[14, [-2, 0]]], 1),
           World.end_]
    World.touch(:id => 52, :x => 3, :y => 1, :sprite => sprite, :trigger => trigger, :list => hop)
  end

  # A corridor cut by a wall at x 4, the player at (1, 1), with a touch event made from opts.
  def pad_map(opts)
    $game_map.load_grid(["#########",
                         "#@..#...#",
                         "#########"])
    World.touch(opts)
  end

  # A room two rows high, the player at (1, 1), with a touch event running list at (3, 1).
  def room_with_door(list)
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#.....#",
                         "#######"])
    World.touch(:id => 58, :x => 3, :y => 1, :list => list)
  end

  # A room with a doorway at (3, 1) that leaves the map only walked into upward, the player at (1, 3).
  def one_sided_door
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#.....#",
                         "#@....#",
                         "#######"])
    World.touch(:id => 60, :x => 3, :y => 1, :list => [World.if_facing(8), leave_map(1), World.end_])
  end

  # A room crossed at row 3 by a story block of five tiles that stops the player and turns them back, its page ending
  # with extra; the player at (3, 5).
  def story_block(name, extra)
    $game_map.load_grid(["#######",
                         "#.....#",
                         "#.....#",
                         "#.....#",
                         "#.....#",
                         "#..@..#",
                         "#######"])
    back = [TestCmd.new(101, ["¡Espera, no te vayas!"]), World.move_player([22, 12])]
    World.touch(:id => 70, :name => name, :x => 1, :y => 3, :list => back + extra)
  end

  # A corridor two tiles wide crossed at row 4 by a block that sends the player back down by a branch per tile: two
  # rows down from x 1, two down and one left from x 2. The player at (1, 7).
  def block_by_tile
    $game_map.load_grid(["####",
                         "#..#",
                         "#..#",
                         "#..#",
                         "#..#",
                         "#..#",
                         "#..#",
                         "#@.#",
                         "####"])
    list = [TestCmd.new(111, [12, "$game_player.x == 1"]), World.move_player([1, 1], 1), World.end_,
            TestCmd.new(111, [12, "$game_player.x == 2"]), World.move_player([1, 1, 2], 1), World.end_]
    World.touch(:id => 72, :name => "Bloqueo size(2,1)", :x => 1, :y => 4, :list => list)
  end

  # Runs the block with the player able to be driven by a move route, as the engine's move_route_forcing tells.
  def with_forced_moves
    class << $game_player; attr_accessor :move_route_forcing; end
    yield
  ensure
    class << $game_player; remove_method :move_route_forcing, :move_route_forcing=; end
    pl = $game_player
    pl.send(:remove_instance_variable, :@move_route_forcing) if pl.instance_variable_defined?(:@move_route_forcing)
  end

  # The steps the engine is asked while the block runs, as [x, y, d] each time; the player's own answers are given.
  def engine_asks
    asked = []
    own = $game_player.method(:passable?)
    $game_player.define_singleton_method(:passable?) do |x, y, d|
      asked.push([x, y, d])
      own.call(x, y, d)
    end
    yield
    asked
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the map's passable? raising on the check of whether anyone can stand on (x, y) (direction 0).
  def with_standing_check_failing(x, y)
    own = $game_map.method(:passable?)
    $game_map.define_singleton_method(:passable?) do |px, py, d|
      raise "no tile data" if d == 0 && px == x && py == y
      own.call(px, py, d)
    end
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the player on a side stair of the v17 port, which only tells on_stair?.
  def with_stair
    def $game_player.on_stair?; true; end
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :on_stair?)
  end

  # Runs the block with the player walking through walls (through on, every step passable to the engine), on a room
  # whose way round a wall at (2, 1) is two presses longer than through it; the player at (1, 1).
  def with_through_walls
    $game_map.load_grid(["#######",
                         "#@#...#",
                         "#.....#",
                         "#######"])
    own = $game_player.method(:passable?)
    class << $game_player; attr_accessor :through; end
    $game_player.define_singleton_method(:passable?) { |x, y, d| through ? true : own.call(x, y, d) }
    $game_player.through = true
    yield
  ensure
    class << $game_player; remove_method :passable?, :through, :through=; end
    $game_player.send(:remove_instance_variable, :@through) if $game_player.instance_variable_defined?(:@through)
  end
end
