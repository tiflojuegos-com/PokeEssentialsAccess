# Pokemon Reborn's legendary quests finished in the remate D (games/reborn/puzzles/): Genesect's drives, the Rhodochrine
# Tree's floors, the Arceus hall's statues on the way to Regigigas, the Tauros ledges of North Aventurine Woods and the
# hops of the hall. Without the assist, what the screen shows; with it, the way.
class RebornPuzzlesRdTest < PokeAccessTest
  SWITCHES = (1729..1742).to_a + [1385, 1805]
  VARS = [588, 637, 661, 662]

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

  test "Genesect's machines say their state, and the plan names the next one, the floor to walk or the way back" do
    on_map(877, 31, 101)
    receptor = place(135, 26, 69, "EV135")
    console = place(82, 31, 72, "EV082")
    place(4, 30, 95, "EV004", 1)
    shock = "{rbrd_gen_receptor drive={rbrd_gen_shock} state=%s}"
    assert_equal format(shock, "{rbrd_gen_inactive}"), PokeAccess::Puzzles.piece_name(receptor)
    assert_equal "{rbrd_gen_console mode={rbrd_gen_mode_a}}", PokeAccess::Puzzles.piece_name(console)
    $game_variables[637] = 10
    refute_includes info_key, "rbrd_gen_"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbrd_gen_floor}"
    assert_includes listed, [30, 95, "{rbrd_gen_floor_spot}"]
    $game_variables[637] = 17
    $game_switches[1729] = true
    $game_switches[1730] = true
    assert_includes info_key, "{rbrd_gen_hint_insert drive={rbrd_gen_shock}}"
    assert_equal "{rbrd_gen_next what=#{format(shock, '{rbrd_gen_inactive}')}}", PokeAccess::Puzzles.piece_name(receptor)
    $game_switches[1729] = false
    assert_includes info_key, "{rbrd_gen_hint_back what={rbrd_gen_hint_console mode={rbrd_gen_mode_b}}}"
    assert_match(/\{rbrd_gen_next what=\{rbrd_gen_console/, PokeAccess::Puzzles.piece_name(console))
    $game_variables[637] = 28
    refute_includes info_key, "rbrd_gen_"
  end

  test "the Rhodochrine Tree names the fights that even both strengths, and how to start a failed floor over" do
    on_map(886, 24, 20)
    espeon = place(3, 21, 21, "EV003", 0, "pkmn_espeon")
    place(4, 26, 18, "EV004", 0, "pkmn_umbreon")
    $game_variables[661] = 9
    $game_variables[662] = 6
    refute_match(/rbrd_tree/, PokeAccess::Puzzles.piece_name(espeon).to_s)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbrd_tree_hint foes=Espeon x=9 y=6}"
    assert_equal "{rbrd_tree_next name=Espeon}", PokeAccess::Puzzles.piece_name(espeon)
    on_map(886, 24, 140)
    PokeAccess::Config.puzzle_assist = true
    [[42, 17, 140, "togetic"], [43, 22, 146, "espeon"], [44, 21, 139, "cleffa"], [45, 32, 140, "mismagius"],
     [46, 26, 141, "mismagius"]].each { |id, x, y, s| place(id, x, y, "EV0#{id}", 0, "pkmn_#{s}") }
    $game_variables[661] = 12
    $game_variables[662] = 14
    assert_includes info_key, "{rbrd_tree_hint foes=Espeon, Cleffa, Mismagius x=12 y=14}"
    World.clear_events
    $game_switches[1805] = true
    World.next_frame
    assert_includes info_key, "{rbrd_tree_failed}"
  end

  test "the Arceus hall's statue switches come first with the assist while the statues stand in the way" do
    on_map(840, 110, 74)
    outside = place(59, 106, 73, "EV059")
    inside = place(60, 93, 73, "EV060")
    west = place(73, 80, 73, "EV073")
    $game_variables[588] = 10
    assert_equal "{rbi_gigas_statues}", PokeAccess::Puzzles.piece_name(outside)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbrd_gigas_statues_next}", PokeAccess::Puzzles.piece_name(outside)
    assert_equal "{rbi_gigas_switch}", PokeAccess::Puzzles.piece_name(west)
    assert_includes info_key, "{rbrd_gigas_statues_in}"
    $game_switches[1385] = true
    assert_equal "{rbrd_gigas_statues_next}", PokeAccess::Puzzles.piece_name(inside)
    assert_includes info_key, "{rbrd_gigas_statues_west}"
    $game_switches[1385] = false
    $game_player.x, $game_player.y = 93, 74
    assert_equal "{rbi_gigas_switch_next}", PokeAccess::Puzzles.piece_name(west)
    assert_includes info_key, "{rbi_gigas_hint}"
    $game_variables[588] = 11
    assert_includes info_key, "{rbrd_gigas_statues_east}"
    $game_switches[1385] = true
    refute_includes info_key, "rbrd_gigas_"
  end

  test "the Tauros ledges are listed with the assist, and the hall's hops are read where they stand" do
    on_map(289, 83, 20)
    refute(listed.any? { |r| r[2].to_s.include?("rbrd_tauros") })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [83, 18, "{rbrd_tauros_ledge_east}"]
    assert_includes listed, [55, 25, "{rbrd_tauros_ledge_up}"]
    rows = ["#######", "#.....#", "#.....#", "#.....#", "#..@..#", "#.....#", "#######"]
    with_tile_world(rows) do |world|
      world.map_id = 840
      world.events[69] = jump_tile(69, 3, 3, { 4 => [-2, 0], 6 => [2, 0] })
      nw = PokeAccess::RebornNewWorldJumps
      nw.forget
      assert_equal [2, 3], nw.hop(4, 3, 4)
      assert_equal [4, 3], nw.hop(2, 3, 6)
      assert_nil nw.hop(3, 4, 8)
    end
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrd_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrd_kept_t)
    i18n.send(:remove_method, :rbrd_kept_t)
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
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A hop tile: a touch page that, for each facing, jumps the player by its move route.
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

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
