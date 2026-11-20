# The ways of Jikan, Hankoshi and Sakyu Temple (games/keishou/puzzles/sakyu_valley.rb): the gems and pads named without
# the assist, and with it each socket's way by stages, read from where its rock lies in the world the player stands in.
# Gamedata pass.
class KeishouSakyuGdTest < PokeAccessTest
  MAPS = [139, 140, 143]
  VARS = [59, 60, 61, 62, 63, 65]

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
    $game_switches[71] = false
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Jikan names its gems and brown pad, and the assist leads each rock by its stage" do
    on_map(139, 9, 16)
    rock1 = boulder(1, 7, 21)
    rock7 = boulder(7, 21, 19)
    gem(12, 24, 10)
    gem(13, 21, 13)
    gem(14, 23, 21)
    assert_equal [t(:ks_o_brown_pad), t(:ks_o_blue_gem), t(:ks_o_blue_gem), t(:ks_o_cyan_gem)],
                 names_at([[5, 14], [21, 13], [23, 21], [24, 10]])
    refute_includes info_key.to_s, t(:ks_o_jikan_pocket_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ks_o_jikan_pocket_hint)
    rock1.x = 7; rock1.y = 14
    assert_includes info_key, t(:ks_o_jikan_socket_hint)
    $game_self_switches[[139, 20, "A"]] = true
    assert_includes info_key, t(:ks_o_jikan_chamber_hint)
    rock7.y = 16
    assert_includes info_key, t(:ks_o_jikan_chamber_hint)
    save_at(22, 13, 139)
    assert_includes info_key, t(:ks_o_jikan_cyan_hint)
    rock7.y = 19
    assert_includes info_key, t(:ks_o_jikan_revert_hint)
    $game_player.x = 22; $game_player.y = 13
    assert_includes info_key, t(:ks_o_jikan_out_hint)
    rock7.y = 21
    refute_includes info_key, t(:ks_o_jikan_out_hint)
    $game_self_switches[[139, 8, "A"]] = true
    %w[pocket socket chamber cyan revert out].each { |k| refute_includes info_key.to_s, t("ks_o_jikan_#{k}_hint".to_sym) }
  end

  test "Hankoshi reads each rock in the world the player stands in" do
    on_map(140, 7, 9)
    rock1 = boulder(1, 22, 7)
    rock7 = boulder(7, 52, 7)
    rock2 = boulder(2, 9, 19)
    boulder(6, 39, 19)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ks_o_hankoshi_a1_hint)
    rock1.x = 23; rock1.y = 10
    assert_includes info_key, t(:ks_o_hankoshi_a2_hint)
    $game_player.x = 52; $game_player.y = 20
    assert_includes info_key, t(:ks_o_hankoshi_a1_hint)
    rock7.x = 53; rock7.y = 21
    assert_includes info_key, t(:ks_o_hankoshi_a2_hint)
    rock7.x = 48; rock7.y = 17
    assert_includes info_key, t(:ks_o_hankoshi_a4_hint)
    $game_player.x = 14; $game_player.y = 16
    rock1.x = 15; rock1.y = 17
    assert_includes info_key, t(:ks_o_hankoshi_a3_hint)
    $game_self_switches[[140, 9, "A"]] = true
    assert_includes info_key, t(:ks_o_hankoshi_b1_hint)
    rock2.x = 8
    assert_includes info_key, t(:ks_o_hankoshi_b2_hint)
    rock2.x = 6; rock2.y = 13
    assert_includes info_key, t(:ks_o_hankoshi_b3_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:ks_o_hankoshi_b3_hint)
  end

  test "Sakyu Temple names its gems, plates and pads, and the assist speaks of the corner under way or the nearest" do
    ev = temple
    assert_equal [t(:ks_o_cyan_gem), t(:ks_o_silver_plate), t(:ks_o_brown_pad), t(:ks_o_dark_pad), t(:ks_o_blue_gem)],
                 names_at([[4, 20], [9, 29], [11, 9], [13, 20], [18, 12]])
    refute_includes info_key.to_s, t(:ks_o_temple_sw1_hint)
    PokeAccess::Config.puzzle_assist = true
    { [10, 27] => :sw1, [28, 10] => :ne1, [8, 10] => :nw1, [28, 26] => :se1 }.each do |(x, y), stage|
      $game_player.x = x; $game_player.y = y
      assert_includes info_key, t("ks_o_temple_#{stage}_hint".to_sym)
    end
    $game_player.x = 60; $game_player.y = 14
    ev[13].x = 65; ev[13].y = 12
    assert_includes info_key, t(:ks_o_temple_ne2_hint)
    $game_player.x = 8; $game_player.y = 27
    ev[9].x = 32; ev[9].y = 7
    assert_includes info_key, t(:ks_o_temple_ne3_hint)
    refute_includes info_key, t(:ks_o_temple_sw1_hint)
    $game_self_switches[[143, 35, "A"]] = true
    assert_includes info_key, t(:ks_o_temple_sw1_hint)
    ev[17].x = 11; ev[17].y = 12
    assert_includes info_key, t(:ks_o_temple_nw2_hint)
    $game_self_switches[[143, 14, "A"]] = true
    ev[24].y = 20
    assert_includes info_key, t(:ks_o_temple_sw2_hint)
    $game_self_switches[[143, 30, "A"]] = true
    assert_includes info_key, t(:ks_o_temple_se1_hint)
    save_at(30, 18, 143)
    ev[34].x = 25; ev[34].y = 22
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    ev[34].x = 21; ev[34].y = 30
    assert_includes info_key, t(:ks_o_temple_se3_hint)
  end

  test "the temple keeps the south-east's way while its steps move the south-west's rock, and measures in the twin world" do
    ev = temple
    PokeAccess::Config.puzzle_assist = true
    $game_player.x = 46; $game_player.y = 28
    assert_includes info_key, t(:ks_o_temple_sw1_hint)
    $game_player.x = 70; $game_player.y = 8
    assert_includes info_key, t(:ks_o_temple_ne2_hint)
    ev[9].y = 13
    ev[17].x = 11; ev[17].y = 12
    $game_player.x = 8; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_nw2_hint)
    $game_player.x = 28; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_ne1_hint)
    ev[9].y = 16
    ev[17].x = 5; ev[17].y = 14
    save_at(30, 18, 143)
    ev[34].x = 25; ev[34].y = 22
    $game_player.x = 8; $game_player.y = 20
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    ev[24].y = 22
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    $game_player.x = 48; $game_player.y = 21
    ev[25].y = 22
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    ev[25].y = 23
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    $game_player.x = 4; $game_player.y = 19
    ev[24].y = 23
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    ev[24].y = 21
    ev[25].y = 21
    ev[34].x = 21; ev[34].y = 30
    assert_includes info_key, t(:ks_o_temple_se3_hint)
    refute_includes info_key, t(:ks_o_temple_sw1_hint)
  end

  test "the temple's north-west and south-west take either rock, by its way, also by row 19 and the twin of 21, 30" do
    ev = temple
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[143, 35, "A"]] = true
    at(ev[24], 11, 15)
    $game_player.x = 8; $game_player.y = 27
    assert_includes info_key, t(:ks_o_temple_nw2_hint)
    at(ev[24], 11, 7)
    assert_includes info_key, t(:ks_o_temple_nw3_hint)
    at(ev[24], 10, 19)
    $game_player.x = 28; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_sw2_hint)
    at(ev[24], 8, 21)
    at(ev[18], 45, 17)
    $game_player.x = 44; $game_player.y = 17
    assert_includes info_key, t(:ks_o_temple_sw1b_hint)
    $game_player.x = 8; $game_player.y = 18
    at(ev[17], 8, 19)
    assert_includes info_key, t(:ks_o_temple_sw2_hint)
    at(ev[17], 13, 20)
    assert_includes info_key, t(:ks_o_temple_sw3_hint)
    at(ev[17], 6, 29)
    $game_self_switches[[143, 30, "A"]] = true
    $game_player.x = 8; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_nw1b_hint)
    $game_self_switches[[143, 30, "A"]] = false
    $game_self_switches[[143, 14, "A"]] = true
    at(ev[17], 5, 14)
    at(ev[24], 6, 7)
    $game_player.x = 8; $game_player.y = 27
    assert_includes info_key, t(:ks_o_temple_sw1b_hint)
    at(ev[17], 3, 10)
    assert_includes info_key, t(:ks_o_temple_reset_hint)
    at(ev[18], 45, 14)
    at(ev[1], 47, 29)
    $game_player.x = 47; $game_player.y = 28
    assert_includes info_key, t(:ks_o_temple_sw4_hint)
  end

  test "the temple leads the north-east on in the twin world and past 20, 12, and the rock of 21, 30 to the south-west" do
    ev = temple
    PokeAccess::Config.puzzle_assist = true
    at(ev[13], 60, 13)
    $game_player.x = 60; $game_player.y = 14
    assert_includes info_key, t(:ks_o_temple_ne2_hint)
    refute_includes info_key, t(:ks_o_temple_ne1_hint)
    at(ev[9], 20, 12)
    $game_player.x = 19; $game_player.y = 11
    assert_includes info_key, t(:ks_o_temple_ne1b_hint)
    at(ev[9], 21, 12)
    assert_includes info_key, t(:ks_o_temple_ne2b_hint)
    at(ev[9], 20, 16)
    at(ev[13], 60, 16)
    save_at(30, 18, 143)
    at(ev[34], 19, 30)
    $game_player.x = 21; $game_player.y = 30
    assert_includes info_key, t(:ks_o_temple_sw4_hint)
    refute_includes info_key, t(:ks_o_temple_se2_hint)
    at(ev[1], 58, 30)
    $game_player.x = 59; $game_player.y = 30
    assert_includes info_key, t(:ks_o_temple_sw4_hint)
    $game_self_switches[[143, 30, "A"]] = true
    assert_includes info_key, t(:ks_o_temple_se2_hint)
    $game_switches[71] = false
    at(ev[34], 6, 29)
    at(ev[1], 46, 29)
    $game_player.x = 8; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_nw1_hint)
    refute_includes info_key, t(:ks_o_temple_se1_hint)
  end

  test "the temple keeps 8, 21 for the open south-west and opens the way to the cyan gem" do
    ev = temple
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[143, 35, "A"]] = true
    $game_self_switches[[143, 10, "A"]] = true
    at(ev[17], 3, 10)
    at(ev[18], 43, 10)
    $game_player.x = 8; $game_player.y = 10
    assert_includes info_key, t(:ks_o_temple_reset3_hint)
    refute_includes info_key, t(:ks_o_temple_nw1b_hint)
    at(ev[24], 8, 22)
    at(ev[25], 48, 22)
    assert_includes info_key, t(:ks_o_temple_reset2_hint)
  end

  private

  # Moves event ev to (x, y).
  def at(ev, x, y)
    ev.x = x
    ev.y = y
  end

  # The temple's rocks, gems and plates on map 143, the player at its entrance; the rocks by id.
  def temple
    on_map(143, 18, 18)
    rocks = { 9 => [20, 16], 13 => [60, 16], 17 => [5, 14], 18 => [45, 14], 24 => [8, 21], 25 => [48, 21],
              33 => [26, 22], 2 => [66, 22], 34 => [21, 30], 1 => [61, 30] }
    ev = {}
    rocks.each { |id, (x, y)| ev[id] = boulder(id, x, y) }
    [[23, 4, 20], [15, 18, 12], [31, 11, 22], [32, 30, 19]].each { |id, x, y| gem(id, x, y) }
    [[5, 9, 29], [12, 49, 29]].each { |id, x, y| silent(id, x, y) }
    ev
  end

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
    $game_switches[71] = false
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # The timestamp of the blue gems saved on (x, y) of map, as their menu stores it.
  def save_at(x, y, map)
    $game_switches[71] = true
    $game_variables[59] = x
    $game_variables[60] = y
    $game_variables[61] = map
  end

  # Puts an event on the map and lets a frame pass.
  def put(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # A Strength boulder.
  def boulder(id, x, y)
    page = TestPage.new(:trigger => 1, :sprite => "Object boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "StrengthBoulder", :pages => [page]))
  end

  # A gem as the ruins draw it: a tile on an event whose page says something.
  def gem(id, x, y)
    page = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :tile_id => 484, :pages => [page]))
  end

  # An event with no graphic and a page that says something, as the silver plates are.
  def silent(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    put(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page]))
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

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
end
