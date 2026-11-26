# Pokemon Reborn's puzzles of part K (games/reborn/puzzles/): Teknite Cave's 3F rocks and 3-4F river, Route 4's jump
# stones and the knight's ambush in Castle at Wit's End. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesKTest < PokeAccessTest
  SWITCHES = [410, 845, 846, 849, 877]
  VARS = [362, 376]

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
    PokeAccess::RebornRoute4Jumps.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Teknite 3F walks the crystals, the middle rock, the cave again and the crystals by the stairs" do
    upper = PokeAccess::RebornTekniteUpper
    on_map(640, 23, 29)
    assert_equal :rbk_tk3_hint_gem, upper.hint(false)
    on_map(648, 23, 26)
    assert_equal :rbk_tk3_hint_side_crystal, upper.hint(true)
    $game_switches[845] = true
    assert_equal :rbk_tk3_hint_side_rock, upper.hint(true)
    $game_switches[846] = true
    assert_equal :rbk_tk3_hint_quake, upper.hint(true)
    on_map(640, 23, 20)
    $game_switches[846] = true
    assert_equal :rbk_tk3_hint_north, upper.hint(false)
    $game_player.x, $game_player.y = 24, 10
    assert_equal :rbk_tk3_hint_gem_here, upper.hint(false)
    on_map(648, 24, 10)
    $game_switches[846] = true
    assert_equal :rbk_tk3_hint_stairs_crystal, upper.hint(true)
    $game_variables[376] = 1
    assert_equal :rbk_tk3_hint_smash, upper.hint(true)
    assert_equal :rbk_tk3_hint_smash, upper.hint(false)
  end

  test "Teknite 3F names the drawn red crystals of 648 and says the rocks as they change" do
    on_map(648, 23, 26)
    crystal = place(8, 23, 27, "EV008")
    assert_equal "{rbf_teknite_crystal}", PokeAccess::Puzzles.piece_name(crystal)
    assert_includes frame { $game_switches[845] = true }.join(" "), "rbf_teknite_reacted"
    assert_includes frame { $game_variables[376] = 1 }.join(" "), "rbf_teknite_reacted"
    assert_includes info_key, "{rbk_tk3_side_rock}"
    $game_variables[376] = 3
    frame
    refute_includes info_key, "rbk_tk3_"
  end

  test "Teknite 3-4F tells the current, the blue crystal and the bridge, the way with the assist alone" do
    upper = PokeAccess::RebornTekniteUpper
    on_map(645, 27, 22)
    assert_equal :rbk_tk34_hint_gem, upper.river_hint(false)
    on_map(649, 24, 27)
    blue = place(5, 24, 28, "EV005")
    assert_equal "{rbk_tk34_blue_crystal}", PokeAccess::Puzzles.piece_name(blue)
    assert_equal :rbk_tk34_hint_crystal, upper.river_hint(true)
    refute_includes info_key, "rbk_tk34_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbk_tk34_hint_crystal}"
    assert_includes frame { $game_switches[849] = true }.join(" "), "rbk_tk34_bridge_on"
    assert_equal :rbk_tk34_hint_bridge, upper.river_hint(true)
    assert_equal [6, 7, 8, 9, 10, 11, 12, 13, 27, 28, 29, 30, 31, 32, 33], upper::EDGES[649]
  end

  test "Route 4's jump stones hop by their live page, and the lower level's blank page throws nothing" do
    rows = ["#######", "#.....#", "#.....#", "#.....#", "#..@..#", "#.....#", "#######"]
    with_tile_world(rows) do |world|
      world.map_id = 715
      stone = jump_tile(30, 3, 3, 8 => [0, -2])
      world.events[30] = stone
      jumps = PokeAccess::RebornRoute4Jumps
      jumps.forget
      assert jumps.from?(3, 4)
      assert_equal [3, 2], jumps.hop(3, 4, 8)
      assert_nil jumps.hop(3, 4, 4)
      blank = TestPage.new(:trigger => 0, :list => [TestCmd.new(0, [], 0)])
      stone.instance_variable_set(:@active, blank)
      assert_equal [3, 2], jumps.hop(3, 4, 8), "read once per level"
      $game_switches[410] = true
      refute jumps.from?(3, 4), "on the lower level the stone's page is blank"
      assert_nil jumps.hop(3, 4, 8)
    end
  end

  test "Wit's End names the knight's column and says the ambush with the assist alone, in its hall" do
    on_map(698, 38, 84)
    $game_variables[362] = 2
    tripwire = place(82, 36, 85, "EV082", 1)
    refute_equal "{rbk_castle_ambush}", PokeAccess::Puzzles.piece_name(tripwire)
    refute_includes info_key, "rbk_castle_ambush_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbk_castle_ambush}", PokeAccess::Puzzles.piece_name(tripwire)
    assert_includes info_key, "{rbk_castle_ambush_hint}"
    $game_player.x, $game_player.y = 9, 13
    refute_includes info_key, "rbk_castle_ambush_hint"
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbk_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbk_kept_t)
    i18n.send(:remove_method, :rbk_kept_t)
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

  def place(id, x, y, name, trigger = 0, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A jump stone: a touch page that, for each facing, branches on it and jumps the player by its delta.
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
end
