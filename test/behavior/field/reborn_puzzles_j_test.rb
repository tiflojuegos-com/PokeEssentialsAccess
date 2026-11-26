# Pokemon Reborn's puzzles of part J (games/reborn/puzzles/): the Underroot's invisible Kecleon and green rocks, the
# Larvitar room and the unstable ground of Tanzan Depths, Totodile's pools, the Coral lighthouses, the Water Treatment
# Center's Electrode, Cresselia's quest and Hydreigon's crystals and altar. Without the assist, what the screen shows;
# with it, the way.
class RebornPuzzlesJTest < PokeAccessTest
  SWITCHES = [479, 570, 571, 738, 740, 798, 1791, 1792, 1793, 2226]
  VARS = [159, 186, 332, 562, 658]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $PokemonBag
  end

  def teardown
    $PokemonBag = @bag
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

  test "the Underroot's unseen wall is named as felt, and as the Kecleon it is with the assist, until its battle" do
    kec = PokeAccess::RebornUnderrootKecleon
    on_map(153, 30, 18)
    $game_switches[479] = true
    wall = place(6, 30, 20, "Kecle1")
    assert_equal "{rbj_ur_unseen}", PokeAccess::Puzzles.piece_name(wall)
    hidden = place(115, 63, 53, "EV115")
    $game_variables[332] = 1
    assert PokeAccess::World::Mechanics.piece_of(hidden).assist, "with the assist alone"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbj_ur_unseen_kecleon}", PokeAccess::Puzzles.piece_name(wall)
    assert_equal "{rbj_ur_kecleon_wall}", PokeAccess::Puzzles.piece_name(hidden)
    assert_includes info_key, "{rbj_ur_kecleon_hint}"
    $game_variables[332] = 10
    refute kec.blocked?
    refute kec.wall?(hidden), "the battle of the corridor clears the cave"
    assert kec.fightable?(place(17, 25, 21, "Kecle9"))
    assert_equal "{rbj_ur_treecko}", PokeAccess::Puzzles.piece_name(place(7, 21, 15, "EV007", 0, "pkmn_treecko"))
    $game_self_switches[[153, 7, "A"]] = true
    refute_includes info_key, "rbj_ur_kecleon_hint"
  end

  test "the green rocks light their crystals, and with the assist the way goes rock, crystal and tree in order" do
    gr = PokeAccess::RebornUnderrootGreenRocks
    assert_equal [62, 78, 79], gr::GREEN.keys.sort
    assert_equal (63..77).to_a, gr::CRYSTALS.values.flatten.sort
    on_map(153, 64, 53)
    rock = place(62, 65, 57, "EV062")
    crystal = place(65, 66, 53, "Rock")
    place(80, 70, 49, "Tree", 0, "cuttree wiggle")
    assert_equal "{rbj_ur_green_rock}", PokeAccess::Puzzles.piece_name(rock)
    assert_equal "{rbj_ur_crystal}", PokeAccess::Puzzles.piece_name(crystal)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, "rbj_ur_gr_", "before a Crystal Key no step of the way can be taken"
    bag = Object.new
    def bag.pbQuantity(item); item == :CRYSTALPLUG3 ? 1 : 0; end
    $PokemonBag = bag
    assert_includes info_key, "{rbj_ur_gr_first}"
    assert_includes frame { $game_switches[1791] = true }, "{rbj_ur_crystals_lit}"
    assert_equal "{rbj_ur_crystal_lit}", PokeAccess::Puzzles.piece_name(crystal)
    assert_includes info_key, "{rbj_ur_gr_tree}"
    assert_equal [[66, 53], [70, 49]], right_ways
    steps = [[6, nil, "{rbj_ur_gr_next}"], [6, 1792, "{rbj_ur_gr_tree}"], [10, nil, "{rbj_ur_gr_tree}"],
             [14, nil, "{rbj_ur_gr_next}"], [14, 1793, "{rbj_ur_gr_east}"], [17, nil, "{rbj_ur_gr_egg}"]]
    steps.each do |cuts, sw, hint|
      $game_variables[658] = cuts
      $game_switches[sw] = true if sw
      assert_includes info_key, hint, "with #{cuts} cuts"
    end
    $game_self_switches[[153, gr::EGG, "A"]] = true
    refute_includes info_key, "rbj_ur_gr_"
  end

  test "the Larvitar plan moves in each step's direction onto a sundae, and the assist follows it or says to start over" do
    lv = PokeAccess::RebornTanzanLarvitar
    steps = { :up => [0, -1], :down => [0, 1], :left => [-1, 0], :right => [1, 0] }
    from = lv::START
    lv::PLAN.each do |dir, id, at|
      dx, dy = steps[dir]
      dist = dx.zero? ? (at[1] - from[1]) * dy : (at[0] - from[0]) * dx
      assert dist > 0 && dist <= 20 && (dx.zero? ? at[0] == from[0] : at[1] == from[1]), "#{dir} to #{at.inspect}"
      assert_includes lv::YUMS, id
      from = at
    end
    assert_equal [27, 18], from
    on_map(621, 18, 15)
    larvitar = place(40, 11, 18, "Larvitar", 0, "pkmn_larvitar")
    assert_equal "{rbj_tz_panel_up}", PokeAccess::Puzzles.piece_name(place(42, 18, 14, "EV042"))
    assert_equal 0, lv.step
    assert_equal :rbj_tz_go_up, lv.hint
    larvitar.x, larvitar.y = 11, 12
    [7, 5, 4].each { |id| $game_self_switches[[621, id, "A"]] = true }
    assert_equal 3, lv.step
    assert_equal :rbj_tz_go_right, lv.hint
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbj_tz_go_right}"
    $game_self_switches[[621, 1, "A"]] = true
    assert_nil lv.step, "a sundae off the plan eaten"
    assert_includes info_key, "{rbj_tz_reset}"
  end

  test "the unstable ground says how to bring the ceiling down with the assist, until the floor gives way" do
    tc = PokeAccess::RebornTanzanCollapse
    on_map(614, 30, 16)
    assert_nil tc.rule(614)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :rbj_tz_quake_hint, tc.rule(614)
    assert_equal :rbj_tz_quake_hint, tc.rule(615)
    $game_switches[740] = true
    assert_nil tc.rule(614)
    assert_equal :rbj_tz_quake_hint, tc.rule(615), "each floor gives way on its own"
  end

  test "the hidden Totodile's tile and the Coral dive are listed with the assist alone" do
    on_map(377, 12, 20)
    totodile = place(16, 13, 17, "Toto")
    $game_variables[186] = 1
    refute_includes listed, [13, 17, "{rbj_am_totodile}"]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [13, 17, "{rbj_am_totodile}"]
    $game_switches[2226] = true
    refute PokeAccess::RebornAmetrineTotodile.hiding?, "with Blindstep it is drawn"
    $game_switches[2226] = false
    $game_variables[186] = 2
    assert_nil PokeAccess::RebornAmetrineTotodile.tile
    refute_nil totodile
    on_map(526, 26, 10)
    assert_equal "{rbj_coral_door}", PokeAccess::Puzzles.piece_name(place(54, 26, 5, "EV054"))
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [26, 15, "{rbj_coral_dive}"]
    assert_includes info_key, "{rbj_coral_hint}"
    $game_switches[798] = true
    refute_includes info_key, "rbj_coral_hint"
  end

  test "the Water Treatment Center's item ball is the Electrode with the assist, and the computer wakes with the machines" do
    on_map(477, 10, 10)
    computer = place(5, 10, 7, "EV005")
    ball = place(2, 13, 4, "Item", 0, "itemball")
    assert_equal "{rbj_wtc_computer}", PokeAccess::Puzzles.piece_name(computer)
    $game_self_switches[[477, 2, "A"]] = true
    assert PokeAccess::World::Mechanics.piece_of(ball).assist, "the item ball keeps its look without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbj_wtc_electrode}", PokeAccess::Puzzles.piece_name(ball)
    assert_includes info_key, "{rbj_wtc_hint}"
    $game_switches[570] = true
    assert_equal "{rbj_wtc_computer_on}", PokeAccess::Puzzles.piece_name(computer)
    assert PokeAccess::RebornWtcFennekin.electrode?, "with the machines on, the ball is still the Electrode"
    assert_equal "{rbj_wtc_electrode}", PokeAccess::Puzzles.piece_name(ball)
    $game_switches[571] = true
    refute_includes info_key, "rbj_wtc_hint"
  end

  test "Cresselia's quest marks the next step of each map with the assist, and the doors read locked until theirs" do
    on_map(831, 34, 32)
    door = place(13, 34, 30, "EV013")
    assert_equal "{rbj_cr_locked}", PokeAccess::Puzzles.piece_name(door)
    assert_equal "{rbj_cr_orb}", PokeAccess::Puzzles.piece_name(place(27, 56, 28, "EV027", 0, "energysphere"))
    place(14, 35, 30, "EV014")
    $game_variables[562] = 8
    refute_equal "{rbj_cr_locked}", PokeAccess::Puzzles.piece_name(door), "an open door takes its own name back"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbj_cr_middle}"
    assert_equal [[34, 30], [35, 30]], right_ways
    on_map(832, 13, 38)
    $game_variables[562] = 8
    place(19, 13, 34, "Shii1", 0, "pkmn_shiinotic")
    assert_equal "{rbj_cr_shiinotic}", PokeAccess::Puzzles.piece_name($game_map.events[19])
    assert_equal "{rbj_cr_chess}", PokeAccess::Puzzles.piece_name(place(1, 35, 11, "BP3", 0, "chess1b"))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbj_cr_middle}"
    assert_equal [[13, 34]], right_ways
    $game_variables[562] = 14
    refute_includes info_key, "rbj_cr_"
  end

  test "Hydreigon's purple crystals take Iolia's name and what they take with the assist, and the altar is listed once the ritual is reached" do
    on_map(345, 15, 28)
    crystal = place(1, 15, 26, "EV001")
    assert_equal "{rbb_iolia_purple}", PokeAccess::Puzzles.piece_name(crystal)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rb1_iolia_purple_hint}", PokeAccess::Puzzles.piece_name(crystal)
    on_map(329, 26, 37)
    altar = place(124, 26, 35, "EV124")
    assert_equal false, PokeAccess::World::Mechanics.piece_of(altar).listed.call(altar)
    $game_variables[159] = 18
    assert_equal "{rbj_hy_altar}", PokeAccess::Puzzles.piece_name(altar)
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbj_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbj_kept_t)
    i18n.send(:remove_method, :rbj_kept_t)
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

  # The puzzles category's tiles as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end

  # The tiles listed as the right way.
  def right_ways
    listed.select { |_x, _y, name| name == "{puzzle_right_way}" }.map { |x, y, _name| [x, y] }
  end
end
