# Pieces that move a tile the way the player faces when walked into (Effects.self_push_dirs, Pokemon Z's Pikachu):
# pushed only the ways they go, and with the puzzle assist carried into a phase's goal (Planner.carry), cut at a push.
class CarryTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Planner = PokeAccess::Routes::Planner
  # A piece's branches as [facing, [[character, move codes], ...]]: here one per facing, stepping it one tile that way.
  ONE_STEP = [[2, [[0, [1, 0]]]], [4, [[0, [2, 0]]]], [6, [[0, [3, 0]]]], [8, [[0, [4, 0]]]]]
  ROOM = ["#########",
          "#@......#",
          "#.......#",
          "#########"]
  ZONE = [6, 1, 7, 2]

  test "pushes a piece every way one of its branches steps it" do
    assert_equal [2, 4, 6, 8], Effects.self_push_dirs(pikachu(16, 3, 1))
  end

  test "takes a piece that only rolls several tiles for no pushed piece" do
    roller = pikachu(18, 5, 1, [[4, [[0, [2, 2, 2, 0]]]], [6, [[0, [3, 3, 3, 0]]]]])
    assert_equal [[], false], [Effects.self_push_dirs(roller), Effects.self_pushed?(roller)]
  end

  test "takes a single step among other move commands for a push" do
    assert_equal [6], Effects.self_push_dirs(pikachu(17, 3, 1, [[6, [[0, [37, 29, 3, 38, 0]]]]]))
  end

  test "takes a branch that carries the player along for no push" do
    assert_equal [], Effects.self_push_dirs(pikachu(17, 3, 1, [[8, [[-1, [3, 3, 0]], [0, [4, 0]]]]]))
  end

  test "takes a branch that only turns the player for a push" do
    assert_equal [6], Effects.self_push_dirs(pikachu(19, 7, 1, [[6, [[-1, [16, 0]], [0, [3, 0]]]]]))
  end

  test "takes a branch with a route of its own beside the step for a push, as a boulder dropping into lava" do
    assert_equal [4], Effects.self_push_dirs(pikachu(20, 9, 1, [[4, [[0, [37, 14, 38, 0]], [0, [2, 0]]]]]))
  end

  test "takes a branch that steps another event, the piece staying put, for no push" do
    list = [TestCmd.new(111, [6, -1, 6], 0), TestCmd.new(209, [5, route(3)], 1), TestCmd.new(0, [], 1),
            TestCmd.new(412, [], 0)]
    assert_equal [], Effects.self_push_dirs(World.touch(:id => 29, :x => 3, :y => 1, :list => list))
  end

  test "takes no branch on another character's facing for a push" do
    list = [TestCmd.new(111, [6, 3, 6], 0), TestCmd.new(209, [0, route(3)], 1), TestCmd.new(0, [], 1),
            TestCmd.new(412, [], 0)]
    assert_equal [], Effects.self_push_dirs(World.touch(:id => 21, :x => 3, :y => 1, :list => list))
  end

  test "counts a facing branched on twice as one way" do
    branch = [TestCmd.new(111, [6, -1, 6], 0), TestCmd.new(209, [0, route(3)], 1), TestCmd.new(0, [], 1),
              TestCmd.new(412, [], 0)]
    assert_equal [6], Effects.self_push_dirs(World.touch(:id => 22, :x => 3, :y => 1, :list => branch + branch))
  end

  test "reads a facing branch up to its else, whatever the else does with the player" do
    list = [TestCmd.new(111, [6, -1, 8], 0), TestCmd.new(209, [0, route(4)], 1), TestCmd.new(0, [], 1),
            World.else_(0), TestCmd.new(209, [-1, route(2)], 1), TestCmd.new(0, [], 1), World.end_(0)]
    assert_equal [8], Effects.self_push_dirs(World.touch(:id => 28, :x => 3, :y => 1, :list => list))
  end

  test "reads a branch that runs to the end of a list with no terminator" do
    page = TestPage.new(:trigger => 1, :list => [TestCmd.new(111, [6, -1, 6], 0), TestCmd.new(209, [0, route(3)], 1)])
    assert_equal [6], Effects.self_push_dirs(TestGameEvent.new(:id => 23, :x => 3, :y => 1, :pages => [page]))
  end

  test "takes a piece fired by its own touch for one, but none worked with the action button" do
    { 1 => [2, 4, 6, 8], 2 => [2, 4, 6, 8], 0 => [] }.each do |trigger, dirs|
      assert_equal dirs, Effects.self_push_dirs(pikachu(24 + trigger, 3, 1, ONE_STEP, trigger)), "trigger #{trigger}"
    end
  end

  test "takes an event with no command list for no such piece" do
    ev = pikachu(27, 3, 1)
    ev.instance_variable_set(:@list, nil)
    assert_equal [], Effects.self_push_dirs(ev)
  end

  test "tells the field move each pushable needs, none for a piece that moves itself" do
    { "a boulder its script pushes" => [scripted(30, "pbPushThisBoulder"), [:STRENGTH]],
      "an event its script pushes" => [scripted(31, "pbPushThisEvent"), [nil]],
      "a piece that moves itself" => [pikachu(32, 3, 1), [nil]],
      "a boulder by its name" => [World.event(:id => 33, :name => "Boulder", :sprite => "boulder"), [:STRENGTH]],
      "a person" => [World.event(:id => 34, :name => "Paco", :sprite => "NPC 01"), nil] }.each do |what, (ev, move)|
      if move
        assert_equal move, Effects.push_move(ev), what
      else
        assert_nil Effects.push_move(ev), what
      end
    end
  end

  test "routes no push of a piece the way it does not go" do
    corridor
    pikachu(19, 3, 1, [[8, [[0, [4, 0]]]]])
    assert_nil Planner.assisted(5, 1)
  end

  test "routes the push of a piece the way it goes, stopping beside it" do
    corridor
    pikachu(20, 3, 1, [[6, [[0, [3, 0]]]]])
    g = Planner.assisted(5, 1)
    assert_equal [[6], :field, [3, 1], nil], [g[0], g[1][:kind], [g[1][:x], g[1][:y]], g[1][:move]]
  end

  test "carries a piece toward its zone: a step to stand behind it, then the first push" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    plan = Planner.carry(pika, ZONE)
    assert_equal [:assisted, [6], :field, [3, 1], nil],
                 [plan.kind, plan.route, plan.gate[:kind], [plan.gate[:x], plan.gate[:y]], plan.gate[:move]]
  end

  test "names the first push as the locator names the piece, toward the way it goes" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    t = PokeAccess::I18n
    assert_equal t.t(:loc_gate_push, :what => PokeAccess::Locator.target_name(pika), :dir => t.t(:side_right),
                                     :toward => t.t(:toward_right)),
                 PokeAccess::Routes::Text.hold(Planner.carry(pika, ZONE).gate, 2, 1)
  end

  test "has nothing left to do with the piece inside its zone" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    pika.x = 6
    plan = Planner.carry(pika, ZONE)
    assert_equal [:walk, []], [plan.kind, plan.route]
  end

  test "finds no way into a zone no push reaches" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    assert_equal :none, Planner.carry(pika, [3, 0, 3, 0]).kind
  end

  test "finds no way, not a cut one, for a piece no push takes off the map's top row, in a room past the states a " \
       "search may take" do
    $game_map.load_grid(["#....@" + "." * 39 + "#"] + Array.new(44) { "#" + "." * 44 + "#" } + ["#" * 46])
    pika = pikachu(16, 4, 0)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :none, Planner.carry(pika, [20, 20, 21, 21]).kind
  end

  test "makes no carry plan for a piece the player cannot push" do
    room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    npc = World.event(:id => 40, :x => 4, :y => 2, :sprite => "NPC 01")
    assert_equal :none, Planner.carry(npc, ZONE).kind
  end

  test "answers a carry asked again from the plan it kept" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    first = Planner.carry(pika, ZONE)
    assert_same first.gate, Planner.carry(pika, ZONE).gate
  end

  test "cuts the pushes the deadline stops instead of telling no way" do
    pika = room_with_pikachu
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = 0
    assert_equal :cut, Planner.carry(pika, ZONE).kind
  end

  test "lists no goal for the tracked piece without the assist" do
    tracked_room
    assert_equal [], goal_targets
  end

  test "lists the phase's goal for the tracked piece with the assist" do
    tracked_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[6, 1, "Meta", 16]], goal_targets.map { |g| [g.x, g.y, g.name, g.ref] }
  end

  test "routes the goal target as the pushes that carry the piece into it" do
    tracked_room
    PokeAccess::Config.puzzle_assist = true
    plan = PokeAccess::Locator.route_plan(goal_targets[0])
    assert_equal [:assisted, [6], [3, 1]], [plan.kind, plan.route, [plan.gate[:x], plan.gate[:y]]]
  end

  test "lists the goal target with how far the piece still is from it, not as blocked by the piece" do
    tracked_room
    PokeAccess::Config.puzzle_assist = true
    t = PokeAccess::I18n
    piece = t.t(:puzzle_track_goal, :label => "Pikachu", :dist => "3 #{t.t(:dir_right)}", :goal => "Meta")
    assert_equal ", " + piece, PokeAccess::Locator.route_phrase(goal_targets[0])[1]
  end

  test "makes no carry plan without the assist" do
    tracked_room
    PokeAccess::Config.puzzle_assist = true
    goal = goal_targets[0]
    PokeAccess::Config.puzzle_assist = false
    assert_nil PokeAccess::Puzzles.carry_plan(goal)
  end

  test "makes no carry plan for a target other than the goal" do
    tracked_room
    PokeAccess::Config.puzzle_assist = true
    spot = PokeAccess::Locator::SurfaceTarget.new(6, 1, "Meta", :puzzle_spot, 16)
    assert_nil PokeAccess::Puzzles.carry_plan(spot)
  end

  private

  # The Pikachu on (x, y), touched with trigger: solid, moving when the grid tile beyond it is open; ways lists, for
  # each facing it branches on, the move routes of that branch as [character, move codes].
  def pikachu(id, x, y, ways = ONE_STEP, trigger = 1)
    list = []
    ways.each do |d, routes|
      list.push(TestCmd.new(111, [6, -1, d], 0))
      routes.each do |who, codes|
        list.push(TestCmd.new(209, [who, TestMoveRoute.new(codes.map { |k| TestMoveCmd.new(k) })], 1))
      end
      list.push(TestCmd.new(0, [], 1))
      list.push(TestCmd.new(412, [], 0))
    end
    ev = World.touch(:id => id, :name => "pikachu", :x => x, :y => y, :trigger => trigger, :sprite => "025",
                     :list => list)
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      return true if through
      !$game_map.blocked?(x + (d == 6 ? 1 : (d == 4 ? -1 : 0)), y + (d == 2 ? 1 : (d == 8 ? -1 : 0)))
    end
    ev
  end

  # A move route of the given codes.
  def route(*codes)
    TestMoveRoute.new(codes.map { |k| TestMoveCmd.new(k) } + [TestMoveCmd.new(0)])
  end

  # An action-button event whose script line is script.
  def scripted(id, script)
    page = TestPage.new(:trigger => 0, :sprite => "boulder", :list => [TestCmd.new(355, [script])])
    ev = TestGameEvent.new(:id => id, :x => 4, :y => 2, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A one-row corridor with the player at its west end.
  def corridor
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
  end

  # The room with the player at its top left and the Pikachu (event 16) on (3, 1).
  def room_with_pikachu
    $game_map.load_grid(ROOM)
    pikachu(16, 3, 1)
  end

  # The room with the Pikachu tracked by a phase of the map's mechanic, its goal the zone, labelled Meta.
  def tracked_room
    room_with_pikachu
    PokeAccess::World::Mechanics.declare($game_map.map_id, :kind => :state,
                                         :phases => [{ :when => lambda { true },
                                                       :track => { :event => 16, :label => "Pikachu", :goal => ZONE,
                                                                   :goal_label => "Meta" } }])
    PokeAccess::World::Mechanics.forget
  end

  # The puzzle category's goal targets.
  def goal_targets
    PokeAccess::Puzzles.category_targets.select do |x|
      x.is_a?(PokeAccess::Locator::SurfaceTarget) && x.key == :puzzle_goal
    end
  end
end
