# Opalo's story puzzles on the shipped profile: the gyms of earth, water, ghosts, Charjabug and ice, the Voodoo Hall, the night
# in Maple's mansion and the Ancient Workshop, each as it is heard without the puzzle assist and with it.
class OpaloPuzzlesTest < PokeAccessTest
  Route = Struct.new(:list)
  Move = Struct.new(:code, :parameters)

  test "the earth gym counts its levers, tells the order with the assist and says why a Mudsdale sent the player back" do
    on_map(38)
    assert_equal [t(:op_g2_rule)], @arrival
    assert_equal [t(:puzzle_progress, :label => t(:op_g2_levers), :n => 1, :of => 5)], tick { $game_switches[169] = true }
    assert_equal PokeAccess.sentences([t(:puzzle_progress, :label => t(:op_g2_levers), :n => 1, :of => 5), t(:op_g2_rule)]), info_key
    refute_includes info_key, t(:op_g2_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g2_hint)
    mudsdale = place(6, 3, 37, [TestCmd.new(0, [])], "750")
    fire(mudsdale)
    assert_equal t(:op_g2_mudsdale_back), PokeAccess::Puzzles.sent_back_line([3, 37, 38], [9, 40, 38])
    assert_nil PokeAccess::Puzzles.sent_back_line([3, 37, 38], [23, 31, 38])
  end

  test "the earth gym names its rocks and its patrolling Mudsdale" do
    on_map(38)
    rock = place(10, 20, 31, [TestCmd.new(0, [])], "", 1570)
    mudsdale = place(7, 5, 30, [TestCmd.new(0, [])], "750")
    assert_equal t(:op_g2_rocks), PokeAccess::Puzzles.piece_name(rock)
    assert_equal t(:op_g2_mudsdale), PokeAccess::Puzzles.piece_name(mudsdale)
  end

  test "the water gym names each jellyfish and says where it carries the player by the way they face" do
    on_map(54)
    assert_equal [t(:op_g4_rule)], @arrival
    jelly = place(1, 18, 41, [TestCmd.new(0, [])], "jelliGim", 0, 1)
    other = place(3, 37, 23, [TestCmd.new(0, [])], "jelliGim", 0, 1)
    assert_equal t(:op_jelly), PokeAccess::Puzzles.piece_name(jelly)
    $game_player.direction = 6
    assert_equal [t(:op_jelly_ride_said, :to => PokeAccess::Puzzles.offset_phrase(11, 0))], tick { fire(jelly) }
    $game_player.direction = 4
    assert_equal [t(:op_jelly_ride_said, :to => PokeAccess::Puzzles.offset_phrase(-11, 0))], tick { fire(jelly) }
    $game_player.direction = 8
    assert_equal [t(:op_jelly_ride_said, :to => PokeAccess::Puzzles.offset_phrase(1, -14))], tick { fire(other) }
    $game_player.direction = 2
    assert_equal [t(:op_jelly)], tick { fire(other) }, "a way of facing that does nothing"
  end

  test "the water gym counts its four plates and names its gates" do
    on_map(54)
    assert_equal [t(:puzzle_progress, :label => t(:op_g4_plates), :n => 1, :of => 4)], tick { $game_switches[202] = true }
    assert_equal [t(:puzzle_progress, :label => t(:op_g4_plates), :n => 2, :of => 4)], tick { $game_switches[179] = true }
    gate = place(12, 37, 38, [TestCmd.new(0, [])], "", 1724)
    assert_equal t(:op_g4_gates), PokeAccess::Puzzles.piece_name(gate)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g4_hint)
  end

  test "the ghost gym counts its levers and names its cracks" do
    on_map(110)
    crack = place(40, 71, 31, [TestCmd.new(0, [])], "grietas")
    assert_equal t(:op_g5_cracks), PokeAccess::Puzzles.piece_name(crack)
    assert_equal [t(:puzzle_progress, :label => t(:op_g5_levers), :n => 1, :of => 3)], tick { $game_switches[218] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g5_hint)
  end

  test "the Charjabug gym names the odd ones and counts those caught, never past four, and gives the values with the assist" do
    on_map(121)
    assert_equal [t(:op_g6_rule)], @arrival
    odd = place(15, 47, 44, [TestCmd.new(0, [])], "char2")
    assert_equal t(:op_g6_special), PokeAccess::Puzzles.piece_name(odd)
    assert_equal [t(:puzzle_progress, :label => t(:op_g6_caught), :n => 1, :of => 4)], tick { $game_switches[285] = true }
    tick { [282, 283].each { |s| $game_switches[s] = true } }
    assert_equal [t(:puzzle_progress, :label => t(:op_g6_caught), :n => 4, :of => 4)], tick { $game_switches[284] = true }
    refute_includes info_key, t(:op_g6_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g6_hint)
  end

  test "the ice gym counts the snowball's pushes and, with the assist, says the next one" do
    on_map(67)
    place(1, 39, 63, [TestCmd.new(0, [])], "", 3955)
    PokeAccess::Config.puzzle_assist = true
    pushes = [[:dir_up, 15], [:dir_left, 7], [:dir_down, 3], [:dir_left, 9], [:dir_down, 6], [:dir_right, 3]]
    pushes.each_with_index do |(dir, n), step|
      $game_variables[119] = step
      assert_includes info_key, t(:op_g8_next, :dir => t(dir), :n => n), "push #{step + 1}"
    end
    $game_variables[119] = 6
    assert_includes info_key, t(:op_g8_done)
    $game_variables[119] = 2
    tick
    assert_includes tick { $game_variables[119] = 3 }, t(:puzzle_progress, :label => t(:op_g8_push), :n => 3, :of => 6)
  end

  test "the ice gym rule is told once, for a room that reloads with each try" do
    on_map(67)
    assert_includes @arrival, t(:op_g8_rule)
    PokeAccess::World::Mechanics.forget
    refute_includes tick, t(:op_g8_rule)
  end

  test "the ice gym tiles send back a repeated one and say when all are stepped" do
    on_map(67)
    first = place(3, 4, 43, [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])], "", 0, 1)
    place(4, 3, 43, [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])], "", 0, 1)
    fire(first)
    assert_equal t(:op_g8_repeat), PokeAccess::Puzzles.sent_back_line([4, 43, 67], [5, 50, 67])
    assert_includes tick { $game_variables[120] = 27 }, t(:op_g8_tiles_solved)
  end

  test "the Voodoo Hall tells with the assist alone which dolls are safe and which attack" do
    on_map(284)
    safe = place(12, 76, 12, [TestCmd.new(0, [])], "282")
    bites = place(13, 69, 12, [TestCmd.new(0, [])], "359")
    assert_equal [nil, nil], [safe, bites].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:op_g10_doll_safe), t(:op_g10_doll_bites)], [safe, bites].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    on_map(285)
    alakazam = place(16, 3, 22, [TestCmd.new(0, [])], "065")
    banette = place(18, 3, 25, [TestCmd.new(0, [])], "354")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:op_g10_doll_safe), t(:op_g10_doll_bites)], [alakazam, banette].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    on_map(287)
    duraludon = place(17, 47, 12, [TestCmd.new(0, [])], "879")
    dusclops = place(18, 30, 35, [TestCmd.new(0, [])], "356")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:op_g10_doll_safe), t(:op_g10_doll_bites)], [duraludon, dusclops].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
  end

  test "the Voodoo Hall numbers the altar slots and, with the assist alone, follows the dolls to them in order" do
    on_map(284)
    [30, 31, 33, 34].each_with_index { |x, i| place(16 + i, x, 19, [TestCmd.new(101, ["..."])]) }
    slots = (16..19).map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
    assert_equal((1..4).map { |n| t(:op_g10_slot, :n => n) }, slots)
    gardevoir = place(20, 36, 20, [TestCmd.new(0, [])], "282")
    place(23, 35, 23, [TestCmd.new(0, [])], "395")
    $game_switches[525] = true
    $game_switches[527] = true
    World.next_frame
    assert_nil PokeAccess::Puzzles.info_line, "the doll that goes next is not told without the assist"
    assert_equal [], tick { gardevoir.x = 30; gardevoir.y = 19 }, "nor is the one that goes after it"
    assert_nil PokeAccess::Puzzles.info_line
    gardevoir.x = 36
    gardevoir.y = 20
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_g10_gardevoir)
    assert_includes info_key, t(:op_g10_hint_1)
    gardevoir.x = 30
    gardevoir.y = 19
    World.next_frame
    assert_includes info_key, t(:op_g10_empoleon)
    assert_includes info_key, t(:op_g10_hint_2)
    $game_switches[525] = false
    $game_switches[527] = false
    World.next_frame
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Maple's mansion says the guard left only in sight of his post, and with the assist which door is free" do
    on_map(293)
    $game_player.x = 40
    $game_player.y = 5
    tick
    $game_switches[545] = true
    assert_equal [], tick, "the noise is told by the game itself"
    assert_equal t(:op_maple_night), PokeAccess::Puzzles.info_line
    assert_empty PokeAccess::Puzzles.category_targets
    $game_player.x = 12
    $game_player.y = 24
    assert_equal [t(:op_maple_guard_gone)], tick
    assert_equal t(:op_maple_guard_gone), PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [12, 19, t(:op_maple_door)]
    assert_includes PokeAccess::Puzzles.info_line, t(:op_maple_hint)
    $game_switches[546] = true
    assert_equal [], tick, "nothing about the guard once the night is over"
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the workshop counts its energy nodes on the info key and lists those left" do
    on_map(152)
    [1, 6, 7].each_with_index { |id, i| place(id, 10 + 4 * i, 5, [TestCmd.new(101, ["!"])], "palancaTaller") }
    assert_equal [t(:op_wk_node)] * 3, listed.map { |row| row[2] }
    assert_equal [], tick { $game_variables[188] = 1 }, "the lever's own message says it"
    assert_equal t(:puzzle_progress, :label => t(:op_wk_nodes), :n => 1, :of => 3), info_key
    $game_variables[188] = 3
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the workshop tells once that the floor changed when the power is back, and with the assist where the nodes are" do
    on_map(358)
    assert_equal [], @arrival, "the power is still off"
    $game_switches[642] = true
    PokeAccess::World::Mechanics.forget
    assert_equal [t(:op_wk_floor)], tick
    PokeAccess::World::Mechanics.forget
    assert_equal [], tick, "not on every arrival"
    $game_switches[642] = false
    $game_variables[179] = 11
    PokeAccess::World::Mechanics.forget
    assert_nil PokeAccess::Puzzles.info_line, "the way to the nodes is not told without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:op_wk_nodes_title)}. #{t(:op_wk_door_hint)}", PokeAccess::Puzzles.info_line
    $game_switches[642] = true
    assert_equal t(:op_wk_floor), PokeAccess::Puzzles.info_line
  end

  test "the workshop maze names its tiles and, with the assist alone, says where each takes the player and what the lever does" do
    on_map(357)
    platform = place(12, 16, 44, [TestCmd.new(201, [0, 357, 5, 29, 2, 0]), TestCmd.new(0, [])])
    pusher = place(25, 22, 48, [TestCmd.new(209, [-1, Route.new([Move.new(44, []), Move.new(2, []), Move.new(2, []), Move.new(2, [])])]),
                                TestCmd.new(0, [])])
    lever = place(60, 37, 5, [TestCmd.new(121, [639, 639, 0]), TestCmd.new(0, [])], "palancaTaller")
    assert_equal [t(:op_wk_platform), t(:op_wk_pusher)], [platform, pusher].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    assert_equal [], tick { $game_switches[639] = true }, "the tile that changed is far from the lever"
    assert_equal [], tick { fire(lever) }
    refute_includes info_key.to_s, t(:op_wk_maze_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:op_wk_platform_to, :to => PokeAccess::Puzzles.offset_phrase(-11, -15)),
                  t(:op_wk_pusher_to, :to => PokeAccess::Puzzles.offset_phrase(-3, 0))],
                 [platform, pusher].map { |ev| PokeAccess::Puzzles.piece_name(ev) }
    assert_equal [t(:op_wk_lever_said)], tick { fire(lever) }
    assert_includes info_key, t(:op_wk_maze_hint)
  end

  test "the workshop messages room lists its terminals, says which are read and counts them" do
    on_map(359)
    [17, 18, 20, 22].each_with_index { |id, i| place(id, 10 + 5 * i, 15, [TestCmd.new(101, ["..."])]) }
    assert_equal [t(:op_wk_terminal)] * 4, listed.map { |row| row[2] }
    $game_self_switches[[359, 18, "A"]] = true
    assert_equal t(:op_wk_terminal_read), PokeAccess::Puzzles.piece_name($game_map.events[18])
    assert_equal [t(:puzzle_progress, :label => t(:op_wk_messages), :n => 1, :of => 4)], tick { $game_variables[180] = 1 }
  end

  test "the gyms say their rule on arriving and answer the info key until their leader's medal is won, then neither" do
    { 38 => [130, :op_g2_rule], 54 => [167, :op_g4_rule], 121 => [255, :op_g6_rule], 36 => [312, :op_traps_hint] }.each do |map, (medal, rule)|
      on_map(map)
      assert_equal [t(rule)], @arrival, "map #{map} before"
      refute_nil PokeAccess::Puzzles.info_line, "map #{map} before"
      on_map(map) { $game_switches[medal] = true }
      assert_empty @arrival, "map #{map} after"
      assert_nil PokeAccess::Puzzles.info_line, "map #{map} after"
    end
  end

  test "the ice gym's ball says no rule on arriving and nothing on the info key once the leader's medal is won" do
    on_map(67)
    assert_includes @arrival, t(:op_g8_rule)
    assert_includes info_key, t(:op_g8_ball_title)
    on_map(67) { $game_switches[382] = true }
    assert_empty @arrival
    refute_includes info_key.to_s, t(:op_g8_ball_title)
  end

  test "the messages room says its rule on arriving until the four terminals are read, then neither it nor the count" do
    on_map(359)
    assert_equal [t(:op_wk_messages_rule)], @arrival
    on_map(359) { $game_variables[180] = 3 }
    assert_equal [t(:op_wk_messages_rule)], @arrival
    refute_nil PokeAccess::Puzzles.info_line
    on_map(359) { $game_variables[180] = 4 }
    assert_empty @arrival
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the office gym names its coffee machine and, with the assist alone, says which coffee the boss wants while it offers them" do
    with_texts("op_g1_coffee" => "coffee %{item}") do
      with_item_names(77 => "Beta Brew") do
        on_map(39)
        machine = place(2, 16, 17, [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
        assert_equal [[16, 17, t(:op_g1_machine)]], listed
        $game_variables[147] = 1
        assert_equal [], tick { fire(machine) }
        PokeAccess::Config.puzzle_assist = true
        assert_equal [t(:op_g1_coffee, :item => "Beta Brew")], tick { fire(machine) }
        $game_variables[147] = 0
        assert_equal [], tick { fire(machine) }, "without the coin the machine offers nothing"
        $game_variables[147] = 1
        $game_switches[95] = true
        assert_equal [], tick { fire(machine) }, "the boss is served"
      end
    end
  ensure
    $game_variables[147] = 0
    $game_switches[95] = false
  end

  test "the boarded-up farm doors of Route 19 are named as such until the plank breaks them" do
    { 251 => [37, 559, 22, 28], 252 => [16, 560, 70, 19] }.each do |map, (id, switch, x, y)|
      on_map(map)
      place(id, x, y, [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
      assert_equal [[x, y, t(:op_boarded_door)]], listed, "map #{map}"
      $game_switches[switch] = true
      assert_equal [[x, y, t(:op_farm_door)]], listed, "map #{map} once broken"
      $game_switches[switch] = false
    end
  end

  test "the berry riddle of Galerna City says its right option with the assist alone, in the game's words" do
    on_map(108)
    options = ["Berry A", "Berry B", "Berry C"]
    sets_a = TestCmd.new(123, ["A", 0], 1)
    list = [TestCmd.new(102, [options, 1], 0)]
    options.each_with_index do |option, i|
      list.push(TestCmd.new(402, [i, option], 0))
      list.push(sets_a) if i == 1
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0), TestCmd.new(0, [], 0))
    place(13, 25, 27, [TestCmd.new(0, [])])
    asker = Object.new
    asker.instance_variable_set(:@event_id, 13)
    assert_equal [], tick { PokeAccess::Puzzles::Answers.say(asker, 0) }
    PokeAccess::Config.puzzle_assist = true
    asker.instance_variable_set(:@list, list)
    asker.instance_variable_set(:@index, 0)
    assert_equal [t(:puzzle_answer, :a => "Berry B")], tick { PokeAccess::Puzzles::Answers.say(asker, 0) }
  end

  test "the boulders that fill a hole are the control of that hole, for the assisted routes, each named, and say nothing of their own" do
    { 166 => [361, 7, 6], 206 => [415, 1, 2] }.each do |map, (filled, boulder, hole)|
      on_map(map)
      assert_empty @arrival, "map #{map}"
      push = TestPage.new(:trigger => 0, :sprite => "rocafuerza", :list => [TestCmd.new(121, [filled, filled, 0], 1), TestCmd.new(0, [])])
      gone = TestPage.new(:trigger => 0, :sprite => "", :condition => { :switch1_valid => true, :switch1_id => filled })
      $game_map.events[boulder] = TestGameEvent.new(:id => boulder, :x => 25, :y => 16, :pages => [push, gone], :active_page => push)
      open = TestPage.new(:trigger => 0, :sprite => "rocagujero", :through => true, :condition => { :switch1_valid => true, :switch1_id => filled })
      closed = TestPage.new(:trigger => 0, :sprite => "agujero")
      $game_map.events[hole] = TestGameEvent.new(:id => hole, :x => 23, :y => 16, :pages => [closed, open], :active_page => closed)
      World.next_frame
      PokeAccess::World::Mechanics.forget
      inst = PokeAccess::World::Mechanics.instances[0]
      assert_equal [boulder], inst.controls.keys, "map #{map}"
      assert_equal t(:op_hole_rock), PokeAccess::Puzzles.piece_name($game_map.events[boulder]), "map #{map}"
      assert_equal t(:op_hole), PokeAccess::Puzzles.piece_name($game_map.events[hole]), "map #{map}"
      assert_nil PokeAccess::Puzzles.info_line, "map #{map}"
      $game_switches[filled] = false
    end
  end

  test "the ice gym's tiles end with the medal, though the game takes their count back to 0 on coming back" do
    on_map(67) do
      $game_switches[382] = true
      $game_variables[120] = 0
    end
    place(3, 5, 50, [TestCmd.new(0, [])])
    assert_empty @arrival
    assert_nil PokeAccess::Puzzles.info_line
    assert_empty tick { $game_player.x = 5; $game_player.y = 50 }
  end

  private

  # The texts of the keys that take values, as the test knows them: the lines of the language files may be older or newer.
  def with_texts(templates)
    [PokeAccess::I18n::REFERENCE, PokeAccess::I18n.lang].uniq.each do |code|
      table = PokeAccess::I18n.table(code)
      templates.each { |key, text| table[key] = text }
    end
    yield
  end

  # Runs the block with the game's item table standing in: the office coffee is item 77 and names maps ids to words.
  def with_item_names(names)
    was = Object.const_defined?(:PBItems) ? Object.send(:remove_const, :PBItems) : nil
    Object.const_set(:PBItems, Module.new do
      const_set(:SAWSBUCKS, 77)
      define_singleton_method(:getName) { |id| names[id] }
    end)
    yield
  ensure
    Object.send(:remove_const, :PBItems) if Object.const_defined?(:PBItems)
    Object.const_set(:PBItems, was) if was
  end

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # Declares the shipped puzzles as the harness loads the profile and puts the player on map with every flag of the
  # puzzles at rest; what is said on arriving is kept in @arrival.
  def on_map(map)
    Harness.load_puzzles("opalo")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    [130, 167, 169, 170, 171, 172, 173, 179, 180, 201, 202, 216, 217, 218, 255, 282, 283, 284, 285, 312, 354, 382, 525, 526, 527,
     528, 529, 545, 546, 639, 642].each { |s| $game_switches[s] = false }
    [83, 119, 120, 179, 180, 188].each { |v| $game_variables[v] = 0 }
    $game_self_switches = {}
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Puzzles::Auto.forget
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  # An event at (x, y) whose live page runs list, drawn with sprite or tile, placed on the map; trigger 1 is a touch.
  def place(id, x, y, list, sprite = "", tile = 0, trigger = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page, :tile_id => tile)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # What the puzzles say on the next map frame, after the block.
  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
