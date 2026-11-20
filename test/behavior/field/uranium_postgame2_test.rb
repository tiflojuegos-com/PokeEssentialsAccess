# Pokemon Uranium 1.4.1's postgame puzzles of the third pass (games/uranium/puzzles): the plan for Route 18's Lotad,
# step by step by where the Lotad stand, and what each of the other places says with no help and what the assist adds.
class UraniumPostgame2Test < PokeAccessTest
  def lotad; PokeAccess::UraniumLotad; end

  test "the Lotad plan starts with a rousing and then gives the first push" do
    pond
    assert_equal [:ura_r3_lotad_rouse_at, { :mx => 12, :my => 43, :x => 13, :y => 43 }], lotad.hint
    assert_equal [13, 43], lotad.stand
    rouse_at(13, 43)
    assert_equal [:ura_r2_push_left, { :x => 24, :y => 43 }], lotad.hint
    assert_equal [25, 43], lotad.stand
  end

  test "roused where the push cannot be reached, the plan asks to settle and rouse again" do
    pond
    rouse_at(16, 38)
    assert_equal [:ura_r3_lotad_reroute, { :mx => 12, :my => 43, :x => 13, :y => 43, :cx => 15, :cy => 38, :sx => 16, :sy => 38 }],
                 lotad.hint
    assert_equal [13, 43], lotad.stand
  end

  test "the plan follows a Lotad halfway and takes the first groups in any order" do
    pond(65 => [23, 42])
    rouse_at(23, 44)
    assert_equal [:ura_r2_push_up, { :x => 23, :y => 42 }], lotad.hint
    pond(70 => [25, 39])
    assert_equal [:ura_r3_lotad_rouse_at, { :mx => 12, :my => 43, :x => 13, :y => 43 }], lotad.hint
    pond(65 => [23, 40], 70 => [25, 39])
    assert_equal [:ura_r3_lotad_rouse_at, { :mx => 26, :my => 33, :x => 26, :y => 34 }], lotad.hint
  end

  test "the last Lotad climbs from the pad on the obstacle and a stray one asks for the reset" do
    pond(65 => [23, 40], 70 => [25, 39], 71 => [24, 34], 69 => [15, 39], 74 => [23, 37])
    rouse_at(23, 40)
    assert_equal [:ura_r2_push_up, { :x => 23, :y => 37 }], lotad.hint
    rouse_at(20, 34)
    assert_equal [:ura_r3_lotad_reroute, { :mx => 24, :my => 40, :x => 23, :y => 40, :cx => 24, :cy => 33, :sx => 23, :sy => 33 }],
                 lotad.hint
    pond(68 => [15, 44])
    assert_equal [:ura_r3_lotad_reset, { :x => 23, :y => 46 }], lotad.hint
    pond(74 => [17, 39])
    assert_equal [:ura_r3_lotad_reset, { :x => 23, :y => 46 }], lotad.hint
  end

  test "the Ludicolo proposed is the nearest by the walk, through the land around as through the water" do
    pond(65 => [23, 40], 70 => [25, 39], 71 => [24, 34], 69 => [15, 39], 74 => [15, 32])
    rouse_at(23, 47)
    assert_equal [[24, 40], [24, 41]], lotad.nearest_master, "from the south shore, not 12,43 by the first open tile"
    assert_equal [:ura_r3_lotad_settle_at, { :x => 15, :y => 32, :mx => 24, :my => 40, :sx => 24, :sy => 41 }], lotad.hint
    rouse_at(25, 45)
    assert_equal [[24, 40], [24, 41]], lotad.nearest_master, "from the water beside an open tile"
    rouse_at(12, 46)
    assert_equal [[12, 43], [12, 44]], lotad.nearest_master
  end

  test "with a Lotad on the channel the plan gives way to settling and crossing" do
    pond(65 => [23, 40], 70 => [25, 39], 71 => [24, 34], 69 => [15, 39], 74 => [15, 32])
    rouse_at(15, 33)
    assert_equal [:ura_r3_lotad_settle_at, { :x => 15, :y => 32, :mx => 24, :my => 33, :sx => 23, :sy => 33 }], lotad.hint
    $game_switches[228] = true
    assert_equal [:ura_r2_lotad_cross, { :x => 15, :y => 32 }], lotad.hint
    $game_player.x = 15
    $game_player.y = 31
    assert_equal "", lotad.hint
    assert_nil lotad.stand
  end

  test "the pond stands solved while the player is north of the channel, and its obstacles are named" do
    refute_includes arrival(227) { $game_player.x = 14; $game_player.y = 30 }, t(:ura_r2_lotad_rule)
    assert_includes arrival(227), t(:ura_r2_lotad_rule)
    pond
    frame
    assert_equal t(:ura_r3_lotad_obstacle), PokeAccess::Puzzles.piece_name($game_map.events[59])
  end

  test "Urayne's laser rule opens once a visit, not on each return to its rooms" do
    on_map(250)
    $game_variables[156] = 0
    $game_player.x = 20
    $game_player.y = 20
    assert_includes frame.join(" "), t(:ura_rp_laser_rule)
    $game_player.y = 40
    frame
    $game_player.y = 20
    refute_includes frame.join(" "), t(:ura_rp_laser_rule)
    PokeAccess::World::Mechanics.forget
    $game_player.y = 40
    frame
    $game_player.y = 20
    assert_includes frame.join(" "), t(:ura_rp_laser_rule)
  end

  test "a tide is named by the way it runs, and with the Tidal Bell its turn is said" do
    on_map(229)
    tide = place_pages(40, 28, 34, "Tide", [{}, { :self_switch_valid => true, :self_switch_ch => "A" }])
    frame
    assert_equal t(:ura_r3_tide_left), PokeAccess::Puzzles.piece_name(tide)
    lines = frame do
      $game_self_switches[[229, 40, "A"]] = true
      tide.instance_variable_set(:@active, tide.instance_variable_get(:@event).pages[1])
    end
    assert(lines.join(" ").include?(t(:ura_r3_right)))
    assert_equal t(:ura_r3_tide_right), PokeAccess::Puzzles.piece_name(tide)
    on_map(255)
    under = place_pages(46, 74, 62, "Tide", [{}, { :self_switch_valid => true, :self_switch_ch => "A" }])
    frame
    assert_equal t(:ura_r3_tide_right), PokeAccess::Puzzles.piece_name(under)
    on_map(221)
    story = place_pages(65, 67, 64, "Tide", [{}, { :switch1_valid => true, :switch1_id => 326 }])
    frame
    assert_equal t(:ura_r3_tide_left), PokeAccess::Puzzles.piece_name(story)
  end

  test "the Sponaree on watch say how they see while the berry mission lasts" do
    lines = arrival(233) { $game_variables[133] = 1 }
    assert_includes lines, t(:ura_r3_sponaree_rule)
    walker = place(17, 31, 29, "Trainer(5)", "PU-Sponaree")
    counter = place(18, 34, 26, "Counter(5)", "PU-Sponaree")
    frame
    assert_equal t(:ura_r3_sponaree), PokeAccess::Puzzles.piece_name(walker)
    assert_equal t(:ura_r3_sponaree_over), PokeAccess::Puzzles.piece_name(counter)
    refute_includes arrival(233) { $game_variables[133] = 2 }, t(:ura_r3_sponaree_rule)
  end

  test "the bridge trap is named once it has given way, or with the assist" do
    on_map(221)
    plank = place(59, 19, 73, "Bridge trap", "", [TestCmd.new(201, [0, 222, 20, 73, 0, 0])])
    frame
    refute_equal t(:ura_r3_bridge_trap), PokeAccess::Puzzles.piece_name(plank)
    $game_self_switches[[221, 59, "A"]] = true
    frame
    assert_equal t(:ura_r3_bridge_trap), PokeAccess::Puzzles.piece_name(plank)
  end

  test "with the assist, a walk keeps off the trap plank while another way exists, and crosses it when none does" do
    on_map(221)
    trap_corridor(["#########", "#@......#", "#.#####.#", "#.......#", "#########"])
    assert_equal [6, 6, 6, 6, 6, 6], walk(7, 1)
    PokeAccess::Config.puzzle_assist = true
    settle
    assert_equal [2, 2, 6, 6, 6, 6, 6, 6, 8, 8], walk(7, 1)
    trap_corridor(["#########", "#@......#", "#########"])
    assert_equal [6, 6, 6, 6, 6, 6], walk(7, 1)
  ensure
    PokeAccess::Config.puzzle_assist = false
    $game_map.clear_grid
  end

  test "once variable 117 reaches 7 the plank is a plain plank and the assisted walk takes it" do
    on_map(221)
    trap_corridor(["#########", "#@......#", "#.#####.#", "#.......#", "#########"])
    plank = $game_map.events[59]
    plank.instance_variable_set(:@active, plank.instance_variable_get(:@event).pages[1])
    plank.instance_variable_set(:@list, [])
    plank.instance_variable_set(:@trigger, 0)
    $game_variables[117] = 7
    PokeAccess::Config.puzzle_assist = true
    settle
    assert_equal [6, 6, 6, 6, 6, 6], walk(7, 1)
  ensure
    PokeAccess::Config.puzzle_assist = false
    $game_map.clear_grid
  end

  test "the lighthouse's tiles behind each arrival say they lead back to the first room" do
    on_map(238)
    back = place(13, 30, 30, "EV013", "", [TestCmd.new(201, [0, 238, 30, 8, 0, 0])])
    frame
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(back, :@list), back.id)
    assert_equal t(:ura_r3_lighthouse_back), PokeAccess::Puzzles.sent_back_line([30, 30, 238], [30, 8])
  end

  test "the silverback's menu gives the option that asks it for help" do
    on_map(256)
    choices = ["Ask", "Ignore"]
    list = [TestCmd.new(102, [choices, 1], 0), TestCmd.new(402, [0, "Ask"], 0), TestCmd.new(123, ["A", 0], 1),
            TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Ignore"], 0), TestCmd.new(0, [], 1), TestCmd.new(404, [], 0),
            TestCmd.new(0, [], 0)]
    place(28, 15, 40, "Silverback", "Silverback", list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 28)
    assert_equal "Ask", PokeAccess::Puzzles::Answers.right_option(int, list, 0)
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # Lays the rows out with the trap plank at (3,1): its page runs until variable 117 reaches 7, the second does nothing.
  def trap_corridor(rows)
    $game_map.load_grid(rows)
    World.clear_events
    $game_player.x = 1
    $game_player.y = 1
    live = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [3300, 3300, 0])])
    plain = TestPage.new(:trigger => 0, :sprite => "", :list => [],
                         :condition => { :variable_valid => true, :variable_id => 117, :variable_value => 7 })
    $game_map.events[59] = TestGameEvent.new(:id => 59, :x => 3, :y => 1, :name => "Bridge trap", :pages => [live, plain])
    settle
  end

  def settle
    PokeAccess::World::Mechanics.forget
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  def walk(x, y)
    r = PokeAccess::Routes::Planner.walk(x, y, true)
    r.status == :found ? r.route.to_a : r.status
  end

  def place_pages(id, x, y, name, conditions)
    pages = conditions.map { |c| TestPage.new(:trigger => 1, :sprite => "tides", :condition => c, :list => [TestCmd.new(0, [])]) }
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => pages, :active_page => pages[0])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def pond(moved = {})
    on_map(227)
    $game_map.width = 50
    $game_map.height = 90
    $game_switches[228] = true
    homes = { 65 => [24, 43], 68 => [15, 43], 69 => [16, 39], 70 => [18, 39], 71 => [25, 34], 74 => [16, 41], 77 => [28, 45] }
    homes.dup.merge!(moved).each { |id, xy| place(id, xy[0], xy[1], "lotadwalker", "lotad") }
    { 58 => [15, 32], 59 => [14, 32], 60 => [13, 32], 61 => [24, 34], 62 => [25, 39], 63 => [23, 40], 66 => [17, 41],
      67 => [15, 39] }.each { |id, xy| obstacle(id, xy[0], xy[1]) }
    { 19 => [12, 43], 28 => [15, 38], 30 => [24, 40], 32 => [26, 33], 33 => [24, 33], 76 => [28, 44] }.each do |id, xy|
      place(id, xy[0], xy[1], "Ludicolo puzzlemaster", "Ludicolo")
    end
    place(1, 23, 46, "Ludicolo resetter", "Ludicolo")
  end

  def obstacle(id, x, y)
    page = TestPage.new(:trigger => 4, :sprite => "", :list => [TestCmd.new(209, [0, nil])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "lotadblock", :tile_id => 1534,
                                              :pages => [page], :active_page => page)
    World.next_frame
  end

  def rouse_at(x, y)
    $game_switches[228] = false
    $game_player.x = x
    $game_player.y = y
  end

  def on_map(map)
    Harness.load_puzzles("uranium")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_switches[228] = false
    [117, 133, 134].each { |id| $game_variables[id] = 0 }
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
end
