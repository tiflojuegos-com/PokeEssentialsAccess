# Insurgence's story puzzles (games/insurgence/puzzles/, but the Erebus Gym mirrors) on the shipped profile over events shaped like
# the game's: Vipik Gym's tree holes, Sonata Gym's flowerbed jumps, Abyssal Base's tiles, force fields and terminals, the
# Deep Cavern's currents, Diana's cell in the Infernal Base and Hekate Town's orbs. What is heard without the puzzle assist
# is the room and its state, said once where the room is a place the player comes back to; the answers come with it.
class InsurgencePuzzlesTest < PokeAccessTest
  MAPS = [225, 226, 269, 278, 432, 245, 521]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
  end

  def teardown
    World.clear_events
    [5, 7, 158, 161, 435, 437, 439].each { |i| $game_switches[i] = false }
    $game_variables[41] = 0
    $game_variables[42] = 0
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, nil)
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the tree holes of both rooms are named, and the assist marks the four that lead to Xavier" do
    on_map(225)
    [[2, 38, 43], [3, 36, 28], [12, 15, 63]].each { |id, x, y| hole(id, x, y) }
    assert_equal [[15, 63, t(:ins_tree_hole)], [36, 28, t(:ins_tree_hole)], [38, 43, t(:ins_tree_hole)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[15, 63, t(:ins_tree_hole_way)], [36, 28, t(:ins_tree_hole)], [38, 43, t(:ins_tree_hole_way)]], listed
    on_map(226)
    [[2, 38, 38], [9, 87, 37], [10, 87, 11]].each { |id, x, y| hole(id, x, y) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[38, 38, t(:ins_tree_hole_way)], [87, 11, t(:ins_tree_hole)], [87, 37, t(:ins_tree_hole_way)]], listed
  end

  test "Vipik Gym tells inside from outside on a crawl, says its rule on arrival and the way only with the assist" do
    PokeAccess::Config.verbosity = :full
    on_map(225)
    assert_equal [t(:ins_vipik_rule)], frame
    on_map(226)
    on_map(225)
    assert_equal [], frame, "coming back out of a trunk does not say the rule again"
    assert_equal t(:ins_tree_out), PokeAccess::Puzzles.sent_back_line([13, 75, 226], [38, 44], :map)
    assert_equal t(:ins_vipik_rule), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:ins_vipik_hint)}. #{t(:ins_vipik_rule)}", info_key
    on_map(226)
    assert_equal t(:ins_tree_in), PokeAccess::Puzzles.sent_back_line([38, 43, 225], [50, 62], :map)
    $game_switches[5] = true
    assert_nil PokeAccess::Puzzles.info_line, "nothing once Xavier is beaten"
  end

  test "the flowerbed jumps are named by their way, the rule is said on arrival and the route carries them" do
    PokeAccess::Config.verbosity = :full
    on_map(269)
    assert_equal [t(:ins_sonata_rule)], frame
    jump(1, 2, 3, 8, [0, -2], [0, 2])
    jump(40, 4, 3, 4, [-2, 0], [2, 0])
    assert_equal [[2, 3, t(:ins_flower_jump_v)], [4, 3, t(:ins_flower_jump_h)]], listed
    jump(2, 3, 3, 8, [0, -2], [0, 2])
    jump(3, 4, 4, 8, [0, -2], [0, 2])
    assert_equal [[3, 3, t(:ins_flower_jump_v)], [4, 3, t(:ins_flower_jump_h)]], listed, "a touching row of jumps is one target"
    $game_map.load_grid(["#####", "#...#", "#...#", "#####", "#@..#", "#####"])
    World.clear_events
    jump(1, 2, 3, 8, [0, -2], [0, 2])
    assert_equal [6, 8, 8], walk_route(2, 1, true), "the hop up over the flowerbed's edge"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:ins_sonata_hint)}. #{t(:ins_sonata_rule)}", info_key
  end

  test "Abyssal Base names its tiles, force fields and terminals, and the assist tells the disguise each field asks" do
    on_map(278)
    silent(54, 10, 96, "teleport")
    field(5, 9, 32)
    field(15, 9, 31)
    field(25, 9, 30)
    field(6, 20, 40)
    field(7, 21, 40)
    field(8, 22, 40)
    silent(52, 23, 32, "EV052")
    names = lambda { listed.map { |x, y, n| [x, y, n] } }
    PokeAccess::Config.puzzle_assist = false
    assert_equal [[9, 31, t(:ins_abyss_field)], [10, 96, t(:ins_abyss_tile)], [21, 40, t(:ins_abyss_field)],
                  [23, 32, t(:ins_abyss_terminal)]], names.call, "a touching row of one name is one target on its middle"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[9, 30, t(:ins_abyss_field_2)], [9, 31, t(:ins_abyss_field_3)], [9, 32, t(:ins_abyss_field_4)]],
                 names.call[0, 3]
    assert_equal [21, 40, t(:ins_abyss_field_4)], names.call.find { |x, y, _n| y == 40 }
  end

  test "the terminal's password is said with the assist, facing it and until the sewers are drained" do
    on_map(278)
    term = silent(52, 23, 32, "EV052")
    frame
    $game_player.direction = 8
    assert_equal [], frame { fire(term) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "proteus")], frame { fire(term) }
    $game_player.direction = 2
    assert_equal [], frame { fire(term) }, "not facing the terminal"
    $game_player.direction = 8
    $game_switches[161] = true
    assert_equal [], frame { fire(term) }, "the sewers are drained already"
  end

  test "Abyssal Base says the disguise as it changes, nothing of the sewers the game already tells, and what a tile did" do
    on_map(278)
    frame
    $game_variables[41] = 3
    assert_includes frame.join(" "), t(:ins_disguise_abyssal_scientist)
    $game_switches[161] = true
    assert_equal [], frame, "the terminal says the sewers are drained"
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 58)
    silent(58, 53, 28, "teleport")
    assert_equal t(:ins_abyss_sent), PokeAccess::Puzzles.sent_back_line([64, 40], [64, 41])
    $game_switches[158] = true
    assert_nil PokeAccess::Puzzles.info_line, "nothing once the base is cleared"
  end

  test "Abyssal Base's rule and hint come with the info key, the hint with the assist alone" do
    on_map(278)
    state = "#{t(:ins_abyss_disguise)}: #{t(:ins_disguise_none)}"
    assert_equal "#{state}. #{t(:ins_abyss_rule)}", info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{state}. #{t(:ins_abyss_hint)}. #{t(:ins_abyss_rule)}", info_key
  end

  test "the Deep Cavern says what its currents do and hides none of them" do
    PokeAccess::Config.verbosity = :full
    on_map(521)
    assert_equal [t(:ins_cavern_rule)], frame
    current = silent(30, 5, 5, "current_left")
    exit_tile = silent(1, 67, 20, "EV001")
    refute PokeAccess::Puzzles.hidden_event?(current)
    refute PokeAccess::Puzzles.hidden_event?(exit_tile)
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::Puzzles.hidden_event?(current)
  end

  test "Diana's cell says the statue's rule once Heart Swap is known, and the way only with the assist" do
    PokeAccess::Config.verbosity = :full
    on_map(432)
    $game_player.x = 57
    $game_player.y = 33
    silent(34, 61, 26, "EV034")
    $game_variables[42] = [false, false, false, false, false, true]
    assert_equal [], frame, "the scene has not ended"
    assert_equal [], listed
    $game_switches[435] = true
    assert_equal [t(:ins_inf_rule)], frame
    assert_equal [], frame, "the rule is said once"
    $game_player.x = 80
    assert_equal [], frame, "and not again by going far and coming back"
    $game_player.x = 57
    assert_equal [], frame
    assert_equal t(:ins_inf_rule), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[61, 26, t(:ins_inf_button)]], listed
    assert PokeAccess::Puzzles.onto?(PokeAccess::Puzzles.category_targets[0]), "the button is stepped on"
    assert_equal "#{t(:ins_inf_rule)}. #{t(:ins_inf_hint)}", info_key
    $game_switches[439] = true
    assert_equal [], listed
    assert_equal "#{t(:ins_inf_rule)}. #{t(:ins_inf_hint_out)}", info_key
    $game_switches[437] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Diana's cell says nothing before Heart Swap is known, even with the assist" do
    PokeAccess::Config.verbosity = :full
    on_map(432)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[435] = true
    assert_equal [], frame
    assert_nil PokeAccess::Puzzles.info_line
    $game_variables[42] = [false, false, false, false, false, true]
    $game_switches[435] = false
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Hekate Town names its orbs, says they join three clearings and, with the assist, which exit is in which" do
    PokeAccess::Config.verbosity = :full
    on_map(245)
    assert_includes frame, t(:ins_hekate_rule)
    on_map(245)
    assert_equal [], frame, "coming back to the town does not say the rule again"
    [[1, 33, 27], [2, 41, 19], [3, 12, 39]].each { |id, x, y| silent(id, x, y, "Particle effect - aura") }
    assert_equal [[12, 39, t(:ins_hekate_orb)], [33, 27, t(:ins_hekate_orb)], [41, 19, t(:ins_hekate_orb)]], listed
    assert_equal t(:ins_hekate_rule), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ins_hekate_hint)
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 2)
    assert_equal t(:ins_hekate_sent), PokeAccess::Puzzles.sent_back_line([33, 27], [83, 31])
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("insurgence")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    [5, 7, 158, 161, 435, 437, 439].each { |i| $game_switches[i] = false }
    $game_variables[41] = 0
    $game_variables[42] = 0
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def silent(id, x, y, name = "EV#{id}")
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def hole(id, x, y)
    page = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def field(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "baldosa415", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "AUDREY_FIELD", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def jump(id, x, y, facing, forward, back)
    list = [World.if_facing(facing), World.move_player([[14, forward]], 1), World.else_, World.move_player([[14, back]], 1),
            World.end_]
    World.touch(:id => id, :x => x, :y => y, :name => "JUMP_UPDOWN", :list => list)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)] }.sort_by { |x, y, _n| [x, y] }
  end
end
