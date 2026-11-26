# Pokemon Reborn's puzzles of the remate E (games/reborn/puzzles/): the Sugiline Cave's Big Hole, the logs and webs of
# Aventurine Woods with what clears each, Route 1's Tauros with the wood of their log, and the story's way through
# Rhodochrine Jungle. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesRbreTest < PokeAccessTest
  SWITCHES = [294, 300, 372, 886, 887]
  VARS = [77, 655, 656]

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
    PokeAccess::RebornSugilineHole.forget
    PokeAccess::RebornRhodochrineStory.forget
    PokeAccess::RebornAventurineBugs.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the Big Hole goes for the right button, then the left, then the stairs, from the cave's mouth" do
    hole = PokeAccess::RebornSugilineHole
    on_map(651, 33, 44)
    assert_equal [nil, [17], :rbre_sh_r1], hole.step(651)
    $game_switches[887] = true
    assert_equal [[13], :rbre_sh_l1], hole.step(651)[1, 2]
    $game_switches[886] = true
    assert_equal [[5], :rbre_sh_s1], hole.step(651)[1, 2]
  end

  test "the Big Hole tells a map's parts apart by the landing, and sends the wrong part back" do
    hole = PokeAccess::RebornSugilineHole
    on_map(656, 37, 34)
    assert_equal [[1], :rbre_sh_r2], hole.step(656)[1, 2]
    on_map(656, 27, 38)
    assert_equal :rbre_sh_back_pit, hole.step(656)[2]
    on_map(659, 21, 11)
    assert_equal [[1], :rbre_sh_r4], hole.step(659)[1, 2]
    on_map(659, 39, 28)
    assert_equal :rbre_sh_back_pit, hole.step(659)[2]
    on_map(654, 33, 23)
    assert_equal [[57], :rbre_sh_r5], hole.step(654)[1, 2]
    $game_switches[887] = true
    assert_equal [[1], :rbre_sh_back], hole.step(654)[1, 2]
    on_map(657, 55, 58)
    $game_switches[887] = true
    assert_equal [[4], :rbre_sh_l2], hole.step(657)[1, 2]
    on_map(657, 18, 39)
    $game_switches[887] = true
    assert_equal [[1], :rbre_sh_l4], hole.step(657)[1, 2]
    on_map(657, 31, 34)
    $game_switches[887] = true
    assert_equal :rbre_sh_back_pit, hole.step(657)[2]
    on_map(653, 12, 31)
    $game_switches[887] = true
    assert_equal [[41], :rbre_sh_l5], hole.step(653)[1, 2]
    on_map(653, 35, 14)
    $game_switches[887] = true
    assert_equal [[47], :rbre_sh_l7], hole.step(653)[1, 2]
    on_map(653, 44, 38)
    $game_switches[887] = true
    assert_equal [[1], :rbre_sh_back], hole.step(653)[1, 2]
    on_map(654, 9, 24)
    $game_switches[887] = true
    assert_equal [[56], :rbre_sh_l8], hole.step(654)[1, 2]
    on_map(654, 33, 46)
    $game_switches[886] = $game_switches[887] = true
    assert_equal [[4], :rbre_sh_s3], hole.step(654)[1, 2]
  end

  test "the Big Hole keeps the part of the visit's first tile, a box when it is no landing" do
    hole = PokeAccess::RebornSugilineHole
    on_map(656, 40, 30)
    assert_equal :east, hole.region(656)
    $game_player.x, $game_player.y = 20, 20
    assert_equal :east, hole.region(656)
    hole.forget
    assert_equal :main, hole.region(656)
  end

  test "the Big Hole lists its step as the right way and says it with the assist alone" do
    on_map(656, 37, 34)
    place(1, 44, 24, "EV001", 1)
    refute_includes info_key, "rbre_sh_"
    assert_empty right_ways
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbre_sh_r2}"
    assert_equal [[44, 24]], right_ways
  end

  test "Aventurine names its logs and webs as drawn, and with the assist what clears each" do
    bugs = PokeAccess::RebornAventurineBugs
    on_map(282, 30, 30)
    place(94, 19, 44, "Heracross", 0, "pkmn_heracross", bug_list(372, "Pinsir crushed the log into bits!"))
    bull_log = place(49, 38, 15, "EV049")
    bug_log = place(60, 12, 45, "EV060")
    stray = place(5, 12, 7, "EV005")
    assert_equal :rbre_aw_log, bugs.obstacle_label(bull_log)
    assert_equal :rbre_aw_log, bugs.obstacle_label(bug_log)
    assert_nil bugs.obstacle_label(stray)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:rbre_aw_log_bull, { :x => 59, :y => 27 }], bugs.obstacle_label(bull_log)
    assert_equal [:rbre_aw_log_bug, { :name => "Heracross", :x => 19, :y => 44 }], bugs.obstacle_label(bug_log)
    assert_equal "{rbre_aw_log_bug name=Heracross x=19 y=44}", PokeAccess::Puzzles.piece_name(bug_log)
    assert_equal 300, bugs.switch_of(bull_log)
  end

  test "Route 1's Tauros say in which wood their log lies, and nothing once it is aside" do
    bulls = PokeAccess::RebornRouteBulls
    on_map(285, 30, 30)
    near = place(12, 10, 17, "Tauros")
    far = place(62, 59, 27, "Tauros")
    assert_equal :rba_r1_log_tauros, bulls.tauros_label(near)
    assert_equal :rbre_r1_log_tauros_far, bulls.tauros_label(far)[0]
    assert_equal [300, 282], bulls::LOGS[[285, 62]]
    $game_switches[294] = true
    assert_nil bulls.tauros_label(near)
  end

  test "Rhodochrine's story steps go by variable 77 and the two vines" do
    story = PokeAccess::RebornRhodochrineStory
    on_map(150, 118, 101)
    $game_variables[77] = 3
    assert_equal [[59], :rbre_rj_pit], story.step(150)[2, 2]
    $game_variables[77] = 5
    assert_nil story.step(150)
    $game_variables[77] = 7
    assert_equal [[248], :rbre_rj_lever], story.step(150)[2, 2]
    $game_variables[77] = 8
    assert_equal [[250], :rbre_rj_cain], story.step(150)[2, 2]
    $game_variables[77] = 9
    assert_equal [[51], :rbre_rj_tree1], story.step(150)[2, 2]
    $game_variables[655] = 4
    assert_equal [[5], :rbre_rj_around_down], story.step(150)[2, 2]
    $game_variables[656] = 6
    assert_equal [[328], :rbre_rj_vines_done], story.step(150)[2, 2]
    $game_variables[655] = 0
    assert_equal [[51], :rbre_rj_tree1], story.step(150)[2, 2]
    $game_variables[77] = 10
    assert_equal [[272], :rbre_rj_leave], story.step(150)[2, 2]
  end

  test "Rhodochrine's way to the second vine's tree runs through The Underroot, Beryl Ward and its house" do
    story = PokeAccess::RebornRhodochrineStory
    [[153, 60, 16, [8]], [150, 148, 82, [31]], [149, 9, 24, [40, 45]], [155, 11, 8, [1]], [149, 11, 15, [84]],
     [150, 158, 62, [88]]].each do |map, x, y, events|
      on_map(map, x, y)
      $game_variables[77] = 9
      $game_variables[655] = 4
      assert_equal events, story.step(map)[2], "map #{map} from #{x}, #{y}"
    end
    on_map(150, 158, 62)
    $game_variables[77] = 9
    assert_equal [[88], :rbre_rj_tree2], story.step(150)[2, 2]
  end

  def bug_list(switch, text)
    [TestCmd.new(111, [0, switch, 1], 0), TestCmd.new(121, [switch, switch, 0], 1), TestCmd.new(101, [text], 1),
     TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
  end

  # Swaps I18n.t for one that answers "{key name=value ...}", so the test reads keys and their values.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbre_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbre_kept_t)
    i18n.send(:remove_method, :rbre_kept_t)
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
    PokeAccess::RebornSugilineHole.forget
    PokeAccess::RebornRhodochrineStory.forget
    PokeAccess::RebornAventurineBugs.forget
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

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  # The tiles listed as the right way.
  def right_ways
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .select { |tg| tg.name == "{puzzle_right_way}" }.map { |tg| [tg.x, tg.y] }
  end
end
