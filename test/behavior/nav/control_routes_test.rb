# Routes through a puzzle's controls with the assist (Routes::Controls), as in Pokemon Z's third gym: rays gone on a
# page needing a switch, controls that write it; the way walks to the first control to press, cut there, and says so.
class ControlRoutesTest < PokeAccessTest
  Planner = PokeAccess::Routes::Planner
  Controls = PokeAccess::Routes::Controls
  Mech = PokeAccess::World::Mechanics
  Text = PokeAccess::Routes::Text
  ROOM = ["#########",
          "#@......#",
          "#.#######",
          "#########"]
  # Two rays in a row, the second's plate in a nook between them: two presses, the plates in turn.
  TWO_PRESS = ["#########",
               "#@......#",
               "#.##.####",
               "#########"]
  # A plate at the end of a nook, open only to its left.
  NOOK = ["#########",
          "#@......#",
          "#.#######",
          "#..######",
          "#########"]
  # Two plates below the corridor, one under the start and one two tiles on.
  PAIRED = ["#########",
            "#@......#",
            "#.#.#####",
            "#########"]
  # A plate's pages as Pokemon Z's: the switch on and its self switch A on, or with A on both off.
  TOGGLE = [[0, nil, 0], [1, { :self_switch_valid => true, :self_switch_ch => "A" }, 1]].freeze

  test "finds no way past the closed rays without the assist" do
    gym_room
    assert_equal :none, Planner.plan(6, 1).kind
  end

  test "routes to the plate that opens the rays, cut before stepping onto it" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [], :control, [1, 2], true], plan_shape(Planner.plan(6, 1))
  end

  test "says the plate as the one to step onto, below" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:loc_control_step, :what => t(:gym3_red), :dir => t(:side_down)),
                 Text.hold(Planner.plan(6, 1).gate, 1, 1)
  end

  test "says in the route's line what opens the way" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    steps = "#{t(:loc_next_to)}; #{t(:loc_control_route, :what => t(:gym3_red))}"
    assert_equal t(:loc_route_gate, :what => t(:gym3_red), :steps => steps), Text.line(Planner.plan(6, 1))
  end

  test "seeks no press while the rays are down already" do
    gym_room
    $game_switches[142] = true
    PokeAccess::Config.puzzle_assist = true
    assert_nil press_route(6, 1)
  end

  test "takes the walls to depend on the switches their pages are conditioned on" do
    gym_room
    assert_equal({ [:switch, 142] => true }, Mech::Links.flags(Mech.instance))
  end

  test "finds no way through a plate that only sets the switch the way it stands" do
    raised_room([[0, nil]])
    PokeAccess::Config.puzzle_assist = true
    assert_equal :none, Planner.plan(6, 1).kind
  end

  test "routes to a plate that writes the switch both ways, which turns it off" do
    raised_room(TOGGLE)
    PokeAccess::Config.puzzle_assist = true
    with_self_switches([[43, "A"]]) do
      assert_equal [:assisted, [], :control, [1, 2], true], plan_shape(Planner.plan(6, 1))
    end
  end

  test "routes to the plate whose page turns the switch off, past one whose page sets it the way it stands" do
    paired_room
    PokeAccess::Config.puzzle_assist = true
    with_self_switches([[43, "A"]]) do
      assert_equal [:assisted, [6, 6], :control, [3, 2], true], plan_shape(Planner.plan(7, 1))
    end
  end

  test "standing on the plate, steps off it to step on again" do
    gym_room
    $game_player.y = 2
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [8], :control, [1, 2], true], plan_shape(Planner.plan(6, 1))
  end

  test "standing on the plate, says the step off it and then to step back onto it" do
    gym_room
    $game_player.y = 2
    PokeAccess::Config.puzzle_assist = true
    back = t(:loc_control_step, :what => t(:gym3_red), :dir => t(:side_down))
    opens = t(:loc_control_route, :what => t(:gym3_red))
    assert_equal "#{t(:loc_route, :steps => t(:loc_leg, :n => 1, :dir => t(:dir_up)))}; #{back}; #{opens}",
                 Text.line(Planner.plan(6, 1), [1, 2])
  end

  test "standing on a plate open only to one side, steps off that way to step on again" do
    lay(NOOK)
    control(43, 2, 3, [[0, nil]])
    rays(20, 4, 1)
    declare
    $game_player.x = 2
    $game_player.y = 3
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [4], :control, [2, 3], true], plan_shape(Planner.plan(6, 1))
  end

  test "standing on the plate, steps off it onto a tile that is no other control of the puzzle when there is one" do
    lay(["#########",
         "#.......#",
         "#..######",
         "#########"])
    control(43, 1, 2, [[0, nil]])
    control(44, 1, 1, [[0, nil]], 1, "", 150)
    rays(20, 4, 1)
    declare([watch(142, :gym3_red), watch(150, :gym3_blue)])
    $game_player.x = 1
    $game_player.y = 2
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [6], :control, [1, 2], true], plan_shape(Planner.plan(6, 1))
  end

  test "standing on the plate whose only way off is onto another control, steps off onto it all the same" do
    lay(["#########",
         "#.......#",
         "#.#######",
         "#########"])
    control(43, 1, 2, [[0, nil]])
    control(44, 1, 1, [[0, nil]], 1, "", 150)
    rays(20, 4, 1)
    declare([watch(142, :gym3_red), watch(150, :gym3_blue)])
    $game_player.x = 1
    $game_player.y = 2
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [8], :control, [1, 2], true], plan_shape(Planner.plan(6, 1))
  end

  test "takes a plate touched by the player or by an event, or drawn and walked over, for one stepped onto" do
    { "touched by the player" => [1, "", false], "touched by an event" => [2, "", false],
      "drawn and walked over" => [1, "losa", true] }.each do |what, (trigger, sprite, through)|
      lay
      plate = control(43, 1, 2, [[0, nil]], trigger, sprite)
      plate.through = through
      rays(20, 4, 1)
      declare
      PokeAccess::Config.puzzle_assist = true
      assert_equal [:assisted, [], :control, [1, 2], true], plan_shape(Planner.plan(6, 1)), what
    end
  end

  test "routes to stand beside a lever, to face it and press it" do
    lever_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [], :control, [1, 2], false], plan_shape(Planner.plan(6, 1))
  end

  test "says the lever as the one to face and press, below" do
    lever_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:loc_control_press, :what => t(:gym3_red), :dir => t(:side_down)),
                 Text.hold(Planner.plan(6, 1).gate, 1, 1)
  end

  test "finds a way of several presses, the plates in turn, starting with the one in reach" do
    two_press_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:assisted, [], :control, [1, 2], true], plan_shape(Planner.plan(7, 1))
  end

  test "says in the route's line how many presses open the way and which, in turn" do
    two_press_room
    PokeAccess::Config.puzzle_assist = true
    plan = Planner.plan(7, 1)
    presses = t(:loc_control_presses, :n => 2, :what => "#{t(:gym3_red)}, #{t(:gym3_blue)}")
    assert_equal "#{Text.hold(plan.gate, 1, 1)}; #{presses}", Text.line(plan, [1, 1])
  end

  test "finds a way of as many presses as its depth allows" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    way = with_limit(:DEPTH, 1) { press_route(6, 1) }
    assert_equal [[], [1, 2]], way_shape(way)
  end

  test "seeks no way of more presses than its depth" do
    two_press_room
    PokeAccess::Config.puzzle_assist = true
    with_limit(:DEPTH, 1) { assert_nil press_route(7, 1) }
  end

  test "walks on while the tiles its presses walked come to no more than its allowance" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    way = with_limit(:VISITS, 4) { press_route(6, 1) }
    assert_equal [[], [1, 2]], way_shape(way), "the four tiles reached before the press are the allowance"
  end

  test "cuts the press search once the tiles its presses walked pass its allowance" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    assert_equal [nil, 1], with_limit(:VISITS, 3) { press_search(6, 1) }
  end

  test "seeks no press, and so is never cut, when no control writes a switch the walls depend on" do
    lay
    control(43, 1, 2, [[0, nil]], 1, "", 150)
    rays(20, 4, 1)
    declare([watch(142, :gym3_red), watch(150, :gym3_blue)])
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1
    assert_equal [nil, 0], press_search(6, 1)
  end

  test "finds no way through a lever that stands past the rays it lowers" do
    lay
    control(43, 6, 1, [[0, nil]], 0, "lever")
    rays(20, 4, 1)
    declare
    PokeAccess::Config.puzzle_assist = true
    assert_nil press_route(7, 1)
  end

  test "finds no way to press the plate underfoot again with no tile to step off it to" do
    lay(["#####",
         "#@..#",
         "#####"])
    control(43, 1, 1, [[0, nil]])
    rays(20, 2, 1)
    declare
    PokeAccess::Config.puzzle_assist = true
    assert_nil press_route(3, 1)
  end

  test "stops a press search past its deadline as a cut" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Config.route_limit = :time
    PokeAccess::Config.route_budget_ms = -1
    assert_equal [nil, 1], press_search(6, 1)
  end

  test "gives no way to a control beyond the route's reach" do
    gym_room
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Config.route_reach = 0
    assert_nil press_route(6, 1)
  end

  test "seeks no press on a map whose mechanic declares no walls" do
    lay
    control(43, 1, 2, [[0, nil]])
    rays(20, 4, 1)
    Mech.declare($game_map.map_id, :kind => :state, :watch => [watch(142, :gym3_red)], :controls => true)
    Mech.forget
    PokeAccess::Config.puzzle_assist = true
    assert_nil press_route(6, 1)
  end

  test "seeks no press on a map with no mechanic" do
    lay
    control(43, 1, 2, [[0, nil]])
    rays(20, 4, 1)
    PokeAccess::Config.puzzle_assist = true
    assert_nil press_route(6, 1)
  end

  private

  # A text of the mod's.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A plan as [kind, route, gate kind, gate tile, whether the gate is stepped onto].
  def plan_shape(plan)
    g = plan.gate || {}
    [plan.kind, plan.route, g[:kind], [g[:x], g[:y]], g[:step]]
  end

  # The way to the first control to press toward (tx, ty), asked as the planner asks it.
  def press_route(tx, ty)
    PokeAccess::Pathfinder.searching { Controls.route(Planner.goal_for(tx, ty, false)) }
  end

  # The way to the first control to press toward (tx, ty) and the cuts its search made, as [way, cuts].
  def press_search(tx, ty)
    PokeAccess::Pathfinder.searching { |l| [Controls.route(Planner.goal_for(tx, ty, false)), l.cuts] }
  end

  # A way to press a control as [steps, the control's tile], or nil for none.
  def way_shape(way)
    way && [way[0], [way[1][:x], way[1][:y]]]
  end

  # Lays rows out, the player on '@'.
  def lay(rows = ROOM)
    $game_map.load_grid(rows)
  end

  # A control on (x, y), event id: its pages write switch as listed ([value, condition, the value of its self switch
  # A or nil] each, 0 on and 1 off), fired with trigger and drawn with sprite, solid when drawn.
  def control(id, x, y, writes, trigger = 1, sprite = "", switch = 142)
    pages = writes.map do |v, cond, own|
      list = [TestCmd.new(121, [switch, switch, v])]
      list.push(TestCmd.new(123, ["A", own])) if own
      TestPage.new(:trigger => trigger, :sprite => sprite, :list => list, :condition => cond || {})
    end
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages)
    ev.blocking = !sprite.empty?
    $game_map.events[id] = ev
  end

  # Rays across the way on (x, y), event id: drawn by default and gone on a page needing switch.
  def rays(id, x, y, switch = 142)
    gone = TestPage.new(:trigger => 0, :sprite => "", :condition => { :switch1_valid => true, :switch1_id => switch })
    pages = [TestPage.new(:trigger => 0, :sprite => "rayosR"), gone]
    wall = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages)
    wall.blocking = true
    $game_map.events[id] = wall
  end

  # A watch entry of the declaration: a switch and its label.
  def watch(switch, label)
    { :switch => switch, :label => label, :on => :gym3_on, :off => :gym3_off }
  end

  # Declares the room's mechanic: the switches watched with their labels, its controls, and the rays as its walls.
  def declare(watched = [watch(142, :gym3_red)])
    Mech.declare($game_map.map_id, :kind => :state, :watch => watched, :controls => true,
                 :obstacles => [{ :match => /rayos/i, :kind => :wall }])
    Mech.forget
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # The gym's room: the plate below the start (event 43), the rays across the corridor (event 20), switch 142 off.
  def gym_room
    lay
    control(43, 1, 2, [[0, nil]])
    rays(20, 4, 1)
    declare
  end

  # The room with a lever below the start, worked with the action button, in the plate's place.
  def lever_room
    lay
    control(43, 1, 2, [[0, nil]], 0, "lever")
    rays(20, 4, 1)
    declare
  end

  # The room with rays raised while switch 142 is on, as it is, and the plate writing it as listed.
  def raised_room(writes)
    lay
    control(43, 1, 2, writes)
    raised_rays(4, 1)
    $game_switches[142] = true
    declare
  end

  # The PAIRED room with rays raised while switch 142 is on, as it is, past its two plates (events 41 and 43), which
  # write it as Pokemon Z's do (TOGGLE).
  def paired_room
    lay(PAIRED)
    control(41, 1, 2, TOGGLE)
    control(43, 3, 2, TOGGLE)
    raised_rays(5, 1)
    $game_switches[142] = true
    declare
  end

  # Rays across the way on (x, y), event 20, raised while switch 142 is on.
  def raised_rays(x, y)
    raised = TestGameEvent.new(:id => 20, :x => x, :y => y,
                               :pages => [TestPage.new(:trigger => 0, :sprite => "rayosRojosV",
                                                       :condition => { :switch1_valid => true, :switch1_id => 142 })])
    raised.blocking = true
    $game_map.events[20] = raised
  end

  # Runs the block with only the self switches listed ([event id, letter] each) on, the game's own put back after.
  def with_self_switches(on)
    was = $game_self_switches
    $game_self_switches = {}
    on.each { |id, ch| $game_self_switches[[$game_map.map_id, id, ch]] = true }
    yield
  ensure
    $game_self_switches = was
  end

  # Two rays in a row (switches 142 and 143) and their plates, the second's past the first rays.
  def two_press_room
    lay(TWO_PRESS)
    control(43, 1, 2, [[0, nil]])
    control(44, 4, 2, [[0, nil]], 1, "", 143)
    rays(20, 3, 1)
    rays(21, 5, 1, 143)
    declare([watch(142, :gym3_red), watch(143, :gym3_blue)])
  end

  # Runs the block with one of the search's limits (DEPTH: the most presses a way may take, VISITS: the most tiles
  # the presses may walk in all) set to value.
  def with_limit(name, value)
    was = Controls.const_get(name)
    Controls.send(:remove_const, name)
    Controls.const_set(name, value)
    yield
  ensure
    Controls.send(:remove_const, name)
    Controls.const_set(name, was)
  end
end
