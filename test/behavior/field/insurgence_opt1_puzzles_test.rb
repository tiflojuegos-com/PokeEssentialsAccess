# Insurgence's first optional puzzles (games/insurgence/puzzles/: meloetta, satellite_corps, perfection_base, perfection_lab,
# holon_pyramid) on the shipped profile over events shaped like the game's: what a seeing player hears from the pedestals,
# locks, floor switches and button rows, and what the puzzle assist adds (the reward, the next button, the way).
class InsurgenceOpt1PuzzlesTest < PokeAccessTest
  MAPS = [192, 660, 222, 243, 373, 283, 424, 553, 474, 575, 576, 577, 641, 642, 751, 754, 547]
  WORDS = {
    "ins_o1_lab_button" => "Button %{n} of 4", "ins_o1_lab_press" => "Press button %{n}",
    "ins_o1_pyr_square" => "Square %{n} of 4", "ins_o1_pyr_press" => "Press square %{n}"
  }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @spot = [$game_player.x, $game_player.y]
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    table = PokeAccess::I18n.table(PokeAccess::I18n.lang)
    WORDS.each { |k, v| table[k] ||= v }
  end

  def teardown
    World.clear_events
    [551, 552, 553, 554, 610, 611, 622, 623, 624].each { |i| $game_switches[i] = false }
    $game_variables[164] = 0
    stand(*@spot)
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "each Meloetta pedestal is named, with its reward only for the assist, and goes once solved" do
    [[192, 26, 16, 2], [424, 55, 27, 6], [474, 14, 13, 5]].each do |map, x, y, id|
      on_map(map)
      silent(id, x, y)
      assert_equal [[x, y, t(:ins_o1_pedestal)]], listed
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[x, y, t(:ins_o1_pedestal_reward)]], listed
      PokeAccess::Config.puzzle_assist = false
    end
  end

  test "the Satellite Corps lock is the only target of its door, and the assist says what the lock opens" do
    on_map(576)
    silent(2, 12, 15)
    door = silent(4, 12, 14)
    assert_equal [[12, 15, t(:ins_o1_lock)]], listed
    assert PokeAccess::Puzzles.hidden_event?(door)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[12, 15, t(:ins_o1_lock_door)]], listed
  end

  test "Perfection Base counts the covered switches of a colour up to what its sign asks, and names pillars and switches" do
    PokeAccess::Config.verbosity = :full
    on_map(641)
    assert_equal [t(:ins_o1_pb_rule)], frame
    silent(4, 38, 21)
    silent(5, 38, 20)
    names = listed.map { |_x, _y, n| n }
    assert_equal 2, names.select { |n| n == t(:ins_o1_pb_pillar_red) }.length
    tile_names = [:red, :green, :yellow, :blue].map { |c| t("ins_o1_pb_tile_#{c}".to_sym) }
    assert_equal 9, names.select { |n| tile_names.include?(n) }.length
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 1, :of => 2)],
                 frame { silent(1, 35, 23, "boulder") }
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 2, :of => 2)],
                 frame { silent(3, 42, 23, "boulder") }
    assert_equal [], frame { silent(6, 35, 18, "boulder") }
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_yellow), :n => 1, :of => 3)],
                 frame { silent(7, 42, 11, "boulder") }
    assert_equal ["#{t(:ins_o1_pb_closed)}. #{t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 1, :of => 2)}"],
                 frame { [3, 6].each { |id| $game_map.events.delete(id) }; World.next_frame },
                 "boulders taken off the switches close the pillars again, and it is said"
    $game_switches[551] = true
    assert_equal [], frame
    PokeAccess::Config.puzzle_assist = true
    $game_switches[552] = true
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_open), :n => 2, :of => 4)], frame
    assert_match(/#{Regexp.escape(t(:ins_o1_pb_hint))}/, info_key)
  end

  test "Perfection Base forgets with a new map that a colour was open, so its pillars are not said to close on the next visit" do
    PokeAccess::Config.verbosity = :full
    on_map(641)
    frame
    frame { silent(1, 35, 23, "boulder") }
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 2, :of => 2)],
                 frame { silent(3, 42, 23, "boulder") }
    PokeAccess::World::Epoch.touch(:map)
    on_map(641)
    frame
    frame { silent(1, 35, 23, "boulder") }
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 0, :of => 2)],
                 frame { $game_map.events.delete(1); World.next_frame }
  end

  test "Perfection Base counts the Manaphy statue and the player on the last switch of a colour, as the game's script does" do
    PokeAccess::Config.verbosity = :full
    on_map(641)
    frame
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_yellow), :n => 1, :of => 3)],
                 frame { silent(2, 31, 6, "HeartSwap_S") }, "the statue counts as any event"
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_green), :n => 1, :of => 1)],
                 frame { stand(45, 13) }, "the player counts on the last switch of green"
    assert_equal ["#{t(:ins_o1_pb_closed)}. #{t(:puzzle_progress, :label => t(:ins_o1_pb_count_green), :n => 0, :of => 1)}"],
                 frame { stand(45, 14) }
    assert_equal [], frame { stand(35, 23) }, "not on a switch that is not the last of its colour"
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 1, :of => 2)],
                 frame { stand(42, 23) }, "passing over the last red switch"
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_red), :n => 0, :of => 2)],
                 frame { stand(42, 24) }, "the pillars were never open, so none is said to close"
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_yellow), :n => 2, :of => 3)],
                 frame { silent(8, 32, 14, "boulder") }
    assert_equal [t(:puzzle_progress, :label => t(:ins_o1_pb_count_yellow), :n => 1, :of => 3)],
                 frame { $game_map.events.delete(8); World.next_frame }, "yellow falling from 2 to 1 closes nothing"
    assert_includes listed.map { |_x, _y, n| n }, t(:ins_o1_pb_tile_red)
    PokeAccess::Config.puzzle_assist = true
    names = listed.map { |x, y, n| [x, y, n] }
    assert_includes names, [42, 23, t(:ins_o1_pb_tile_player, :tile => t(:ins_o1_pb_tile_red))]
    assert_includes names, [35, 23, t(:ins_o1_pb_tile_red)]
  end

  test "the Perfection Base circuit panel is named, with Mewtwo only for the assist" do
    on_map(642)
    silent(1, 28, 31)
    assert_equal [[28, 31, t(:ins_o1_circuit)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[28, 31, t(:ins_o1_circuit_reward)]], listed
  end

  test "the Perfection Laboratory buttons are numbered and the assist follows the sequence from the game's own state" do
    on_map(751)
    [[18, 37], [19, 38], [20, 39], [21, 40]].each { |id, x| silent(id, x, 30) }
    assert_equal [[25, 34, t(:ins_o1_lab_pink_tile)], [37, 30, t(:ins_o1_lab_button, :n => 1)], [38, 30, t(:ins_o1_lab_button, :n => 2)],
                  [39, 30, t(:ins_o1_lab_button, :n => 3)], [40, 30, t(:ins_o1_lab_button, :n => 4)]], listed
    assert_equal [], frame
    on_map(751)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ins_o1_lab_press, :n => 2), t(:ins_o1_lab_statue_hint)], frame,
                 "the assisted rule, silent on the first arrival without the assist, is said on the next"
    $game_variables[164] = 1
    $game_switches[611] = true
    assert_equal [t(:ins_o1_lab_press, :n => 4)], frame
    $game_variables[164] = 2
    assert_equal [t(:ins_o1_lab_press, :n => 3)], frame
    $game_switches[611] = false
    assert_equal [t(:ins_o1_lab_broken)], frame
    $game_variables[164] = 0
    $game_switches[611] = true
    assert_equal [t(:ins_o1_lab_press, :n => 2)], frame
    $game_switches[624] = true
    assert_equal [], frame
  end

  test "the laboratory's pink tile is named, the pillars go with the switch, and the statue's way is for the assist" do
    PokeAccess::Config.verbosity = :full
    on_map(751)
    [6, 10, 14, 15].each { |id| silent(id, 50 + id, 56) }
    assert_equal [], frame
    names = listed.map { |_x, _y, n| n }
    assert_equal 4, names.select { |n| n == t(:ins_o1_lab_pillar) }.length
    assert_includes names, t(:ins_o1_lab_pink_tile)
    PokeAccess::Config.puzzle_assist = true
    assert_match(/#{Regexp.escape(t(:ins_o1_lab_statue_hint))}/, info_key)
    $game_switches[623] = true
    refute_match(/#{Regexp.escape(t(:ins_o1_lab_statue_hint))}/, info_key.to_s)
  end

  test "the security tape on map 754 says what the scientist presses and none of the laboratory's help" do
    PokeAccess::Config.verbosity = :full
    on_map(754)
    [[18, 37], [19, 38], [20, 39], [21, 40]].each { |id, x| silent(id, x, 30) }
    silent(2, 21, 22)
    assert_equal [t(:ins_o1_lab_tape)], frame
    assert_equal [], listed
    on_map(754)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ins_o1_lab_tape)], frame
    $game_variables[164] = 1
    $game_switches[611] = true
    assert_equal [], frame
    refute_match(/#{Regexp.escape(t(:ins_o1_lab_statue_hint))}/, info_key.to_s)
  end

  test "the laboratory's keypad door says the password with the assist alone" do
    on_map(751)
    silent(2, 21, 22)
    assert_equal [[21, 22, t(:ins_o1_lab_door)], [25, 34, t(:ins_o1_lab_pink_tile)]], listed
    ev = $game_map.events[2]
    assert_equal [], frame { fire(ev) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "antilithium")], frame { fire(ev) }
  end

  test "the Holon Pyramid squares are numbered west to east and the assist follows its own count to the right ones" do
    on_map(547)
    [[9, 45], [11, 46], [51, 47], [52, 48]].each { |id, x| silent(id, x, 38) }
    assert_equal [45, 46, 47, 48].each_with_index.map { |x, i| [x, 38, t(:ins_o1_pyr_square, :n => i + 1)] }, listed
    on_map(547)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ins_o1_pyr_press, :n => 4)], frame
    [[1, 4], [2, 1], [3, 3]].each do |v, n|
      $game_variables[164] = v
      $game_switches[611] = true
      assert_equal [t(:ins_o1_pyr_press, :n => n)], frame
    end
    $game_switches[611] = false
    assert_equal [t(:ins_o1_pyr_broken)], frame
    $game_switches[610] = true
    assert_equal [], frame
  end

  test "the Holon Pyramid's third square gives up its name to the way it opens once the sequence is done" do
    on_map(547)
    squares = [[9, 45], [11, 46], [51, 47], [52, 48]].map { |id, x| silent(id, x, 38) }
    third = squares[2]
    assert_equal t(:ins_o1_pyr_square, :n => 3), PokeAccess::Puzzles.piece_name(third)
    $game_switches[610] = true
    assert_nil PokeAccess::Puzzles.piece_name(third)
    assert_equal [[45, 38, t(:ins_o1_pyr_square, :n => 1)], [46, 38, t(:ins_o1_pyr_square, :n => 2)],
                  [48, 38, t(:ins_o1_pyr_square, :n => 4)]], listed
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
    [551, 552, 553, 554, 610, 611, 622, 623, 624].each { |i| $game_switches[i] = false }
    $game_variables[164] = 0
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

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def info_key; PokeAccess::Info.map_text; end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

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
