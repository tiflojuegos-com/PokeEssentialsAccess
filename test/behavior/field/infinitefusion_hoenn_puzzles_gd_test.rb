# Pokemon Infinite Fusion Hoenn's Mauville Gym (games/infinitefusion_hoenn/puzzles/mauville_gym.rb): the four floor switches are
# named by the layout they build, the fences are walls by name, and the layout in force is said when a switch changes it.
# Gamedata pass.
class InfinitefusionHoennPuzzlesGdTest < PokeAccessTest
  MAP = 102
  SWITCHES = { 8 => [10, 23], 20 => [13, 15], 18 => [14, 19], 21 => [20, 15] }

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    [6, 2198].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the floor switches are named by colour, the fences are walls, and the layout is said when it changes" do
    on_map
    SWITCHES.each { |id, (x, y)| switch(id, x, y) }
    [[4, 17, 20], [9, 9, 16]].each { |id, x, y| fence(id, x, y) }
    $game_self_switches[[MAP, 14, "B"]] = true
    $game_self_switches[[MAP, 8, "A"]] = true
    frame
    names = listed.map { |_x, _y, n| n }
    assert_equal 2, names.count(t(:if_jh_switch_blue))
    assert_equal 2, names.count(t(:if_jh_switch_red))
    assert_equal [t(:if_jh_layout_red)], frame { $game_self_switches[[MAP, 8, "A"]] = false; $game_self_switches[[MAP, 18, "A"]] = true }
    assert_equal [t(:if_jh_layout_blue)], frame { $game_self_switches[[MAP, 18, "A"]] = false; $game_self_switches[[MAP, 20, "A"]] = true }
    assert_equal [], frame { $game_self_switches[[MAP, 20, "A"]] = false; $game_self_switches[[MAP, 8, "A"]] = true }
  end

  test "the rule is said on arriving, and with the generator off no layout is said and the rule stays silent" do
    on_map
    SWITCHES.each { |id, (x, y)| switch(id, x, y) }
    $game_self_switches[[MAP, 14, "B"]] = true
    $game_switches[2198] = true
    assert_equal [], frame
    assert_equal [], frame { $game_self_switches[[MAP, 8, "A"]] = false; $game_self_switches[[MAP, 18, "A"]] = true }
    assert_equal [t(:if_jh_layout_red)], frame { $game_switches[2198] = false }
    on_map
    assert_equal [t(:if_jh_mauville_rule)], frame
  end

  test "the rule stops sounding once Wattson is beaten, the fences still being worked" do
    on_map
    SWITCHES.each { |id, (x, y)| switch(id, x, y) }
    $game_self_switches[[MAP, 14, "B"]] = true
    $game_switches[6] = true
    assert_equal [], frame
    assert_equal [t(:if_jh_layout_red)], frame { $game_self_switches[[MAP, 18, "A"]] = true }
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def on_map
    Harness.load_puzzles("infinitefusion_hoenn")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = MAP
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def switch(id, x, y)
    put(id, x, y, "switch size(1,2).sl forced_z=0", "lighting_button", [TestCmd.new(355, ["mauville_reset_switches"]), TestCmd.new(0, [])], 1)
  end

  def fence(id, x, y)
    put(id, x, y, "ELEC(0,0) size(5,1).sl", "electricity_v", [TestCmd.new(0, [])], 0)
  end

  def put(id, x, y, name, sprite, list, trigger)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    World.next_frame
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
