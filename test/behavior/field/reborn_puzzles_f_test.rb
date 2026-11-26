# Pokemon Reborn's puzzles of part F (games/reborn/puzzles/): the Railnet's train switches, Voclain Estate's mirrors,
# Glitch City's statue, the Citae Astrae towers, Charous Hall's lifts, Byxbysion Cave's reactors, the Meteor grunts of
# Rhodochrine Jungle, Corin-Rouge's decoys, Stalemate's corridor, the desert's shards and the smaller ones. Without the
# assist, what the screen shows; with it, the way.
class RebornPuzzlesFTest < PokeAccessTest
  SWITCHES = [380, 381, 382, 383, 519, 544, 661, 662, 663, 664, 665, 683, 969, 971, 1291, 1294, 1295, 1296, 1297, 1298,
              1299, 1300, 1301, 1302, 1753, 1786]
  VARS = [77, 123, 124, 125, 126, 127, 128, 129, 131, 132, 134, 135, 136, 137, 155, 278, 359, 375, 377, 697]
  NOEL = { 124 => 1, 125 => 2, 127 => 1, 128 => 1, 129 => 2, 131 => 1, 134 => 1, 135 => 0, 136 => 1, 137 => 2 }

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
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the Railnet's levers want what Noel compares, and the assist counts the presses left on each" do
    rail = PokeAccess::RebornRailnet
    wanted = {}
    rail::LEVERS.each { |lv| wanted[lv[1]] = lv[3] if lv[3] }
    assert_equal NOEL, wanted
    on_map(228, 25, 74)
    $game_switches[969] = true
    assert_nil rail.plan
    PokeAccess::Config.puzzle_assist = true
    presses = "{rbf_rail_lever n=1} 1, {rbf_rail_lever n=2} 2, {rbf_rail_lever n=4} 1, {rbf_rail_lever n=5} 1, " \
              "{rbf_rail_lever n=6} 2, {rbf_rail_lever n=7} 1, {rbf_rail_lever n=9} 1, {rbf_rail_lever n=11} 1, " \
              "{rbf_rail_lever n=12} 2"
    list = rail::LEVERS.each_with_index.map { |lv, k| [k + 1, rail.left(lv)] }.select { |_k, n| n && n > 0 }
    assert_equal presses, list.map { |k, n| "{rbf_rail_lever n=#{k}} #{n}" }.join(", ")
    $game_variables[125] = 1
    assert_equal 1, rail.left(rail::LEVERS[1])
    NOEL.each { |v, n| $game_variables[v] = n }
    $game_variables[126] = 1
    assert_equal :rbf_rail_ready, rail.plan
    assert_equal 10, rail.right
    $game_switches[971] = true
    refute_includes info_key, "rbf_rail_"
  end

  test "Voclain's mirrors all share one name, and only the assist tells the right one of each room" do
    on_map(506, 8, 62)
    mirror = place(10, 13, 59, "Glass")
    assert_equal "{rbf_voclain_mirror}", PokeAccess::Puzzles.piece_name(mirror)
    refute_includes info_key, "rbf_voclain_hint1"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbf_voclain_hint1}"
    $game_variables[123] = 20
    refute_includes info_key, "rbf_voclain_hint"
  end

  test "Voclain's second room says its pink hydrangea and the third its column with no reflection, as a sighted player sees" do
    on_map(506, 8, 62)
    frame
    assert_includes frame { $game_player.y = 47 }.join(" "), "{rbf_voclain_room2}"
    assert_includes frame { $game_player.x = 11; $game_player.y = 30 }.join(" "), "{rbf_voclain_no_reflection}"
    $game_variables[123] = 20
    refute_includes frame { $game_player.y = 31 }.join(" "), "rbf_voclain"
  end

  test "Glitch City's statue is named as drawn and the barrier says when it opens" do
    on_map(451, 11, 7)
    statue = place(13, 11, 6, "EV013")
    assert_equal "{rbf_glitch_statue}", PokeAccess::Puzzles.piece_name(statue)
    assert_includes frame { $game_switches[519] = true }.join(" "), "rbf_glitch_gate_open"
  end

  test "the towers' statues go by their species, Emerald's answer is Dark and Sapphire's count needs the assist" do
    on_map(822, 7, 22)
    assert_equal "{rbf_statue name=Bellossom}", PokeAccess::Puzzles.piece_name(place(11, 11, 23, "EV011"))
    on_map(823, 7, 14)
    assert_equal "{rbf_statue name=Umbreon}", PokeAccess::Puzzles.piece_name(place(17, 9, 8, "EV017"))
    refute_includes frame { $game_switches[1295] = true }.join(" "), "rbf_sa_count"
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame { $game_switches[1296] = true }.join(" "), "rbf_sa_count"
  end

  test "Charous Hall's lifts say where each one rests" do
    lifts = PokeAccess::RebornLifts
    on_map(819, 16, 161)
    low = place(21, 20, 87, "ptop1")
    high = place(26, 19, 60, "ptop4")
    assert_equal [:rbf_lift, { :n => 1, :where => "{rbf_lift_down}" }], lifts.label(low)
    assert_equal [:rbf_lift, { :n => 4, :where => "{rbf_lift_up}" }], lifts.label(high)
    low.y = 83
    assert_equal [:rbf_lift, { :n => 1, :where => "{rbf_lift_moving}" }], lifts.label(low)
    assert_empty boarding
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[13, 87, :puzzle_spot], [14, 69, :puzzle_spot], [19, 69, :puzzle_spot], [20, 87, :puzzle_spot]],
                 boarding, "each lower stop is faced from beside it, one step from boarding"
  end

  test "Byxbysion's assist gives the pushes for the first button still off, and the count its reactors" do
    cave = PokeAccess::RebornByxbysion
    on_map(277, 16, 7)
    first = cave.hint
    assert_equal :rbf_byx_plan, first[0]
    assert_equal 2, first[1][:n]
    assert_equal "{rbf_byx_push dir={rbf_dir_down} x=18 y=10}", first[1][:list].split("; ").first
    assert_equal "{rbf_byx_push dir={rbf_dir_right} x=24 y=14}", first[1][:list].split("; ").last
    $game_switches[381] = true
    assert_equal 1, cave.hint[1][:n]
    $game_switches[380] = true
    assert_equal 3, cave.hint[1][:n]
    $game_switches[382] = true
    assert_nil cave.hint
  end

  test "the Meteor grunts say where they face until they catch the player" do
    on_map(150, 117, 101)
    grunt = place(64, 112, 101, "EV064")
    grunt.instance_variable_set(:@direction, 4)
    assert_equal "{rbf_grunt_left}", PokeAccess::Puzzles.piece_name(grunt)
    assert_includes frame { $game_switches[1786] = true }.join(" "), "rbf_stealth_rule"
    $game_variables[77] = 4
    refute_equal "{rbf_grunt_left}", PokeAccess::Puzzles.piece_name(grunt)
  end

  test "Corin-Rouge's suspects are named while hunted, the real one with the assist alone" do
    corin = PokeAccess::RebornCorin
    $game_variables[155] = 10
    assert_equal :rbf_corin_suspect, corin.label(533)
    $game_variables[155] = 13
    assert_nil corin.label(522)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :rbf_corin_real, corin.label(522)
    assert_nil corin.label(533)
  end

  test "Stalemate's loop is said with the assist alone" do
    on_map(893, 95, 85)
    $game_variables[697] = 19
    assert_nil PokeAccess::Puzzles.sent_back_line([95, 85], [95, 37])
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbf_stalemate_loop}", PokeAccess::Puzzles.sent_back_line([95, 85], [95, 37])
    assert_nil PokeAccess::Puzzles.sent_back_line([95, 60], [95, 37])
  end

  test "the Onyx double door, the geysers and the green crystal say what changes" do
    on_map(121, 13, 10)
    frame
    assert_includes frame { $game_variables[278] = 3 }.join(" "), "rbf_onyx_door_open"
    on_map(238, 37, 13)
    geyser = place(25, 37, 12, "noreflectGeyser 1")
    assert_equal "{rbf_geyser_off}", PokeAccess::Puzzles.piece_name(geyser)
    $game_switches[661] = true
    assert_equal "{rbf_geyser_on}", PokeAccess::Puzzles.piece_name(geyser)
    on_map(273, 19, 16)
    frame
    assert_includes frame { $game_switches[544] = true }.join(" "), "rbf_green_crystal_lit"
  end

  test "Chrysolia Spring's assist leads by Surf to the hole down, the boulder dropped first, and on B1F back up" do
    on_map(238, 33, 60)
    place(6, 35, 25, "Boulder", 1, "Object boulder")
    place(7, 36, 25, "EV007", 1)
    refute_includes info_key, "rbn3_spring"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbn3_spring_down}"
    assert_equal [[35, 25], [36, 25]], right_ways
    $game_switches[683] = true
    assert_includes info_key, "{rbn3_spring_hole}"
    assert_equal [[36, 25]], right_ways
    on_map(545, 31, 30)
    place(12, 38, 54, "noreflectReturn Geyser", 1, "geyser")
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbn3_spring_b1}"
    assert_equal [[38, 54]], right_ways
  end

  private

  # The tiles listed as the right way.
  def right_ways
    marks = PokeAccess::Puzzles.category_targets.select { |tg| tg.name.to_s == "{puzzle_right_way}" }
    marks.map { |tg| [tg.x, tg.y] }.sort
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbf_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbf_kept_t)
    i18n.send(:remove_method, :rbf_kept_t)
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
  # The lifts' boarding spots listed, by tile and how they are reached.
  def boarding
    PokeAccess::Puzzles.category_targets.select { |tg| tg.name.to_s.include?("rbf_lift_board") }
                       .map { |tg| [tg.x, tg.y, tg.key] }.sort_by { |x, y, _k| [x, y] }
  end
end
