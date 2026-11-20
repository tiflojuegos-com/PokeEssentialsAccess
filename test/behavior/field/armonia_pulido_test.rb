# Pokemon Armonia's optional and late puzzles on the shipped profile: the museum's hidden lever, the old man's pots, Racine's
# trampoline and bug Pokemon, the statues of Pirámides Origen, the arrow floor of Sede Nytia, the termites and the Hippopotas,
# each as it is heard without the puzzle assist and with it.
class ArmoniaPulidoTest < PokeAccessTest
  SWITCHES = [91, 94, 96]

  test "the museum's pot is listed with the assist alone, the hole by what it leads to, and with the assist where it opened" do
    on_map(81)
    place(66, 57, 10, [text])
    hole = place(71, 74, 44, [TestCmd.new(201, [0, 89, 8, 35, 0, 0])], "BUJERO")
    assert_equal t(:arm_wiel_hole), PokeAccess::Puzzles.piece_name(hole)
    assert_equal [[74, 44, t(:arm_wiel_hole)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[57, 10, t(:arm_wiel_pot)], [74, 44, t(:arm_wiel_hole)]], listed
    $game_player.x = 57
    $game_player.y = 11
    assert_equal [t(:arm_wiel_hole_at, :dist => "17 #{t(:dir_right)}, 33 #{t(:dir_down)}")], pull(66, 0)
    assert_empty pull(66, 1), "not on saying no"
    PokeAccess::Config.puzzle_assist = false
    assert_empty pull(66, 0)
  end

  test "the old man's shuffle is said as it starts, and with the assist the pot that wins" do
    on_map(24)
    place(1, 34, 31, [text])
    int = interpreter(1, (0..11).map { |n| TestCmd.new(101, ["Line #{n}"]) }, 9)
    PokeAccess::Puzzles::Reach.before_text(int)
    assert_nil PokeAccess.take_tail
    int.instance_variable_set(:@index, 10)
    PokeAccess::Puzzles::Reach.before_text(int)
    assert_equal t(:arm_oasis_shuffle), PokeAccess.take_tail
    win = [TestCmd.new(123, ["C", 0], 1)]
    away = [TestCmd.new(123, ["A", 1], 1), TestCmd.new(201, [0, 215, 20, 21, 0, 0], 1)]
    assert_equal "Izquierda", option(1, %w[Izquierda Central Derecha], [win, away, away])
    assert_nil option(1, %w[Si No], [win + away, [text]]), "the invitation holds the whole game"
  end

  test "the trampoline is followed as it moves, with the assist how far its place is, and the jump is named once it is there" do
    on_map(167)
    trampoline = place(1, 30, 29, [text], "trampolin")
    place(4, 14, 9, [text])
    $game_player.x = 31
    $game_player.y = 29
    assert_equal t(:arm_racine_trampoline), PokeAccess::Puzzles.piece_name(trampoline)
    tick
    assert_equal [t(:puzzle_track_rel, :label => t(:arm_racine_trampoline), :dist => "2 #{t(:dir_left)}")], tick { trampoline.x = 29 }
    refute_includes listed.map { |r| r[2] }, t(:arm_racine_jump)
    PokeAccess::Config.puzzle_assist = true
    goal = t(:puzzle_track_goal, :label => t(:arm_racine_trampoline), :dist => "10 #{t(:dir_left)}, 12 #{t(:dir_up)}",
                                 :goal => t(:arm_racine_trampoline_goal))
    assert_equal [goal], tick { trampoline.x = 28 }
    assert_includes info_key, t(:arm_racine_trampoline_hint)
    assert_includes listed, [18, 17, t(:arm_racine_trampoline_goal)]
    $game_switches[96] = true
    assert_includes listed, [14, 9, t(:arm_racine_jump)]
    refute_includes info_key.to_s, t(:arm_racine_trampoline_hint)
  end

  test "a bug Pokemon of the gym above says it threw the player back down" do
    on_map(168)
    guard = place(56, 29, 54, [text], "742")
    place(3, 18, 75, [text], "742")
    fire(guard)
    assert_equal t(:arm_racine_knocked), PokeAccess::Puzzles.sent_back_line([29, 59, 168], [29, 61, 168])
    fire($game_map.events[3])
    assert_nil PokeAccess::Puzzles.sent_back_line([29, 59, 168], [29, 61, 168])
  end

  test "each statue of the hidden rooms goes by its Pokemon until the room's sarcophagus opens" do
    { 144 => [12, 8, 8, 6], 145 => [1, 10, 11, 9] }.each do |map, (sarcophagus, volcarona, haxorus, lucario)|
      on_map(map)
      names = listed.map { |r| r[2] }
      [[:VOLCARONA, volcarona], [:HAXORUS, haxorus], [:LUCARIO, lucario]].each do |sym, n|
        label = PokeAccess::Puzzles.label_of([:arm_origen_relief, { :name => PokeAccess::Data.species_name(sym).to_s }])
        assert_equal n, names.count(label), "map #{map} #{sym}"
      end
      $game_self_switches[[map, sarcophagus, "A"]] = true
      assert_empty listed, "map #{map}"
    end
  end

  test "the arrows go by their way, the floor's rule is said on arriving and with the assist the way to the keypad" do
    on_map(200)
    assert_equal [t(:arm_nytia_arrows_rule)], @arrival
    arrows = { 1 => [9, 28], 3 => [11, 38], 5 => [12, 41], 20 => [19, 25], 35 => [8, 29] }
    arrows.each { |id, (x, y)| place(id, x, y, [text]) }
    assert_equal [[8, 29, t(:arm_nytia_arrow_up)], [9, 28, t(:arm_nytia_arrow_down)], [11, 38, t(:arm_nytia_arrow_down)],
                  [12, 41, t(:arm_nytia_arrow_right)], [19, 25, t(:arm_nytia_arrow_left)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:arm_nytia_arrows_hint)
    way = listed.select { |r| r[2] == t(:puzzle_right_way) }.map { |r| [r[0], r[1]] }
    assert_equal [[11, 38], [12, 41], [19, 25]], way, "the arrows of the way that stand here"
    $game_self_switches[[200, 26, "A"]] = true
    refute_includes info_key.to_s, t(:arm_nytia_arrows_hint)
    on_map(200) { $game_self_switches[[200, 26, "A"]] = true }
    assert_empty @arrival
  end

  test "the routes land where the arrows leave the player, chains taken, and nowhere else" do
    on_map(200)
    { 1 => [9, 28], 5 => [12, 41], 20 => [19, 25] }.each { |id, (x, y)| place(id, x, y, [text]) }
    with_arrow_floor do
      moves = PokeAccess::Routes::Moves
      assert_equal [9, 34], moves.arrive(9, 28, 2)
      assert_equal [20, 35], moves.arrive(12, 41, 6)
      assert_equal [14, 19], moves.arrive(19, 25, 4)
      assert_equal [10, 28], moves.arrive(10, 28, 2), "an arrow with no event standing there"
      $game_map.map_id = 199
      assert_equal [9, 28], moves.arrive(9, 28, 2), "another map"
    end
  end

  test "the termites sound as they move, their room's rule and the move back are said, and the hint with the assist" do
    on_map(149)
    assert_equal [t(:arm_termite_rule)], @arrival
    termite = place(1, 42, 27, [text], "011")
    place(4, 27, 23, [text], "011")
    refute_includes listed.map { |r| [r[0], r[1]] }, [42, 27], "a moving obstacle stays out of the list"
    piece = PokeAccess::World::Mechanics.piece_of(termite)
    assert piece && piece.moving, "a moving obstacle"
    fire(termite)
    assert_equal t(:arm_termite_caught), PokeAccess::Puzzles.sent_back_line([41, 27, 149], [44, 27, 149])
    on_map(149) { PokeAccess::Config.puzzle_assist = true }
    assert_equal [t(:arm_termite_rule), t(:arm_termite_hint)].sort, @arrival.sort
    on_map(149) { $game_switches[94] = true }
    assert_empty @arrival
  end

  test "the Hippopotas send back through the city, which is said as theirs, and the rule once until the scene at the end" do
    on_map(69)
    assert_equal [t(:arm_laken_rule)], @arrival
    hippo = place(1, 14, 13, [text], "449")
    assert PokeAccess::World::Mechanics.piece_of(hippo).moving
    assert_nil PokeAccess::World::Mechanics.piece_of(place(4, 27, 15, [text], "449"))
    assert_equal t(:arm_laken_caught), PokeAccess::Puzzles.sent_back_line([11, 26, 111], [19, 17, 69], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([1, 11, 73], [19, 17, 69], :map), "walking in from the west"
    assert_empty arrive(69), "said once a session"
    on_map(69) { $game_switches[91] = true }
    assert_empty @arrival
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def text; TestCmd.new(101, ["text"]); end

  # An interpreter stand-in on an event's page, at a command.
  def interpreter(id, list, index, branch = nil)
    int = Object.new
    { :@list => list, :@index => index, :@event_id => id, :@branch => branch || {} }.each { |k, v| int.instance_variable_set(k, v) }
    int
  end

  # What is said as the branch of a Yes/No menu on an event starts.
  def pull(id, choice)
    menu = [TestCmd.new(102, [%w[Si No], 2]), TestCmd.new(402, [0, "Si"]), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "No"]),
            TestCmd.new(404, [])]
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(interpreter(id, menu, choice == 0 ? 1 : 3, { 0 => choice }))
    SpeakCapture.log.map { |line| line[0] }
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

  # Runs the block with the arrow floor's route rule registered, the core's rule list put back after.
  def with_arrow_floor
    moves = PokeAccess::Routes::Moves
    arrivals = moves.instance_variable_get(:@arrival_rules)
    saved = arrivals.dup
    verbose = $VERBOSE
    $VERBOSE = nil
    path = File.join(Harness::ROOT, "games", "armonia", "arrow_floor.rb")
    eval(File.read(path), TOPLEVEL_BINDING, path)
    $VERBOSE = verbose
    yield
  ensure
    $VERBOSE = verbose
    arrivals.replace(saved)
    moves.forget_map rescue nil
  end

  # Comes onto a map within the same session: what is said there.
  def arrive(map)
    World.clear_events
    $game_map.map_id = map
    World.next_frame
    tick
  end

  def on_map(map)
    Harness.load_puzzles("armonia")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_map.map_id = map
    SWITCHES.each { |s| $game_switches[s] = false }
    $game_self_switches = {}
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    PokeAccess::Puzzles::Auto.forget
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
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
