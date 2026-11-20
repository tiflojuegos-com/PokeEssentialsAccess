# Fire Ash's and Dark Horizon's optional puzzles: the Kubfu rocks, Lumiose's five doors, Mauville's lasers, Shadow Lab's floor of
# hidden tiles, Shadow HQ's laser and Gateon Port's bridges, over events shaped like the games'. Gamedata pass.
class FaDhOptPuzzlesGdTest < PokeAccessTest
  FA_MAPS = [222, 833, 877, 398]
  DH_MAPS = [99, 110, 138]
  TILE_AT = { 62 => [68, 16], 65 => [69, 16], 67 => [69, 15], 68 => [69, 14], 69 => [69, 13], 70 => [70, 13] }

  class FakeBag
    def initialize(items); @items = items; end

    def has?(item); @items.include?(item); end
  end

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $bag
  end

  def teardown
    World.clear_events
    [43, 44, 115, 146, 171, 181, 182, 184, 185, 253].each { |i| $game_switches[i] = false }
    $game_variables[28] = 0
    $game_self_switches = @selfs
    $bag = @bag
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Config.verbosity = :full
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the Kubfu's two rocks are named for the form they give and a walk keeps off them" do
    on_map(222)
    put(11, 28, 48, :trigger => 1, :list => [TestCmd.new(355, ["pbEvolvePokemonEvent(:KUBFU,0)"]), TestCmd.new(0, [])])
    put(12, 32, 48, :trigger => 1, :list => [TestCmd.new(355, ["pbEvolvePokemonEvent(:KUBFU,1)"]), TestCmd.new(0, [])])
    assert_equal [[28, 48, t(:fa_o_rock_single)], [32, 48, t(:fa_o_rock_rapid)]], listed
    keep_off = PokeAccess::Routes::Controls.keep_off
    assert keep_off[PokeAccess::Routes.pkey(28, 48)], "a walk keeps off the Single Strike rock"
    assert keep_off[PokeAccess::Routes.pkey(32, 48)], "a walk keeps off the Rapid Strike rock"
    refute keep_off[PokeAccess::Routes.pkey(30, 48)]
  end

  test "Lumiose numbers its five doors, says which kind of room a door gives and, with the assist, the right one" do
    on_map(833)
    { 4 => [15, [3, 20]], 5 => [19, [23, 27]], 6 => [23, [46, 20]], 7 => [27, [13, 5]], 8 => [31, [35, 5]] }.each do |id, (x, to)|
      pad(id, x, 41, 833, to)
    end
    names = (1..5).map { |n| t(:fa_o_clemont_door, :n => n) }
    assert_equal names, listed.map { |_x, _y, n| n }
    assert_equal [t(:fa_o_clemont_rule)], frame
    frame
    fire(@events[6])
    assert_equal t(:fa_o_clemont_trainer), PokeAccess::Puzzles.sent_back_line([23, 41, 833], [46, 20, 833])
    fire(@events[5])
    assert_equal t(:fa_o_clemont_leader), PokeAccess::Puzzles.sent_back_line([19, 41, 833], [23, 27, 833])
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed.map { |_x, _y, n| n }, t(:puzzle_right_way)
    assert_includes info_key, t(:fa_o_clemont_hint)
    $game_switches[253] = true
    mechanics.forget
    assert_equal [], frame
    refute_includes info_key, t(:fa_o_clemont_hint)
    fire(@events[6])
    assert_nil PokeAccess::Puzzles.sent_back_line([23, 41, 833], [46, 20, 833])
    fire(@events[5])
    assert_nil PokeAccess::Puzzles.sent_back_line([19, 41, 833], [23, 27, 833])
  end

  test "Team Flare's copy of the gym has empty rooms and its door 5 leads to Xerosic and the Prism Tower" do
    on_map(877)
    { 4 => [15, [3, 20]], 5 => [19, [23, 27]], 6 => [23, [46, 20]], 7 => [27, [13, 5]], 8 => [31, [35, 5]] }.each do |id, (x, to)|
      pad(id, x, 41, 877, to)
    end
    names = (1..5).map { |n| t(:fa_o_clemont_door, :n => n) }
    assert_equal names, listed.map { |_x, _y, n| n }
    assert_equal [t(:fa_o_flare_rule)], frame
    frame
    fire(@events[6])
    assert_equal t(:fa_o_flare_empty), PokeAccess::Puzzles.sent_back_line([23, 41, 877], [46, 20, 877])
    fire(@events[5])
    assert_equal t(:fa_o_flare_stairs), PokeAccess::Puzzles.sent_back_line([19, 41, 877], [23, 27, 877])
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed.map { |_x, _y, n| n }, t(:puzzle_right_way)
    assert_includes info_key, t(:fa_o_flare_hint)
    $game_self_switches[[877, 1, "A"]] = true
    mechanics.forget
    assert_equal [], frame
    refute_includes info_key, t(:fa_o_flare_hint)
  end

  test "Mauville's lasers are listed while a switch draws them, each row says when it goes off and the hint names the trainers" do
    on_map(398)
    $game_switches[43] = true
    $game_switches[44] = true
    mechanics.forget
    [7, 10].each { |id| put(id, id == 7 ? 9 : 6, 10) }
    [11, 16].each { |id| put(id, id == 11 ? 9 : 6, 9) }
    assert_equal 4, listed.length
    assert_equal [t(:fa_o_wattson_rule)], frame
    said = frame { $game_switches[43] = false }
    assert_includes said.join(" "), t(:fa_o_row_open)
    said = frame { $game_switches[44] = false }
    assert_includes said.join(" "), t(:fa_o_row_open)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [], frame
    refute_includes info_key, t(:fa_o_wattson_hint)
    $game_switches[44] = true
    mechanics.forget
    assert_includes info_key, t(:fa_o_wattson_hint)
  end

  test "Mauville's rule and hint say the rows stay when Wattson was beaten before they were drawn" do
    on_map(398)
    $game_switches[115] = true
    $game_switches[43] = true
    mechanics.forget
    assert_equal [t(:fa_o_wattson_late_rule)], frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:fa_o_wattson_late_hint)
    refute_includes info_key, t(:fa_o_wattson_hint)
    $game_switches[43] = false
    mechanics.forget
    assert_equal [], frame
  end

  test "Shadow Lab's tile floor counts the tiles, says why a repeat sent the player back and, with the assist, the next step" do
    on_map(99)
    put(66, 67, 16)
    put(61, 72, 11)
    cells = TILE_AT.merge(real_tiles)
    cells.each { |id, (x, y)| put(id, x, y) }
    names = listed.map { |_x, _y, n| n }
    assert_includes names, t(:dh_o_tiles_start_name)
    assert_includes names, t(:dh_o_laser)
    assert_equal 53, PokeAccess::DHTileFloor::TILES.length
    $game_player.x = 67
    $game_player.y = 15
    assert_equal [t(:dh_o_tiles_rule)], frame
    said = frame { $game_variables[28] = 3 }
    assert_includes said.join(" "), t(:dh_o_tiles_count)
    assert_nil PokeAccess::Puzzles.sent_back_line([70, 16, 99], [67, 15, 99])
    assert_equal [], frame { $game_player.x = 66 }
    assert_equal [], frame { $game_player.x = 67 }
    assert_equal [], frame { $game_player.x = 77 }
    PokeAccess::Config.puzzle_assist = true
    $game_player.x = 67
    $game_player.y = 16
    assert_equal t(:dh_o_tiles_next, :dir => t(:dh_o_dir_right), :left => 53), PokeAccess::DHTileFloor.hint
    assert_includes info_key, t(:dh_o_tiles_next, :dir => t(:dh_o_dir_right), :left => 53)
    [62, 65, 67].each { |id| $game_self_switches[[99, id, "A"]] = true }
    $game_player.x = 69
    $game_player.y = 15
    assert_equal t(:dh_o_tiles_next, :dir => t(:dh_o_dir_up), :left => 50), PokeAccess::DHTileFloor.hint
    $game_player.x = 60
    $game_player.y = 3
    assert_equal t(:dh_o_tiles_off), PokeAccess::DHTileFloor.hint
  end

  test "the tile floor says which sides have a lit tile without the assist and that any way back to zero starts the walk over" do
    on_map(99)
    put(66, 67, 16)
    TILE_AT.each { |id, (x, y)| put(id, x, y) }
    $game_player.x = 67
    $game_player.y = 16
    assert_includes info_key, t(:dh_o_tiles_near_none)
    $game_self_switches[[99, 62, "A"]] = true
    $game_self_switches[[99, 67, "A"]] = true
    $game_player.x = 69
    $game_player.y = 16
    assert_includes info_key, t(:dh_o_tiles_near, :dirs => [t(:dh_o_dir_up), t(:dh_o_dir_left)].join(", "))
    $game_player.x = 60
    $game_player.y = 3
    refute_includes info_key.to_s, t(:dh_o_tiles_near_none)
    $game_player.x = 69
    $game_player.y = 16
    frame { $game_variables[28] = 3 }
    said = frame { $game_variables[28] = 0 }
    assert_includes said.join(" "), t(:dh_o_tiles_reset)
    assert_includes said.join(" "), t(:dh_o_tiles_count)
  end

  test "a repeated tile says its way back once, with the count at zero in the same line" do
    on_map(99)
    put(66, 67, 16)
    TILE_AT.each { |id, (x, y)| put(id, x, y) }
    $game_player.x = 69
    $game_player.y = 16
    frame { $game_variables[28] = 3 }
    $game_player.x = 67
    $game_player.y = 15
    said = frame { $game_variables[28] = 0 }
    assert_equal 1, said.length, said.inspect
    assert_includes said.first, t(:dh_o_tiles_back)
    assert_includes said.first, t(:dh_o_tiles_count)
    refute_includes said.join(" "), t(:dh_o_tiles_reset)
  end

  test "the tile floor's solver finds a walk over all 53 tiles, and says so when a lit tile cut one off" do
    on_map(99)
    put(66, 67, 16)
    real_tiles.merge(TILE_AT).each { |id, (x, y)| put(id, x, y) }
    steps = PokeAccess::DHTileFloor.route([67, 16], PokeAccess::DHTileFloor.dark)
    assert_equal 53, steps.length
    assert_equal 53, steps.uniq.length
    $game_self_switches[[99, 70, "A"]] = true
    $game_player.x = 70
    $game_player.y = 13
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:dh_o_tiles_stuck), PokeAccess::DHTileFloor.hint
  end

  test "Shadow HQ's laser has a named panel and wall, a rule for the room and, with the assist, where the card comes from" do
    on_map(110)
    put(43, 57, 10)
    (25..31).each { |id| put(id, 56, 9 + id - 25) }
    names = listed.map { |_x, _y, n| n }
    assert_includes names, t(:dh_o_nucleus_panel)
    assert_includes names, t(:dh_o_laser_wall)
    $game_player.x = 50
    $game_player.y = 12
    assert_equal [t(:dh_o_nucleus_rule)], frame
    assert_equal [], frame { $game_player.x = 65 }
    assert_equal [], frame { $game_player.x = 64 }
    assert_equal [t(:dh_o_nucleus_panel)], listed.select { |_x, _y, n| n == t(:dh_o_nucleus_panel) }.map { |_x, _y, n| n }
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed.map { |_x, _y, n| n }, t(:dh_o_nucleus_panel_card)
    $bag = FakeBag.new([])
    assert_includes info_key, t(:dh_o_nucleus_from)
    refute_includes info_key, t(:dh_o_nucleus_have)
    $bag = FakeBag.new([:KEY_HQ_NUCLEUS])
    assert_includes info_key, t(:dh_o_nucleus_have)
    refute_includes info_key, t(:dh_o_nucleus_from)
    $game_switches[171] = true
    mechanics.forget
    assert_equal [], listed.select { |_x, _y, n| n == t(:dh_o_laser_wall) }
  end

  test "Gateon Port names its levers and sensors by bridge and says each bridge's position as it turns" do
    on_map(138)
    { 164 => [34, 30], 165 => [32, 9], 169 => [21, 29] }.each { |id, (x, y)| put(id, x, y) }
    { 166 => [20, 29], 167 => [18, 9] }.each { |id, (x, y)| put(id, x, y) }
    put(71, 34, 19)
    put(72, 22, 19)
    names = listed.map { |_x, _y, n| n }
    assert_equal 3, names.select { |n| n == t(:dh_o_lever_one) }.length
    assert_equal 2, names.select { |n| n == t(:dh_o_lever_two) }.length
    assert_includes names, t(:dh_o_sensor_one)
    assert_includes names, t(:dh_o_sensor_two)
    frame
    assert_includes frame { $game_switches[181] = true }.join(" "), t(:dh_o_bridge_one_horizontal)
    assert_includes frame { $game_switches[181] = false; $game_switches[182] = true }.join(" "), t(:dh_o_bridge_one_vertical)
    assert_includes frame { $game_switches[184] = true }.join(" "), t(:dh_o_bridge_two_north)
    assert_includes frame { $game_switches[184] = false; $game_switches[185] = true }.join(" "), t(:dh_o_bridge_two_south)
    refute_includes info_key, t(:dh_o_bridges_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:dh_o_bridges_hint)
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # The 53 tiles' places but the first six, as {id => [x, y]}.
  def real_tiles
    coords = "70,14 70,15 70,16 70,17 69,17 69,18 70,18 70,19 70,20 71,20 71,19 71,18 72,18 72,17 72,19 72,20 73,20 73,19 73,18 " \
             "73,17 74,17 74,18 75,18 75,19 75,20 74,20 76,19 76,18 76,17 76,16 76,15 75,15 75,16 75,17 74,16 73,16 73,15 74,15 " \
             "74,14 74,13 73,13 73,14 72,14 71,14 71,13 72,13 72,12".split.map { |p| p.split(",").map { |v| v.to_i } }
    ids = (71..113).to_a + (115..118).to_a
    all = {}
    ids.each_with_index { |id, i| all[id] = coords[i] }
    all
  end

  # Declares both profiles' puzzles on their maps, loading each once per process.
  def declare_puzzles
    self.class.declared ||= begin
      kept = []
      [["fireash", FA_MAPS], ["darkhorizon", DH_MAPS]].each do |profile, maps|
        Harness.load_puzzles(profile)
        all = mechanics.instance_variable_get(:@defs)
        maps.each { |map| kept << [map, all[map]] }
      end
      kept
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
    $game_variables[28] = 0
    $game_map.map_id = map
    $game_map.instance_variable_set(:@events, {})
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map: one page with the trigger, sprite and commands of opts.
  def put(id, x, y, opts = {})
    pages = [TestPage.new(:trigger => opts.fetch(:trigger, 1), :sprite => opts.fetch(:sprite, ""),
                          :list => opts.fetch(:list, [TestCmd.new(355, ["script"]), TestCmd.new(0, [])]))]
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => 0, :pages => pages)
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # A touch event that only transfers to the tile to of a map.
  def pad(id, x, y, map, to)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(201, [0, map, to[0], to[1], 8, 0]), TestCmd.new(0, [])])
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
