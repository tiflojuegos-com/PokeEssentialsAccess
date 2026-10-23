# Marin's side stairs on the grid stub: a Slope event arms its end, crossed sideways onto the partner's tile in one
# press per tile; the step guide stays on the run, and the probe keeps no answer only partway along one.
class RouteRunsTest < PokeAccessTest
  # A stair from (2, 3) three tiles right and a row up to (5, 2), over the walls between; the player at (1, 3).
  STAIR = ["#########",
           "#########",
           "####....#",
           "#@..#####",
           "#########"].freeze

  test "a route crosses a side stair either way in one press per tile it runs sideways" do
    stair_map
    { [1, 3, 7, 2] => [6, 6, 6, 6, 6], [6, 2, 1, 3] => [4, 4, 4, 4] }.each do |(px, py, tx, ty), want|
      $game_player.x = px
      $game_player.y = py
      assert_equal want, walk_route(tx, ty), "from (#{px}, #{py}) to beside (#{tx}, #{ty}): a press onto an end, the run"
    end
  end

  test "the route key says the way over a stair as the presses it takes" do
    stair_map
    with_selected(chest) do |loc|
      loc.announce_route
      steps = PokeAccess::I18n.t(:loc_leg, :n => 5, :dir => PokeAccess::I18n.t(:dir_right))
      assert_equal [[PokeAccess::I18n.t(:loc_route, :steps => steps), true]], SpeakCapture.log
    end
  end

  test "the replay passes the stair's tiles partway along its run and lands on the partner's tile" do
    stair_map
    want = [[2, 3, false, :walk], [3, 3, true, :run], [4, 3, true, :run], [5, 2, false, :run], [6, 2, false, :walk]]
    assert_equal want, traced(1, 3, 0, [6, 6, 6, 6, 6]).map { |s| [s.x, s.y, s.mid, s.kind] }, "[x, y, mid, kind]"
  end

  test "each end of a stair sets off only toward the other, any other press there is a plain step" do
    stair_map
    want = { [2, 3, 6] => [5, 2, 0, 3, nil, false, false, :run], [2, 3, 4] => [1, 3, 0, 1, nil, false, false, :walk],
             [5, 2, 4] => [2, 3, 0, 3, nil, false, false, :run], [5, 2, 6] => [6, 2, 0, 1, nil, false, false, :walk] }
    assert_equal want, want.keys.each_with_object({}) { |(x, y, d), got| got[[x, y, d]] = step_from(x, y, d).to_a },
                 "[x, y, press] => the move it makes"
  end

  test "the slope comment is read wherever it stands in the event's list" do
    $game_map.load_grid(STAIR)
    slope(80, 2, 3, 3, -1, true)
    assert_equal [5, 2, 0, 3, nil, false, false, :run], step_from(2, 3, 6).to_a
  end

  test "a stair one tile long is one press onto its partner's tile" do
    short_stair_map(1)
    assert_equal [[3, 1, 0, 1, nil, false, false, :run]], traced(2, 2, 0, [6]).map { |s| s.to_a }
  end

  test "a slope comment with no tiles sideways arms no stair" do
    short_stair_map(0)
    assert_equal [1, 2, 0, 1, nil, false, false, :walk], step_from(2, 2, 4).to_a
  end

  test "a stair whose first step the map walls off is no way, and no press sets off on it" do
    $game_map.load_grid(["#########",
                         "#####...#",
                         "#@.######",
                         "#########"])
    slope(82, 2, 2, 3, -1)
    assert_nil walk_route(7, 1), "no route takes the stair"
    assert_nil step_from(2, 2, 6), "nor does a press"
  end

  test "the step guide says the run once and keeps quiet along the stair, up to the arrival" do
    stair_map
    steps_aim(PokeAccess::Locator, chest)
    said = [[1, 3], [2, 3], [3, 3], [4, 3], [5, 2], [6, 2]].map { |x, y| walk_to(PokeAccess::Locator, x, y) }
    leg = PokeAccess::I18n.t(:loc_leg, :n => 5, :dir => PokeAccess::I18n.t(:dir_right))
    assert_equal [[leg], [], [], [], [], [PokeAccess::I18n.t(:loc_arrived)]], said, "what it says on each tile walked"
  end

  test "standing on a stair's end, the step guide's checks of the way ahead plan nothing as the seconds pass" do
    stair_map
    steps_aim(PokeAccess::Locator, chest)
    walk_to(PokeAccess::Locator, 1, 3)
    walk_to(PokeAccess::Locator, 2, 3)
    plans = counting_plans { ticking_clock(6, PokeAccess::Guide::RECHECK_SEC + 0.1) { guide_frame } }
    assert_equal 0, plans
  end

  test "walked along the stair, the step guide has a press less left for each of its tiles" do
    stair_map
    steps_aim(PokeAccess::Locator, chest)
    left = [[1, 3], [2, 3], [3, 3], [4, 3], [5, 2]].map do |x, y|
      walk_to(PokeAccess::Locator, x, y)
      PokeAccess::Guide.remaining
    end
    assert_equal [[6, 6, 6, 6, 6], [6, 6, 6, 6], [6, 6, 6], [6, 6], [6]], left
  end

  test "the probe keeps no answer only partway along a stair, as each port of the plugin tells it" do
    {
      { :on_stair? => true, :on_middle_of_stair? => false } => true,
      { :on_stair? => true, :on_middle_of_stair? => true } => false,
      { :on_stair? => true } => false,
      { :on_stair? => false } => true,
      {} => true,
      { :on_middle_of_stair? => :raise } => true,
      nil => true
    }.each do |answers, want|
      got = as_player(answers) { PokeAccess::World::Probe.stable_now? }
      assert_equal want, got, "a player answering #{answers.inspect}"
    end
  end

  private

  # The stair map (STAIR) with both of its Slope events.
  def stair_map
    $game_map.load_grid(STAIR)
    slope(80, 2, 3, 3, -1)
    slope(81, 5, 2, -3, 1)
  end

  # A stair from (2, 2) a tiles right and a row up, a tile of floor past each end; the player at (1, 2).
  def short_stair_map(a)
    $game_map.load_grid(["######",
                         "###..#",
                         "#@..##",
                         "######"])
    slope(84, 2, 2, a, -1)
  end

  # A Slope event at (x, y) with its comments as the plugin reads them: the partner a tiles sideways and b rows down,
  # the width comment first with width_first.
  def slope(id, x, y, a, b, width_first = false)
    comments = [TestCmd.new(108, ["Slope: #{a}x#{b}"]), TestCmd.new(108, ["Width: 0/1"])]
    World.touch(:id => id, :name => "Slope", :x => x, :y => y, :trigger => 2,
                :list => width_first ? comments.reverse : comments)
  end

  # How many plans the planner is asked for while the block runs.
  def counting_plans
    pl = PokeAccess::Routes::Planner
    real = pl.method(:plan)
    n = 0
    pl.define_singleton_method(:plan) { |*a| n += 1; real.call(*a) }
    yield
    n
  ensure
    pl.define_singleton_method(:plan, real)
  end

  # Runs the block frames times with PokeAccess.clock moved on by secs before each, the real clock put back after.
  def ticking_clock(frames, secs)
    real = PokeAccess.method(:clock)
    now = [real.call]
    PokeAccess.define_singleton_method(:clock) { now[0] }
    frames.times do
      now[0] += secs
      yield
    end
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # The move a press toward d makes from (x, y), as the replay takes it.
  def step_from(x, y, d)
    pf = PokeAccess::Pathfinder
    pf.searching { PokeAccess::Routes::Moves.step(x, y, 0, PokeAccess::Routes::DIR_OF[d], pf.replay_mode) }
  end

  # The spot past the stair the step guide is aimed at.
  def chest
    PokeAccess::Locator::SurfaceTarget.new(7, 2, "cofre", :spot)
  end

  # Runs the block with target selected and the target list taken as current, nothing said yet; the block gets the
  # locator.
  def with_selected(target)
    loc = PokeAccess::Locator
    stale = loc.instance_variable_get(:@targets_stale)
    loc.instance_variable_set(:@target, target)
    loc.instance_variable_set(:@targets_stale, false)
    SpeakCapture.clear
    yield loc
  ensure
    loc.instance_variable_set(:@targets_stale, stale)
  end

  # Runs the block with a stand-in player answering the stair questions given (:raise for one that fails), or with no
  # player for nil.
  def as_player(answers)
    was = $game_player
    pl = answers && Object.new
    (answers || {}).each do |name, value|
      pl.define_singleton_method(name) { value == :raise ? raise("no stair state") : value }
    end
    $game_player = pl
    yield
  ensure
    $game_player = was
  end
end
