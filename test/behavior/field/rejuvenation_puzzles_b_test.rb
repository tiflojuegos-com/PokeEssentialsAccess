# Pokemon Rejuvenation's puzzles, part B (games/rejuvenation/puzzles/): the Tower of Theolia, Valor Mountain, Cubi
# Excellus, Helojak Factory, Club S.T.F.U., Marble Mansion, Atebit Town, the School of Nightmares, Hiyoshi City, the
# Darchlight Caves and Heracross Woods. Without the assist, what the screen shows; with it, the way.
class RejuvenationPuzzlesBTest < PokeAccessTest
  SWITCHES = [274, 575, 576, 577, 604, 1324, 1449, 1450]
  VARS = [96, 115, 181, 183, 184, 186, 246, 265, 294, 296, 456, 514, 546, 684, 694]

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

  test "Theolia's statues say each push of the plan with the assist alone, and the servant once off the plan" do
    on_map(339, 55, 75)
    statue = place(32, 59, 72, "EV032", 0, "object_angiestatue")
    ladder = place(33, 59, 96, "Ladder 1", 1, "object_angiestatue")
    assert_equal "{rj_theolia_statue}", PokeAccess::Puzzles.piece_name(statue)
    refute(frame.any? { |l| l.include?("rj_theolia_push") }, "no plan without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{rj_theolia_push dir={face_south} from={face_north}}"
    assert_includes listed, [59, 71, "{rj_theolia_push_from}"]
    statue.y = 73
    ladder.y = 95
    assert_includes frame, "{rj_theolia_push dir={face_west} from={face_east}}"
    statue.x = 60
    assert_includes frame, "{rj_theolia_reset}"
    statue.x = 52
    ladder.x = 52
    ladder.y = 96
    assert_includes frame, "{rj_theolia_hint_back}"
  end

  test "Theolia's mirrors: every one listed alike without the assist; with it, the traps hidden and the right ones named" do
    on_map(339, 55, 91)
    right = place(30, 59, 89, "Break")
    trap = place(29, 57, 89, "Break")
    secret = place(162, 95, 70, "Break")
    assert_equal "{rj_theolia_mirror}", PokeAccess::Puzzles.piece_name(right)
    refute PokeAccess::Puzzles.hidden_event?(trap)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rj_theolia_mirror_right}", PokeAccess::Puzzles.piece_name(right)
    assert_equal "{rj_theolia_mirror_secret}", PokeAccess::Puzzles.piece_name(secret)
    assert PokeAccess::Puzzles.hidden_event?(trap)
    $game_switches[1449] = true
    assert_includes frame, "{rj_theolia_hint_up}"
  end

  test "Cubi Excellus says the next push of its room's plan and the statue each yellow tile waits for" do
    on_map(107, 10, 16)
    $game_variables[514] = 2
    toge = place(4, 13, 13, "Togekiss")
    place(5, 8, 13, "Greninja")
    place(6, 11, 10, "Seviper")
    assert_equal "{rj_garufa_statue name=Togekiss}", PokeAccess::Puzzles.piece_name(toge)
    assert_includes listed, [8, 11, "{rj_garufa_yellow}"]
    assert_includes listed, [8, 38, "{rj_garufa_drawn name=Togekiss}"]
    refute(frame.any? { |l| l.include?("rj_garufa_push") })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [8, 11, "{rj_garufa_goes name=Togekiss}"]
    assert_includes frame, "{rj_garufa_push dir={face_west} from={face_east} name=Togekiss}"
    toge.x = 12
    assert_includes frame, "{rj_garufa_push dir={face_west} from={face_east} name=Togekiss}"
    assert_includes listed, [13, 13, "{rj_garufa_push_from}"]
    toge.y = 12
    assert_includes frame, "{rj_garufa_reset}"
    { 4 => [8, 11], 5 => [11, 13], 6 => [13, 11] }.each { |id, (x, y)| $game_map.events[id].x = x; $game_map.events[id].y = y }
    assert_nil PokeAccess::RejuvGarufa.next_push(PokeAccess::RejuvGarufa::ROOMS[0]), "no reset once every statue is home"
    $game_variables[514] = 3
    assert_includes frame, "{rj_garufa_seal}"
  end

  test "Valor Mountain names a crystal by its colour, says the energy, and with the assist the next step by the stage" do
    on_map(139, 132, 40)
    red = place(4, 43, 13, "Valor Crystal", 0, "object_valorcryst", 2)
    source = place(22, 132, 84, "EV022", 0, "object_valorcryst_1", 2)
    assert_equal "{rj_valor_crystal_red}", PokeAccess::Puzzles.piece_name(red)
    assert_equal "{rj_valor_source_blue}", PokeAccess::Puzzles.piece_name(source)
    assert_includes info_key, "{rj_valor_look_neutral}"
    valor = PokeAccess::RejuvValor
    $game_variables[181] = 42
    assert_equal 41, valor.target(139)
    $game_switches[577] = true
    assert_equal 23, valor.target(139)
    place(23, 132, 30, "Valor Crystal", 0, "object_valorcryst", 4)
    assert_empty(listed.select { |r| r[2] == "{rj_valor_next}" })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [132, 30, "{rj_valor_next}"]
    on_map(140, 20, 20)
    $game_variables[181] = 42
    assert_equal :rj_valor_hint_magma, valor.hint(140)
    $game_variables[181] = 43
    assert_nil valor.target(140)
  end

  test "Helojak Factory names its machines and, with the assist, lists the way's steps by the lanes' variables" do
    on_map(463, 50, 30)
    $game_variables[96] = 34
    machine = place(13, 13, 20, "EV013", 0, "machine")
    place(12, 51, 26, "EV012", 1)
    place(59, 45, 24, "EV059", 1)
    assert_equal "{rj_helojak_machine}", PokeAccess::Puzzles.piece_name(machine)
    assert_includes info_key, "{rj_helojak_flow_left}"
    assert_empty(listed.select { |r| r[2].include?("rj_helojak_step") })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [51, 26, "{rj_helojak_step n=4}"]
    refute_includes listed, [45, 24, "{rj_helojak_step n=5}"]
    $game_variables[184] = 1
    assert_includes listed, [45, 24, "{rj_helojak_step n=5}"]
    refute_includes listed, [51, 26, "{rj_helojak_step n=4}"]
  end

  test "Club S.T.F.U.'s door says its meter as drawn, and the assist the hype left to 550" do
    on_map(414, 35, 14)
    door = place(6, 35, 11, "EV006", 0, "Hypeometer")
    $game_variables[115] = 120
    assert_equal "{rj_club_door n=2 of=8}", PokeAccess::Puzzles.piece_name(door)
    club = PokeAccess::RejuvClub
    assert_equal [:rj_club_hint_hype, { :n => 120, :of => 550 }], club.hint
    $game_variables[115] = 700
    assert_equal "{rj_club_door n=8 of=8}", PokeAccess::Puzzles.piece_name(door)
    assert_equal :rj_club_hint_open, club.hint
    $game_switches[274] = true
    assert_equal :rj_club_hint_enter, club.hint
  end

  test "the Meloetta statues say each turn, and with the assist whether it faces what the checker wants" do
    on_map(250, 63, 12)
    statue = place(25, 63, 10, "Meloetta 1", 0, "pkmn_meloetta_1")
    frame
    statue.direction = 6
    assert_includes frame, "{rj_meloetta_statue}: {face_east}"
    PokeAccess::Config.puzzle_assist = true
    statue.direction = 8
    assert_includes frame, "{rj_meloetta_statue}: {face_north}. {statue_goal dir={face_east}}"
    statue.direction = 6
    assert_includes frame, "{rj_meloetta_statue}: {face_east}. {statue_ok}"
    assert_includes listed, [63, 11, "{rj_meloetta_turn_from}"]
  end

  test "the family portrait and Kabuto's wall, both with no graphic, are listed while their puzzle is ahead" do
    on_map(250, 58, 53)
    portrait = place(57, 58, 52, "EV057")
    assert_equal "{rj_marble_portrait}", PokeAccess::Puzzles.piece_name(portrait)
    assert_includes listed, [58, 52, "{rj_marble_portrait}"]
    $game_switches[604] = true
    refute_includes listed, [58, 52, "{rj_marble_portrait}"]
    on_map(293, 59, 67)
    place(48, 59, 66, "EV048")
    $game_variables[265] = 19
    assert_includes listed, [59, 66, "{rj_atebit_tile_puzzle}"]
    $game_variables[265] = 21
    refute_includes listed, [59, 66, "{rj_atebit_tile_puzzle}"]
  end

  test "the Funky Forest names its flowers, keeps routes off them with the assist alone, and hints by the quest" do
    on_map(293, 30, 22)
    flower = place(27, 32, 25, "EV027", 1)
    assert_equal "{rj_atebit_flower}", PokeAccess::Puzzles.piece_name(flower)
    key = PokeAccess::Routes.pkey(32, 25)
    refute PokeAccess::Routes::Controls.keep_off[key]
    PokeAccess::Config.puzzle_assist = true
    assert PokeAccess::Routes::Controls.keep_off[key]
    $game_variables[265] = 17
    assert_equal :rj_atebit_hint_alice, PokeAccess::RejuvAtebit.forest_hint
    $game_variables[265] = 18
    assert_equal :rj_atebit_hint_cave, PokeAccess::RejuvAtebit.forest_hint
  end

  test "the masked men's entry is answered by the core with the assist, from the word the page compares" do
    script = TestCmd.new(355, ['pbTextEntry("Password",0,13,28)'])
    upcase = TestCmd.new(355, ["pbGet(28).upcase!"])
    check = TestCmd.new(111, [12, '$game_variables[28]=="SORRY"'])
    int = Object.new
    int.instance_variable_set(:@list, [script, upcase, check, TestCmd.new(0, [])])
    int.instance_variable_set(:@index, 0)
    assert_equal "SORRY", PokeAccess::Puzzles::Answers.expected(int, 0)
    on_map(94, 10, 41)
    man = place(25, 10, 39, "Man 1", 0, "NPC 22_2")
    assert_equal "{rj_school_masked_man}", PokeAccess::Puzzles.piece_name(man)
    $game_switches[1324] = true
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rj_school_password_hint}"
    $game_variables[684] = 4
    refute_includes info_key, "{rj_school_password_hint}"
  end

  test "Nymiera's bookcase is listed at variable 546's step 100 alone, naming its switch with the assist" do
    on_map(375, 47, 63)
    shelf = place(60, 47, 64, "EV060")
    $game_variables[546] = 100
    assert_includes listed, [47, 64, "{rj_nymiera_bookcase}"]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [47, 64, "{rj_nymiera_switch}"]
    $game_variables[546] = 101
    refute(listed.any? { |r| r[0] == 47 && r[1] == 64 })
    assert_equal "{rj_nymiera_switch}", PokeAccess::Puzzles.piece_name(shelf)
  end

  test "the Darchlight Caves name their gem pillars and, with the assist, number the way while the chapter runs" do
    on_map(363, 13, 18)
    gem = place(20, 8, 77, "EV020")
    place(14, 45, 25, "EV014", 1)
    assert_equal "{rj_darch_gem}", PokeAccess::Puzzles.piece_name(gem)
    PokeAccess::Config.puzzle_assist = true
    assert_empty(listed.select { |r| r[2].include?("rj_darch_step") })
    $game_variables[296] = 14
    assert_includes listed, [45, 25, "{rj_darch_step n=3}"]
    assert_includes listed, [8, 77, "{rj_darch_step n=4}"]
    $game_variables[296] = 19
    assert_empty(listed.select { |r| r[2].include?("rj_darch_step") })
  end

  test "Heracross Woods says each run of the red Heracross, and the assist the tile that takes the chase on" do
    on_map(244, 10, 41)
    $game_variables[456] = 29
    hera = place(4, 19, 41, "Heracross 0", 0, "pkmn_heracross")
    place(77, 15, 41, "EV077", 1)
    place(9, 25, 45, "EV009", 1)
    assert_equal "{rj_heracross}", PokeAccess::Puzzles.piece_name(hera)
    frame
    $game_variables[694] = 3
    assert_includes frame, "{rj_heracross_fled}"
    $game_variables[694] = 7
    refute_includes frame, "{rj_heracross_fled}"
    $game_variables[694] = 0
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [15, 41, "{rj_heracross_next}"]
    assert PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(25, 45)]
    $game_variables[694] = 6
    assert_equal :rj_heracross_hint_talk, PokeAccess::RejuvHeracross.hint
  end

  private

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

  def place(id, x, y, name, trigger = 0, sprite = "", direction = 2)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :direction => direction,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    ev.direction = direction
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
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

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rjb_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rjb_kept_t)
  end
end
