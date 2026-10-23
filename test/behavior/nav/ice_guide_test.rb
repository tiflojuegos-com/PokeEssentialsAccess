# Ice and the two guides: a slide is one route step landing where it stops, so the guides hold while the engine's slide
# flag is up, the route survives the crossing, and each leg is said where it starts, the slide a leg of its own.
class IceGuideTest < PokeAccessTest
  Guide = PokeAccess::Guide
  ICE = 12
  # Ice from (3, 2) to (7, 2) with a wall below the landing, which leaves one best route to (9, 5): onto the ice, past
  # the landing and then down.
  RINK = ["############",
          "#..........#",
          "#..........#",
          "#.......#..#",
          "#..........#",
          "#..........#",
          "############"]
  # The tiles of the walk across RINK, the five of ice in the middle.
  CROSSING = [[1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2]]

  test "says the slide as a leg of its own where it starts, nothing during it, and each leg past it where it starts" do
    rink
    said = guiding(World.event(:kind => :npc, :id => 77, :x => 9, :y => 5)) do
      CROSSING.map { |x, y| [slide_to(x, y), Guide.on?(:steps)] }
    end
    slide = [[[t(:loc_slide_leg, :dir => t(:dir_right))], true]]
    want = [[[leg(1, :dir_right)], true]] + slide + [[[], true]] * 5 +
           [[[leg(1, :dir_right)], true], [[leg(2, :dir_down)], true]]
    assert_equal want, said
  end

  test "says nothing more once the step guide is turned off during a slide" do
    rink
    said = guiding(World.event(:kind => :npc, :id => 77, :x => 9, :y => 5)) do
      CROSSING.first(5).each { |x, y| slide_to(x, y) }
      Guide.switch(:steps, false)
      [CROSSING.drop(5).map { |x, y| slide_to(x, y) }, Guide.on?(:steps)]
    end
    assert_equal [[[]] * 4, false], said
  end

  test "follows the route planned before the slide, the slide counted as one step" do
    rink
    left, searches = counting_walks do
      guiding(World.event(:kind => :npc, :id => 77, :x => 9, :y => 5)) do
        CROSSING.first(8).each { |x, y| slide_to(x, y) }
        Guide.remaining
      end
    end
    assert_equal [[6, 2, 2], 1], [left, searches], "at the landing one step right and two down are left, of one search"
  end

  test "plans a route that is only a slide as one press" do
    short_rink
    left = guiding(World.event(:kind => :npc, :id => 78, :x => 8, :y => 2)) do
      slide_to(1, 1)
      Guide.remaining
    end
    assert_equal [6], left
  end

  test "says the arrival where a slide stops, not on its first ice tile, and holds on until then" do
    short_rink
    said = guiding(World.event(:kind => :npc, :id => 78, :x => 8, :y => 2)) do
      (1..8).map { |x| [slide_to(x, 1), Guide.on?(:steps)] }
    end
    want = [[[t(:loc_slide_leg, :dir => t(:dir_right))], true]] + [[[], true]] * 6 + [[[t(:loc_arrived)], false]]
    assert_equal want, said
  end

  test "the cane holds through a slide, flag or no flag, and chimes again once it is over" do
    $game_map.load_grid(["##########",
                         "#@.......#",
                         "#........#",
                         "##########"])
    (2..6).each { |x| $game_map.set_terrain(x, 1, ICE) }
    target = World.event(:kind => :npc, :id => 79, :x => 8, :y => 2)
    chimes = []
    with_guide_state do |loc|
      guide_aim(loc, target)
      $game_player.x = 3
      with_cue_log do |log|
        $PokemonGlobal.sliding = true
        chimes.push(cane_frame(log))
        $PokemonGlobal.sliding = false
        moving { chimes.push(cane_frame(log)) }
        chimes.push(cane_frame(log))
      end
    end
    assert_equal [0, 0, 1], chimes, "flag up, stepping onto the ice before the flag, the slide over"
  ensure
    $PokemonGlobal.sliding = false
  end

  test "replays a step onto ice as one step to where the run ends, and any other step as one tile" do
    $game_map.load_grid(["##########",
                         "#........#",
                         "#........#",
                         "##########"])
    (3..6).each { |x| $game_map.set_terrain(x, 1, ICE) }
    { [2, 1, [6]] => [[7, 1, 0]], [7, 1, [6]] => [[8, 1, 0]], [2, 2, [6]] => [[3, 2, 0]],
      [2, 1, [6, 6]] => [[7, 1, 0], [8, 1, 0]] }.each do |(x, y, path), want|
      assert_equal want, spots(traced(x, y, 0, path)), "from (#{x}, #{y}) pressing #{path.inspect}"
    end
  end

  test "stops a slide on the last ice tile before a wall" do
    $game_map.load_grid(["##########",
                         "#....#...#",
                         "#........#",
                         "##########"])
    (3..6).each { |x| $game_map.set_terrain(x, 1, ICE) }
    assert_equal [[4, 1, 0]], spots(traced(2, 1, 0, [6]))
  end

  # A slide event (a sprite-less tile that force-moves the player across a gap) is part of the step that lands on it;
  # this one fires only walked into from the left.
  test "replays a step onto a slide event to where it leaves the player, and one onto it another way as a tile" do
    $game_map.load_grid(["##########",
                         "#........#",
                         "#........#",
                         "##########"])
    World.touch(:id => 40, :x => 3, :y => 1, :list => [World.if_facing(6), World.move_player([3, 3, 3], 1), World.end_])
    PokeAccess::Pathfinder.invalidate_cache(true)
    { [2, 1, [6]] => [[6, 1, 0]], [3, 2, [8]] => [[3, 1, 0]],
      [2, 1, [6, 6]] => [[6, 1, 0], [7, 1, 0]] }.each do |(x, y, path), want|
      assert_equal want, spots(traced(x, y, 0, path)), "from (#{x}, #{y}) pressing #{path.inspect}"
    end
  end

  private

  def t(key, opts = {}); PokeAccess::I18n.t(key, opts); end

  # The step guide's leg of presses toward dir, as it says it.
  def leg(presses, dir)
    t(:loc_leg, :n => presses, :dir => t(dir))
  end

  # Lays RINK with its ice.
  def rink
    $game_map.load_grid(RINK)
    (3..7).each { |x| $game_map.set_terrain(x, 2, ICE) }
  end

  # A room whose row 1 is ice from (2, 1) to (7, 1), the target beside its end.
  def short_rink
    $game_map.load_grid(["##########",
                         "#........#",
                         "#........#",
                         "#........#",
                         "##########"])
    (2..7).each { |x| $game_map.set_terrain(x, 1, ICE) }
  end

  # The block's value with the step guide alone aimed at target, the guides off and the slide flag down after.
  def guiding(target)
    with_guide_state do |loc|
      steps_aim(loc, target)
      yield
    end
  ensure
    $PokemonGlobal.sliding = false
  end

  # Moves the player to (x, y) with the engine's slide flag up on ice, and returns what the guides said there.
  def slide_to(x, y)
    $PokemonGlobal.sliding = $game_map.terrain_tag(x, y) == ICE
    walk_to(nil, x, y)
  end

  # The block's value and how many routes the planner walked meanwhile, its own walk put back after.
  def counting_walks
    planner = PokeAccess::Routes::Planner
    real = planner.method(:walk)
    n = 0
    planner.define_singleton_method(:walk) { |*a| n += 1; real.call(*a) }
    [yield, n]
  ensure
    planner.define_singleton_method(:walk, real) if real
  end

  # Runs the block with the player taking a step, as on the frame it steps onto a tile.
  def moving
    $game_player.define_singleton_method(:moving?) { true }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :moving?) if $game_player.singleton_methods.include?(:moving?)
  end

  # One map frame of the guides, and how many guide chimes it played into the log.
  def cane_frame(log)
    before = log.count { |entry| cue_name(entry).start_with?("pa_guide") }
    guide_frame
    log.count { |entry| cue_name(entry).start_with?("pa_guide") } - before
  end
end
