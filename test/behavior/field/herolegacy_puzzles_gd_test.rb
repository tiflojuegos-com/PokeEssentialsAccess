# Hero Legacy's puzzles (games/herolegacy/puzzles/): the three ice chambers of Mt. Aoraki and its entrance from Paiata, the
# candles of Nepia's crypt, Johannes's dolls, the maze of Route 12, the ruins of Mawera, Martin's farm, the fossil
# scouting, Kopiranga's school and quest 36's gravestones. Without the assist, what the screen shows; with it, the way.
# Gamedata pass.
class HerolegacyPuzzlesGdTest < PokeAccessTest
  MAPS = [4, 98, 121, 127, 137, 228, 208, 256, 300, 306, 319, 321, 335, 336, 344, 358, 360, 361, 362, 363, 364, 418]
  SWITCHES = [125, 128, 144, 145, 146, 147, 148] + (151..167).to_a
  VARS = (45..51).to_a + [58, 63, 64, 67] + (68..72).to_a + (92..95).to_a

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
    reset_flags
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "chamber 1 names each cracked tile by its step, and the assist lists the next tile of the walk, then the drop" do
    on_map(360)
    tile(18, 34, 23)
    tile(19, 33, 23)
    tile(117, 16, 24)
    block(6, 30, 22)
    assert_equal t(:hl_ice_cracked), PokeAccess::Puzzles.piece_name(@events[18])
    assert_equal [[30, 22, t(:hl_ice_block)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[30, 22, t(:hl_ice_block)], [34, 23, t(:hl_ice_next)]], listed
    step_on(18)
    assert_equal t(:hl_ice_broken), PokeAccess::Puzzles.piece_name(@events[18])
    assert_equal [[30, 22, t(:hl_ice_block)], [33, 23, t(:hl_ice_next)]], listed
    until chamber::GOAL.include?(chamber.next_tile)
      step_on(chamber.next_tile)
    end
    assert_equal (18..116).to_a, (18..116).select { |id| chamber.stepped?(id) }
    assert_equal [[16, 24, t(:hl_ice_drop, :name => frigometri)], [30, 22, t(:hl_ice_block)]], listed
    assert_includes info_key, t(:hl_ice_hint, :name => frigometri)
    $game_switches[144] = true
    assert_equal [[30, 22, t(:hl_ice_block)]], listed
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:hl_ice_rule)
  end

  test "chamber 1 searches a new walk when a step leaves it, and says with the assist when none is left" do
    on_map(360)
    { 22 => [29, 27], 25 => [30, 27], 33 => [28, 26], 34 => [28, 27] }.each { |id, (x, y)| tile(id, x, y) }
    PokeAccess::Config.puzzle_assist = true
    frame
    [18, 19, 20, 21, 22].each { |id| step_on(id) }
    assert_equal 23, chamber.next_tile
    assert_equal [], frame { step_on(34) }
    assert_includes listed, [28, 26, t(:hl_ice_next)]
    on_map(360)
    { 22 => [29, 27], 25 => [30, 27] }.each { |id, (x, y)| tile(id, x, y) }
    PokeAccess::Config.puzzle_assist = true
    [18, 19, 20, 21, 22].each { |id| step_on(id) }
    frame
    assert_equal [t(:hl_ice_stuck)], frame { step_on(25) }
    assert_nil chamber.next_tile
    assert_includes info_key, t(:hl_ice_stuck)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:hl_ice_stuck)
  end

  test "the free camera names chamber 1's cracked tiles by their step, and with the assist the drop behind the last block" do
    on_map(360)
    tile(18, 34, 23)
    tile(117, 16, 24)
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y) }
    assert_equal [[t(:hl_ice_cracked)], [t(:hl_ice_cracked)], []], [lines[34, 23], lines[16, 24], lines[35, 23]]
    step_on(18)
    assert_equal [t(:hl_ice_broken)], lines[34, 23]
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:hl_ice_drop, :name => frigometri)], lines[16, 24]
    $game_self_switches[[360, 117, "A"]] = true
    assert_equal [t(:hl_ice_drop_once, :name => frigometri)], lines[16, 24]
    assert_equal [t(:hl_ice_broken)], lines[34, 23]
    $game_map.map_id = 361
    assert_equal [], lines[34, 23]
  end

  test "the free camera names the switch tiles of the way in and of chambers 2 and 3, drawn with the caves' tile 439" do
    data = $game_map.data
    drawn = Object.new
    class << drawn
      def [](x, y, z); [x, y, z] == [21, 17, 1] ? 439 : 0; end
    end
    $game_map.instance_variable_set(:@data, drawn)
    [358, 361, 362].each do |map|
      on_map(map)
      assert_equal [[t(:hl_switch_tile)], []], [PokeAccess::Camera.tile_lines(21, 17), PokeAccess::Camera.tile_lines(21, 18)]
    end
    on_map(360)
    assert_equal [], PokeAccess::Camera.tile_lines(21, 17), "a map with no boulder"
  ensure
    $game_map.instance_variable_set(:@data, data)
    PokeAccess::Caches.reset_all
  end

  test "chamber 1 says why the player fell, unless the fall lands beside Frigometri" do
    on_map(363)
    assert_equal t(:hl_ice_fell), PokeAccess::Puzzles.sent_back_line([34, 23, 360], [34, 23, 363], :map)
    assert_equal t(:hl_ice_fell), PokeAccess::Puzzles.sent_back_line([16, 15, 360], [16, 16, 363], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([16, 24, 360], [15, 24, 363], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([36, 20, 360], [36, 21, 363], :map)
  end

  test "chamber 2 gives with the assist each boulder's hole in turn, and below which boulders are still missing" do
    on_map(361)
    put(4, 13, 7, "StrengthBoulder 1", 1, "Object boulder")
    refute_includes info_key.to_s, t(:hl_boulder)
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:hl_q2_hole, :x => 13, :y => 7, :gx => 14, :gy => 7)
    [162, 163, 165].each { |sw| $game_switches[sw] = true }
    assert_includes info_key, t(:hl_q2_crack, :x => 27, :y => 12, :gx => 24, :gy => 12)
    $game_switches[167] = true
    assert_includes info_key, t(:hl_q2_far, :x => 22, :y => 23, :gx => 15, :gy => 17)
    on_map(364)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:hl_q2_below_missing, :name => frigometri)
    [162, 163, 164, 166].each { |sw| $game_switches[sw] = true }
    assert_includes info_key, t(:hl_q2_below_ready, :name => frigometri)
  end

  test "chamber 3 and the entrance give with the assist the boulder to move and its tile, one after another" do
    on_map(362)
    put(3, 21, 19, "StrengthBoulder 1", 1, "Object boulder")
    refute_includes info_key.to_s, t(:hl_boulder)
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:hl_boulder_to, :x => 21, :y => 19, :gx => 21, :gy => 17)
    [151, 155, 156, 157].each { |sw| $game_switches[sw] = true }
    assert_includes info_key, t(:hl_boulder_to, :x => 8, :y => 10, :gx => 13, :gy => 13)
    on_map(358)
    put(30, 10, 54, "StrengthBoulder", 1, "Object boulder")
    refute_includes info_key.to_s, t(:hl_boulder)
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:hl_boulder_to, :x => 10, :y => 54, :gx => 12, :gy => 54)
    $game_self_switches[[358, 1, "A"]] = true
    assert_includes info_key, t(:hl_boulder_to, :x => 7, :y => 49, :gx => 5, :gy => 49)
  end

  test "Nepia's candles say which candle of a row burns blue, and the assist the steps each plate still needs" do
    on_map(256)
    frame
    assert_equal [t(:puzzle_value, :label => t(:hl_nepia_row, :n => 1), :v => 2)], frame { $game_variables[45] = 2 }
    assert_equal [t(:puzzle_value, :label => t(:hl_nepia_row, :n => 2), :v => t(:hl_nepia_none))],
                 frame { $game_variables[46] = 5 }
    assert_includes info_key, t(:hl_nepia_rule_plain)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:hl_nepia_over_ziva, :name => species(:CHANDELURE))
    $game_self_switches[[256, 1, "A"]] = true
    assert_includes info_key, t(:hl_nepia_over, :name => species(:CHANDELURE))
    assert_includes info_key, t(:hl_nepia_rule, :name => species(:CHANDELURE))
    $game_variables[46] = 3
    rows = [[1, 5], [3, 5], [4, 4], [5, 4], [6, 4], [7, 4]].map { |n, steps| t(:hl_nepia_row_steps, :n => n, :steps => steps) }
    assert_includes info_key, t(:hl_nepia_hint, :rows => rows.join("; "))
  end

  test "Johannes's dolls are counted out of their total with the assist alone, while his test runs" do
    on_map(321)
    $game_variables[63] = 1
    frame
    assert_equal [], frame { $game_variables[64] = 1 }
    PokeAccess::Config.puzzle_assist = true
    frame
    said = frame { $game_variables[64] = 4 }
    assert_includes said, t(:puzzle_progress, :label => t(:hl_banette_count), :n => 4, :of => 11)
  end

  test "Johannes's dolls are given with the assist one after another, with the pushes each needs first" do
    on_map(321)
    order = PokeAccess::HeroLegacyDolls::ORDER
    order.each { |id, (x, y), _p| put(id, x, y, "EV%03d" % id, 0, "Object_Puppe") }
    $game_variables[63] = 1
    first, second = order[0], order[1]
    refute_includes listed, [first[1][0], first[1][1], t(:hl_banette_next_doll)]
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [first[1][0], first[1][1], t(:hl_banette_next_doll)]
    { 46 => [31, 9], 42 => [29, 7] }.each { |id, (x, y)| put(id, x, y, "StrengthBoulder", 1, "Object boulder") }
    left, down = t(:dir_left), t(:dir_down)
    push = lambda { |x, y, dir| t(:hl_banette_push, :x => x, :y => y, :dir => dir) }
    from_42 = [push.call(29, 7, left), push.call(28, 7, left)] + (7..10).map { |y| push.call(27, y, down) }
    from_46 = [push.call(31, 9, left), push.call(30, 9, left)]
    assert_includes info_key, t(:hl_banette_pushes, :steps => (from_46 + from_42).join("; "), :x => 29, :y => 10)
    @events[46].x = 29
    refute_includes info_key, push.call(31, 9, left)
    assert_includes info_key, t(:hl_banette_pushes, :steps => from_42.join("; "), :x => 29, :y => 10)
    @events[42].x, @events[42].y = 27, 11
    assert_includes info_key, t(:hl_banette_next, :x => 29, :y => 10)
    @events[46].y = 8
    assert_includes info_key, t(:hl_banette_offplan)
    @events[46].y = 9
    $game_self_switches[[321, first[0], "A"]] = true
    assert_includes listed, [second[1][0], second[1][1], t(:hl_banette_next_doll)]
    refute_includes listed, [first[1][0], first[1][1], t(:hl_banette_next_doll)]
  end

  test "the maze's real item and decoys, the farm's pens and the fossil traces are named with the assist where nothing shows them" do
    on_map(127)
    ball(25, 17, 43)
    ball(59, 25, 48)
    assert_nil PokeAccess::Puzzles.piece_name(@events[25])
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:hl_maze_real), PokeAccess::Puzzles.piece_name(@events[25])
    assert_equal t(:hl_maze_decoy), PokeAccess::Puzzles.piece_name(@events[59])
    $game_switches[128] = true
    assert_nil PokeAccess::Puzzles.piece_name(@events[25])
    on_map(418)
    put(14, 15, 12, "EV014", 0)
    assert_equal t(:hl_farm_pen, :name => species(:SKIDDO)), PokeAccess::Puzzles.piece_name(@events[14])
    on_map(98)
    put(1, 42, 16, "Fossil-Check", 1)
    assert_nil PokeAccess::Puzzles.piece_name(@events[1])
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:hl_fossil_spot), PokeAccess::Puzzles.piece_name(@events[1])
    assert_equal [[42, 16, t(:hl_fossil_spot)]], listed
    $game_self_switches[[98, 1, "A"]] = true
    assert_empty listed
    $game_self_switches[[98, 1, "A"]] = false
    $game_variables[92] = 3
    assert_empty listed
    on_map(4)
    put(7, 44, 22, "EV007", 1)
    assert_nil PokeAccess::Puzzles.piece_name(@events[7])
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:hl_deoxys_spot, :name => species(:RAYQUAZA)), PokeAccess::Puzzles.piece_name(@events[7])
  end

  test "the tiles before Pata Wai's appliances go by the appliance, which a sighted player sees" do
    on_map(228)
    put(7, 21, 9, "EV007", 1)
    put(16, 23, 9, "EV016", 1)
    assert_equal [[21, 9, t(:hl_rotom_frost)], [23, 9, t(:hl_rotom_mow)]], listed
  end

  test "Mawera's statues go by the guardian they show" do
    on_map(335)
    put(1, 24, 19, "EV001 size(3,2)", 0, "statue_regice")
    assert_equal t(:hl_statue, :name => species(:REGICE)), PokeAccess::Puzzles.piece_name(@events[1])
  end

  test "the school's exhibits go by number, and the assist lists those left to read, then who gives the prize" do
    on_map(300)
    [[6, 40, 13], [8, 42, 13], [4, 46, 14], [3, 41, 16], [2, 42, 16], [5, 46, 17]].each do |id, x, y|
      put(id, x, y, "EV%03d" % id, 0, "Item001")
    end
    put(25, 41, 12, "EV025", 0, "NPC 130")
    assert_equal t(:hl_school_item, :n => 1), PokeAccess::Puzzles.piece_name(@events[6])
    assert_equal t(:hl_school_item, :n => 6), PokeAccess::Puzzles.piece_name(@events[5])
    assert_empty listed
    assert_equal [], frame { $game_variables[58] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal 6, listed.length
    frame
    said = frame do
      $game_self_switches[[300, 6, "A"]] = true
      $game_variables[58] = 2
    end
    assert_includes said, t(:puzzle_progress, :label => t(:hl_school_count), :n => 2, :of => 6)
    refute_includes listed, [40, 13, t(:hl_school_item, :n => 1)]
    [8, 4, 3, 2, 5].each { |id| $game_self_switches[[300, id, "A"]] = true }
    $game_variables[58] = 6
    assert_equal [[41, 12, t(:hl_school_prize)]], listed
    assert_includes info_key, t(:hl_school_hint, :x => 41, :y => 12)
    $game_self_switches[[300, 25, "A"]] = true
    assert_empty listed
  end

  test "the gravestones go by what they are, and the assist says after the epitaph the item each takes and the others left" do
    renamed = { 121 => "Taipuia", 137 => "Paiata", 306 => "Route 16" }
    before = {}
    renamed.each_key { |map| before[map] = PokeAccess::MapNames.get(map) }
    begin
      renamed.each { |map, name| PokeAccess::MapNames.set(map, name) }
      on_map(137)
      put(41, 51, 27, "EV041 size(2,1)", 0)
      assert_equal t(:hl_gravestone), PokeAccess::Puzzles.piece_name(@events[41])
      assert_empty listed
      PokeAccess::Config.puzzle_assist = true
      assert_nil epitaph(41)
      $game_variables[67] = 4
      assert_equal [[51, 27, t(:hl_gravestone)]], listed
      item = PokeAccess::Data.item_name(:ICESTONE).to_s
      assert_equal t(:hl_grave_item_others, :item => item, :places => "Taipuia, Route 16"), epitaph(41)
      $game_self_switches[[121, 101, "A"]] = true
      $game_self_switches[[306, 47, "A"]] = true
      assert_equal t(:hl_grave_item, :item => item), epitaph(41)
      PokeAccess::Config.puzzle_assist = false
      assert_nil epitaph(41)
      $game_self_switches[[137, 41, "A"]] = true
      assert_empty listed
      on_map(306)
      put(47, 16, 52, "EV047 size(2,1)", 0)
      $game_variables[67] = 4
      PokeAccess::Config.puzzle_assist = true
      assert_equal t(:hl_grave_item_others, :item => PokeAccess::Data.item_name(:IRONBALL).to_s,
                                            :places => "Taipuia, Paiata"), epitaph(47)
    ensure
      before.each { |map, name| name ? PokeAccess::MapNames.set(map, name) : PokeAccess::MapNames.delete(map) }
    end
  end

  private

  # What the assist says right after a gravestone's third Show Text, the epitaph's last line.
  def epitaph(id)
    PokeAccess::Puzzles::Reach.forget
    PokeAccess.take_tail
    int = Object.new
    list = (0..3).map { |n| TestCmd.new(101, ["Line #{n}"]) }
    { :@list => list, :@index => 2, :@event_id => id, :@branch => {} }.each { |k, v| int.instance_variable_set(k, v) }
    PokeAccess::Puzzles::Reach.before_text(int)
    PokeAccess.take_tail
  end

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def chamber; PokeAccess::HeroLegacyIceChamber; end

  # A step onto a cracked tile of chamber 1, as the game counts it: its self switch, its zone's variable, and the
  # zone's block broken once the count is full.
  def step_on(id)
    zone = chamber::ZONES[chamber.zone_of(id)]
    $game_self_switches[[360, id, "A"]] = true
    $game_variables[zone[2]] += 1
    $game_self_switches[[360, zone[3], "A"]] = true if $game_variables[zone[2]] == zone[4]
    ev = @events[id]
    $game_player.x, $game_player.y = ev.x, ev.y if ev
  end

  def frigometri; species(:CRYOGONAL); end

  def species(id); PokeAccess::Data.species_name(id).to_s; end

  def reset_flags
    SWITCHES.each { |i| $game_switches[i] = false }
    VARS.each { |i| $game_variables[i] = 0 }
  end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("herolegacy")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the flags clear, the assist off and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    reset_flags
    $game_map.map_id = map
    @events = {}
    [:@sig, :@stepped, :@plan].each { |v| chamber.instance_variable_set(v, nil) }
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event of the given name on the map, its one page of the given trigger saying something.
  def put(id, x, y, name, trigger, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # A cracked ice tile: a silent touch page that counts its step in variable 68.
  def tile(id, x, y)
    page = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(122, [68, 68, 1, 0, 1]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Cracked ice", :tile_id => 472, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # An ice block whose parallel page waits for variable 68 to reach 4.
  def block(id, x, y)
    list = [TestCmd.new(111, [1, 68, 0, 4, 0]), TestCmd.new(123, ["A", 0], 1), TestCmd.new(0, [], 1), TestCmd.new(0, [])]
    page = TestPage.new(:trigger => 4, :sprite => "Object Ice rock", :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Eisblock 1", :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # One of the maze's balls.
  def ball(id, x, y)
    put(id, x, y, "Item", 0, "Object ball")
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key; PokeAccess::Info.map_text; end

  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
