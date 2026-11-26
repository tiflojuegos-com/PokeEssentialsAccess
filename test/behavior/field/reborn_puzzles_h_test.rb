# Pokemon Reborn's puzzles of part H (games/reborn/puzzles/): the jump tiles of Obsidia Slums 2F and of the Slums
# Playground with its Scraggy quest, Blacksteam's Ditto, Aventurine Woods' bugs, Devon's Double Magic Square and the
# Mechanic Shed's Gastly. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesHTest < PokeAccessTest
  include TileWorldHelpers

  SWITCHES = [161, 164, 165, 169, 170, 372, 410, 411, 412, 426, 927, 1028, 1029, 1030, 2226]
  VARS = [66, 107, 108, 109, 110, 111, 112, 113, 114, 115, 122, 156, 393] + (451..468).to_a

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
    PokeAccess::RebornMagicSquare.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Obsidia Slums 2F's jump tiles hop as 1F's do" do
    with_tile_world(rows) do |world|
      world.map_id = 91
      world.events[5] = jump_tile(5, 3, 3, 8 => [0, -2])
      PokeAccess::RebornJumpTiles.forget
      assert_equal [3, 2], step_up
    end
  end

  test "the playground's jump tiles hop above and are walked over on the lower level" do
    with_tile_world(rows) do |world|
      world.map_id = 321
      above = jump_tile(5, 3, 3, 8 => [0, -2])
      def above.over_trigger?; false; end
      blank = TestPage.new(:condition => { :switch1_valid => true, :switch1_id => 410 })
      pages = [PokeAccess.ivar(above, :@page), blank]
      above.instance_variable_get(:@event).pages = pages
      world.events[5] = above
      PokeAccess::RebornJumpTiles.forget
      assert_equal [3, 2], step_up
      $game_switches[410] = true
      world.events[5] = TestGameEvent.new(:id => 5, :x => 3, :y => 3, :pages => pages, :active_page => blank)
      PokeAccess::Caches.reset_all
      assert_equal [3, 3], step_up, "below, the tile's page is blank and the press walks onto it"
    end
  end

  test "the playground's devices are named, and the Scraggy quest's next step comes with the assist" do
    pg = PokeAccess::RebornPlayground
    on_map(321, 14, 43)
    device = place(60, 11, 15, "EV060")
    assert_equal "{rbh_pg_device}", PokeAccess::Puzzles.piece_name(device)
    $game_variables[156] = 2
    assert_equal :rbh_pg_hint_pangoro_left, pg.hint
    $game_switches[411] = true
    assert_equal :rbh_pg_hint_device_left, pg.hint
    $game_self_switches[[321, 60, "A"]] = true
    $game_variables[156] = 3
    assert_equal "{rbh_pg_device_pressed}", PokeAccess::Puzzles.piece_name(device)
    assert_equal :rbh_pg_hint_pangoro_right, pg.hint
    $game_switches[412] = true
    assert_equal :rbh_pg_hint_device_right, pg.hint
    $game_self_switches[[321, 67, "A"]] = true
    $game_variables[156] = 4
    assert_equal :rbh_pg_hint_boss, pg.hint
    $game_variables[156] = 6
    assert_nil pg.hint
  end

  test "the Sun Stone is said to be picked up from below, with the assist alone" do
    on_map(321, 14, 43)
    stone = place(32, 22, 37, "Item", 1, "itemball")
    refute_equal "{rbh_pg_sun_stone}", PokeAccess::Puzzles.piece_name(stone)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbh_pg_sun_stone}", PokeAccess::Puzzles.piece_name(stone)
    $game_switches[410] = true
    refute_equal "{rbh_pg_sun_stone}", PokeAccess::Puzzles.piece_name(stone)
  end

  test "the Ditto's way: wake and bond with Abra, empty the cage below it, bring Lickitung, then Makuhita" do
    dit = PokeAccess::RebornBlacksteamDitto
    on_map(11, 2, 3)
    $game_variables[66] = 10
    $game_variables[107] = 12
    assert_nil dit.hint, "while the cell stands, the cell's puzzle speaks"
    $game_variables[107] = 13
    cages(108 => 1, 109 => 2, 110 => 0, 111 => 4, 112 => 5)
    assert_equal [:rba_bf_hint_go, { :name => "{rba_bf_loudred}" }], dit.hint
    $game_switches[164] = true
    assert_equal :rba_bf_hint_abra, dit.hint
    $game_switches[165] = true
    assert_equal :rbh_bf_hint_clear, dit.hint
    cages(108 => 0, 110 => 1)
    assert_equal [:rba_bf_hint_go, { :name => "{rba_bf_lickitung}" }], dit.hint
    cages(108 => 2, 109 => 0)
    assert_equal :rba_bf_hint_release, dit.hint
    $game_switches[165] = false
    assert_equal [:rbh_bf_hint_transform, { :name => "{rba_bf_lickitung}" }], dit.hint
    $game_switches[169] = true
    $game_variables[122] = 2
    $game_switches[165] = true
    assert_equal :rbh_bf_hint_clear, dit.hint, "with the Rare Candy given, Makuhita is wanted"
    cages(108 => 4, 111 => 2)
    $game_switches[165] = false
    assert_equal [:rbh_bf_hint_transform, { :name => "{rba_bf_makuhita}" }], dit.hint
    $game_switches[170] = true
    $game_variables[66] = 12
    assert_equal :rbh_bf_hint_take, dit.hint
    $game_switches[426] = true
    assert_nil dit.hint
  end

  test "the caged Ditto and the freed one are named while each waits" do
    on_map(11, 2, 3)
    ditto = place(6, 1, 2, "Ditto", 4, "pkmn_ditto")
    freed = place(19, 1, 4, "Ditto2", 0, "pkmn_ditto")
    $game_variables[66] = 10
    assert_equal "{rbh_bf_ditto_caged}", PokeAccess::Puzzles.piece_name(ditto)
    assert_includes listed_names, "{rbh_bf_ditto_caged}"
    refute_includes listed_names, "{rbh_bf_ditto_freed}"
    $game_variables[66] = 12
    $game_switches[170] = true
    assert_includes listed_names, "{rbh_bf_ditto_freed}"
    refute_includes listed_names, "{rbh_bf_ditto_caged}"
    assert freed
  end

  test "a bug says, with the assist, whether beating it has its partner break a log or a web" do
    bugs = PokeAccess::RebornAventurineBugs
    log = bug_list(372, "Pinsir crushed the log into bits!")
    web = bug_list(373, "Heracross tore down the spider web!")
    plain = [TestCmd.new(101, ["Heracross absconded peacefully."]), TestCmd.new(121, [361, 361, 1]), TestCmd.new(0, [])]
    on_map(282, 10, 10)
    assert_equal [372, :log], bugs.breaks(place(94, 19, 44, "Heracross", 0, "pkmn_heracross", log))
    assert_equal [373, :web], bugs.breaks(place(93, 18, 44, "Pinsir", 0, "pkmn_pinsir", web))
    hera = place(95, 25, 32, "Heracross", 0, "pkmn_heracross", plain)
    assert_nil bugs.breaks(hera)
    heracross = $game_map.events[94]
    refute_equal "{rbh_aw_bug_log name=Heracross}", PokeAccess::Puzzles.piece_name(heracross)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbh_aw_bug_log name=Heracross}", PokeAccess::Puzzles.piece_name(heracross)
    assert_equal "{rbh_aw_bug_web name=Pinsir}", PokeAccess::Puzzles.piece_name($game_map.events[93])
    assert_equal "{rbh_aw_bug_plain name=Heracross}", PokeAccess::Puzzles.piece_name(hera)
    $game_switches[372] = true
    assert_equal "{rbh_aw_bug_plain name=Heracross}", PokeAccess::Puzzles.piece_name(heracross)
  end

  test "each Double Magic Square plan ends in the checker's win, and a pick off it leads back" do
    sq = PokeAccess::RebornMagicSquare
    lines = [[0, 8], [1, 7], [2, 6], [3, 5]]
    [0, 1].each do |k|
      s = sq.trail(k).last
      a = s[0, 9]
      b = s[9, 9]
      assert lines.all? { |i, j| a[4] + a[i] + a[j] == 15 && b[4] + b[i] + b[j] == 15 }, "plan #{k}"
      assert (0..8).all? { |i| i == 4 || a[i] != b[i] }, "plan #{k}"
      assert_equal sq::STARTS[k].sort, s.sort, "a pick only moves numbers round"
    end
    assert_equal [12, 1, 2, 3, 10, 11], [0, 1, 2, 9, 10, 11].map { |i| sq.apply((1..18).to_a, [77, 1, :right])[i] }
    assert_equal [4, 7, 1], [0, 3, 6].map { |i| sq.apply((1..18).to_a, [78, 1, :up])[i] }
    assert_equal [77, 1, :left], sq.next_move(sq::STARTS[0])
    off = sq.apply(sq::STARTS[0], [79, 1, :up])
    assert_equal [79, 1, :down], sq.next_move(off)
  end

  test "the magic square's screens are said as they change, with the next pick with the assist" do
    sq = PokeAccess::RebornMagicSquare
    on_map(765, 12, 21)
    set_grid(sq::STARTS[0])
    sq.poll
    assert_equal [], said { sq.poll }, "the screens found on arriving are left to the info key"
    $game_switches[1029] = true
    sq.forget
    sq.poll
    set_grid(sq.apply(sq::STARTS[0], [77, 1, :left]))
    $game_switches[1030] = true
    assert_equal [], said { sq.poll }, "not while the checker runs"
    $game_switches[1030] = false
    PokeAccess::Config.puzzle_assist = true
    line = said { sq.poll }.join
    assert_includes line, "{rbh_dm_screens a=9 6 1, 5 8 3, 2 4 1 b=2 5 4, 7 7 9, 6 3 8}"
    assert_includes line, "{rbh_dm_hint dir=Right line=Row 2 terminal={rbh_dm_terminal_middle}}"
    assert_equal [:rbh_dm_hint, { :terminal => "{rbh_dm_terminal_middle}", :line => "Row 2", :dir => "Right" }], sq.hint
    $game_switches[1028] = true
    assert_nil sq.hint
  end

  test "the Gastly flees as a corner of its row is stepped on, and the assist says how to reach it" do
    ms = PokeAccess::RebornMechanicShed
    on_map(748, 24, 12)
    gastly = place(9, 22, 7, "ghast", 0, "pkmn_gastly")
    corner_n = place(24, 23, 7, "EV024", 1)
    corner_s = place(25, 21, 9, "EV025", 1)
    assert_nil ms.corner(corner_n), "not before the Breloom is beaten"
    $game_variables[393] = 2
    assert_equal :rbh_ms_flees, ms.corner(corner_n)
    assert_nil ms.corner(corner_s)
    assert_equal :rbh_ms_hint_north, ms.hint
    gastly.y = 9
    assert_equal :rbh_ms_flees, ms.corner(corner_s)
    assert_equal :rbh_ms_hint_south, ms.hint
    $game_switches[927] = true
    assert_nil ms.corner(corner_s)
    assert_equal :rbh_ms_hint_still, ms.hint
    $game_variables[393] = 3
    assert_nil ms.hint
  end

  private

  def rows
    ["#######", "#.....#", "#.....#", "#.....#", "#..@..#", "#.....#", "#######"]
  end

  # Where a press up from (3, 4) lands, as the routes play it.
  def step_up
    up = PokeAccess::Routes::DIRS.find { |v| v[2] == 8 }
    s = PokeAccess::Pathfinder.searching { PokeAccess::Routes::Moves.step(3, 4, 0, up, PokeAccess::Pathfinder.replay_mode) }
    [s.x, s.y]
  end

  def cages(map)
    map.each { |v, c| $game_variables[v] = c }
  end

  def set_grid(s)
    (451..468).each_with_index { |v, i| $game_variables[v] = s[i] }
  end

  # A bug's page: beaten, its partner breaks what a switch guards, once.
  def bug_list(switch, text)
    [TestCmd.new(111, [0, switch, 1], 0), TestCmd.new(121, [switch, switch, 0], 1), TestCmd.new(101, [text], 1),
     TestCmd.new(0, [], 1), TestCmd.new(412, [], 0), TestCmd.new(0, [], 0)]
  end

  def said
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbh_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbh_kept_t)
    i18n.send(:remove_method, :rbh_kept_t)
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

  # A jump tile: a touch page that, for each facing, jumps the player by its move route.
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

  def listed_names
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
  end
end
