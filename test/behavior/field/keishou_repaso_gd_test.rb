# What the review of Keishou's puzzles added (games/keishou/puzzles/): the cracked ice and the boulder sockets of Kazan, the
# dark pads, temporal tiles and twin worlds of Sakyu's ruins, the crossing of the Terastal Caves, the returns of two dreams
# and the altar and barrow of Kiri Forest. Without the assist, what the screen shows; with it, the way. Gamedata pass.
class KeishouRepasoGdTest < PokeAccessTest
  MAPS = [105, 106, 123, 127, 130, 136, 139, 140, 143, 177, 183, 255, 256]
  VARS = [50, 51, 52, 55, 62, 63, 65]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @at = [$game_player.x, $game_player.y]
  end

  def teardown
    World.clear_events
    VARS.each { |i| $game_variables[i] = 0 }
    (151..154).each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the ice before Kazan's north stair names each tile whole or cracked, says its rule by the field and the crack, and why the player fell" do
    on_map(127, 26, 20)
    PokeAccess::Config.verbosity = :full
    ice(14, 26, 19)
    ice(26, 26, 16)
    assert_includes frame, t(:ks_o_ice_rule)
    assert_equal [t(:ks_o_ice_thin), t(:ks_o_ice_thin)], names_at([[26, 16], [26, 19]])
    assert_equal [t(:ks_o_ice_cracks)], frame { $game_self_switches[[127, 14, "A"]] = true }
    assert_equal [t(:ks_o_ice_thin), t(:ks_o_ice_cracked)], names_at([[26, 16], [26, 19]])
    assert_includes info_key, t(:ks_o_ice_rule)
    refute_includes info_key, t(:ks_o_ice_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ks_o_ice_hint)
    on_map(127, 1, 6)
    refute_includes frame, t(:ks_o_ice_rule)
    refute_includes info_key.to_s, t(:ks_o_ice_hint)
    on_map(130, 13, 16)
    assert_equal t(:ks_o_ice_fall), PokeAccess::Puzzles.sent_back_line([26, 19, 127], [13, 16, 130], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([28, 23, 127], [15, 20, 130], :map)
  end

  test "Kazan lists each boulder socket until its sensor has the rock, and counts the golden rocks as they break" do
    on_map(127, 1, 6)
    assert_equal [[13, 19], [33, 10], [34, 41], [38, 15]], goals
    $game_self_switches[[127, 22, "A"]] = true
    assert_equal [[13, 19], [34, 41], [38, 15]], goals
    frame
    assert_equal [progress(:ks_o_gold_rocks, 1, 3)], frame { $game_variables[51] = 1 }
    refute_includes info_key.to_s, t(:ks_o_gold_rocks)
    on_map(123, 1, 1)
    assert_equal [[12, 41], [13, 21], [32, 42]], goals
  end

  test "Kuukan names its dark pads and silver plate, says where the game puts a rock, and the assist carries each rock through its pad" do
    on_map(136, 7, 9)
    rock1 = boulder(1, 23, 6)
    boulder(2, 9, 19)
    silent(28, 7, 13)
    assert_equal [t(:ks_o_dark_pad), t(:ks_o_silver_plate), t(:ks_o_dark_pad)], names_at([[5, 21], [7, 13], [19, 7]])
    frame { rock1.x = 19; rock1.y = 7 }
    assert_includes frame { rock1.x = 9; rock1.y = 13 }, t(:ks_o_rock_warped, :x => 9, :y => 13)
    PokeAccess::Config.puzzle_assist = true
    refute_includes info_key, t(:ks_o_kuukan_plate_hint)
    rock1.x = 23; rock1.y = 6
    assert_includes info_key, t(:ks_o_kuukan_plate_hint)
    $game_self_switches[[136, 20, "A"]] = true
    assert_includes info_key, t(:ks_o_kuukan_pad_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:ks_o_kuukan_pad_hint)
  end

  test "the temporal tiles of Jikan and the temple are named and say why they send the player back, and a rock thrown over the ledge is told" do
    on_map(139, 9, 16)
    tile = touch(4, 9, 17)
    assert_equal [t(:ks_o_temporal_tile)], names_at([[9, 17]])
    frame
    fire(tile)
    assert_equal t(:ks_o_temporal_back), PokeAccess::Puzzles.sent_back_line([9, 17, 139], [9, 16, 139])
    rock = boulder(1, 5, 14)
    frame
    assert_includes frame { rock.x = 7 }, t(:ks_o_rock_jumped, :x => 7, :y => 14)
    on_map(143, 16, 12)
    tile = touch(19, 15, 12)
    frame
    fire(tile)
    assert_equal t(:ks_o_temporal_back), PokeAccess::Puzzles.sent_back_line([15, 12, 143], [16, 12, 143])
    assert_nil PokeAccess::Puzzles.sent_back_line([15, 12, 143], [19, 12, 143])
  end

  test "Hankoshi and the temple say which world the player stands in and the crossing, and the temple lists its four sockets" do
    on_map(140, 14, 17)
    touch(5, 14, 16)
    assert_equal [t(:ks_o_distortion_tile)], names_at([[14, 16]])
    assert_includes info_key, t(:ks_o_world_normal)
    assert_equal t(:ks_o_world_to_distortion), PokeAccess::Puzzles.sent_back_line([14, 16, 140], [44, 16, 140])
    assert_equal t(:ks_o_world_to_normal), PokeAccess::Puzzles.sent_back_line([44, 16, 140], [14, 16, 140])
    $game_player.x = 44
    assert_includes info_key, t(:ks_o_world_distortion)
    on_map(143, 18, 29)
    assert_equal t(:ks_o_world_to_distortion), PokeAccess::Puzzles.sent_back_line([18, 29, 143], [58, 29, 143])
    assert_equal [[30, 7], [30, 29], [46, 7], [46, 29]],
                 listed.select { |_x, _y, n| n == t(:ks_ruin_socket) }.map { |x, y, _n| [x, y] }
  end

  test "the crossing of the Terastal Caves names its four sockets, watches the crystals and says them on the way into a cave" do
    on_map(255, 11, 12)
    [[4, 11, 11], [5, 11, 28], [10, 28, 28], [11, 29, 11]].each { |id, x, y| silent(id, x, y) }
    assert_equal [t(:ks_o_crystal_socket)] * 4, names_at([[11, 11], [11, 28], [28, 28], [29, 11]])
    frame
    refute_empty frame { $game_switches[151] = true }.select { |l| l.include?(t(:ks_o_crystal_damp)) }
    now = t(:ks_o_crystal_now, :set => t(:ks_o_crystal_damp))
    on_map(256, 31, 50)
    $game_switches[151] = true
    assert_equal now, PokeAccess::Puzzles.sent_back_line([32, 11, 255], [31, 50, 256], :map)
    on_map(255, 32, 11)
    $game_switches[151] = true
    assert_equal now, PokeAccess::Puzzles.sent_back_line([31, 50, 256], [32, 11, 255], :map)
  end

  test "the water dream says why its orbs send the player back, the grass dream why its exit does, and Kiri names its altar and barrow" do
    on_map(106, 25, 61)
    orb = touch(14, 32, 54)
    frame
    fire(orb)
    assert_equal t(:ks_o_orb_back), PokeAccess::Puzzles.sent_back_line([32, 53, 106], [25, 61, 106])
    on_map(105, 8, 40)
    way_out = touch(7, 9, 40)
    frame
    fire(way_out)
    assert_equal t(:ks_o_dream_exit_back), PokeAccess::Puzzles.sent_back_line([9, 40, 105], [8, 40, 105])
    on_map(183, 32, 13)
    silent(32, 32, 12)
    assert_equal [t(:ks_o_altar)], names_at([[32, 12]])
    on_map(177, 11, 47)
    silent(22, 11, 46)
    assert_equal [t(:ks_o_barrow)], names_at([[11, 46]])
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

  # Puts the player on (x, y) of map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map, x, y)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    VARS.each { |i| $game_variables[i] = 0 }
    (151..154).each { |i| $game_switches[i] = false }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # Puts an event on the map and lets a frame pass.
  def put(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # An event with no graphic and a page that says something, as the game's sockets and plates are.
  def silent(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page]))
  end

  # A floor event with no graphic fired by stepping on it, its page a script, as the temporal tiles and exits are.
  def touch(id, x, y)
    page = TestPage.new(:trigger => 1, :through => true, :list => [TestCmd.new(355, ["pbSEPlay('Up')"]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page]))
  end

  # A tile of cracked ice as Kazan draws it: a tile on a touch page walked through, which sets its own self switch.
  def ice(id, x, y)
    page = TestPage.new(:trigger => 1, :through => true, :list => [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Cracked ice", :tile_id => 1577, :pages => [page]))
  end

  # A Strength boulder.
  def boulder(id, x, y)
    page = TestPage.new(:trigger => 1, :sprite => "Object boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "StrengthBoulder", :pages => [page]))
  end

  # Fires an event as the player's use of it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # A count as the mod says it.
  def progress(label, n, of); t(:puzzle_progress, :label => t(label), :n => n, :of => of); end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

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

  # The names the puzzles category gives the tiles, in the order asked.
  def names_at(tiles)
    rows = listed
    tiles.map { |x, y| (rows.find { |rx, ry, _n| rx == x && ry == y } || [])[2] }
  end

  # The tiles listed as a boulder's goal, sorted.
  def goals
    listed.select { |_x, _y, n| n == t(:ks_o_boulder_goal) }.map { |x, y, _n| [x, y] }
  end
end
