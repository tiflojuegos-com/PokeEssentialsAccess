# Pokemon Armonia's puzzles on the shipped profile (games/armonia/puzzles): Ferese's gym, the catacombs of Santuario de Ordelen,
# the maze of Jungla Simfo and the small declarations of the yincana, the gyms' quizzes and the errands, each as it is heard
# without the puzzle assist and with it.
class ArmoniaPuzzlesTest < PokeAccessTest
  SWITCHES = [5, 8, 77, 93, 95]
  VARIABLES = [29, 31, 34]
  SIDES = [:arm_simfo_at_north, :arm_simfo_at_east, :arm_simfo_at_south, :arm_simfo_at_west]
  SIDE_TILE = [[14, 3], [27, 16], [14, 27], [2, 15]]
  # Each room as it is drawn: its flowers to the north, east, south and west, the note it stands for, the side that goes on, that
  # exit's event and an exit that sends back.
  JUNGLE = { 130 => [%w[pink blue yellow white], "re", "blue", 1, 4, 2], 131 => [%w[pink white blue yellow], "do", "pink", 0, 1, 3],
             132 => [%w[white yellow pink blue], "la", "yellow", 1, 1, 4], 133 => [%w[yellow white blue pink], "fa", "white", 1, 1, 3],
             134 => [%w[blue pink white yellow], "re", "blue", 0, 1, 3], 135 => [%w[pink white yellow blue], "re", "blue", 3, 1, 3],
             136 => [%w[yellow blue pink white], "do", "pink", 2, 14, 4], 137 => [%w[white yellow pink blue], "la", "yellow", 1, 1, 3],
             138 => [%w[pink blue white yellow], "do", "pink", 0, 1, 3] }

  test "the first two rooms list every Milotic statue alike, say the curtain's state and with the assist name the button" do
    on_map(6)
    assert_equal [t(:arm_ferese_rule)], @arrival
    place(10, 5, 13, [text])
    place(11, 16, 13, [text])
    place(7, 10, 12, [TestCmd.new(0, [])], "aacortina")
    assert_equal [[5, 13, t(:arm_ferese_statue)], [16, 13, t(:arm_ferese_statue)]], listed
    assert_equal t(:arm_ferese_curtain), PokeAccess::Puzzles.piece_name($game_map.events[7])
    assert_includes info_key, "#{t(:arm_ferese_curtain)}: #{t(:arm_ferese_closed)}"
    refute_includes info_key, t(:arm_ferese_hint_room)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[5, 13, t(:arm_ferese_statue_plain)], [16, 13, t(:arm_ferese_statue_room)]], listed
    assert_includes info_key, t(:arm_ferese_hint_room)
    PokeAccess::Config.puzzle_assist = false
    $game_self_switches[[6, 11, "A"]] = true
    assert_equal [[5, 13, t(:arm_ferese_statue)]], listed
    assert_equal ["#{t(:arm_ferese_curtain)}: #{t(:arm_ferese_open)}"], tick { $game_self_switches[[6, 7, "A"]] = true }
    assert_empty listed
    on_map(7)
    place(5, 6, 23, [text])
    assert_equal [t(:arm_ferese_rule)], @arrival
    assert_equal [[6, 23, t(:arm_ferese_statue)]], listed
    assert_equal ["#{t(:arm_ferese_curtain)}: #{t(:arm_ferese_open)}"], tick { $game_self_switches[[7, 6, "A"]] = true }
  end

  test "the third room says its temperature as it moves, with the assist the cooling presses left and what each button does" do
    on_map(4)
    assert_equal [t(:arm_ferese_rule)], @arrival
    [[4, 41, 19], [11, 8, 19], [23, 8, 38], [24, 41, 38]].each { |id, x, y| place(id, x, y, [text]) }
    assert_equal 4, listed.length
    assert_equal [t(:arm_ferese_statue)], listed.map { |r| r[2] }.uniq
    assert_equal PokeAccess.sentences(["#{t(:arm_ferese_title)}. #{temperature(:arm_ferese_t_0)}", t(:arm_ferese_rule)]), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:arm_ferese_statue_warm), t(:arm_ferese_statue_cool), t(:arm_ferese_statue_cool), t(:arm_ferese_statue_plain)],
                 [11, 23, 4, 24].map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
    assert_includes info_key, t(:arm_ferese_hint, :n => 2)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [temperature(:arm_ferese_t_1)], tick { $game_variables[29] = 1 }
    assert_equal [temperature(:arm_ferese_t_m1)], tick { $game_variables[29] = -1 }
    $game_self_switches[[4, 11, "A"]] = true
    assert_equal t(:arm_ferese_statue_used), PokeAccess::Puzzles.piece_name($game_map.events[11])
    assert_equal 3, listed.length
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:arm_ferese_hint, :n => 3)
    assert_equal [temperature(:arm_ferese_t_2)], tick { $game_variables[29] = 2 }
    assert_includes info_key, t(:arm_ferese_hint, :n => 0)
    $game_self_switches[[4, 1, "A"]] = true
    tick
    assert_empty listed
    refute_includes info_key.to_s, t(:arm_ferese_title)
  end

  test "the third room says no rule on arriving once its curtain is open, and nothing on the info key" do
    on_map(4) { $game_self_switches[[4, 1, "A"]] = true }
    assert_empty @arrival
    assert_nil PokeAccess::Puzzles.info_line
    on_map(4) { $game_variables[29] = 2 }
    assert_equal [t(:arm_ferese_rule)], @arrival
  end

  test "the catacombs name their levers and doors, count the mechanisms with no total and with the assist say what each opens, until the badge" do
    on_map(119)
    plain = lambda { |n| t(:arm_ordelen_count_plain, :n => n) }
    count = lambda { |n| t(:arm_ordelen_count, :n => n, :of => 6) }
    assert_empty @arrival
    [[3, 48, 15], [4, 39, 18], [13, 9, 3]].each { |id, x, y| place(id, x, y, [text], "antorcha") }
    door = place(9, 19, 23, [text], "PuertasCripta")
    ghost = place(1, 43, 25, [text], "428")
    assert_equal 3, listed.select { |r| r[2] == t(:arm_ordelen_lever) }.length
    assert_equal t(:arm_ordelen_door), PokeAccess::Puzzles.piece_name(door)
    assert_equal t(:arm_ordelen_blocker), PokeAccess::Puzzles.piece_name(ghost)
    $game_self_switches[[119, 3, "A"]] = true
    assert_equal 2, listed.select { |r| r[2] == t(:arm_ordelen_lever) }.length
    assert_equal [plain.call(1)], tick { $game_variables[34] = 1 }
    assert_equal plain.call(1), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:arm_ordelen_blocker_item), PokeAccess::Puzzles.piece_name(ghost)
    assert_equal ["#{count.call(2)}. #{t(:arm_ordelen_hint_2)}"], tick { $game_variables[34] = 2 }
    assert_includes info_key, t(:arm_ordelen_hint_2)
    (3..5).each do |n|
      assert_equal ["#{count.call(n)}. #{t("arm_ordelen_hint_#{n}")}"], tick { $game_variables[34] = n }
    end
    assert_equal ["#{count.call(6)}. #{t(:arm_ordelen_hint_6)}"], tick { $game_variables[34] = 6 }
    assert_equal ["#{count.call(6)}. #{t(:arm_ordelen_hint_6)}"], arrive(120)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [plain.call(6)], arrive(119)
    on_map(118)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:arm_ordelen_hint_0)], arrive(120)
    PokeAccess::Config.puzzle_assist = false
    arrive(118)
    place(17, 16, 31, [text], "antorcha")
    assert_equal [[16, 31, t(:arm_ordelen_lever)]], listed
    $game_variables[34] = 3
    $game_switches[8] = true
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_empty tick
    assert_empty arrive(119)
    assert_empty arrive(120)
    refute_includes info_key.to_s, count.call(3)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, plain.call(3)
  end

  test "the catacombs' levers and fights are controls of the doors that wait for the count, each named, a lever until it is pulled" do
    add = TestCmd.new(122, [34, 34, 1, 0, 1], 1)
    on_map(119)
    [[3, 48, 15], [4, 39, 18], [13, 9, 3]].each { |id, x, y| place(id, x, y, [TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]), add], "antorcha") }
    place(9, 19, 23, [text], "PuertasCripta")
    PokeAccess::World::Mechanics.forget
    assert_equal [3, 4, 13], PokeAccess::World::Mechanics.instances.map { |inst| inst.controls.keys }.flatten.sort
    assert_equal 3, listed.select { |r| r[2] == t(:arm_ordelen_lever) }.length
    $game_self_switches[[119, 3, "A"]] = true
    assert_equal 2, listed.select { |r| r[2] == t(:arm_ordelen_lever) }.length, "pulled, its page still runs"
    on_map(120)
    place(5, 12, 13, [TestCmd.new(101, ["Pent!"]), add], "608")
    place(8, 7, 19, [TestCmd.new(101, ["Pent..."]), add], "608")
    PokeAccess::World::Mechanics.forget
    assert_equal [t(:arm_ordelen_lampent), t(:arm_ordelen_lampent2)], [5, 8].map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
  end

  test "with the assist the catacombs tell when two levers came before the fight with the Lampent, and not when it was fought" do
    on_map(119)
    PokeAccess::Config.puzzle_assist = true
    count = lambda { |n| t(:arm_ordelen_count, :n => n, :of => 6) }
    $game_self_switches[[119, 13, "A"]] = true
    assert_equal ["#{count.call(1)}. #{t(:arm_ordelen_hint_1)}"], tick { $game_variables[34] = 1 }
    $game_self_switches[[119, 3, "A"]] = true
    assert_equal ["#{count.call(2)}. #{t(:arm_ordelen_hint_lost)}"], tick { $game_variables[34] = 2 }
    assert_includes info_key, t(:arm_ordelen_hint_lost)
    $game_self_switches[[119, 4, "A"]] = true
    assert_equal ["#{count.call(3)}. #{t(:arm_ordelen_hint_lost)}"], tick { $game_variables[34] = 3 }
    on_map(119)
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[119, 3, "A"]] = true
    assert_equal ["#{count.call(2)}. #{t(:arm_ordelen_hint_2)}"], tick { $game_variables[34] = 2 }
    $game_self_switches[[119, 4, "A"]] = true
    assert_equal ["#{count.call(3)}. #{t(:arm_ordelen_hint_3)}"], tick { $game_variables[34] = 3 }
  end

  test "the ghosts before Elus are named while they stand and said on the info key, and with the assist so are the two ways round them" do
    on_map(118)
    ghost = place(37, 24, 46, [TestCmd.new(355, ["pbPlayCry(253)"])], "253")
    assert_equal t(:arm_ordelen_ghost), PokeAccess::Puzzles.piece_name(ghost)
    assert_equal t(:arm_ordelen_elus), PokeAccess::Puzzles.piece_name(place(34, 24, 14, [text], "Elus3"))
    assert_equal [t(:arm_ordelen_ghost)], listed.map { |r| r[2] }
    refute_includes info_key, t(:arm_ordelen_ghosts)
    $game_self_switches[[118, 37, "A"]] = true
    tick
    assert_includes info_key, t(:arm_ordelen_ghosts)
    refute_includes info_key, t(:arm_ordelen_bypass)
    assert_empty gaps
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:arm_ordelen_bypass)
    assert_equal [[20, 46], [28, 46]], gaps
    $game_self_switches[[118, 37, "B"]] = true
    tick
    refute_includes info_key, t(:arm_ordelen_ghosts)
    assert_empty gaps
    place(37, 24, 46, [TestCmd.new(0, [])])
    assert_empty listed, "gone once its page is blank"
    $game_self_switches[[118, 37, "B"]] = false
    $game_switches[8] = true
    tick
    refute_includes info_key, t(:arm_ordelen_ghosts)
  end

  test "the Kiwono are named by colour and note, and the song, in order with the colours, is said as Thorn's scene ends and then on the info key" do
    on_map(129)
    assert_equal [t(:arm_simfo_start)], @arrival
    { 1 => [18, 13, :arm_simfo_blue], 2 => [21, 13, :arm_simfo_yellow], 3 => [18, 15, :arm_simfo_pink],
      4 => [21, 15, :arm_simfo_white] }.each { |id, (x, y, _key)| place(id, x, y, [text]) }
    assert_equal [t(:arm_simfo_kiwono)], listed.map { |r| r[2] }.uniq, "no note before the scene shows it"
    notes = %w[re do la fa re re do la do].map { |n| t("arm_simfo_v_#{n}") }.join(", ")
    whole = PokeAccess.sentences([t(:arm_simfo_song, :notes => notes), t(:arm_simfo_rule)])
    assert_nil PokeAccess::Puzzles.info_line, "no sighted player has seen it before the scene"
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = false
    assert_equal [t(:arm_simfo_rule)], tick { $game_self_switches[[129, 13, "A"]] = true }
    assert_equal whole, info_key
    assert_equal [[18, 13, t(:arm_simfo_blue)], [18, 15, t(:arm_simfo_pink)], [21, 13, t(:arm_simfo_yellow)],
                  [21, 15, t(:arm_simfo_white)]], listed
    assert_empty tick
    place(13, 20, 20, [text])
    [1, 2, 3, 4, 13].each { |id| assert_empty tick { fire($game_map.events[id]) }, "event #{id}" }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:arm_simfo_key)
    PokeAccess::Config.puzzle_assist = false
    arrive(130)
    assert_equal [t(:arm_simfo_rule)], arrive(129), "a wrong exit comes back to the whole rule"
  end

  test "the song is said as the scene and each Kiwono sing it, and a wrong exit says so on coming back to the start" do
    on_map(129)
    int = Object.new
    { :@list => [], :@index => 0, :@event_id => 13 }.each { |k, v| int.instance_variable_set(k, v) }
    place(13, 20, 20, [TestCmd.new(0, [])])
    scene = (0..5).map { |n| TestCmd.new(101, ["Line #{n}"]) }
    notes = %w[re do la fa re re do la do].map { |n| t("arm_simfo_v_#{n}") }.join(", ")
    song = t(:arm_simfo_song, :notes => notes)
    int.instance_variable_set(:@list, scene)
    int.instance_variable_set(:@index, 3)
    PokeAccess::Puzzles::Reach.before_text(int)
    assert_nil PokeAccess.take_tail, "not on the texts before it"
    int.instance_variable_set(:@index, 4)
    PokeAccess::Puzzles::Reach.before_text(int)
    assert_equal song, PokeAccess.take_tail
    place(1, 18, 13, [text])
    menu = [TestCmd.new(102, [%w[Si No], 2]), TestCmd.new(402, [0, "Si"]), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "No"]), TestCmd.new(404, [])]
    int.instance_variable_set(:@event_id, 1)
    int.instance_variable_set(:@list, menu)
    int.instance_variable_set(:@index, 1)
    int.instance_variable_set(:@branch, { 0 => 0 })
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(int)
    assert_equal [song], SpeakCapture.log.map { |line| line[0] }
    int.instance_variable_set(:@branch, { 0 => 1 })
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(int)
    assert_empty SpeakCapture.log, "they asked not to hear it"
    assert_equal t(:arm_simfo_wrong), PokeAccess::Puzzles.sent_back_line([14, 3, 133], [19, 12, 129], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([14, 3, 128], [19, 12, 129], :map), "not from the map before the maze"
    assert_nil PokeAccess::Puzzles.sent_back_line([14, 3, 133], [38, 32, 129], :map), "not landing elsewhere"
  end

  test "every room says its flowers on arrival and names each exit by them, and with the assist its place, its note and the way on" do
    JUNGLE.each do |map, (flowers, note, colour, way, good, back)|
      on_map(map)
      line = flowers_line(flowers)
      assert_equal [t(:arm_simfo_room), line], @arrival, "map #{map}"
      other = (way + 1) % 4
      right = exit_at(good, way, [0, map + 1, 3, 16, 0, 0], "morgan size(1,5)")
      wrong = exit_at(back, other, [0, 129, 19, 12, 0, 0], "tp")
      assert_equal t(:arm_simfo_exit, :c => t("arm_simfo_c_#{colour}")), PokeAccess::Puzzles.piece_name(right), "map #{map}"
      assert_equal t(:arm_simfo_exit, :c => t("arm_simfo_c_#{flowers[other]}")), PokeAccess::Puzzles.piece_name(wrong), "map #{map}"
      refute PokeAccess::Locator.hidden?(wrong), "map #{map}"
      assert_empty listed, "map #{map}"
      hint = t(:arm_simfo_hint, :n => map - 129, :note => t("arm_simfo_v_#{note}"), :c => t("arm_simfo_c_#{colour}"), :at => t(SIDES[way]))
      assert_equal PokeAccess.sentences([line, t(:arm_simfo_room)]), info_key, "map #{map}"
      PokeAccess::Config.puzzle_assist = true
      assert PokeAccess::Locator.hidden?(wrong), "map #{map}"
      refute PokeAccess::Locator.hidden?(right), "map #{map}"
      assert_equal t(:arm_simfo_right_exit, :c => t("arm_simfo_c_#{colour}")), PokeAccess::Puzzles.piece_name(right), "map #{map}"
      assert_equal [[right.x, right.y, t(:arm_simfo_right_exit, :c => t("arm_simfo_c_#{colour}"))]], listed, "map #{map}"
      assert_includes info_key, hint, "map #{map}"
    end
  end

  test "a room says its rule once, however many tries come back to it, and its flowers on each arrival" do
    on_map(130)
    line = flowers_line(JUNGLE[130][0])
    assert_equal [t(:arm_simfo_room), line], @arrival
    arrive(129)
    assert_equal [line], arrive(130)
  end

  test "the exits to the optional side rooms are named by their flowers and not hidden with the assist" do
    { 132 => ["tp", 142, 0], 136 => ["morgan size(1,5)", 141, 1] }.each do |map, (name, room, side)|
      on_map(map)
      leads_off = exit_at(3, side, [0, room, 13, 55, 0, 0], name)
      PokeAccess::Config.puzzle_assist = true
      refute PokeAccess::Locator.hidden?(leads_off), "map #{map}"
      assert_equal t(:arm_simfo_exit, :c => t("arm_simfo_c_#{JUNGLE[map][0][side]}")), PokeAccess::Puzzles.piece_name(leads_off), "map #{map}"
    end
  end

  test "the yincana's balloons are listed until popped and its clues counted while it runs" do
    on_map(18)
    balloon = place(47, 1, 36, [text], "globo")
    $game_switches[77] = true
    assert_equal [[1, 36, t(:arm_kalima_balloon)]], listed
    assert_equal t(:arm_kalima_balloon), PokeAccess::Puzzles.piece_name(balloon)
    refute_includes info_key.to_s, t(:arm_kalima_clues)
    clue = t(:puzzle_progress, :label => t(:arm_kalima_clues), :n => 1, :of => 3)
    assert_equal [clue], tick { $game_variables[31] = 1 }
    assert_includes info_key, clue
    $game_self_switches[[18, 47, "A"]] = true
    assert_empty listed
    tick { $game_variables[31] = 3 }
    refute_includes info_key.to_s, t(:arm_kalima_clues)
  end

  test "the quizzes say with the assist the option that avoids the fight or adds to the mark, in the game's words" do
    fight = [TestCmd.new(111, [12, "pbTrainerBattle(PBTrainers::SCIENTIST,\"Edward\")"], 1)]
    pass = [TestCmd.new(123, ["A", 0], 1)]
    { 25 => 29, 26 => 31, 27 => 8, 197 => 29 }.each do |map, id|
      on_map(map)
      assert_equal "Right", option(id, %w[Wrong Right], [fight, pass]), "map #{map}"
    end
    on_map(197)
    assert_equal "Right", option(29, %w[Wrong Jump Right], [fight + pass, [TestCmd.new(119, ["fight"], 1)], pass])
    { 103 => [5, 8], 105 => [5, 7] }.each do |map, ids|
      ids.each do |id|
        on_map(map)
        assert_equal "No", option(id, %w[Si No], [fight, pass]), "map #{map} event #{id}"
      end
    end
    on_map(105)
    assert_nil option(4, %w[Si No], [pass, pass])
    on_map(140)
    assert_equal "Mudsdale", option(4, %w[Metagross Mudsdale], [[TestCmd.new(250, ["ok"], 1)], [TestCmd.new(122, [35, 35, 1, 0, 1], 1)]])
    exam = [TestCmd.new(201, [0, 140, 7, 10, 0, 0], 1), TestCmd.new(122, [35, 35, 1, 0, 1], 1)]
    assert_nil option(4, %w[Yes Pass], [exam, [TestCmd.new(250, ["ok"], 1)]]), "the invitation is not an answer"
  end

  test "the piles of rubbish go by that name in the lists" do
    [179, 180, 209, 210].each do |map|
      on_map(map)
      pile = place(25, 44, 50, [text], "OW_Basura")
      assert_equal t(:arm_trash_heap), PokeAccess::Puzzles.piece_name(pile), "map #{map}"
      assert_equal [[44, 50, t(:arm_trash_heap)]], listed, "map #{map}"
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def text; TestCmd.new(101, ["text"]); end

  def flowers_line(flowers)
    parts = (0..3).map { |i| "#{t("arm_simfo_c_#{flowers[i]}")} #{t(SIDES[i])}" }
    t(:arm_simfo_flowers, :list => parts.join(", "))
  end

  def exit_at(id, side, transfer, name)
    place(id, SIDE_TILE[side][0], SIDE_TILE[side][1], [TestCmd.new(201, transfer)], "", name)
  end

  def gaps
    listed.select { |r| r[2] == t(:arm_ordelen_gap) }.map { |r| [r[0], r[1]] }
  end

  # The option right_choice picks of a menu on an event, its page made of the options and each one's commands.
  def option(id, options, branches)
    list = [TestCmd.new(102, [options, 1], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    place(id, 5, 5, list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
  end

  # Comes onto a map within the same session: what is said there.
  def arrive(map)
    World.clear_events
    $game_map.map_id = map
    World.next_frame
    tick
  end

  def temperature(word)
    t(:puzzle_value, :label => t(:arm_ferese_temp), :v => t(word))
  end

  def on_map(map)
    Harness.load_puzzles("armonia")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    PokeAccess::Puzzles::Auto.forget
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  def place(id, x, y, list, sprite = "", name = nil)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    opts = { :id => id, :x => x, :y => y, :pages => [page], :active_page => page }
    opts[:name] = name if name
    ev = TestGameEvent.new(opts)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
