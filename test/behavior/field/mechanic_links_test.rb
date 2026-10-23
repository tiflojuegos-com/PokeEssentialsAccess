# What a control does to its mechanic's walls, read off their pages as in Pokemon Z's third gym (Mechanics::Links),
# and how Puzzles says it: each flip with the walls it moved and, with the assist, what each control would do.
class MechanicLinksTest < PokeAccessTest
  # The red plate's watch entry: switch 142.
  RED = { :switch => 142, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off }
  # The ship's crank: variable 132.
  CRANK = { :var => 132, :label => :ship_crank_red, :on => :ship_crank_on, :off => :ship_crank_off }
  # The page conditions of the gym's walls.
  ALWAYS = {}
  ON_141 = { :switch1_valid => true, :switch1_id => 141 }
  ON_142 = { :switch1_valid => true, :switch1_id => 142 }
  # A page graphic drawn from the tileset (a tile id, no sprite).
  TileGraphic = Struct.new(:character_name, :pattern, :tile_id)

  test "flipping a switch opens the walls drawn without it and raises those drawn only with it, leaving the rest" do
    red_rays
    assert_equal [[20, :open], [39, :close]], effects(RED)
  end

  test "with the switch on, flipping it does the same the other way round" do
    red_rays
    $game_switches[142] = true
    assert_equal [[20, :close], [39, :open]], effects(RED)
  end

  test "an erased wall is gone for good" do
    red_rays[0].instance_variable_set(:@erased, true)
    assert_equal [[39, :close]], effects(RED)
  end

  test "a wall up neither before nor after the flip is left out, shown by no page or by one walked through" do
    ghost = wall(30, 3, 3, [[ON_141, "rayos"], [ON_142, "rayos"]])
    ghost.instance_variable_get(:@event).pages[1].through = true
    mech.define(:state, $game_map.map_id) { obstacle(/rayos/i) }
    assert_equal [], effects(RED), "the switch off: no page shown, then one walked through"
    $game_switches[142] = true
    assert_equal [], effects(RED), "the switch on: walked through, then no page shown"
  end

  test "each change names the wall taken down or put up by the label declared for it" do
    red_rays(:labels)
    assert_equal [[20, :open, :gym3_rays_red], [39, :close, :gym3_rays_red_v]],
                 links.effects(mech.instance, RED).map { |ev, what, label| [ev.id, what, label] }.sort
  end

  test "a moving obstacle is no wall" do
    red_rays(:moving)
    assert_equal [], effects(RED)
  end

  test "a variable is on from 1: turning the crank lets the jet through, and back stops it" do
    turned = { :variable_valid => true, :variable_id => 132, :variable_value => 1 }
    jet = wall(9, 28, 35, [[ALWAYS, "humo"], [turned, "humo"]])
    jet.instance_variable_get(:@event).pages[1].through = true
    mech.define(:state, $game_map.map_id) do
      watch CRANK
      obstacle(/humo/i)
    end
    assert_equal [[9, :open]], effects(CRANK), "the crank at 0"
    $game_variables[132] = 1
    assert_equal [[9, :close]], effects(CRANK), "the crank at 1"
  end

  test "a wall stands where the last page whose conditions all hold draws it" do
    with_self_switches do
      $game_switches[142] = true
      $game_switches[51] = true
      $game_variables[7] = 3
      $game_variables[8] = 2
      $game_self_switches[[$game_map.map_id, 6, "A"]] = true
      condition_walls
      assert_equal blocking(1, 3, 4, 6, 8), links.blocked(mech.instance, {}),
                   "drawn: switch 142; 142 and 51 on; variable 7 at 3; self switch A; a page with no conditions; " \
                   "not: 142 with 50 off, variable 8 at 2, self switch B off, a page walked through"
    end
  end

  test "a press can change a wall only by the switches and variables its pages test, self switches aside" do
    condition_walls
    assert_equal({ [:switch, 142] => true, [:switch, 50] => true, [:switch, 51] => true, [:var, 7] => true,
                   [:var, 8] => true },
                 links.flags(mech.instance))
  end

  test "a wall drawn from the tileset stands as one with a sprite" do
    gate = wall(10, 10, 1, [[ALWAYS, "rayos"], [ON_142, ""]])
    gate.instance_variable_get(:@event).pages[0].through = true
    gate.instance_variable_get(:@event).pages[1].graphic = TileGraphic.new("", 0, 400)
    $game_switches[142] = true
    mech.define(:state, $game_map.map_id) { obstacle(/rayos/i) }
    assert_equal blocking(10), links.blocked(mech.instance, {})
  end

  test "a wall goes by its declared name, and one declared without a name by the locator's own" do
    room = gym_room
    assert_equal t(:gym3_rays_red), PokeAccess::Locator.target_name(room[:gone][0]), "the red rays"
    assert_equal "humo", PokeAccess::Locator.target_name(room[:jet]), "the jet, by its sprite"
  end

  test "a flip is said with the walls that went, then those that came, a group a label in the order declared" do
    flip_red_plate(gym_room)
    line = ["#{t(:gym3_red)}: #{t(:gym3_on)}", group(:gym3_rays_red, :ctrl_quit, 2),
            group(:obstacle_group, :ctrl_quit, 1), group(:gym3_rays_red_v, :ctrl_rise, 1)].join(". ")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a wall the flip puts up goes by its declared name" do
    room = gym_room
    flip_red_plate(room)
    assert_equal t(:gym3_rays_red_v), PokeAccess::Locator.target_name(room[:raised])
  end

  test "a flip that changes no wall says the flag alone" do
    gym_room
    puzzles.tick
    $game_switches[147] = true
    SpeakCapture.clear
    puzzles.tick
    assert_equal [["#{t(:gym3_power)}: #{t(:gym3_power_on)}", false]], SpeakCapture.log
  end

  test "without the assist the info key says each watched flag's state" do
    flip_red_plate(gym_room)
    assert_equal "#{t(:gym3_red)}: #{t(:gym3_on)}. #{t(:gym3_power)}: #{t(:gym3_power_off)}", puzzles.info_line
  end

  test "with the assist the info key adds the hint and what each control would do, a flag no control writes left out" do
    flip_red_plate(gym_room)
    PokeAccess::Config.puzzle_assist = true
    flags = "#{t(:gym3_red)}: #{t(:gym3_on)}. #{t(:gym3_power)}: #{t(:gym3_power_off)}"
    plate = t(:ctrl_hint, :what => t(:gym3_red),
                          :changes => [group(:gym3_rays_red_v, :ctrl_quit, 1), group(:gym3_rays_red, :ctrl_rise, 2),
                                       group(:obstacle_group, :ctrl_rise, 1)].join(". "))
    assert_equal "#{flags}. #{t(:gym3_hint)} #{plate}", puzzles.info_line, "the hint's own stop kept, none doubled"
  end

  test "with the assist a room without walls adds its hint alone" do
    mech.define(:state, $game_map.map_id) do
      watch RED
      hint :gym3_hint
    end
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:gym3_red)}: #{t(:gym3_off)}. #{t(:gym3_hint)}", puzzles.info_line
  end

  private

  # The modules under test.
  def mech; PokeAccess::World::Mechanics; end
  def links; PokeAccess::World::Mechanics::Links; end
  def puzzles; PokeAccess::Puzzles; end

  # A spoken text by its key.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # What a control would do to one label's walls, as Puzzles words it.
  def group(label, part, n)
    t(:ctrl_group, :what => t(label), :changes => t(part, :n => n))
  end

  # The [event id, :open | :close] each wall would go through if watch entry w's flag flipped now.
  def effects(w)
    links.effects(mech.instance, w).map { |ev, what, _label| [ev.id, what] }.sort
  end

  # An event on the map with the given pages, each [condition, sprite].
  def wall(id, x, y, pages)
    pgs = pages.map { |cond, sprite| TestPage.new(:trigger => 0, :sprite => sprite, :condition => cond) }
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pgs)
  end

  # A wall at (x, 1) open on its first page and drawn on a second page gated by cond.
  def gated(x, cond)
    wall(x, x, 1, [[ALWAYS, ""], [cond, "rayos"]])
  end

  # The tiles (x, 1) blocked, as the routes look them up: the routes' tile key => true.
  def blocking(*xs)
    xs.map { |x| [PokeAccess::World::Events.key(x, 1), true] }.to_h
  end

  # Walls at (1..9, 1), declared, each drawn on a second page gated by: switch 142; 142 and switch 50; 142 and switch
  # 51; variable 7 at 3 or more; variable 8 at 3 or more; self switch A; self switch B; no conditions object at all;
  # nothing, but walked through.
  def condition_walls
    gated(1, ON_142)
    gated(2, ON_142.merge(:switch2_valid => true, :switch2_id => 50))
    gated(3, ON_142.merge(:switch2_valid => true, :switch2_id => 51))
    gated(4, :variable_valid => true, :variable_id => 7, :variable_value => 3)
    gated(5, :variable_valid => true, :variable_id => 8, :variable_value => 3)
    gated(6, :self_switch_valid => true, :self_switch_ch => "A")
    gated(7, :self_switch_valid => true, :self_switch_ch => "B")
    gated(8, ALWAYS).instance_variable_get(:@event).pages[1].condition = nil
    gated(9, ALWAYS).instance_variable_get(:@event).pages[1].through = true
    mech.define(:state, $game_map.map_id) { obstacle(/rayos/i) }
  end

  # The gym's red rays, gone on a page needing switch 142; its red vertical rays, drawn only on such a page; and a
  # blue barrier on switch 141, declared as walls (with :labels, each by its name; with :moving, as movers). The red
  # rays come first.
  def red_rays(how = nil)
    down = wall(20, 13, 15, [[ALWAYS, "rayosR"], [ON_142, ""]])
    up = wall(39, 12, 15, [[ON_142, "rayosRojosV"]])
    wall(12, 9, 14, [[ALWAYS, "rayosBarrera"], [ON_141, ""]])
    mech.define(:state, $game_map.map_id) do
      watch RED
      controls
      if how == :labels
        obstacle(/\ArayosR\z/i, :label => :gym3_rays_red)
        obstacle(/\ArayosRojosV\z/i, :label => :gym3_rays_red_v)
      end
      obstacle(/rayos/i, :moving => how == :moving)
    end
    [down, up]
  end

  # The gym's red room as the game lays it out: the red plate (event 43, writing switch 142), two red rays it takes
  # down, a red vertical ray it puts up (not drawn yet) and a jet it stops, declared with the Regent's power switch
  # (147), which no event on the map writes, and the gym's hint. The jet's id comes first, so the order heard is the
  # declaration's, not the events'. The locator's levers, kept per map id, are taken afresh from these events.
  def gym_room
    plate = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [142, 142, 0])])
    $game_map.events[43] = TestGameEvent.new(:id => 43, :x => 10, :y => 17, :pages => [plate])
    gone = [20, 21].map { |id| wall(id, id - 7, 15, [[ALWAYS, "rayosR"], [ON_142, ""]]) }
    raised = wall(39, 12, 15, [[ON_142, "rayosRojosV"]])
    raised.character_name = ""
    jet = wall(10, 2, 2, [[ALWAYS, "humo"], [ON_142, ""]])
    mech.define(:state, $game_map.map_id) do
      watch :switch => 142, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off
      watch :switch => 147, :label => :gym3_power, :on => :gym3_power_on, :off => :gym3_power_off
      controls
      obstacle(/\ArayosR\z/i, :label => :gym3_rays_red)
      obstacle(/\ArayosRojosV\z/i, :label => :gym3_rays_red_v)
      obstacle(/humo/i)
      hint :gym3_hint
    end
    PokeAccess::Locator.refresh_lever_cache
    { :gone => gone, :raised => raised, :jet => jet }
  end

  # Steps on the red plate in the gym room: a frame takes the room as it is, switch 142 goes on and the walls show
  # their new pages; the frame after says the flip (the speech before it cleared).
  def flip_red_plate(room)
    puzzles.tick
    $game_switches[142] = true
    room[:gone].each { |ev| ev.character_name = "" }
    room[:jet].character_name = ""
    room[:raised].character_name = "rayosRojosV"
    World.next_frame
    SpeakCapture.clear
    puzzles.tick
  end

  # Runs the block with the game's self switches as an empty table, put back after.
  def with_self_switches
    was = $game_self_switches
    $game_self_switches = {}
    yield
  ensure
    $game_self_switches = was
  end
end
