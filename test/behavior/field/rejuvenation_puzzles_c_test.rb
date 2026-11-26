# Pokemon Rejuvenation's optional puzzles (games/rejuvenation/puzzles/, part C): the Thief's Dungeon board and gates, the
# Amethyst power panels, the Evergreen boulders, Volcanion's terminal, the Stolen Cargo arrows, Griselda's panels, the
# night rocks, the Edge of My World door, the Forsaken Laboratory's crest and the Garufa type beacons. Without the assist,
# what the screen shows; with it, the way.
class RejuvenationPuzzlesCTest < PokeAccessTest
  SWITCHES = [60, 1151, 1152, 1588, 1589, 2031]
  VARS = [214, 342, 343, 431, 471, 633, 750]

  def setup
    super
    keyed
    Harness.load_puzzles("rejuvenation")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the Thief's Dungeon board reads the path its pattern draws, and the gates say where they lead with the assist" do
    on_map(81, 51, 17)
    $game_variables[633] = 2
    board = listed.find { |r| r[0] == 51 && r[1] == 16 }
    assert_equal "{rj_thief_board first={rj_thief_right} second={rj_thief_middle} third={rj_thief_left} " \
                 "yellow={rj_thief_middle}}", board[2]
    gate = place(47, 46, 62, "EV047", 1)
    assert_equal "{rj_thief_gate col={rj_thief_left}}", PokeAccess::Puzzles.piece_name(gate)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_thief_gate_pit}", PokeAccess::Puzzles.piece_name(gate)
    $game_variables[633] = 3
    assert_equal "{rj_thief_gate_on}", PokeAccess::Puzzles.piece_name(gate)
    thief = PokeAccess::RejuvThiefDungeon
    assert_equal [:rj_thief_hint, { :first => "{rj_thief_left}", :second => "{rj_thief_right}", :third => "{rj_thief_right}" }],
                 thief.hint
    assert_equal :treasure, thief.gate(59)
    $game_variables[633] = 0
    assert_nil thief.hint
  end

  test "every pattern's safe gates lead on, its yellow square marks the treasure, and its green end the bare way out" do
    thief = PokeAccess::RejuvThiefDungeon
    (1..3).each do |p|
      $game_variables[633] = p
      cols = thief::BOARD[p]
      assert_equal :on, thief.gate(thief::ROWS[0][cols[0]])
      assert_equal :on, thief.gate(thief::ROWS[1][cols[1]])
      assert_equal :exit, thief.gate(thief::ROWS[2][cols[2]])
      assert_equal :treasure, thief.gate(thief::ROWS[2][cols[3]])
    end
  end

  test "the Amethyst lights count for anyone at the grid, capped at six, and a seventh panel is flagged with the assist" do
    on_map(162, 25, 75)
    $game_variables[342] = 7
    assert_includes info_key, "{puzzle_progress"
    assert_includes info_key, "n=6"
    refute_includes info_key, "n=7"
    panel = place(11, 60, 16, "EV011")
    assert_equal "{rj_amethyst_panel}", PokeAccess::Puzzles.piece_name(panel)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_amethyst_panel_spare}", PokeAccess::Puzzles.piece_name(panel)
    $game_variables[343] = 3
    assert_equal "{rj_amethyst_panel}", PokeAccess::Puzzles.piece_name(panel)
  end

  test "the Evergreen boulders' hint follows the stage, and a dead-end hole says to start over" do
    on_map(490, 20, 10)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[471] = 1
    assert_includes info_key, "{rj_evergreen_second_hint}"
    $game_variables[471] = 3
    assert_includes info_key, "{rj_evergreen_wrong_hole}"
    $game_variables[471] = 4
    assert_includes info_key, "{rj_evergreen_third_hint}"
    $game_variables[471] = 7
    refute_includes info_key, "rj_evergreen"
  end

  test "the Evergreen boulders' rule holds on the melted copy of the cave the ice drops the player into" do
    on_map(486, 21, 6)
    assert_equal "{rj_evergreen_fell}", PokeAccess::Puzzles.sent_back_line([42, 19, 485], [42, 19, 486], :map)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_evergreen_first_hint}"
    refute_includes info_key, "{rj_evergreen_ice_hint}", "the ice is gone on map 486"
    $game_variables[471] = 1
    assert_includes info_key, "{rj_evergreen_go_down}"
    $game_variables[471] = 7
    refute_includes info_key, "rj_evergreen"
  end

  test "the Forsaken Laboratory's crest is named and listed until its tile puzzle is solved" do
    on_map(403, 30, 63)
    crest = place(62, 30, 62, "EV062")
    assert_equal "{rj_null_panel}", PokeAccess::Puzzles.piece_name(crest)
    assert_includes listed, [30, 62, "{rj_null_panel}"]
    $game_variables[431] = 5
    refute_includes listed, [30, 62, "{rj_null_panel}"]
  end

  test "the Garufa type beacons are named and listed until each is lit by its own flag" do
    on_map(72, 55, 102)
    water = place(12, 55, 101, "Type beacon")
    assert_equal "{rj_type_beacon}", PokeAccess::Puzzles.piece_name(water)
    assert_includes listed, [55, 101, "{rj_type_beacon}"]
    $game_variables[750] = 9
    refute_includes listed, [55, 101, "{rj_type_beacon}"]
    on_map(107, 16, 9)
    dragon = place(8, 15, 9, "Type beacon")
    poison = place(59, 79, 20, "Type beacon")
    assert_equal ["{rj_type_beacon}", "{rj_type_beacon}"], [dragon, poison].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    $game_switches[1588] = true
    refute_includes listed, [15, 9, "{rj_type_beacon}"]
    assert_includes listed, [79, 20, "{rj_type_beacon}"]
    $game_switches[1589] = true
    refute_includes listed, [79, 20, "{rj_type_beacon}"]
  end

  test "Volcanion's terminal is named while it can be used, and the assist alone gives the shutdown id as it is used" do
    on_map(153, 7, 56)
    terminal = place(30, 7, 55, "EV030")
    $game_variables[214] = 9
    assert_equal "{rj_volcanion_terminal}", PokeAccess::Puzzles.piece_name(terminal)
    refute_includes frame { fire(terminal) }, "{rj_volcanion_id}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { fire(terminal) }, "{rj_volcanion_id}"
    $game_variables[214] = 10
    refute_includes frame { fire(terminal) }, "{rj_volcanion_id}"
  end

  test "the Stolen Cargo arrows are named by the way they point now, and the monitors by their arrow with the assist" do
    on_map(79, 17, 28)
    lower = place(22, 17, 27, "Shock", 2)
    upper = place(37, 17, 20, "Shock", 2)
    monitor = place(69, 9, 12, "EV069")
    assert_equal "{rj_cargo_arrow_left}", PokeAccess::Puzzles.piece_name(lower)
    assert_equal "{rj_cargo_arrow_up}", PokeAccess::Puzzles.piece_name(upper)
    assert_equal "{rj_cargo_monitor}", PokeAccess::Puzzles.piece_name(monitor)
    $game_switches[1151] = true
    $game_switches[1152] = true
    assert_equal "{rj_cargo_arrow_up}", PokeAccess::Puzzles.piece_name(lower)
    assert_equal "{rj_cargo_arrow_right}", PokeAccess::Puzzles.piece_name(upper)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_cargo_monitor_upper}", PokeAccess::Puzzles.piece_name(monitor)
    assert_includes info_key, "{rj_cargo_hint}"
    $game_switches[1152] = false
    assert_includes info_key, "{rj_cargo_hint_straight}"
  end

  test "Griselda's panels say the badges they ask for with the assist alone, and the night rocks are listed only with it" do
    on_map(508, 30, 13)
    panel = place(2, 30, 12, "EV002")
    panel.tile_id = 814
    assert_equal "{rj_griselda_panel}", PokeAccess::Puzzles.piece_name(panel)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_griselda_panel_badges n=3}", PokeAccess::Puzzles.piece_name(panel)
    on_map(183, 31, 38)
    place(6, 31, 37, "EV006")
    assert_empty listed.select { |r| r[2] == "{rj_night_rock}" }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[31, 37, "{rj_night_rock}"]], listed.select { |r| r[2] == "{rj_night_rock}" }
  end

  test "the Edge of My World says the third knock's flight for anyone, and its door goes once it is done" do
    on_map(617, 21, 16)
    door = place(9, 21, 15, "EV009")
    frame
    assert_equal "{rj_edge_door}", PokeAccess::Puzzles.piece_name(door)
    assert_includes frame { $game_self_switches[[617, 9, "C"]] = true }, "{rj_edge_flew}"
    refute(listed.any? { |r| r[2] == "{rj_edge_door}" }, "the door leaves the list once the notes have flown")
  end

  test "the Darchlight machine's monitor is named while the shard heats, and the assist alone says the timer's moment" do
    on_map(365, 47, 22)
    sys = $game_system
    sys.singleton_class.send(:attr_accessor, :timer_working, :timer)
    units = (Object.const_get(:TIMER_UNITS) rescue nil) || (Graphics.frame_rate rescue 40)
    monitor = place(21, 47, 21, "EV021")
    $game_variables[523] = 5
    sys.timer_working = true
    sys.timer = 20 * units
    assert_equal "{rj_darch_monitor}", PokeAccess::Puzzles.piece_name(monitor)
    PokeAccess::Config.puzzle_assist = true
    refute_includes frame, "{rj_darch_now}"
    sys.timer = 15 * units + 1
    assert_includes frame, "{rj_darch_now}"
    PokeAccess::Config.puzzle_assist = false
    sys.timer = 20 * units
    frame
    sys.timer = 15 * units
    refute_includes frame, "{rj_darch_now}", "the moment is said with the assist alone"
  ensure
    sys.timer_working = false if sys
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjc_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjc_kept_t)
    i18n.send(:remove_method, :rjc_kept_t)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
