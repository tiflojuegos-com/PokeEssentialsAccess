# Pokemon Reborn's puzzles of part A (games/reborn/puzzles/): Mosswater's keypads, Peridot's Voltorb, Obsidia Slums'
# jump tiles, the two cut mazes, Beryl's tubes, Lapis' computers, the Grand Stairway, Blacksteam's cell, Pyrous'
# lava, Azurine's Foongus, Chrysolia's forest, Tanzan's base, Route 1's bulls, Vanhanen's chess and the Ruby Tower.
# Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesATest < PokeAccessTest
  include TileWorldHelpers

  SWITCHES = [98, 99, 101, 102, 103, 104, 105, 106, 140, 141, 142, 143, 144, 145, 146, 150, 164, 165, 167, 168, 174,
              175, 176, 177, 267, 268, 269, 272, 394, 2242]
  VARS = [54, 107, 108, 109, 110, 111, 112, 113, 114, 115, 145, 149, 150, 154, 319, 320, 634, 642, 654]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
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
    PokeAccess::RebornJumpTiles.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Mosswater's keypads are named, and the clue monitors and the codes come with the assist alone" do
    on_map(71, 60, 31)
    assert_equal "{rba_mw_lift_keypad}", PokeAccess::Puzzles.piece_name(place(183, 60, 30, "EV183"))
    monitor = place(186, 50, 7, "P1L", 0, "mosswaterkeyboard")
    refute_equal "{rba_mw_clue_monitor}", PokeAccess::Puzzles.piece_name(monitor)
    refute_includes info_key, "rba_mw_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rba_mw_clue_monitor}", PokeAccess::Puzzles.piece_name(monitor)
    assert_includes info_key, "{rba_mw_hint_lift}"
    $game_variables[634] = 22
    assert_includes info_key, "{rba_mw_hint_security}"
    $game_variables[634] = 27
    refute_includes info_key, "rba_mw_"
  end

  test "Peridot's gates are listed while closed, a following Voltorb is said, and the next step comes with the assist" do
    gym = PokeAccess::RebornPeridotGym
    on_map(78, 10, 22)
    gate = place(7, 10, 20, "EV007", 0, "")
    assert gym.closed?(gate)
    frame
    lines = frame { $game_variables[54] = 1 }
    assert_includes lines, "{rba_pg_following}"
    assert_equal [], frame { $game_variables[54] = 2 }.select { |l| l.include?("rba_pg_following") }
    refute gym.closed?(gate), "the first gate opens at 2"
    assert gym.closed?(place(17, 10, 15, "EV017", 0, ""))
    assert_equal :rba_pg_hint_voltorb, gym.hint
    $game_variables[54] = 3
    assert_equal :rba_pg_hint_gate, gym.hint
    $game_switches[2242] = true
    assert_nil gym.hint
    refute gym.closed?(place(25, 9, 7, "EV025", 0, ""))
  end

  test "Peridot's secret switch takes the Yes that turns switch 2242 on" do
    on_map(37, 64, 25)
    yes = [TestCmd.new(121, [2242, 2242, 0], 1)]
    assert_equal "Yes", option(154, ["Yes", "No"], [yes, []])
  end

  test "Obsidia Slums' jump tiles hop two tiles the way their page says, onto open ground alone" do
    rows = ["#######", "#.....#", "#.....#", "#.....#", "#..@..#", "#.....#", "#######"]
    with_tile_world(rows) do |world|
      world.map_id = 90
      world.events[5] = jump_tile(5, 3, 3, 8 => [0, -2], 2 => [0, 2])
      jumps = PokeAccess::RebornJumpTiles
      jumps.forget
      assert_equal({ 8 => [0, -2], 2 => [0, 2] }, jumps.table[[3, 3]])
      assert jumps.from?(3, 4)
      refute jumps.from?(2, 3), "no facing of the tile throws from its west"
      assert_equal [3, 2], jumps.hop(3, 4, 8)
      assert_nil jumps.hop(3, 4, 4)
      up = PokeAccess::Routes::DIRS.find { |v| v[2] == 8 }
      s = PokeAccess::Pathfinder.searching { PokeAccess::Routes::Moves.step(3, 4, 0, up, PokeAccess::Pathfinder.replay_mode) }
      assert_equal [3, 2], [s.x, s.y]
      blocker = TestGameEvent.new(:id => 6, :x => 3, :y => 2)
      blocker.blocking = true
      world.events[6] = blocker
      assert_equal false, jumps.hop(3, 4, 8), "a jump onto a blocked tile stays in place"
    end
  end

  test "the cut mazes list their next tree with the assist alone, in the order the cuts leave the vines" do
    on_map(269, 35, 39)
    park = PokeAccess::RebornObsidiaPark
    trees = [12, 11, 10, 7, 8, 17, 4].map { |id| [id, place(id, 30 + id, 30, "Tree", 0, "cuttree wiggle")] }
    [[4, 12], [8, 11], [12, 10], [17, 7], [20, 8], [24, 17], [29, 4]].each do |v, id|
      $game_variables[642] = v
      assert_equal id, park.next_tree, "V642 = #{v}"
    end
    $game_variables[642] = 34
    assert_nil park.next_tree
    $game_variables[642] = 8
    refute(listed_names.include?("{rba_cm_next_tree}"))
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rba_cm_next_tree}", PokeAccess::Puzzles.piece_name(trees[1][1])
    on_map(132, 98, 41)
    $game_variables[654] = 5
    assert_equal 72, PokeAccess::RebornMalchous.next_tree
  end

  test "Beryl's panels are numbered, the tubes said by colour, and the assist names the fewest panels to press" do
    beryl = PokeAccess::RebornBerylGym
    on_map(162, 9, 17)
    panels = { 7 => [6, 12], 8 => [9, 12], 12 => [12, 12], 13 => [8, 15], 14 => [11, 15], 15 => [14, 15] }
    panels.each { |id, (x, y)| place(id, x, y, "EV#{id}", 0, "") }
    assert_equal "{rba_bg_panel n=4}", PokeAccess::Puzzles.piece_name($game_map.events[13])
    $game_switches[102] = true
    $game_switches[105] = true
    frame
    assert_equal [1, 3], beryl.presses
    assert_equal [:rba_bg_hint_red, { :list => "1, 3" }], beryl.hint
    lines = frame { $game_switches[101] = true }
    assert_includes lines.join(" "), "{rba_bg_tube n=1}: {rba_bg_red}"
    [101, 102, 103, 104, 105, 106].each { |s| $game_switches[s] = false }
    [98, 101, 102, 106].each { |s| $game_switches[s] = true }
    assert_equal [4, 5], beryl.presses
    flips = [4, 5].map { |n| beryl::PANELS[n - 1][1] }.flatten
    assert_equal [101, 102, 106], flips.select { |s| flips.count(s) % 2 == 1 }.uniq.sort
    refute_includes info_key, "rba_bg_hint"
  end

  test "Lapis' computers say their state and the game's own mark, and the assist follows the mark or the reset" do
    gym = PokeAccess::RebornLapisGym
    on_map(182, 16, 25)
    $game_variables[319] = 7
    assert_equal "{rba_lg_computer_marked state={rba_lg_off}}", PokeAccess::Puzzles.piece_name(place(18, 16, 23, "EV018"))
    assert_equal "{rba_lg_computer state={rba_lg_off}}", PokeAccess::Puzzles.piece_name(place(17, 2, 23, "EV017"))
    assert_equal :rba_lg_hint_marked, gym.hint
    $game_variables[319] = 5
    assert_equal :rba_lg_hint_ledge, gym.hint
    $game_variables[319] = -1
    $game_variables[320] = -1
    assert_equal :rba_lg_hint_reset, gym.hint
    gym::COMPUTERS.values.each { |s| $game_switches[s] = true }
    assert_equal :rba_lg_hint_walk, gym.hint
    $game_switches[150] = true
    assert_nil gym.hint
  end

  test "Blacksteam's cages say what they hold, and the assist walks the heat, cold and break in order" do
    cells = PokeAccess::RebornBlacksteam
    on_map(11, 7, 5)
    { 108 => 1, 109 => 2, 111 => 5, 112 => 4, 113 => 3, 114 => 7, 115 => 6 }.each { |v, c| $game_variables[v] = c }
    assert_equal "{rba_bf_cage name={rba_bf_loudred}}", PokeAccess::Puzzles.piece_name(place(12, 12, 8, "EV012"))
    assert_equal "{rba_bf_cage_empty}", PokeAccess::Puzzles.piece_name(place(15, 9, 8, "EV015"))
    assert_equal [:rba_bf_hint_go, { :name => "{rba_bf_loudred}" }], cells.hint
    $game_switches[164] = true
    assert_equal :rba_bf_hint_abra, cells.hint
    $game_switches[165] = true
    assert_equal [:rba_bf_hint_go, { :name => "{rba_bf_cyndaquil}" }], cells.hint
    $game_variables[110] = 7
    $game_variables[114] = 0
    assert_equal :rba_bf_hint_release, cells.hint
    $game_switches[165] = false
    $game_switches[168] = true
    assert_equal [:rba_bf_hint_go, { :name => "{rba_bf_jigglypuff}" }], cells.hint
    $game_switches[167] = true
    assert_equal :rba_bf_hint_attack, cells.hint
    $game_variables[107] = 11
    $game_switches[165] = true
    assert_equal :rba_bf_hint_take_out, cells.hint, "Cyndaquil has to leave the middle cage for Vanillite"
    assert_equal "{rba_bf_bars_hot}", PokeAccess::Puzzles.piece_name(place(2, 9, 10, "Cell1"))
    $game_variables[107] = 13
    assert_nil cells.hint
  end

  test "Pyrous' glowing rock is named while it drains, and the assist goes B1F, 2F, 1F, B1F, then up" do
    pyrous = PokeAccess::RebornPyrous
    on_map(35, 37, 28)
    [174, 175, 177].each { |s| $game_switches[s] = true }
    rock = place(4, 37, 27, "Rock", 0, "rocksmash3b")
    assert_equal "{rba_pm_glowing_rock}", PokeAccess::Puzzles.piece_name(rock)
    steps = []
    4.times do
      steps.push(pyrous.hint)
      case steps.last
      when :rba_pm_hint_b1 then $game_switches[175] = false; $game_switches[174] = true
      when :rba_pm_hint_2f then $game_switches[177] = false; $game_switches[176] = true
      when :rba_pm_hint_1f then $game_switches[176] = false; $game_switches[175] = true
      end
    end
    assert_equal [:rba_pm_hint_b1, :rba_pm_hint_2f, :rba_pm_hint_1f, :rba_pm_hint_b1], steps
    assert_nil pyrous.hint
    assert pyrous.drained?
    rock.character_name = "rocksmash3"
    refute_equal "{rba_pm_glowing_rock}", PokeAccess::Puzzles.piece_name(rock)
  end

  test "Azurine's Foongus are named for what they are with the assist alone" do
    on_map(206, 25, 9)
    foongus = place(38, 27, 22, "Item", 0, "pkmn_foongus")
    refute_equal "{rba_az_foongus}", PokeAccess::Puzzles.piece_name(foongus)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rba_az_foongus}", PokeAccess::Puzzles.piece_name(foongus)
  end

  test "Chrysolia says the forest changing, and the assist lists the one tile that moves it on" do
    on_map(234, 9, 27)
    frame
    assert_includes frame { $game_variables[145] = 1 }, "{rba_cf_changed}"
    PokeAccess::Config.puzzle_assist = true
    $game_variables[145] = 3
    place(26, 16, 30, "EV026")
    assert_includes listed, [16, 30, "{rba_cf_next}"]
    refute(listed.any? { |r| r[2] == "{rba_cf_next}" && r[0] != 16 })
    assert_includes info_key, "{rba_cf_hint}"
    $game_variables[145] = 8
    refute_includes info_key, "rba_cf_"
  end

  test "Tanzan's discs turn the player out of the arm their switch says, Map 255's the other way" do
    base = PokeAccess::RebornTanzan
    on_map(246, 9, 9)
    assert_equal [11, 11, 1], base.spin(9, 9, 2)
    assert_equal [9, 9, 1], base.spin(7, 11, 6)
    assert_nil base.spin(9, 9, 4)
    $game_switches[269] = true
    assert_equal [7, 11, 1], base.spin(9, 9, 2)
    assert_equal [9, 9, 1], base.spin(11, 11, 4)
    on_map(255, 10, 8)
    assert_equal [8, 10, 1], base.spin(10, 8, 2), "off, map 255's disc turns as the others on"
    assert_equal :rba_tz_hint_cells, base.hint(254)
    $game_variables[149] = 8
    assert_equal :rba_tz_hint_locks, base.hint(255)
    $game_variables[149] = 10
    assert_nil base.hint(254)
    assert_equal :rba_tz_hint_gate_a, base.hint(246)
    $game_switches[267] = true
    $game_switches[268] = true
    $game_variables[149] = 6
    assert base.open?(246), "past the gates, map 246 still leads to Laura"
    assert_equal :rba_tz_hint_north, base.hint(246)
    $game_variables[149] = 7
    refute base.open?(246)
  end

  test "Route 1's bulls of a log pair are named with the assist alone" do
    on_map(285, 10, 20)
    tauros = place(12, 10, 17, "Tauros", 0, "pkmn_tauros")
    refute_equal "{rba_r1_log_tauros}", PokeAccess::Puzzles.piece_name(tauros)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rba_r1_log_tauros}", PokeAccess::Puzzles.piece_name(tauros)
    assert_equal "{rba_r1_log_bouffalant}", PokeAccess::Puzzles.piece_name(place(11, 8, 17, "Bouffalant", 0, "pkmn_bouffalant"))
  end

  test "Vanhanen's chess pieces say their colour and square, and the assist follows the mate move by move" do
    chess = PokeAccess::RebornChess
    on_map(313, 9, 16)
    rook = place(9, 6, 15, "1-WR1", 0, "chess3")
    king = place(42, 10, 15, "1-WK", 0, "chess6")
    assert_equal "{rba_vc_white_rook square=a1}", PokeAccess::Puzzles.piece_name(rook)
    assert_equal "{rba_vc_black_king square=h8}", PokeAccess::Puzzles.piece_name(place(10, 13, 8, "1-BK", 0, "chess6b"))
    assert_equal [:rba_vc_hint_push, { :from => "a1", :to => "a8" }], chess.hint(313)
    rook.y = 11
    assert_equal [:rba_vc_hint_push, { :from => "a5", :to => "a8" }], chess.hint(313)
    rook.y = 8
    king.x = 11
    assert_equal [:rba_vc_hint_push, { :from => "f1", :to => "g1" }], chess.hint(313)
    king.x = 12
    king.y = 12
    assert_equal [:rba_vc_hint_push, { :from => "g4", :to => "g6" }], chess.hint(313)
    king.y = 10
    assert_equal :rba_vc_hint_check, chess.hint(313)
    king.x = 13
    assert_equal :rba_vc_hint_reset, chess.hint(313)
    refute_includes info_key, "rba_vc_hint"
  end

  test "Vanhanen's bishops and crowning pawns are told how they move" do
    chess = PokeAccess::RebornChess
    on_map(318, 9, 16)
    { 49 => [7, 13], 53 => [11, 13], 54 => [11, 15], 57 => [7, 15] }.each { |id, (x, y)| place(id, x, y, "W", 0, "chess1") }
    hint = chess.hint(318)
    assert_equal :rba_vc_hint_crown, hint[0]
    assert_equal({ :from => "b3", :to => "b8", :into => "{rba_vc_bishop}" }, hint[1])
    $game_map.events[49].y = 8
    hint = chess.hint(318)
    assert_equal [:rba_vc_hint_diagonal, { :from => "b8", :to => "e5", :face => "{dir_right}", :key => "{dir_down}" }], hint
  end

  test "the Ruby Tower's statues take the answer that turns their switch on" do
    on_map(310, 7, 25)
    off = [TestCmd.new(121, [394, 394, 1], 1)]
    on = [TestCmd.new(121, [394, 394, 0], 1)]
    assert_equal "Dark", option(12, ["Light", "Dark"], [off, on])
    lee = [TestCmd.new(121, [399, 399, 0], 1)]
    assert_equal "Light", option(42, ["Light", "Dark"], [lee, [TestCmd.new(121, [399, 399, 1], 1)]])
    assert_equal "{rba_rt_chimchar}", PokeAccess::Puzzles.piece_name($game_map.events[12])
  end

  test "the Grand Stairway's way on is named with the assist alone" do
    on_map(179, 48, 7)
    stairs = place(7, 57, 53, "EV007")
    refute_equal "{rba_cc_way_on}", PokeAccess::Puzzles.piece_name(stairs)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rba_cc_way_on}", PokeAccess::Puzzles.piece_name(stairs)
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rba_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rba_kept_t)
    i18n.send(:remove_method, :rba_kept_t)
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

  def place(id, x, y, name, trigger = 0, sprite = "", list = nil)
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => list || [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A jump tile of Obsidia Slums: a touch page that, for each facing, jumps the player by its move route.
  def jump_tile(id, x, y, jumps)
    list = []
    jumps.each do |d, (dx, dy)|
      route = Struct.new(:list).new([TestCmd.new(14, [dx, dy]), TestCmd.new(0, [])])
      list.push(TestCmd.new(111, [6, -1, d], 0), TestCmd.new(209, [-1, route], 1), TestCmd.new(412, [], 0))
    end
    list.push(TestCmd.new(0, [], 0))
    page = TestPage.new(:trigger => 1, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.blocking = true
    ev
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
    place(id, 5, 5, "EV#{id}", 0, "", list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
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
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end

  def listed_names
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
  end
end
