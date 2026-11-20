# Keishou's challenges on the map (games/keishou/minigames.rb): the Kusa Sprint's trails and their time, the Bounsweet Hunt's
# finds and the pupils about to see the player, the Carvanha Chase's pools and Bruxish, and Mr. Hyper's training in Sakyu
# Valley. Gamedata pass.
class KeishouMiniGdTest < PokeAccessTest
  MAPS = [133, 269, 270, 271]
  T = PokeAccess::I18n

  # A patrol's custom route: its move commands and whether it starts over.
  PatrolRoute = Struct.new(:list, :repeat)

  # A parallel timer's interpreter, down to what the reader reads.
  class TimerInterpreter
    def initialize(index, wait)
      @index = index
      @wait_count = wait
    end
  end

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @at = [$game_player.x, $game_player.y, $game_player.direction]
  end

  def teardown
    World.clear_events
    [81, 138, 139, 142].each { |i| $game_variables[i] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y, $game_player.direction = @at
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "a trail says itself, its try and its time as its timer starts, its time left in the info key, and nothing once time is up" do
    on_map(270)
    placed(9, 23, 16, "trchar000")
    placed(19, 22, 35, "trchar000")
    timer = placed(1, 22, 9, "", [TestCmd.new(106, [250]), TestCmd.new(101, ["Time's up"]), TestCmd.new(0, [])])
    assert_equal [[22, 35, t(:ks_mini_trail_goal, :n => 1)], [23, 16, t(:ks_mini_trail_start, :n => 1)]], listed
    $game_variables[139] = 3
    frame
    said = frame { $game_self_switches[[270, 1, "A"]] = true }
    assert_equal [PokeAccess.sentences([t(:ks_mini_trail_run, :n => 1, :try => 1, :of => 3), t(:ks_mini_time_left, :n => 12)])], said
    assert_in_delta 12.5, mini.left(1), 0.001
    timer.instance_variable_set(:@interpreter, TimerInterpreter.new(1, 300))
    assert_in_delta 5.0, mini.left(1), 0.001
    $game_variables[139] = 2
    assert_equal PokeAccess.sentences([t(:ks_mini_trail_run, :n => 1, :try => 2, :of => 3), t(:ks_mini_time_left, :n => 5)]),
                 PokeAccess::Puzzles.info_line
    timer.instance_variable_set(:@interpreter, TimerInterpreter.new(2, 0))
    assert_nil mini.left(1)
    assert_equal [], frame
    refute PokeAccess::Puzzles.active?
  end

  test "the time left follows the game's speed-up, its frames running that many times faster" do
    on_map(270)
    timer = placed(1, 22, 9, "", [TestCmd.new(106, [250]), TestCmd.new(101, ["Time's up"]), TestCmd.new(0, [])])
    $game_self_switches[[270, 1, "A"]] = true
    saved = $GameSpeed
    with_stages([1, 2, 3]) do
      $GameSpeed = 2
      assert_in_delta 12.5 / 3, mini.left(1), 0.001
      timer.instance_variable_set(:@interpreter, TimerInterpreter.new(1, 300))
      assert_in_delta 5.0 / 3, mini.left(1), 0.001
      assert_equal t(:ks_mini_time_left, :n => 1), mini.time_text(1)
      $GameSpeed = 1
      assert_in_delta 2.5, mini.left(1), 0.001
    end
  ensure
    $GameSpeed = saved
  end

  test "the hunt names all six Bounsweet, counts the finds and answers the info key while it runs" do
    on_map(269)
    (11..16).each { |id| placed(id, id, 20, "pkmn_BOUNSWEET") }
    assert_equal [11, 12, 13, 14, 15, 16], listed.select { |_x, _y, n| n == t(:ks_mini_bounsweet) }.map { |x, _y, _n| x }
    $game_self_switches[[269, 10, "A"]] = true
    frame
    assert_equal [progress(:ks_mini_bounsweet_found, 1, 6)], frame { $game_variables[138] = 1 }
    assert_equal progress(:ks_mini_bounsweet_found, 1, 6), PokeAccess::Puzzles.info_line
    $game_variables[138] = 6
    refute PokeAccess::Puzzles.active?
  end

  test "a pupil's patrol is read ahead in time, not in commands: its turn four commands on still warns, once, cutting speech" do
    on_map(269)
    $game_self_switches[[269, 10, "A"]] = true
    pupil = patrol(18, 20, 30, 2, [1, 1, 1, 18, 4, 4, 4, 17])
    assert_equal [[20, 31, 2], [20, 32, 2], [20, 33, 2], [20, 33, 6]], mini.checks(pupil)[0, 4]
    assert_equal 9, mini.checks(pupil).length
    put(22, 33, 8)
    assert_equal [[t(:ks_mini_pupil_back), true]], pulse
    assert_equal [], pulse
    put(22, 34, 8)
    assert_equal [[t(:ks_mini_pupil_stop), true]], pulse
    put(22, 33, 6)
    assert_equal [[t(:ks_mini_pupil_dodge, :dir => t(:dir_up)), true]], pulse
    put(25, 33, 8)
    assert_equal [], pulse
    put(22, 33, 8)
    assert_equal [[t(:ks_mini_pupil_back), true]], pulse
  end

  test "a pupil past the horizon says nothing until the speed-up brings it in, nor one that sees the player already or was fought" do
    on_map(269)
    $game_self_switches[[269, 10, "A"]] = true
    pupil = patrol(18, 20, 33, 8, [15, 18])
    pupil.instance_variable_get(:@move_route).list[0].parameters = [60]
    put(22, 33, 8)
    assert_equal [], pulse
    saved = $GameSpeed
    with_stages([1, 2, 3]) do
      $GameSpeed = 2
      assert_equal [[t(:ks_mini_pupil_back), true]], pulse
    end
    $GameSpeed = saved
    assert_equal [], pulse
    pupil.instance_variable_set(:@wait_count, 0)
    pupil.instance_variable_set(:@move_route, PatrolRoute.new([TestMoveCmd.new(18)], true))
    assert_equal [[t(:ks_mini_pupil_back), true]], pulse
    pupil.direction = 6
    assert_equal [], pulse
    pupil.direction = 8
    $game_self_switches[[269, 18, "A"]] = true
    assert_equal [], pulse
    $game_self_switches[[269, 18, "A"]] = false
    $game_variables[138] = 6
    assert_equal [], pulse
    pupil.instance_variable_set(:@move_route, PatrolRoute.new([TestMoveCmd.new(9), TestMoveCmd.new(18)], true))
    assert_equal [], mini.checks(pupil)
  ensure
    $GameSpeed = saved
  end

  test "the chase names each pool's way in and its end while they work, says the pool and the try as it starts, and follows Bruxish" do
    on_map(271)
    [[11, 40, 23], [12, 40, 37], [23, 54, 23], [24, 54, 37], [32, 45, 39]].each { |id, x, y| placed(id, x, y, "trchar000") }
    bruxish = placed(33, 30, 57, "pkmn_BRUXISH")
    assert_equal [[30, 57, t(:ks_mini_bruxish)], [40, 23, t(:ks_mini_pool_entrance, :n => 1)]], listed
    $game_variables[142] = 3
    frame
    said = frame do
      $game_self_switches[[271, 11, "A"]] = true
      $game_self_switches[[271, 12, "A"]] = true
      $game_self_switches[[271, 10, "B"]] = true
    end
    assert_equal [t(:ks_mini_pool_run, :n => 1, :try => 1, :of => 3)], said
    assert_equal [[30, 57, t(:ks_mini_bruxish)], [40, 37, t(:ks_mini_pool_goal, :n => 1)]], listed
    $game_self_switches[[271, 10, "B"]] = false
    $game_self_switches[[271, 32, "D"]] = true
    assert_includes listed, [45, 39, t(:ks_mini_pool_entrance, :n => 3)]
    $game_variables[142] = 2
    assert_equal [t(:ks_mini_pool_run, :n => 3, :try => 2, :of => 3)], frame { $game_self_switches[[271, 33, "B"]] = true }
    assert_includes listed, [43, 84, t(:ks_mini_bruxish_goal)]
    put(30, 60)
    said = frame { bruxish.y = 58 }
    assert_equal [t(:puzzle_track_rel, :label => t(:ks_mini_bruxish), :dist => PokeAccess::Puzzles.offset_phrase(0, -2))], said
  end

  test "the training names its rocks, says its time as each test starts, counts the rocks and follows the boulder" do
    on_map(133)
    [[3, 12, 37], [14, 20, 35], [15, 8, 42]].each { |id, x, y| placed(id, x, y, "Object rock") }
    rocks = placed(19, 4, 40, "", [TestCmd.new(106, [200]), TestCmd.new(0, [])])
    boulder = placed(16, 9, 37, "Object boulder")
    placed(20, 4, 39, "", [TestCmd.new(106, [470]), TestCmd.new(0, [])])
    assert_equal [], listed.select { |_x, _y, n| n == t(:ks_mini_training_rock) }
    [3, 14, 15].each { |id| $game_self_switches[[133, id, "B"]] = true }
    assert_equal 3, listed.select { |_x, _y, n| n == t(:ks_mini_training_rock) }.size
    frame
    assert_equal [t(:ks_mini_time_left, :n => 10)], frame { $game_self_switches[[133, 19, "A"]] = true }
    assert_equal [progress(:ks_mini_rocks, 1, 3)], frame { $game_variables[81] = 1 }
    $game_self_switches[[133, 3, "C"]] = true
    assert_equal 2, listed.select { |_x, _y, n| n == t(:ks_mini_training_rock) }.size
    rocks.instance_variable_set(:@interpreter, TimerInterpreter.new(1, 120))
    assert_equal PokeAccess.sentences([t(:ks_mini_time_left, :n => 2), progress(:ks_mini_rocks, 1, 3)]), PokeAccess::Puzzles.info_line
    $game_self_switches[[133, 19, "A"]] = false
    assert_equal [t(:ks_mini_time_left, :n => 23)], frame { $game_self_switches[[133, 20, "A"]] = true }
    assert_includes listed, [9, 40, t(:ks_mini_boulder_goal)]
    put(9, 36)
    said = frame { boulder.y = 38 }
    assert_equal [t(:puzzle_track_rel, :label => t(:ks_mini_boulder), :dist => PokeAccess::Puzzles.offset_phrase(0, 2))], said
  end

  private

  def t(*args); T.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def mini; PokeAccess::KeishouMini; end

  # Declares the profile's challenges on their maps, loading the file once per process.
  def declare
    self.class.declared ||= begin
      path = File.join(Harness::ROOT, "games", "keishou", "minigames.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map)
    declare
    World.clear_events
    $game_self_switches = {}
    [81, 138, 139, 142].each { |i| $game_variables[i] = 0 }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map with a sprite (or none) and a page of the given commands.
  def placed(id, x, y, sprite, list = [TestCmd.new(101, ["..."]), TestCmd.new(0, [])], name = nil)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name || "EV#{id}", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A pupil on patrol: a trainer of sight 3 facing dir, on a custom route of these move codes from its first, 16 frames
  # a tile (60 a second here) with no pause after each step.
  def patrol(id, x, y, dir, codes)
    ev = placed(id, x, y, "trchar188", [TestCmd.new(0, [])], "Trainer(3)")
    ev.direction = dir
    ev.instance_variable_set(:@move_type, 3)
    ev.instance_variable_set(:@move_route, PatrolRoute.new(codes.map { |c| TestMoveCmd.new(c) }, true))
    ev.instance_variable_set(:@move_route_index, 0)
    ev.instance_variable_set(:@move_speed_real, 8.0)
    ev
  end

  # What one pulse of the hunt says, as [text, interrupt].
  def pulse
    SpeakCapture.clear
    mini.tick
    SpeakCapture.log.map { |text, cut| [text, cut] }
  end

  # Runs the block with the game's SPEEDUP_STAGES set to stages, then puts back what was there.
  def with_stages(stages)
    had = Object.const_defined?(:SPEEDUP_STAGES, false)
    was = had ? Object.const_get(:SPEEDUP_STAGES) : nil
    Object.send(:remove_const, :SPEEDUP_STAGES) if had
    Object.const_set(:SPEEDUP_STAGES, stages)
    yield
  ensure
    Object.send(:remove_const, :SPEEDUP_STAGES) if Object.const_defined?(:SPEEDUP_STAGES, false)
    Object.const_set(:SPEEDUP_STAGES, was) if had
  end

  def put(x, y, dir = 2)
    $game_player.x = x
    $game_player.y = y
    $game_player.direction = dir
  end

  def progress(label, n, of); t(:puzzle_progress, :label => t(label), :n => n, :of => of); end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name as the locator says it], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
