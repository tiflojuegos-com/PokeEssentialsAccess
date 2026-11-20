# Solar Light's puzzles on the shipped profile: the stones and jumps of Highpoint, the two floors of Goldune, the lifts of
# Subhail, the cracks of the Icecaps, the temples, Sario's gate, the dancer, Lake Bliss's statue, the end of Victory Isle,
# and the currents, jump spots and ski lifts the routes follow. What a sighted player sees goes without the assist; the answers, with it.
class SolarlightPuzzlesTest < PokeAccessTest
  SWITCHES = [7, 8, 10, 258, 259, 260, 261, 262, 274, 275, 536, 561, 562, 563, 564, 568, 569, 570, 683, 761, 796, 797, 798,
              799]

  test "Highpoint lists each lever and jump by its stone and says a stone as its lever moves it" do
    on_map(134)
    place(6, 14, 19, "Switch1", "BWSwitches")
    place(8, 22, 24, "Jump1")
    assert_equal [t(:solar_highpoint_jump, :n => 1), t(:solar_highpoint_lever, :n => 1)].sort, listed
    tick
    $game_switches[258] = true
    assert_equal [["#{t(:solar_highpoint_stone, :n => 1)}: #{t(:solar_highpoint_up)}", false]], tick
    $game_switches[258] = false
    assert_equal [["#{t(:solar_highpoint_stone, :n => 1)}: #{t(:solar_highpoint_down)}", false]], tick
  end

  test "Highpoint gives the next lever with the assist alone, Amber once all stones are up, and goes quiet with the badge" do
    on_map(134)
    refute_includes info_key.to_s, t(:solar_highpoint_next, :n => 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_highpoint_next, :n => 1)
    [258, 259, 260].each { |s| $game_switches[s] = true }
    assert_includes info_key, t(:solar_highpoint_next, :n => 4)
    [261, 262, 274, 275].each { |s| $game_switches[s] = true }
    assert_includes info_key, t(:solar_highpoint_amber)
    $game_switches[8] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Goldune names the quicksand and door 2 above, says the entrance boulder falling and the door opening" do
    on_map(85)
    place(9, 25, 41, "Quicksand left")
    place(27, 41, 17, "Door Goldune Gym 2", "DoorGolduneGym")
    names = listed
    assert_includes names, t(:solar_goldune_quicksand)
    assert_includes names, t(:solar_goldune_door, :n => 2)
    assert_includes names, t(:solar_goldune_plate)
    tick
    $game_switches[561] = true
    assert_equal [["#{t(:solar_goldune_entry_rock)}: #{t(:solar_goldune_fell)}", false]], tick
    $game_switches[569] = true
    assert_equal [["#{t(:solar_goldune_door, :n => 2)}: #{t(:solar_goldune_open)}", false]], tick
  end

  test "Goldune gives each step with the assist alone: the entrance boulder, door 1 below, the last boulder spelt out" do
    on_map(85)
    refute_includes info_key.to_s, t(:solar_goldune_h_entry)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_goldune_h_entry)
    $game_switches[561] = true
    assert_includes info_key, t(:solar_goldune_h_door1_above)
    on_map(86)
    PokeAccess::Config.puzzle_assist = true
    $game_switches[561] = true
    assert_includes info_key, t(:solar_goldune_h_door1)
    on_map(85)
    PokeAccess::Config.puzzle_assist = true
    [561, 568, 569, 564, 563].each { |s| $game_switches[s] = true }
    assert_includes info_key, t(:solar_goldune_h_three_last)
  end

  test "Goldune counts the boulders on the lower plates up to 3, opens door 3 and goes quiet with the badge" do
    on_map(86)
    [561, 568, 569, 562, 563, 564].each { |s| $game_switches[s] = true }
    tick
    $game_variables[154] = 2
    assert_equal [[t(:puzzle_progress, :label => t(:solar_goldune_on_plates), :n => 2, :of => 3), false]], tick
    $game_variables[154] = 3
    $game_switches[570] = true
    assert_includes tick.map { |l, _q| l }, "#{t(:solar_goldune_door, :n => 3)}: #{t(:solar_goldune_open)}"
    $game_variables[154] = 4
    assert_equal [], tick, "the third rock's watcher counts it again the frame after the door opens"
    assert_includes info_key, t(:puzzle_progress, :label => t(:solar_goldune_on_plates), :n => 3, :of => 3)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_goldune_h_dustin)
    $game_switches[7] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Goldune guides the first rock not yet counted to the first free plate below, whichever plates the others took" do
    was = $game_self_switches
    $game_self_switches = {}
    on_map(86)
    PokeAccess::Config.puzzle_assist = true
    [561, 568, 569, 562, 563, 564].each { |s| $game_switches[s] = true }
    rocks = { 20 => [13, 22], 12 => [11, 22], 8 => [12, 23] }
    rocks.each { |id, (x, y)| place(id, x, y, "Boulder", "Object boulder") }
    assert_equal [20, [14, 26, 14, 26]], guided
    move(20, 11, 33)
    $game_self_switches[[86, 24, "A"]] = true
    assert_equal [12, [14, 26, 14, 26]], guided
    move(12, 14, 26)
    $game_self_switches[[86, 21, "A"]] = true
    assert_equal [8, [5, 30, 5, 30]], guided
    move(20, 10, 31)
    assert_equal [8, [11, 33, 11, 33]], guided, "a counted rock moved off frees its plate and is not asked again"
    $game_switches[570] = true
    assert_nil guided
  ensure
    $game_self_switches = was
  end

  test "Subhail names its ski lifts and gives the slopes' hint with the assist alone" do
    on_map(260)
    place(13, 32, 43, "Skilift1", "skilift")
    assert_includes listed, t(:solar_subhail_lift)
    refute_includes info_key.to_s, t(:solar_subhail_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_subhail_hint)
    $game_switches[10] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the Icecaps list each crack as a jump, and the rescue ends the puzzle" do
    on_map(226)
    place(1, 18, 31, "Jump3")
    assert_equal [t(:solar_icecaps_crack)], listed
    $game_switches[536] = true
    refute PokeAccess::Puzzles.active?
  end

  test "a temple names its pillar and tells the type it needs with the assist alone" do
    on_map(100)
    place(2, 9, 35, "Earth Stone")
    assert_equal [t(:solar_temple_pillar)], listed
    refute_includes info_key.to_s, t(:solar_temple_hint_ground)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:solar_temple_hint_ground)
    $game_switches[761] = true
    refute PokeAccess::Puzzles.active?
  end

  test "Sario names each pillar by its stone, counts the stones and tells the hole's rule with the assist once it opens" do
    on_map(222)
    place(31, 14, 17, "Earth Stone")
    assert_equal [t(:solar_sario_pillar, :stone => t(:solar_sario_earth))], listed
    tick
    $game_variables[188] = 1
    assert_equal [[t(:puzzle_progress, :label => t(:solar_sario_stones), :n => 1, :of => 5), false]], tick
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key.to_s, t(:solar_sario_hint)
    $game_switches[796] = true
    assert_includes info_key, t(:solar_sario_hint)
  end

  test "Sario's pillar says its stone in the language chosen after the profile loaded" do
    on_map(222)
    place(31, 14, 17, "Earth Stone")
    i18n = PokeAccess::I18n
    was = i18n.method(:t)
    lang = PokeAccess::Config.language
    i18n.define_singleton_method(:t) do |key, *rest|
      next "earth-#{i18n.lang}" if key == :solar_sario_earth
      key == :solar_sario_pillar ? "pillar, #{rest[0][:stone]}" : was.call(key, *rest)
    end
    { :en => "pillar, earth-en", :pl => "pillar, earth-pl" }.each do |code, name|
      PokeAccess::Config.language = code
      assert_equal [name], listed, code.to_s
    end
  ensure
    i18n.define_singleton_method(:t, was) if was
    PokeAccess::Config.language = lang
  end

  test "the dancer says she waits for four directions, and which with the assist" do
    Harness.load_puzzles("solarlight")
    PokeAccess::Config.puzzle_assist = false
    reach = PokeAccess::World::Mechanics.instance_variable_get(:@defs)[55].map { |d| d[1] }.find { |s| s[:reaches] }
    label = reach[:reaches][0][:label]
    assert_equal 0, reach[:reaches][0][:text]
    assert_equal :solar_dancer_wait, label.call(nil)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :solar_dancer_answer, label.call(nil)
  end

  test "Lake Bliss names the statue and gives the party order with the assist once Parafox has come" do
    was = $game_self_switches
    $game_self_switches = {}
    on_map(177)
    place(21, 22, 21, "Parafox event")
    assert_equal [t(:solar_bliss_statue)], listed
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key.to_s, t(:solar_bliss_hint)
    $game_self_switches[[177, 21, "A"]] = true
    assert_includes info_key, t(:solar_bliss_hint)
    $game_self_switches[[177, 21, "B"]] = true
    refute PokeAccess::Puzzles.active?
  ensure
    $game_self_switches = was
  end

  test "a current carries an arriving step on to the first tile that is none, stops where the way is shut, and is named" do
    with_rules do
      $game_map.load_grid(["#######", "#.....#", "#######"])
      [[2, 1], [3, 1]].each { |x, y| $game_map.set_terrain(x, y, 20) }
      PokeAccess::World.reset!
      assert_equal [4, 1], PokeAccess::Routes::Moves.arrive(2, 1, 6)
      assert_equal [1, 1], PokeAccess::Routes::Moves.arrive(1, 1, 4), "off the currents"
      assert_equal [t(:solar_current, :dir => t(:dir_right))], PokeAccess::Camera.tile_lines(2, 1)
      assert_equal [], PokeAccess::Camera.tile_lines(1, 1)
      [[4, 1], [5, 1]].each { |x, y| $game_map.set_terrain(x, y, 20) }
      PokeAccess::World.reset!
      assert_equal [5, 1], PokeAccess::Routes::Moves.arrive(2, 1, 6)
    end
  end

  test "a jump spot hops the player over it only while its switch is on, and only on the maps that have them" do
    with_rules do
      $game_map.load_grid(["#####", "#...#", "#.#.#", "#...#", "#####"])
      $game_map.map_id = 134
      jump = TestCmd.new(209, [-1, route(TestMoveCmd.new(14, [0, -2]))], 1)
      spot(8, "Jump1", 2, 2, [TestCmd.new(111, [0, 258, 0]), jump, TestCmd.new(412, [])])
      assert PokeAccess::SolarJumps.at?(2, 2)
      assert_nil PokeAccess::SolarJumps.step(2, 3, [0, -1, 8], 0)
      $game_switches[258] = true
      PokeAccess::World.reset!
      s = PokeAccess::SolarJumps.step(2, 3, [0, -1, 8], 0)
      assert_equal [2, 1, :act, 8], [s.x, s.y, s.gate[:kind], s.gate[:face]]
      jump_step = PokeAccess::Routes::Moves.instance_variable_get(:@assist_sources).last
      assert PokeAccess::Routes::Moves.owns?(jump_step.owner, 2, 2)
      $game_map.map_id = 85
      refute PokeAccess::Routes::Moves.owns?(jump_step.owner, 2, 2)
    end
  end

  test "a crack hops down facing down and up otherwise, by the branch on the player's facing and its else" do
    with_rules do
      $game_map.load_grid(["#####", "#...#", "#.#.#", "#...#", "#####"])
      $game_map.map_id = 226
      down = TestCmd.new(209, [-1, route(TestMoveCmd.new(14, [0, 2]))], 1)
      up = TestCmd.new(209, [-1, route(TestMoveCmd.new(14, [0, -2]))], 1)
      spot(1, "Jump3", 2, 2, [TestCmd.new(111, [6, -1, 2]), down, TestCmd.new(411, []), up, TestCmd.new(412, [])])
      s = PokeAccess::SolarJumps.step(2, 1, [0, 1, 2], 0)
      assert_equal [2, 3], [s.x, s.y]
      s = PokeAccess::SolarJumps.step(2, 3, [0, -1, 8], 0)
      assert_equal [2, 1], [s.x, s.y]
    end
  end

  test "a ski lift rides the player up with Through on, faced from below alone" do
    with_rules do
      $game_map.load_grid(["#####", "#...#", "#...#", "#####", "#...#", "#...#", "#####"])
      $game_map.map_id = 260
      ride = [TestCmd.new(209, [-1, route(TestMoveCmd.new(37), TestMoveCmd.new(14, [0, -1]))], 1),
              TestCmd.new(209, [-1, route(TestMoveCmd.new(37), TestMoveCmd.new(4), TestMoveCmd.new(4), TestMoveCmd.new(4))], 1),
              TestCmd.new(209, [-1, route(TestMoveCmd.new(38), TestMoveCmd.new(14, [0, 1]))], 1)]
      spot(13, "Skilift1", 2, 4, [TestCmd.new(111, [6, -1, 8])] + ride + [TestCmd.new(412, [])], "skilift")
      s = PokeAccess::SolarJumps.step(2, 5, [0, -1, 8], 0)
      assert_equal [2, 2], [s.x, s.y]
      assert_nil PokeAccess::SolarJumps.step(3, 4, [-1, 0, 4], 0)
    end
  end

  test "Goldune lists each row of quicksand once" do
    on_map(85)
    [[9, 25, 41], [10, 25, 42], [15, 25, 40]].each { |id, x, y| place(id, x, y, "Quicksand left") }
    assert_equal 1, listed.select { |n| n == t(:solar_goldune_quicksand) }.length
  end

  test "Victory Isle's hints end once the League Village's scene has run" do
    on_map(227)
    PokeAccess::Config.puzzle_assist = true
    $game_player.x = 62
    $game_player.y = 47
    assert_includes info_key, t(:solar_isle_h_west)
    $game_switches[683] = true
    refute PokeAccess::Puzzles.active?
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def on_map(map)
    Harness.load_puzzles("solarlight")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    SWITCHES.each { |s| $game_switches[s] = false }
    [153, 154, 188].each { |v| $game_variables[v] = 0 }
    $game_player.x = 1
    $game_player.y = 1
    World.next_frame
  end

  def place(id, x, y, name, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :name => name, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def route(*cmds)
    TestMoveRoute.new(cmds + [TestMoveCmd.new(0)])
  end

  def spot(id, name, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list + [TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :name => name, :x => x, :y => y, :pages => [page], :active_page => page)
    PokeAccess::World.reset!
  end

  def move(id, x, y)
    $game_map.events[id].x = x
    $game_map.events[id].y = y
    World.next_frame
  end

  # The rock the current phase of map 86 guides and its goal, or nil when it guides none.
  def guided
    ph = PokeAccess::World::Mechanics::State.current_phase(Harness.declared(86))
    tr = ph && ph[:track]
    tr ? [tr[:event], tr[:goal]] : nil
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }.sort
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  def info_key
    PokeAccess::Info.map_text
  end

  # Runs the block with the profile's current and jump rules registered, the core's rule lists and the camera's tile
  # readers put back after.
  def with_rules
    moves = PokeAccess::Routes::Moves
    arrivals = moves.instance_variable_get(:@arrival_rules)
    assists = moves.instance_variable_get(:@assist_sources)
    readers = PokeAccess::Camera.instance_variable_get(:@readers)
    saved = [arrivals.dup, assists.dup, readers.dup]
    verbose = $VERBOSE
    $VERBOSE = nil
    %w[currents jumps].each do |f|
      path = File.join(Harness::ROOT, "games", "solarlight", "#{f}.rb")
      eval(File.read(path), TOPLEVEL_BINDING, path)
    end
    $VERBOSE = verbose
    yield
  ensure
    $VERBOSE = verbose
    arrivals.replace(saved[0])
    assists.replace(saved[1])
    readers.replace(saved[2])
    moves.forget_map rescue nil
    $game_map.clear_grid rescue nil
    PokeAccess::World.reset!
  end
end
