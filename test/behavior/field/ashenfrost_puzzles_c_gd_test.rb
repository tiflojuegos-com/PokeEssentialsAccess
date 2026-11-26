# Pokemon Ashen Frost's puzzles of part C (games/ashenfrost/puzzles/): Rococo Retreat's smells, the apprentice's name, the
# factory's second floor with Tiramisu, and the Well Temple's sand pits, candles, depths, Unown hall and the box of its rocks.
# Without the assist, what the screen shows; with it, the step due. Gamedata pass.

# The event interpreter, down to Set Move Route (command 209), as realidea_jade_test.rb has it.
class Interpreter
  def command_209; true; end unless method_defined?(:command_209)
end

class AshenfrostPuzzlesCGdTest < PokeAccessTest
  SWITCHES = [71, 280]
  VARS = [142, 175, 251, 252, 253, 254]
  Route = Struct.new(:list)
  Move = Struct.new(:code, :parameters)

  def setup
    super
    keyed
    Harness.load_puzzles("ashenfrost")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    $game_self_switches = {}
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

  test "Rococo's smells go by their colour and their hole, and the assist counts them and sends back to Trainer Smell" do
    on_map(493, 26, 30)
    $game_switches[71] = true
    $game_variables[142] = 1
    green = place(17, 38, 25, [TestCmd.new(101, ["A smell!"])], "HiddenItem_Smell_Green")
    trainer = place(14, 26, 32, [TestCmd.new(101, ["A smell!"])], "Syl_walk_4")
    assert_equal "{afc_smell_green}", PokeAccess::Puzzles.piece_name(green)
    assert_equal "{afc_smell_trainer}", PokeAccess::Puzzles.piece_name(trainer)
    refute_includes info_key, "afc_smell_count"
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[493, 17, "A"]] = true
    $game_variables[142] = 2
    assert_equal "{afc_smell_dug}", PokeAccess::Puzzles.piece_name(green)
    refute_includes info_key, "afc_smell_back"
    [15, 16, 18].each { |id| $game_self_switches[[493, id, "A"]] = true }
    $game_variables[142] = 5
    assert_equal 4, PokeAccess::AshenRococo.dug
    assert_includes info_key, "{afc_smell_back}"
    $game_variables[142] = 6
    refute_includes info_key, "afc_smell_"
  end

  test "the apprentice's word is spelled after her line, the only point of her page" do
    list = [TestCmd.new(101, ["\\xn[Apprentice]\\r<i>Plllfffbt!"]), TestCmd.new(101, ["\\xn[Apprentice]\\rNo! <i>Plllfffbt!"]),
            TestCmd.new(101, ["\\xn[Mordecai]\\c[49]<i>Pllllllffbtttt?"]),
            TestCmd.new(111, [12, "passCheck(\"Plllfffbt\",\"My new name?\",0,9,false)"])]
    on_map(549, 3, 7)
    girl = place(1, 3, 6, list, "NPC_63")
    letters = "P, l, l, l, f, f, f, b, t"
    assert_equal [:afc_name_spelled, { :letters => letters }], PokeAccess::AshenApprentice.her_word(girl)
    points = PokeAccess::World::Mechanics.entries_for(:reaches, girl)
    assert_equal 1, points.size, "the answer at the entry is assist_answers.rb's"
    assert_equal [1], list.each_index.select { |i| list[i].parameters[0].to_s =~ points[0][:text] }
  end

  test "the factory names Tiramisu, the seesaws and the spikes as they stand, and the assist gives each step" do
    on_map(112, 3, 8)
    tiramisu = place(2, 5, 9, [TestCmd.new(101, ["text"])], "Truffles_walk")
    spikes = place(11, 16, 26, [], "")
    spikes.tile_id = 597
    assert_equal "{afc_factory_tiramisu}", PokeAccess::Puzzles.piece_name(tiramisu)
    assert_equal "{afc_factory_red_spikes}", PokeAccess::Puzzles.piece_name(spikes)
    refute_includes info_key, "afc_factory_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afc_factory_hint_talk}"
    $game_self_switches[[112, 2, "A"]] = true
    assert_includes info_key, "{afc_factory_hint_jump}"
    $game_self_switches[[112, 6, "A"]] = true
    assert_includes info_key, "{afc_factory_hint_red}"
    lines = frame { $game_self_switches[[112, 11, "A"]] = true }
    assert_includes lines.join(" "), "{afc_factory_red_down}"
    assert_equal "{afc_factory_lowered spikes={afc_factory_red_spikes}}", PokeAccess::Puzzles.piece_name(spikes)
    $game_self_switches[[112, 8, "B"]] = true
    assert_includes info_key, "{afc_factory_hint_sparkle}"
    $game_self_switches[[112, 14, "A"]] = true
    assert_includes info_key, "{afc_factory_hint_roof}"
    $game_variables[175] = 2
    refute_includes info_key, "afc_factory_hint"
  end

  test "the sand pits go by their corner, the rule is said in the room, and the assist marks the pit due" do
    on_map(686, 38, 8)
    upper_left = place(33, 32, 5, [TestCmd.new(201, [0, 686, 38, 8, 2, 0])], "", 1)
    lower_right = place(39, 43, 13, [TestCmd.new(201, [0, 686, 38, 8, 2, 0])], "", 1)
    assert_equal "{afc_pit_ul}", PokeAccess::Puzzles.piece_name(upper_left)
    assert_includes info_key, "{afc_pits_rule}"
    refute_includes info_key, "afc_pits_next"
    assert_empty frame { $game_variables[254] = 1 }
    $game_variables[254] = 0
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afc_pits_next n=1 pit={afc_pit_ul}}"
    assert_equal "{afc_due name={afc_pit_ul}}", PokeAccess::Puzzles.piece_name(upper_left)
    $game_variables[254] = 1
    assert_includes info_key, "{afc_pits_next n=2 pit={afc_pit_lr}}"
    assert_equal "{afc_due name={afc_pit_lr}}", PokeAccess::Puzzles.piece_name(lower_right)
    assert_equal "{afc_pit_ul}", PokeAccess::Puzzles.piece_name(upper_left)
    assert_includes(frame { $game_variables[254] = 2 }.join(" "), "{afc_pits_next n=3 pit={afc_pit_ur}}")
    $game_variables[254] = 7
    assert_includes info_key, "{afc_pits_next n=8 pit={afc_pit_ur}}"
    $game_variables[254] = 8
    assert_includes info_key, "{afc_pits_any}"
    $game_player.x, $game_player.y = 7, 33
    assert_includes info_key, "{afc_pits_press}"
    $game_self_switches[[686, 46, "A"]] = true
    refute_includes info_key, "afc_pits_"
  end

  test "each candle is said by its number as the game lights it, and the assist gives the base due at each level" do
    on_map(686, 7, 7)
    base = place(15, 8, 8, [TestCmd.new(122, [253, 253, 0, 0, 1])])
    SpeakCapture.clear
    set_route(20, [Move.new(44, []), Move.new(41, ["Object_Candles", 0, 2, 0])])
    set_route(15, [Move.new(41, ["Object_Candles", 0, 2, 0])])
    set_route(20, [Move.new(1, [])])
    assert_equal ["{afc_candle_lit n=3}"], SpeakCapture.lines
    assert_equal "{afc_candle_base n=3}", PokeAccess::Puzzles.piece_name(base)
    assert_includes info_key, "{afc_candles_rule}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afc_candles_next base=1 level=1 n=1 of=4}"
    assert_includes(frame { $game_variables[252] = 1 }.join(" "), "{afc_candles_next base=3 level=2 n=1 of=5}")
    assert_equal "{afc_due name={afc_candle_base n=3}}", PokeAccess::Puzzles.piece_name(base)
    $game_variables[252] = 2
    $game_variables[253] = 2
    assert_includes info_key, "{afc_candles_next base=5 level=3 n=3 of=7}"
    lines = frame { $game_self_switches[[686, 10, "A"]] = true }
    assert_includes lines.join(" "), "{afc_candles_spikes_down}"
    $game_variables[252] = 3
    refute_includes info_key, "afc_candles_"
  end

  test "the depths name their switch, and the assist gives the way round until it is pressed" do
    on_map(687, 34, 24)
    switch = place(3, 33, 12, [TestCmd.new(122, [251, 251, 1, 0, 1])])
    assert_equal "{afc_switch}", PokeAccess::Puzzles.piece_name(switch)
    refute_includes info_key, "afc_depths_way"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afc_depths_way}"
    $game_self_switches[[687, 3, "A"]] = true
    refute_includes info_key, "afc_depths_way"
  end

  test "the Unown hall names the letters in the way, and the assist follows the four that open it" do
    hall = PokeAccess::AshenTempleHall
    on_map(688, 9, 54)
    zaps = { 12 => "Zap - E", 14 => "Zap - I", 21 => "Zap - E", 24 => "Zap - E", 26 => "Zap - I", 29 => "Zap - I" }
    events = {}
    zaps.each { |id, name| events[id] = named(id, 9, 40 - id, name) }
    assert_equal "{afc_hall_zap letter=E}", PokeAccess::Puzzles.piece_name(events[12])
    refute_includes info_key, "afc_hall_next"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afc_hall_next letter=E}"
    assert_equal "{afc_due name={afc_hall_zap letter=E}}", PokeAccess::Puzzles.piece_name(events[12])
    assert_includes(frame { zap([12]) }.join(" "), "{afc_hall_next letter=I}")
    assert_equal [14, 21, 24, nil], [[], [14], [21], [24]].map { |ids| zap(ids); hall.next_zap }
    $game_self_switches = {}
    zap([11, 16, 26])
    assert_equal 29, hall.next_zap
    zap([29])
    assert_nil hall.next_zap
    assert_includes info_key, "{afc_hall_go}"
    $game_switches[280] = true
    refute_includes info_key, "afc_hall_"
  end

  test "the rocks' box is pointed to with the assist as the right wing drops it, and not once it is taken" do
    on_map(686, 28, 61)
    $game_self_switches[[686, 61, "A"]] = true
    refute_includes(frame { $game_self_switches[[686, 61, "B"]] = true }.join(" "), "afc_temple_box_hint")
    $game_self_switches[[686, 61, "B"]] = false
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes(frame { $game_self_switches[[686, 61, "B"]] = true }.join(" "), "{afc_temple_box_hint}")
    assert PokeAccess::AshenWellTemple.box_due?
    assert_includes info_key, "{afc_temple_box_hint}", "the info key, while the box holds the Scroll"
    PokeAccess::World::Mechanics.forget
    assert_includes(frame.join(" "), "{afc_temple_box_hint}", "coming back to the map")
    $game_self_switches[[686, 64, "B"]] = true
    refute PokeAccess::AshenWellTemple.box_due?
    refute_includes info_key, "afc_temple_box_hint"
  end

  def set_route(character, moves)
    interp = Interpreter.allocate
    interp.instance_variable_set(:@parameters, [character, Route.new(moves)])
    interp.command_209
  end

  def zap(ids)
    ids.each { |id| $game_self_switches[[688, id, "A"]] = true }
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afc_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afc_kept_t)
    i18n.send(:remove_method, :afc_kept_t)
  end

  def on_map(map, x, y)
    World.clear_events
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "", trigger = 0)
    named(id, x, y, "EV#{id}", list, sprite, trigger)
  end

  def named(id, x, y, name, list = [TestCmd.new(250, [nil])], sprite = "201_4", trigger = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list + [TestCmd.new(0, [])])
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
    World.next_frame
    PokeAccess::Info.map_text.to_s
  end
end
