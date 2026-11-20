# Pokemon Uranium 1.4.1's puzzles after the story (games/uranium/puzzles): Urayne's laser gate and conveyor maze, the seal
# of Route 15's seafloor, the leaps of the Tsukinami Foundation, the Escher staircase, the dance floor, the cracked floors
# and the picross tiles the acolyte reveals; what each says with no help and what the assist adds.
class UraniumRepasoTest < PokeAccessTest
  test "the laser gate names its levers by colour and place, says its rule near them and gives the next pull" do
    lines = arrival(250) { $game_player.x = 14; $game_player.y = 25 }
    assert_includes lines, t(:ura_rp_laser_rule)
    green = place(83, 32, 30, "LeverR")
    red = place(28, 34, 30, "LeverR")
    blue = place(82, 33, 30, "LeverR")
    frame
    assert_equal t(:ura_rp_laser_green), PokeAccess::Puzzles.piece_name(green)
    $game_self_switches[[250, 82, "A"]] = true
    assert_equal t(:ura_rp_lever_down, :lever => t(:ura_rp_laser_blue)), PokeAccess::Puzzles.piece_name(blue)
    laser = PokeAccess::UrayneLaser
    assert_equal :ura_rp_laser_raise, laser.hint
    $game_self_switches[[250, 82, "A"]] = false
    assert_equal :ura_rp_laser_next_green, laser.hint
    $game_self_switches[[250, 83, "A"]] = true
    $game_variables[156] = 1
    assert_equal :ura_rp_laser_next_red, laser.hint
    $game_self_switches[[250, 28, "A"]] = true
    $game_variables[156] = 2
    assert_equal :ura_rp_laser_next_blue, laser.hint
    assert_equal t(:ura_rp_lever_down, :lever => t(:ura_rp_laser_red)), PokeAccess::Puzzles.piece_name(red)
    $game_variables[156] = 3
    assert_equal "", laser.hint
    refute_includes arrival(250) { $game_player.x = 14; $game_player.y = 25; $game_variables[156] = 3 }, t(:ura_rp_laser_rule)
    refute_includes arrival(250) { $game_player.x = 33; $game_player.y = 58 }, t(:ura_rp_laser_rule)
    refute_includes arrival(250) { $game_player.x = 67; $game_player.y = 23 }, t(:ura_rp_laser_rule)
    assert_includes frame { $game_player.x = 37; $game_player.y = 25 }, t(:ura_rp_laser_rule)
    refute_includes frame { $game_player.x = 36 }, t(:ura_rp_laser_rule)
  end

  test "the conveyor maze names its levers, keeps pulled ones out of the list and plans the switch levers" do
    refute_includes arrival(250) { $game_variables[156] = 3; $game_player.x = 33; $game_player.y = 58 }, t(:ura_rp_maze_rule)
    assert_includes frame { $game_player.y = 90 }, t(:ura_rp_maze_rule)
    refute_includes frame { $game_player.y = 91 }, t(:ura_rp_maze_rule)
    capacity = place(102, 21, 96, "Capacity Door Lever")
    switch = place(103, 85, 92, "EV103")
    [[98, 46, 83], [96, 97, 99], [33, 84, 114]].each { |id, x, y| place(id, x, y, "Capacity Door Lever") }
    frame
    assert_equal t(:ura_rp_capacity), PokeAccess::Puzzles.piece_name(capacity)
    assert_equal t(:ura_rp_switch), PokeAccess::Puzzles.piece_name(switch)
    assert(listed.any? { |r| r[0] == 21 && r[1] == 96 && r[2] == t(:ura_rp_capacity) })
    maze = PokeAccess::UrayneMaze
    assert_equal [:ura_rp_maze_next, { :x => 21, :y => 96 }], maze.hint
    [102, 98, 96].each { |id| $game_self_switches[[250, id, "A"]] = true }
    $game_variables[155] = 3
    frame
    refute(listed.any? { |r| r[0] == 21 && r[1] == 96 })
    assert_equal [:ura_rp_maze_switch_first, { :x => 85, :y => 92 }], maze.hint
    $game_self_switches[[250, 103, "A"]] = true
    assert_equal t(:ura_rp_switch_moved), PokeAccess::Puzzles.piece_name(switch)
    assert_equal [:ura_rp_maze_next, { :x => 84, :y => 114 }], maze.hint
    assert_includes info_key, "#{t(:ura_rp_maze_count)}: 3"
    $game_variables[155] = 8
    assert_equal "", maze.hint
  end

  test "the seal of Route 15 names the seal and the bubbles, says what the symbols take away and gives the sequence" do
    lines = arrival(220)
    assert_includes lines, t(:ura_rp_seal_rule)
    list = seal_page
    seal = place(10, 37, 11, "EV010", "", list)
    bubbles = place(1, 40, 16, "EV001", "PU-Bubbles")
    frame
    assert_equal t(:ura_rp_seal), PokeAccess::Puzzles.piece_name(seal)
    assert_equal t(:ura_rp_bubbles), PokeAccess::Puzzles.piece_name(bubbles)
    assert_equal [t(:ura_rp_bubbles_left_gone)], frame { $game_switches[146] = true }
    assert_equal [t(:ura_rp_bubbles_right_gone)], frame { $game_switches[147] = true }
    $game_switches[146] = false
    fire(bubbles)
    assert_equal t(:ura_rp_bubbles_back), PokeAccess::Puzzles.sent_back_line([40, 15, 220], [36, 12, 220])
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 10)
    answers = PokeAccess::Puzzles::Answers
    picks = lambda { [0, 2, 4, 6, 8, 17, 19, 21, 23, 32].map { |i| answers.right_option(int, list, i) } }
    assert_equal ["Earth Gem", "Storm Gust", "Storm Gust", "Earth Gem", "Tao Symbol", nil, nil, nil, nil, nil], picks.call
    $game_switches[146] = true
    $game_switches[147] = false
    assert_equal ["Clover", nil, nil, nil, nil, "Water Drop", "Earth Gem", "Water Drop", "Tao Symbol", nil], picks.call,
                 "the left current gone, the sequence of the right one"
    $game_switches[147] = true
    assert_equal [nil] * 10, picks.call, "both gone"
  end

  test "the koan of the Lost Seas gives, with the assist, the pick of each menu, and none where either is right" do
    on_map(259)
    list = koan_page
    place(1, 52, 16, "Trainer(4)", "HGSS_018", list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 1)
    menus = (0...list.length).select { |i| list[i].code == 102 }
    picked = menus.map { |i| PokeAccess::Puzzles::Answers.right_option(int, list, i) }
    assert_equal ["Leviathao", nil, "Leviathao", "Krakanao", "Leviathao", "Baitatao"], picked
  end

  test "the Foundation gives the next leap toward the south room, then the plates, Urayne and the last leap" do
    on_map(241)
    $game_switches[186] = true
    [[2, 7, 11], [27, 30, 19], [37, 26, 35], [44, 23, 9]].each { |id, x, y| place(id, x, y, "Quantum Leap") }
    foundation = PokeAccess::UraniumFoundation
    $game_player.x = 2
    $game_player.y = 7
    assert_equal [:ura_rp_leap_next, { :x => 7, :y => 11 }], foundation.hint
    $game_player.x = 35
    $game_player.y = 20
    assert_equal [:ura_rp_leap_next, { :x => 30, :y => 19 }], foundation.hint
    $game_player.x = 26
    $game_player.y = 41
    assert_equal :ura_rp_leap_plates, foundation.hint
    $game_variables[138] = 2
    assert_equal :ura_rp_leap_urayne, foundation.hint
    $game_variables[138] = 6
    assert_equal [:ura_rp_leap_next, { :x => 26, :y => 35 }], foundation.hint
    $game_player.x = 21
    $game_player.y = 9
    assert_equal :ura_rp_leap_flutes, foundation.hint
    $game_self_switches[[241, 16, "A"]] = true
    assert_equal "", foundation.hint
    $game_variables[138] = 0
  end

  test "the Escher staircase says its rule in its hall until climbed and, with the assist, how many climbs are left" do
    refute_includes arrival(216) { $game_player.x = 52; $game_player.y = 8 }, t(:ura_rp_escher_rule)
    assert_includes frame { $game_player.x = 28; $game_player.y = 55 }, t(:ura_rp_escher_rule)
    refute_includes frame { $game_player.y = 54 }, t(:ura_rp_escher_rule)
    assert_includes arrival(216) { $game_player.x = 28; $game_player.y = 56 }, t(:ura_rp_escher_rule)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[32] = 1
    assert_includes info_key, t(:ura_rp_escher_hint, :n => 2)
    refute_includes arrival(216) { $game_player.x = 28; $game_player.y = 56; $game_variables[32] = 3 }, t(:ura_rp_escher_rule)
    $game_variables[32] = 0
  end

  test "the dance floor names its pads by place and, with the assist, points at the next one" do
    on_map(224)
    pad = place(4, 62, 16, "Blue")
    frame
    assert_equal t(:ura_rp_pad_top_left), PokeAccess::Puzzles.piece_name(pad)
    PokeAccess::Config.puzzle_assist = true
    simon = Object.new
    simon.instance_variable_set(:@simonRunning, true)
    simon.instance_variable_set(:@simonAnswer, [1, 0])
    simon.instance_variable_set(:@simonPlayer, [])
    $Simon = simon
    assert(listed.any? { |r| r[0] == 62 && r[1] == 16 && r[2] == t(:ura_po_simon_next) })
    $Simon = nil
  end

  test "the cracked floors of the Shattered Caves say why the player fell, and the picross skips revealed tiles" do
    on_map(258)
    floor = place(35, 39, 39, "EV035", "", [TestCmd.new(201, [0, 258, 66, 64, 2, 0]), TestCmd.new(0, [])])
    frame
    assert_equal t(:ura_rp_cracked_floor), PokeAccess::Puzzles.piece_name(floor)
    fire(floor)
    assert_equal t(:ura_rp_cracked_fell), PokeAccess::Puzzles.sent_back_line([39, 38, 258], [66, 64, 258])
    on_map(257)
    $game_player.x = 65
    $game_player.y = 14
    tile = [TestCmd.new(117, [98]), TestCmd.new(0, [])]
    place(73, 68, 16, "Correct", "itemball", tile)
    place(100, 69, 16, "Correct", "", tile)
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[68, 16, t(:ura_pp_picross_cell)]], listed
  end

  test "the free camera names a cracked floor of the Shattered Caves while it shows" do
    on_map(258)
    floor = place(35, 39, 39, "EV035", "")
    floor.tile_id = 3334
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y).uniq }
    assert_equal [[t(:ura_rp_cracked_floor)], []], [lines[39, 39], lines[39, 40]]
    floor.tile_id = 0
    assert_equal [], lines[39, 39]
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def seal_page
    menu = "Press which symbol? \\ch[1,-1,Water Drop,Clover,Earth Gem,Storm Gust,Tao Symbol]"
    [TestCmd.new(101, [menu], 0), TestCmd.new(111, [1, 1, 0, 2, 0], 0),
     TestCmd.new(101, [menu], 1), TestCmd.new(111, [1, 1, 0, 3, 0], 1),
     TestCmd.new(101, [menu], 2), TestCmd.new(111, [1, 1, 0, 3, 0], 2),
     TestCmd.new(101, [menu], 3), TestCmd.new(111, [1, 1, 0, 2, 0], 3),
     TestCmd.new(101, [menu], 4), TestCmd.new(111, [1, 1, 0, 4, 0], 4),
     TestCmd.new(121, [146, 146, 0], 5),
     TestCmd.new(412, [], 4), TestCmd.new(412, [], 3), TestCmd.new(412, [], 2), TestCmd.new(412, [], 1),
     TestCmd.new(411, [], 0), TestCmd.new(111, [1, 1, 0, 1, 0], 1),
     TestCmd.new(101, [menu], 2), TestCmd.new(111, [1, 1, 0, 0, 0], 2),
     TestCmd.new(101, [menu], 3), TestCmd.new(111, [1, 1, 0, 2, 0], 3),
     TestCmd.new(101, [menu], 4), TestCmd.new(111, [1, 1, 0, 0, 0], 4),
     TestCmd.new(101, [menu], 5), TestCmd.new(111, [1, 1, 0, 4, 0], 5),
     TestCmd.new(121, [147, 147, 0], 6),
     TestCmd.new(412, [], 5), TestCmd.new(412, [], 4), TestCmd.new(412, [], 3), TestCmd.new(412, [], 2),
     TestCmd.new(412, [], 1), TestCmd.new(412, [], 0),
     TestCmd.new(101, [menu], 0), TestCmd.new(0, [], 0)]
  end

  # The koan's page as the game words it (map 259, event 1): chained Show Choices, a wrong pick jumping to fail, a pointless
  # one back to the middle menu, and the way through to victory, which sets self switch B.
  def koan_page
    l = [TestCmd.new(101, ["Who would he bring to the far shore?"], 0)]
    jump = lambda { |label, at| l.push(TestCmd.new(119, [label], at)) }
    choices(l, 0, ["Baitatao", "Leviathao", "Krakanao", "Give up"]) do |i, at|
      next jump.call(i == 3 ? "gave up" : "fail", at) unless i == 1
      l.push(TestCmd.new(118, ["mid riddle safe harbor"], at))
      choices(l, at, ["Baitatao", "Krakanao", "Give Up"]) do |j, at2|
        next jump.call("gave up", at2) if j == 2
        first, other = j == 0 ? %w[Baitatao Krakanao] : %w[Krakanao Baitatao]
        choices(l, at2, [first, "Leviathao", "Empty Handed", "Give Up"]) do |k, at3|
          jump.call("mid riddle safe harbor", at3) if k == 0
          jump.call("fail", at3) if k == 2
          next unless k == 1
          choices(l, at3, ["Empty Handed", other, "Give Up"]) { |m, at4| jump.call(["fail", "victory", "gave up"][m], at4) }
        end
      end
    end
    l.push(TestCmd.new(118, ["victory"], 0), TestCmd.new(101, ["You show great wisdom. Well done!"], 0),
           TestCmd.new(123, ["B", 0], 0), TestCmd.new(115, [], 0), TestCmd.new(118, ["fail"], 0),
           TestCmd.new(101, ["And that's how the Shattered Sea came to be shattered."], 0), TestCmd.new(118, ["gave up"], 0),
           TestCmd.new(101, ["You'll need more wisdom."], 0), TestCmd.new(0, [], 0))
  end

  # A Show Choices at indent into l, each option's branch filled by the block (its place, the branch's indent).
  def choices(l, indent, options)
    l.push(TestCmd.new(102, [options, options.length], indent))
    options.each_with_index do |o, i|
      l.push(TestCmd.new(402, [i, o], indent))
      yield(i, indent + 1)
      l.push(TestCmd.new(0, [], indent + 1))
    end
    l.push(TestCmd.new(404, [], indent))
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
    [146, 147, 186].each { |id| $game_switches[id] = false }
    [32, 138, 155, 156].each { |id| $game_variables[id] = 0 }
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

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
