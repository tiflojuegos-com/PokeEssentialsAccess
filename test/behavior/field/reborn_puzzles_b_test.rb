# Pokemon Reborn's puzzles of part B (games/reborn/puzzles/): 7th Street's trash can, the Subseven Sanctum, Iolia Valley,
# Route 2's Crustles, Calcenon Gym, Blake's apartment, Glitch City, the Water Treatment Center, Devon Corp, the Scrapyard's
# trains, Once Upon a Somewhere, Tower Corybantia, Fiore Gym and the Glass Workstation's channels. Without the assist, what
# the screen shows; with it, the way.
class RebornPuzzlesBTest < PokeAccessTest
  SWITCHES = [432, 528, 428, 429, 430, 431, 2034, 443, 439, 446, 452, 453, 454, 463, 464, 469, 470, 471, 472, 493, 507,
              508, 509, 510, 511, 512, 513, 514, 515, 519, 746, 747, 748, 749, 830, 831, 833, 834, 874, 878, 907, 910,
              941, 943, 946, 953, 957, 964, 748, 761, 762, 764, 753, 754, 755, 756, 410]
  VARS = [159, 162, 165, 166, 167, 168, 169, 170, 171, 188, 256, 257, 258, 259, 260, 261, 262, 263, 264, 276, 342, 363,
          365, 366, 368, 369, 371, 372, 373, 374, 380, 381, 391, 396, 398, 399, 400, 469]

  # A Crystal Key bag: holds the keys it is given.
  class KeyBag
    def initialize; @held = {}; end
    def give(n); @held = { "CRYSTALPLUG#{n}".to_sym => 1 }; end
    def pbQuantity(item); @held[item].to_i; end
  end

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
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $PokemonBag = @bag
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "7th Street's trash can is named as a sighted player sees it, and with the assist as the switch it hides" do
    on_map(324, 30, 10)
    can = place(51, 30, 9, "EV051")
    assert_equal "{rbb_7th_trash}", PokeAccess::Puzzles.piece_name(can)
    refute_includes info_key, "rbb_7th_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbb_7th_trash_switch}", PokeAccess::Puzzles.piece_name(can)
    assert_includes info_key, "{rbb_7th_hint}"
    $game_switches[2034] = true
    refute_includes info_key, "rbb_7th_hint"
  end

  test "the Sanctum's guards say where they face, and the assist says now as the first wait opens" do
    on_map(330, 46, 19)
    $game_switches[432] = true
    guard = place(17, 41, 18, "Trainer(5)")
    guard.direction = 6
    assert_equal "{rbb_s7_guard dir=#{PokeAccess::Puzzles.face_name(6)}}", PokeAccess::Puzzles.piece_name(guard)
    PokeAccess::Config.puzzle_assist = true
    frame
    guard.direction = 8
    assert_includes frame, "{rbb_s7_now}"
    guard.direction = 6
    frame
    PokeAccess::Config.puzzle_assist = false
    guard.direction = 8
    refute_includes frame, "{rbb_s7_now}"
    $game_switches[528] = true
    assert_nil PokeAccess::RebornSanctum.guard(guard)
  end

  test "the Sanctum's statues go by their colour, and the books name their statue with the assist alone" do
    on_map(332, 15, 5)
    blue = place(5, 17, 7, "EV005")
    assert_equal "{rbb_s7_book}", PokeAccess::Puzzles.piece_name(blue)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbb_s7_book_blue}", PokeAccess::Puzzles.piece_name(blue)
    on_map(329, 25, 44)
    $game_variables[159] = 14
    green = place(23, 19, 47, "EV023")
    assert_equal "{rbb_s7_statue_green}", PokeAccess::Puzzles.piece_name(green)
    $game_switches[428] = true
    $game_switches[431] = true
    assert_includes info_key, "{rbb_s7_arcs}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbb_s7_scripture_hint}"
    $game_variables[159] = 16
    refute_includes info_key, "rbb_s7_scripture_hint"
  end

  test "Iolia Valley's steps follow one another from the first crystal to the gym's cave" do
    iolia = PokeAccess::RebornIolia
    $PokemonBag = KeyBag.new
    $PokemonBag.give(1)
    on_map(336, 16, 10)
    seen = []
    40.times do
      st = iolia.step
      break unless st
      seen.push(iolia::STEPS.index(st))
      apply_iolia(st)
      $game_map.map_id = 333 if seen.length == 2
    end
    assert_nil iolia.step
    assert_equal seen.sort, seen
    assert_equal seen.uniq, seen
    assert_equal 3, $game_variables[171]
    assert_equal :rbb_iolia_red_spent, iolia.crystal_label(335, 7)
    assert_equal [:rbb_iolia_rule, { :colors => "{rbb_iolia_colors4}" }], iolia.rule(335)
  end

  test "Iolia Valley's next step is said with the assist alone" do
    $PokemonBag = KeyBag.new
    $PokemonBag.give(1)
    on_map(334, 11, 9)
    refute_includes info_key, "rbb_iolia_s01"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbb_iolia_s01}"
    crystal = place(4, 11, 8, "EV004")
    assert_equal "{rbb_iolia_red}", PokeAccess::Puzzles.piece_name(crystal)
  end

  test "Route 2's Crustle plans end on their holes after the pushes counted" do
    r2 = PokeAccess::RebornRoute2
    ends = { 137 => [[44, 91], 14], 123 => [[25, 91], 15], 198 => [[35, 91], 51], 2 => [[54, 42], 17] }
    r2::PLANS.each do |plan|
      t = r2.table(plan)
      pos = plan[2]
      pushes = 0
      while (s = t[pos]) && pushes < 100
        assert_equal ends[plan[0]][1] - pushes, s[3]
        pos = r2.after(plan, pos, s[2])
        pushes += 1
      end
      assert_equal ends[plan[0]], [pos, pushes]
    end
  end

  test "a route to Crustle 198 ends on the level its next push is made from" do
    r2 = PokeAccess::RebornRoute2
    on_map(360, 47, 68)
    crustle = place(198, 46, 67, "Crustle5")
    $game_switches[471] = true
    $game_switches[472] = true
    $game_self_switches[[360, 198, "B"]] = true
    assert_equal [:rbb_r2_push, { :x => 47, :y => 67, :dir => "{dir_o}", :left => 51 }], r2.step_for(r2.current)
    assert_equal true, r2.push_floor(46, 67), "the first pushes, from below"
    assert_nil r2.push_floor(45, 67), "no Crustle there"
    crustle.x, crustle.y = 39, 78
    assert_equal false, r2.push_floor(39, 78), "from the ninth on, from above"
    $game_self_switches[[360, 198, "B"]] = false
    assert_nil r2.push_floor(39, 78), "awake, it is not pushed"
  end

  test "Route 2's assist goes powder, nest, sleep and push, and names the next push as one is made" do
    r2 = PokeAccess::RebornRoute2
    on_map(360, 43, 80)
    crustle = place(137, 45, 75, "Crustle6")
    plan = r2::PLANS[0]
    assert_equal [:rbb_r2_get_powder, { :x => 43, :y => 82 }], r2.step_for(plan)
    $game_switches[464] = true
    assert_equal [:rbb_r2_use_nest, { :x => 45, :y => 76 }], r2.step_for(plan)
    crustle.x, crustle.y = 45, 77
    assert_equal :rbb_r2_sleep_it, r2.step_for(plan)
    $game_self_switches[[360, 137, "B"]] = true
    assert_equal [:rbb_r2_push, { :x => 46, :y => 77, :dir => "{dir_o}", :left => 14 }], r2.step_for(plan)
    $game_player.x, $game_player.y = 46, 77
    $game_player.direction = 4
    assert_equal [:rbb_r2_then, { :x => 45, :y => 77, :dir => "{dir_o}", :left => 13 }], r2.then_line(crustle)
    $game_player.direction = 2
    assert_nil r2.then_line(crustle)
  end

  test "Route 2 lists an open hole as a spot on its tile, and a filled one by its Crustle" do
    on_map(360, 40, 80)
    hole = place(74, 35, 92, "EV074 invert_always_on_top")
    assert_equal [[35, 92]], hole_spots
    $game_switches[470] = true
    PokeAccess::World::Mechanics.forget
    assert_equal [], hole_spots
    assert_equal "{rbb_r2_hole_filled}", PokeAccess::Puzzles.piece_name(hole)
  end

  test "Calcenon's orders cover each stretch once, and the assist marks the next tile" do
    gym = PokeAccess::RebornCalcenon
    gym::STRETCHES.each_with_index do |s, i|
      cells = gym.cells(i)
      assert_equal s[:total], cells.length
      assert_equal cells.uniq, cells
    end
    on_map(419, 9, 55)
    gym::STRETCHES[0][:tiles].each_with_index { |id, k| place(id, gym.cells(0)[k][0], gym.cells(0)[k][1], "EV#{id}") }
    assert_equal 11, gym.next_id(0)
    $game_self_switches[[419, 11, "A"]] = true
    $game_variables[188] = 1
    $game_player.x, $game_player.y = 9, 54
    assert_equal gym::STRETCHES[0][:tiles][1], gym.next_id(0)
    assert_equal :rbb_calc_hint, gym.hint(0)
    $game_player.x, $game_player.y = 7, 50
    assert_equal :rbb_calc_off_plan, gym.hint(0)
  end

  test "Blake's apartment says what is carried, and the assist the next piece of furniture" do
    blake = PokeAccess::RebornBlake
    on_map(457, 22, 10)
    $game_switches[507] = true
    assert_equal :rbb_blake_h_console, blake.hint
    $game_switches[512] = true
    $game_switches[514] = true
    assert_equal [:rbb_blake_held, { :list => "{rbb_blake_disc}, {rbb_blake_head}" }], blake.held_line
    assert_equal :rbb_blake_h_key, blake.hint
    [515, 513, 511].each { |s| $game_switches[s] = true }
    assert_equal :rbb_blake_h_plug, blake.hint
    $game_switches[510] = true
    $game_switches[509] = true
    assert_equal :rbb_blake_h_monitor, blake.hint
    assert_nil blake.held_line
    refute_includes info_key, "rbb_blake_h_monitor"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbb_blake_h_monitor}"
  end

  test "Glitch City's hideout and mansion give their way with the assist alone" do
    on_map(448, 27, 3)
    refute_includes info_key, "rbb_glitch_hideout_hint"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbb_glitch_hideout_hint}"
    on_map(451, 6, 2)
    assert_equal 1, PokeAccess::World::Mechanics.instances.length, "one mechanic tells the mansion"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbb_glitch_mansion_switch_hint}"
    refute_includes info_key, "rbb_glitch_mansion_exit_hint"
    $game_switches[519] = true
    assert_includes info_key, "{rbb_glitch_mansion_exit_hint}"
  end

  test "the Water Treatment Center tells each room's water, and while cleaning the districts left" do
    wtc = PokeAccess::RebornWTC
    on_map(486, 10, 10)
    $game_variables[276] = 23
    wtc::VARS.each_value { |v| $game_variables[v] = 3 }
    $game_variables[261] = 2
    assert_equal [:rbb_wtc_water, { :level => "{rbb_wtc_level2}" }], wtc.water_line
    assert_equal [:rbb_wtc_clean_lower, { :name => "{rbb_wtc_coral}", :left => "{rbb_wtc_coral}" }], wtc.hint
    $game_variables[261] = 3
    assert_equal :rbb_wtc_h24, wtc.hint
    $game_variables[276] = 11
    assert_equal :rbb_wtc_h11, wtc.hint
  end

  test "Devon's spinners carry the player round as their page moves them, and the shock floors go by their page" do
    devon = PokeAccess::RebornDevon
    route = TestCmd.new(209, [-1, TestMoveRoute.new([TestMoveCmd.new(5), TestMoveCmd.new(2), TestMoveCmd.new(44)])])
    page = TestPage.new(:trigger => 1, :list => [route, TestCmd.new(122, [343, 343, 0, 0, 2]), TestCmd.new(0, [])])
    edge = TestGameEvent.new(:id => 50, :x => 8, :y => 5, :pages => [page], :active_page => page)
    on_map(630, 8, 4)
    assert_equal [:carry, -2, 1, false, nil, nil], devon.spinner_carry(edge)
    on_map(628, 8, 4)
    assert_nil devon.spinner_carry(edge)
    shock = TestPage.new(:trigger => 1, :list => [TestCmd.new(355, ["pbFieldDamage"]), TestCmd.new(0, [])])
    panel = TestGameEvent.new(:id => 8, :name => "Buzzy", :pages => [shock], :active_page => shock)
    assert devon.shocks?(panel)
    on_map(630, 24, 23)
    assert_equal :rbb_devon630_a, devon.hint
    [747, 749].each { |s| $game_switches[s] = true }
    assert_equal :rbb_devon630_c, devon.hint
    $game_switches[749] = false
    $game_switches[746] = true
    assert_equal :rb1_devon630_off, devon.hint, "the belt at 23, 23 runs up while 746 is on"
    [748, 749].each { |s| $game_switches[s] = true }
    assert_equal "{rbb_devon630_d}. {rb1_devon_spin_back}", devon.hint
    on_map(629, 5, 27)
    assert_equal "{rbb_devon629_a}. {rb1_devon_spin_back}", devon.hint
    [753, 755, 754, 756].each { |s| $game_switches[s] = true }
    assert_equal :rbb_devon629_e, devon.hint
    on_map(631, 9, 26)
    [764, 762, 761].each { |s| $game_switches[s] = true }
    assert_equal :rb1_devon631_off, devon.step_key, "the belt at 29, 24 pushes into the computer while 761 is on"
    $game_switches[761] = false
    assert_equal :rbb_devon631_c, devon.step_key
  end

  test "the Scrapyard's assist walks the engines in order, by the part of the yard the player is in" do
    sy = PokeAccess::RebornScrapyard
    on_map(663, 60, 70)
    assert_equal :rbb_sy_rock3, sy.yard_hint
    $game_switches[833] = true
    assert_equal :rbb_sy_ride3, sy.yard_hint
    $game_variables[365] = 1
    $game_switches[831] = true
    $game_variables[366] = 1
    $game_variables[363] = 1
    $game_switches[834] = true
    assert_equal :rbb_sy_go_east, sy.yard_hint
    $game_player.x, $game_player.y = 100, 70
    assert_equal :rbb_sy_ride7, sy.yard_hint
    on_map(692, 33, 27)
    assert_equal :rbb_sy_ride_small1, sy.line_hint
  end

  test "Once Upon a Somewhere counts the wraps left with the assist, and the bridge as it comes in sight" do
    some = PokeAccess::RebornSomewhere
    on_map(696, 31, 23)
    $game_variables[380] = 1
    assert_equal [:rbb_some_hint, { :n => 2 }], some.hint
    $game_variables[380] = 3
    refute some.bridge_in_sight?
    $game_player.x, $game_player.y = 50, 30
    assert some.bridge_in_sight?
    assert_equal :rbb_some_hint_bridge, some.hint
  end

  test "Tower Corybantia names its books read, and the assist counts those left" do
    cory = PokeAccess::RebornCorybantia
    on_map(699, 6, 9)
    book = place(1, 6, 8, "EV001")
    assert_equal "{rbb_cory_book}", PokeAccess::Puzzles.piece_name(book)
    $game_self_switches[[699, 1, "A"]] = true
    assert_equal "{rbb_cory_book_read}", PokeAccess::Puzzles.piece_name(book)
    assert_equal [:rbb_cory_hint_books, { :n => 3 }], cory.hint
    [2, 3, 4].each { |id| $game_self_switches[[699, id, "A"]] = true }
    assert_equal :rbb_cory_hint_stairs, cory.hint
    $game_variables[381] = 8
    assert_equal :rbb_cory_hint_exit, cory.hint
  end

  test "Fiore Gym's goal follows the story and its way, and the next leg is said with the assist alone" do
    f = PokeAccess::RebornFiore
    on_map(678, 14, 25)
    $game_variables[381] = 14
    assert_equal :arena, f.goal
    $game_variables[381] = 15
    assert_equal :z1, f.goal
    $game_switches[878] = true
    assert_equal :r1, f.goal
    $game_variables[381] = 18
    assert_nil f.goal
    $game_switches[878] = false
    $game_variables[381] = 14
    assert_equal 0, f.region
    assert_nil f.next_line
    PokeAccess::Config.puzzle_assist = true
    line = f.next_line
    assert_equal :rbb_fiore_next, line[0]
    assert_equal "{rbb_fiore_step_dive n=#{f.step[1] + 1}}", line[1][:step]
    assert_operator line[1][:n], :>, 1
  end

  test "the Glass Workstation's channels freeze in order with Glaceon, then the catwalks by the elevator" do
    glass = PokeAccess::RebornGlassPaths
    on_map(732, 58, 28)
    $game_variables[391] = 20
    assert_equal :rbb_glass_hint_fetch, glass.hint
    $game_switches[946] = true
    assert_equal :rbb_glass_hint_channel1, glass.hint
    [396, 398, 399, 400].each { |v| $game_variables[v] = 60 }
    assert_equal :rbb_glass_hint_door, glass.hint
    $game_variables[391] = 23
    assert_nil glass.hint
    $game_switches[957] = true
    assert_equal :rbb_glass_hint_elevator, glass.hint
    $game_switches[964] = true
    assert_equal :rbb_glass_hint_rail1, glass.hint
    assert_equal :rbb_glass_rail_molten, glass.rail_label(941)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :rbb_glass_rail_next, glass.rail_label(941)
  end

  private

  # Does what an Iolia step asks: wakes its crystal, smashes its wall or picks its key.
  def apply_iolia(st)
    iolia = PokeAccess::RebornIolia
    map = st[1]
    id = st[2]
    keys = { [335, 157] => 2, [335, 158] => 3, [343, 3] => 4 }
    purple = { 343 => 453, 344 => 454, 347 => 452 }
    if keys[[map, id]]
      $PokemonBag.give(keys[[map, id]])
    elsif (iolia::RED[map] || {})[id]
      $game_variables[iolia::RED[map][id]] = 2
    elsif (iolia::WALLS[map] || {})[id]
      $game_variables[iolia::WALLS[map][id]] = 3
    elsif (iolia::GREEN[map] || {})[id]
      $game_switches[iolia::GREEN[map][id]] = true
    elsif (iolia::BLUE[map] || {})[id]
      $game_switches[iolia::BLUE[map][id]] = true
    elsif purple[map]
      $game_switches[purple[map]] = !$game_switches[purple[map]]
    end
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbb_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbb_kept_t)
    i18n.send(:remove_method, :rbb_kept_t)
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

  # The tiles of the holes the locator lists as spots, from its puzzle targets.
  def hole_spots
    locator = PokeAccess::Locator
    locator.instance_variable_set(:@cat_id, :puzzles)
    locator.rebuild_targets
    spots = locator.instance_variable_get(:@targets).select do |t|
      t.is_a?(PokeAccess::Locator::SurfaceTarget) && t.key == :puzzle_spot && t.name.to_s.include?("rbb_r2_hole")
    end
    spots.map { |t| [t.x, t.y] }
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
end
