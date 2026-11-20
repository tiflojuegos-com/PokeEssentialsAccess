# Keishou's optional puzzles (games/keishou/puzzles/): the dragon leaps of the Road of Ascension, the Yama Passage boulder, the
# Haiiro and Creation sockets, the four seals of Miraijima, the Cavern of Order, the Nightmare, the three Bonding Dreams, the
# temple challenges and the crystal sockets of the Ancient Terastal Caves. What a sighted player sees is named and counted
# with no help; what only the events know (the right colour, the order, the targets) comes with the puzzle assist.
# Gamedata pass.
class KeishouOptPuzzlesGdTest < PokeAccessTest
  MAPS = [87, 105, 104, 106, 113, 145, 151, 153, 159, 161, 179, 206, 219, 252, 254, 265, 273, 274, 275]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    [74, 83, 119, 150, 153].each { |i| $game_variables[i] = 0 }
    [73, 74, 76, 77, 107, 134].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the four dragon leaps of the Road of Ascension are named while a dragon answers, and say how far they go with the assist" do
    on_map(179)
    [[9, 28, 39], [10, 28, 28], [19, 28, 12], [20, 28, 2]].each { |id, x, y| silent(id, x, y) }
    assert_equal [], listed
    $game_switches[73] = true
    assert_equal [[28, 28, t(:ks_o_jump)], [28, 39, t(:ks_o_jump)]], listed
    $game_switches[76] = true
    assert_equal 4, listed.size
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[28, 2, t(:ks_o_jump_down, :n => 10)], [28, 12, t(:ks_o_jump_up, :n => 10)],
                  [28, 28, t(:ks_o_jump_down, :n => 11)], [28, 39, t(:ks_o_jump_up, :n => 11)]], listed
  end

  test "Yama Passage names the tile the boulder is to rest on, leaves what opens to the core, and the hint comes with the assist" do
    on_map(113)
    silent(2, 3, 23)
    assert_includes listed, [16, 32, t(:ks_o_boulder_goal)]
    frame
    assert_equal [], frame
    assert_equal [], frame { $game_self_switches[[113, 2, "A"]] = true }
    refute_includes listed, [16, 32, t(:ks_o_boulder_goal)]
    assert_nil PokeAccess::Puzzles.info_line
    on_map(113)
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert PokeAccess::Puzzles.active?
    assert_equal t(:ks_o_yama_hint), hint_text
  end

  test "the Haiiro socket is named, and says what it asks for only with the assist, until Kyurem has taken the ring" do
    on_map(206)
    silent(1, 14, 11)
    assert_equal [[14, 11, t(:ks_o_kyurem_socket)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[14, 11, t(:ks_o_kyurem_socket_asks)]], listed
    $game_self_switches[[206, 1, "C"]] = true
    assert_equal [], listed
  end

  test "the Creation sockets are named, and the count of right colours comes only with the assist" do
    on_map(87)
    (16..20).each { |id| silent(id, 10 + id, 30) }
    assert_equal 5, listed.size
    assert(listed.all? { |_x, _y, name| name == t(:ks_o_minior_socket) })
    frame
    assert_equal [], frame { $game_variables[74] = 2 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:ks_o_minior_set, 3, 5)], frame { $game_variables[74] = 3 }
  end

  test "each seal button says its species with the assist, the count of seals in too, and what falls back when the order breaks" do
    on_map(159)
    silent(33, 49, 2)
    assert_equal [[49, 2, t(:ks_o_seal)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[49, 2, t(:ks_o_seal_1)]], listed
    frame
    assert_equal [progress(:ks_o_seals_in, 1, 4)], frame { $game_variables[119] = 1 }
    assert_equal [PokeAccess.sentences([t(:ks_o_seals_out), progress(:ks_o_seals_in, 0, 4)])], frame { $game_variables[119] = 0 }
    assert_equal t(:ks_o_seals_hint), hint_text
    assert PokeAccess::Puzzles.active?
    $game_variables[119] = 4
    refute PokeAccess::Puzzles.active?
    on_map(153)
    silent(48, 39, 13)
    assert_equal [[39, 13, t(:ks_o_seal_riddle)]], listed
    $game_variables[119] = 4
    assert_equal [], listed
    on_map(151)
    silent(27, 22, 8)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[22, 8, t(:ks_o_seal_4)]], listed
    $game_self_switches[[151, 27, "A"]] = true
    assert_equal [], listed
  end

  test "the Cavern of Order names its tiles and its cube sockets, and the hint stops once Zygarde is summoned" do
    on_map(219)
    (1..3).each { |id| silent(id, 22 + id, 48) }
    (5..7).each { |id| silent(id, 18 + id, 35) }
    silent(19, 24, 53)
    silent(21, 24, 24)
    names = listed.map { |_x, _y, name| name }
    assert_equal 3, names.count(t(:ks_o_order_pair_tile))
    assert_equal 3, names.count(t(:ks_o_order_letter_tile))
    assert_includes names, t(:ks_o_cube_pickup)
    assert_includes names, t(:ks_o_cube_socket)
    refute_includes names, t(:ks_o_order_pair_tile_asks)
    PokeAccess::Config.puzzle_assist = true
    assert_equal 3, listed.map { |_x, _y, name| name }.count(t(:ks_o_order_pair_tile_asks))
    assert_includes listed.map { |_x, _y, name| name }, t(:ks_o_cube_socket_cells)
    assert PokeAccess::Puzzles.active?
    $game_switches[134] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the statues of the Nightmare are named while unseen, their count and the target only with the assist" do
    on_map(274)
    [[10, 60, 12], [11, 8, 39], [12, 93, 51]].each { |id, x, y| silent(id, x, y) }
    assert_equal [[8, 39, t(:ks_o_statue)], [60, 12, t(:ks_o_statue)], [93, 51, t(:ks_o_statue)]], listed
    frame
    assert_equal [], frame { $game_variables[153] = 1 }
    $game_self_switches[[274, 11, "A"]] = true
    assert_equal [[60, 12, t(:ks_o_statue)], [93, 51, t(:ks_o_statue)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [progress(:ks_o_statues_seen, 2, 3)], frame { $game_variables[153] = 2 }
    assert_equal t(:ks_o_nightmare_hint), hint_text
  end

  test "the grassy dream names its pads while the game has them working and its plates while unpressed, and counts the plates" do
    on_map(105)
    [1, 9, 10].each_with_index { |id, i| silent(id, 5 + i, 40) }
    silent(23, 11, 23)
    silent(24, 38, 23)
    names = listed.map { |_x, _y, name| name }
    assert_equal 0, names.count(t(:ks_o_launch_pad))
    assert_equal 2, names.count(t(:ks_o_floor_plate))
    $game_switches[107] = true
    assert_equal 3, listed.map { |_x, _y, name| name }.count(t(:ks_o_launch_pad))
    frame
    assert_equal [progress(:ks_o_plates_down, 1, 4)], frame { $game_variables[83] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert PokeAccess::Puzzles.active?
    $game_self_switches[[105, 3, "A"]] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the fire and water dreams say when the sensor opens the way, and where the target is only with the assist" do
    on_map(104)
    silent(10, 14, 19)
    assert_includes listed, [18, 23, t(:ks_o_boulder_goal)]
    frame
    assert_equal [], frame { $game_self_switches[[104, 10, "A"]] = true }
    on_map(104)
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ks_o_fire_hint), hint_text
    on_map(106)
    silent(13, 10, 25)
    silent(30, 21, 50)
    assert_equal [[10, 26, t(:ks_o_orb_goal)], [21, 50, t(:ks_o_escort_orb)]], listed
    frame
    assert_equal [t(:ks_o_water_open)], frame { $game_self_switches[[106, 13, "A"]] = true }
  end

  test "Yuki's plates are named while unpressed and counted, and the Netsu hint comes with the assist" do
    on_map(275)
    [[13, 15, 20], [14, 26, 20]].each { |id, x, y| silent(id, x, y) }
    assert_equal 2, listed.size
    frame
    assert_equal [progress(:ks_o_plates_pressed, 1, 4)], frame { $game_variables[150] = 1 }
    $game_self_switches[[275, 13, "A"]] = true
    assert_equal [[26, 20, t(:ks_o_pressure_plate)]], listed
    on_map(273)
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ks_o_fire_course_hint), hint_text
  end

  test "Yukino's final challenge says its rule as it starts, names deflectors and switch while it runs, and keeps the hint for the assist" do
    on_map(275)
    silent(42, 31, 52)
    silent(43, 29, 51)
    silent(46, 29, 42)
    silent(47, 29, 39)
    silent(50, 45, 42)
    silent(77, 43, 53)
    silent(76, 37, 56)
    assert_equal [], listed
    frame
    assert_equal [t(:ks_o_ice_final_rule)], frame { $game_self_switches[[275, 33, "A"]] = true }
    expected = lambda do
      { [29, 39] => :right, [29, 42] => :right, [29, 51] => :up, [31, 52] => :left, [43, 53] => :right, [45, 42] => :left }
    end
    check = lambda do |changes|
      want = expected.call.merge(changes)
      got = {}
      listed.each { |x, y, n| got[[x, y]] = n }
      want.each { |at, dir| assert_equal t("ks_o_ice_deflector_#{dir}".to_sym), got[at], "deflector at #{at.inspect}" }
      assert_equal t(:ks_o_ice_switch), got[[37, 56]]
      assert_equal want.size + 1, got.size
    end
    check.call({})
    $game_self_switches[[275, 46, "B"]] = true
    check.call([29, 42] => :left)
    $game_self_switches[[275, 50, "B"]] = true
    check.call([29, 42] => :left, [45, 42] => :right)
    $game_self_switches[[275, 47, "A"]] = true
    check.call([29, 42] => :left, [45, 42] => :right, [29, 39] => :left)
    $game_self_switches[[275, 46, "A"]] = true
    got = listed.map { |x, y, _n| [x, y] }
    refute_includes got, [29, 42]
    assert_includes got, [29, 39]
    PokeAccess::Config.puzzle_assist = true
    assert_includes hints, t(:ks_o_ice_final_hint)
    $game_self_switches[[275, 33, "B"]] = true
    assert_equal [], listed
  end

  test "the crystal sockets of the caves are named and each crystal says whether it is set" do
    [252, 265].each do |cave|
      on_map(cave)
      silent(5, 31, 50)
      assert_equal [[31, 50, t(:ks_o_crystal_socket)]], listed
    end
    frame
    assert_equal ["#{t(:ks_o_crystal_icy)}: #{t(:ks_o_crystal_set)}"],
                 frame { $game_switches[153] = true }
    $game_switches[153] = false
  end

  test "a crystal that moves the player to another cave says which crystals are set on arriving, as does coming in from the crossing, and a move from elsewhere says nothing" do
    on_map(254)
    $game_switches[151] = true
    $game_switches[153] = true
    set = "#{t(:ks_o_crystal_damp)}, #{t(:ks_o_crystal_icy)}"
    assert_equal t(:ks_o_crystal_shift, :set => set), PokeAccess::Puzzles.sent_back_line([31, 51, 252], [31, 51, 254], :map)
    $game_switches[151] = false
    $game_switches[153] = false
    assert_equal t(:ks_o_crystal_shift, :set => t(:ks_o_crystal_none)),
                 PokeAccess::Puzzles.sent_back_line([31, 51, 265], [31, 51, 254], :map)
    assert_equal t(:ks_o_crystal_now, :set => t(:ks_o_crystal_none)),
                 PokeAccess::Puzzles.sent_back_line([11, 35, 255], [31, 51, 254], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([11, 35, 199], [31, 51, 254], :map)
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("keishou")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    [74, 83, 119, 150, 153].each { |i| $game_variables[i] = 0 }
    [73, 74, 76, 77, 107, 134, 151, 152, 153, 154].each { |i| $game_switches[i] = false }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map: no graphic, a page that says something, as the game's controls are.
  def silent(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A count as the mod says it.
  def progress(label, n, of); t(:puzzle_progress, :label => t(label), :n => n, :of => of); end

  # The hints of every puzzle of the map.
  def hints
    mechanics.instances.map { |inst| PokeAccess::Puzzles.label_of(inst.spec[:hint]) }
  end

  # The hint of the puzzle on the map, as the assist says it.
  def hint_text
    PokeAccess::Puzzles.label_of(mechanics.instances.first.spec[:hint])
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name as the locator says it], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
