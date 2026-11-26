# Pokemon Reborn's optional puzzles of part I (games/reborn/puzzles/): the New World's jump tiles, the Regi's rituals and
# Regice's ice, Regigigas' secret switches and the Tapus' Unown.
# Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesITest < PokeAccessTest
  SWITCHES = [1377, 1379, 1380, 1381, 1382, 1383, 1559, 1666, 1667, 1668, 1669]
  VARS = [576, 577, 579, 580, 581, 582, 583, 584, 585, 588, 621, 779]

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
    PokeAccess::World::Mechanics.forget
    PokeAccess::RebornNewWorldJumps.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "a New World jump tile hops only while the page that throws stands" do
    rows = ["#######", "#.....#", "#.....#", "#.....#", "#..@..#", "#.....#", "#######"]
    with_tile_world(rows) do |world|
      world.map_id = 837
      world.events[5] = jump_tile(5, 3, 3, { 8 => [0, -2] }, :switch1_valid => true, :switch1_id => 1559)
      nw = PokeAccess::RebornNewWorldJumps
      nw.forget
      assert_nil nw.hop(3, 4, 8), "the tile stands only with switch 1559"
      refute nw.from?(3, 4)
      $game_switches[1559] = true
      PokeAccess::World::Epoch.dirty!
      assert nw.from?(3, 4)
      assert_equal [3, 2], nw.hop(3, 4, 8)
      assert_nil nw.hop(3, 4, 4), "no facing of the tile throws from its east"
      up = PokeAccess::Routes::DIRS.find { |v| v[2] == 8 }
      s = PokeAccess::Pathfinder.searching { PokeAccess::Routes::Moves.step(3, 4, 0, up, PokeAccess::Pathfinder.replay_mode) }
      assert_equal [3, 2], [s.x, s.y]
    end
  end

  test "the Regi's rituals name the levers as turned, the two boulders by colour and the rocks to touch" do
    on_map(825, 70, 30)
    lever = place(105, 70, 28, "EV105")
    grey = place(82, 6, 66, "Boulder", 1, "rockstrength2")
    brown = place(83, 11, 67, "Boulder", 1, "rockstrength")
    north = "{rbi_regi_lever side={rbi_regi_north} state=%s}"
    assert_equal format(north, "{rbi_regi_center}"), PokeAccess::Puzzles.piece_name(lever)
    $game_variables[582] = 1
    assert_equal format(north, "{rbi_regi_left}"), PokeAccess::Puzzles.piece_name(lever)
    $game_variables[582] = 2
    assert_equal format(north, "{rbi_regi_right}"), PokeAccess::Puzzles.piece_name(lever)
    assert_equal "{rbi_regi_grey_rock}", PokeAccess::Puzzles.piece_name(grey)
    assert_equal "{rbi_regi_brown_rock}", PokeAccess::Puzzles.piece_name(brown)
    refute(listed.any? { |r| r[2] == "{rbi_regi_rock}" })
    $game_variables[576] = 4
    assert_includes listed, [47, 89, "{rbi_regi_rock}"]
    $game_variables[579] = 2
    assert_includes listed, [5, 65, "{rbi_regi_tallest}"]
    assert_includes listed, [9, 66, "{rbi_regi_center_stone}"]
    refute_includes info_key, "rbi_regi_ritual_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbi_regi_ritual_hint}"
    $game_variables[576] = 5
    $game_variables[579] = 3
    refute_includes info_key, "rbi_regi_ritual_hint"
  end

  test "Danielle's menus take Opt Out and its Yes with the assist, by the quest variable they write" do
    on_map(825, 60, 90)
    PokeAccess::Config.puzzle_assist = true
    list = [TestCmd.new(102, [["Start over", "Opt Out"], 1], 0), TestCmd.new(402, [0, "Start over"], 0),
            TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Opt Out"], 0), TestCmd.new(102, [["Yes", "No"], 2], 1),
            TestCmd.new(402, [0, "Yes"], 1), TestCmd.new(122, [576, 576, 0, 0, 5], 2), TestCmd.new(0, [], 2),
            TestCmd.new(402, [1, "No"], 1), TestCmd.new(0, [], 2), TestCmd.new(404, [], 1), TestCmd.new(0, [], 1),
            TestCmd.new(404, [], 0), TestCmd.new(0, [], 0)]
    assert_equal "Opt Out", pick(1, list, 0)
    assert_equal "Yes", pick(1, list, 4)
    ready = [TestCmd.new(102, [["Yes", "No"], 2], 0), TestCmd.new(402, [0, "Yes"], 0),
             TestCmd.new(122, [744, 744, 0, 0, 1], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "No"], 0),
             TestCmd.new(0, [], 1), TestCmd.new(404, [], 0), TestCmd.new(0, [], 0)]
    assert_nil pick(1, ready, 0), "starting the ritual writes no quest variable"
  end

  test "Regice's cracks are named as they stand, and each slide of the plan comes with the assist" do
    on_map(825, 28, 25)
    crack = place(90, 25, 22, "EV090", 1)
    place(88, 25, 20, "EV088", 1)
    assert_equal "{rbi_ice_crack}", PokeAccess::Puzzles.piece_name(crack)
    $game_switches[1381] = true
    assert_equal "{rbi_ice_crack_broken}", PokeAccess::Puzzles.piece_name(crack)
    $game_switches[1381] = false
    $game_variables[580] = 2
    $game_variables[577] = 1
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, "rbi_ice_", "Danielle has not told the order yet"
    $game_self_switches[[825, 87, "B"]] = true
    assert_includes info_key, "{rbi_ice_step1}"
    assert_includes listed, [28, 22, "{rbi_ice_start}"]
    $game_variables[577] = 2
    $game_switches[1381] = true
    assert_includes info_key, "{rbi_ice_step2}"
    assert_includes listed, [22, 21, "{rbi_ice_start}"]
    $game_switches[1379] = true
    assert_includes info_key, "{rbi_ice_reset}", "a second crack broken before the second slide spoils the ritual"
    refute(listed.any? { |r| r[2] == "{rbi_ice_start}" })
    $game_variables[577] = 8
    [1380, 1382].each { |s| $game_switches[s] = true }
    assert_includes info_key, "{rbi_ice_step5}"
    assert_includes listed, [23, 24, "{rbi_ice_start}"]
    $game_switches[1377] = true
    assert_includes info_key, "{rbi_ice_reset}"
    $game_switches[1377] = false
    $game_variables[580] = 3
    refute_includes info_key, "rbi_ice_"
  end

  test "Regigigas' secret switches are named, and the next one, the tiles on and the boulders' spots come with the assist" do
    on_map(840, 112, 89)
    $game_variables[588] = 1
    first = place(44, 112, 88, "EV044")
    second = place(47, 67, 85, "EV047")
    statues = place(59, 106, 73, "EV059")
    assert_equal "{rbi_gigas_switch}", PokeAccess::Puzzles.piece_name(first)
    assert_equal "{rbi_gigas_statues}", PokeAccess::Puzzles.piece_name(statues)
    refute_includes info_key, "rbi_gigas_"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbi_gigas_switch_next}", PokeAccess::Puzzles.piece_name(first)
    assert_equal "{rbi_gigas_switch}", PokeAccess::Puzzles.piece_name(second)
    assert_includes info_key, "{rbi_gigas_hint}"
    $game_variables[588] = 2
    assert_includes info_key, "{rbi_gigas_hint_onward}"
    assert_includes listed, [70, 87, "{rbi_gigas_onward}"]
    $game_variables[588] = 4
    assert_equal "{rbi_gigas_switch_next}", PokeAccess::Puzzles.piece_name(second)
    refute(listed.any? { |r| r[2] == "{rbi_gigas_onward}" })
    $game_variables[588] = 13
    assert_includes info_key, "{rbi_gigas_hint_boulders}"
    assert_includes listed, [98, 56, "{rbi_gigas_boulder_goal}"]
    $game_variables[588] = 18
    refute_includes info_key, "rbi_gigas_"
  end

  test "the Tapus' Unown says its letter as it is used, and the stage's terrain comes with the assist" do
    on_map(855, 29, 27)
    unown = place(12, 29, 26, "EV012")
    assert_equal "{rbi_tapu_unown}", PokeAccess::Puzzles.piece_name(unown)
    $game_variables[621] = 2
    $game_variables[779] = 19
    assert_includes frame { fire(unown) }, "{rbi_tapu_letter letter=P}"
    $game_variables[779] = 25
    assert_includes frame { fire(unown) }, "{rbi_tapu_letter letter=C}"
    refute_includes info_key, "rbi_tapu_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbi_tapu_hint terrain={rbi_tapu_psychic}}"
    $game_switches[1667] = true
    refute_includes info_key, "rbi_tapu_hint"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbi_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbi_kept_t)
    i18n.send(:remove_method, :rbi_kept_t)
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

  # A jump tile of the New World: a touch page that, for each facing, jumps the player by its move route, standing while
  # its condition holds.
  def jump_tile(id, x, y, jumps, condition = {})
    list = []
    jumps.each do |d, (dx, dy)|
      route = Struct.new(:list).new([TestCmd.new(14, [dx, dy]), TestCmd.new(0, [])])
      list.push(TestCmd.new(111, [6, -1, d], 0), TestCmd.new(209, [-1, route], 1), TestCmd.new(412, [], 0))
    end
    list.push(TestCmd.new(0, [], 0))
    page = TestPage.new(:trigger => 1, :list => list, :condition => condition)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.blocking = true
    ev
  end

  # The option right_choice picks of the menu at list[i], on an event whose page is the list.
  def pick(id, list, i)
    place(id, 5, 5, "EV#{id}", 0, "", list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, i)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
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
end
