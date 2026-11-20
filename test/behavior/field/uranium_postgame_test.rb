# Pokemon Uranium 1.4.1's postgame puzzles of the second pass (games/uranium/puzzles): Route 18's Lotad pond, the Rangers'
# missions (the Xenomite, the Hazma and the Floatzel) and the professor's test; what each says with no help and what the
# assist adds.
class UraniumPostgameTest < PokeAccessTest
  test "the Lotad pond names its pieces by state, says the rule and gives the goal, the settling and the crossing" do
    lines = arrival(227)
    assert_includes lines, t(:ura_r2_lotad_rule)
    lotad = place(68, 15, 43, "lotadwalker", "lotad")
    master = place(28, 15, 38, "Ludicolo puzzlemaster", "Ludicolo")
    frame
    assert_equal t(:ura_r2_lotad_awake), PokeAccess::Puzzles.piece_name(lotad)
    assert_equal t(:ura_r2_ludicolo), PokeAccess::Puzzles.piece_name(master)
    assert(frame { $game_switches[228] = true }.join(" ").include?(t(:ura_r2_lotad_settled)))
    assert_equal t(:ura_r2_lotad_pad), PokeAccess::Puzzles.piece_name(lotad)
    pond = PokeAccess::UraniumLotad
    lotad.x = 14
    lotad.y = 32
    $game_switches[228] = false
    $game_map.width = 50
    $game_map.height = 90
    $game_player.x = 23
    $game_player.y = 47
    assert_equal [:ura_r3_lotad_settle_at, { :x => 14, :y => 32, :mx => 15, :my => 38, :sx => 16, :sy => 38 }], pond.hint
    $game_switches[228] = true
    assert_equal [:ura_r2_lotad_cross, { :x => 14, :y => 32 }], pond.hint
  end

  test "the Xenomite chase tells the side to speak from by the spot it has run to" do
    on_map(32)
    $game_variables[133] = 7
    xeno = place(26, 38, 41, "Mission Xenomite", "PU-Xenomite")
    frame
    assert_equal t(:ura_r2_xenomite), PokeAccess::Puzzles.piece_name(xeno)
    rangers = PokeAccess::UraniumRangers
    assert_equal :ura_r2_xeno_above_or_left, rangers.xenomite_hint
    $game_variables[134] = 3
    assert_equal :ura_r2_xeno_not_right, rangers.xenomite_hint
    $game_variables[134] = 5
    assert_equal :ura_r2_xeno_left, rangers.xenomite_hint
    $game_variables[134] = 99
    assert_equal "", rangers.xenomite_hint
  end

  test "the Hazma mission names its Pokémon and the ball and gives each push in turn" do
    lines = arrival(112) { $game_variables[133] = 6 }
    assert_includes lines, t(:ura_r2_hazma_rule)
    first = place(41, 35, 42, "MissionHazma41", "PU-Hazma")
    place(42, 34, 41, "MissionHazma42", "PU-Hazma")
    frame
    assert_equal t(:ura_r2_hazma), PokeAccess::Puzzles.piece_name(first)
    rangers = PokeAccess::UraniumRangers
    assert_equal [:ura_r2_push_down, { :x => 35, :y => 42 }], rangers.push_hint(112)
    first.x = 36
    assert_equal :ura_r2_ranger_reset, rangers.push_hint(112)
    $game_self_switches[[112, 41, "A"]] = true
    assert_equal [:ura_r2_push_down, { :x => 34, :y => 41 }], rangers.push_hint(112)
    refute_includes arrival(112) { $game_variables[133] = 7 }, t(:ura_r2_hazma_rule)
  end

  test "the Floatzel mission gives the slides toward the Ranger" do
    lines = arrival(225) { $game_variables[133] = 5 }
    assert_includes lines, t(:ura_r2_floatzel_rule)
    place(41, 20, 29, "MissionFloatzel41", "floatzel")
    second = place(43, 27, 12, "MissionFloatzel43", "floatzel")
    rangers = PokeAccess::UraniumRangers
    assert_equal [:ura_r2_push_down, { :x => 20, :y => 29 }], rangers.push_hint(225)
    $game_self_switches[[225, 41, "A"]] = true
    second.y = 17
    assert_equal [:ura_r2_push_left, { :x => 27, :y => 17 }], rangers.push_hint(225)
    $game_variables[134] = 99
    assert_equal "", rangers.push_hint(225)
  end

  test "the professor's test tells the last answer, the one that moves the memory on" do
    on_map(265)
    list = quiz_page
    place(1, 8, 5, "Professor", "HGSS_040", list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 1)
    assert_equal "Two or three inches of lead", PokeAccess::Puzzles::Answers.right_option(int, list, 0)
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def quiz_page
    choices = ["A glass of water", "Two or three inches of lead", "A cinderblock", "A mirror"]
    [TestCmd.new(102, [choices, 0], 0),
     TestCmd.new(402, [0, choices[0]], 0), TestCmd.new(119, ["wrong"], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [1, choices[1]], 0), TestCmd.new(201, [0, 268, 12, 14, 0, 0], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [2, choices[2]], 0), TestCmd.new(119, ["wrong"], 1), TestCmd.new(0, [], 1),
     TestCmd.new(402, [3, choices[3]], 0), TestCmd.new(119, ["wrong"], 1), TestCmd.new(0, [], 1),
     TestCmd.new(404, [], 0), TestCmd.new(0, [], 0)]
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def on_map(map)
    Harness.load_puzzles("uranium")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_switches[228] = false
    [133, 134].each { |id| $game_variables[id] = 0 }
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, sprite = "itemball", list = [TestCmd.new(0, [])])
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end
end
