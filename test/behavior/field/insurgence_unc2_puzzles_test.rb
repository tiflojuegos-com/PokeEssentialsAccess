# Insurgence's checked "unconfirmed" puzzles of the second batch (games/insurgence/puzzles/: holon_jungle, void_gauntlet,
# crystal_caves, slither_forest) on the shipped profile over events shaped like the game's: what a seeing player hears, and
# what the puzzle assist adds.
class InsurgenceUnc2PuzzlesTest < PokeAccessTest
  MAPS = [454, 470, 443, 585, 765, 281]
  WORDS = {
    "ins_u2_jungle_plate" => "Boulder tile", "ins_u2_jungle_hint" => "Push a boulder onto the tile",
    "ins_u2_mansion_switch" => "Secret switch", "ins_u2_mansion_gate" => "Gate",
    "ins_u2_mansion_hint" => "Heart Swap to the chamber", "ins_u2_mansion_open_hint" => "Gates open, press again to shut",
    "ins_u2_slither_hint" => "Heart Swap to the pocket", "ins_u2_fiery_plate" => "Boulder tile",
    "ins_u2_fiery_hint" => "Push the boulder onto the tile and right",
    "ins_u1_tesseract_spot" => "Tesseract spot"
  }
  SWITCHES = [148, 529, 686]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    table = PokeAccess::I18n.table(PokeAccess::I18n.lang)
    WORDS.each { |k, v| table[k] ||= v }
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Holon Jungle marks the boulder tile and says the way only with the assist, until the door is open" do
    on_map(454)
    assert_equal [], listed
    refute_includes info_key.to_s, t(:ins_u2_jungle_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[39, 31, t(:ins_u2_jungle_plate)]], listed
    assert_match(/#{t(:ins_u2_jungle_hint)}\z/, info_key)
    $game_switches[529] = true
    assert_equal [], listed
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Pokemon Mansion names its secret switch and its gates as one target, and the assist says the Heart Swap way" do
    on_map(470)
    silent(30, 9, 7, "EV030")
    [[18, 35, 20], [19, 36, 20], [20, 37, 20], [21, 35, 21], [22, 36, 21], [23, 37, 21]].each do |id, x, y|
      silent(id, x, y, "Gate_1#{(64 + id - 17).chr}")
    end
    names = listed.map { |_x, _y, n| n }
    assert_equal [t(:ins_u2_mansion_switch), t(:ins_u2_mansion_gate)], names.sort_by { |n| n == t(:ins_u2_mansion_gate) ? 1 : 0 }
    assert_equal 1, names.count(t(:ins_u2_mansion_gate))
    refute_includes info_key.to_s, t(:ins_u2_mansion_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_match(/#{t(:ins_u2_mansion_hint)}\z/, info_key)
    $game_switches[686] = true
    assert_match(/#{t(:ins_u2_mansion_open_hint)}\z/, info_key)
    refute_includes info_key.to_s, t(:ins_u2_mansion_hint)
    $game_switches[686] = false
    assert_match(/#{t(:ins_u2_mansion_hint)}\z/, info_key)
  end

  test "Fiery Caverns marks the tile for the boulder with the assist alone, until the cascade floor is drawn" do
    on_map(281)
    assert_equal [], listed
    refute_includes info_key.to_s, t(:ins_u2_fiery_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[40, 24, t(:ins_u2_fiery_plate)]], listed
    assert_match(/#{t(:ins_u2_fiery_hint)}\z/, info_key)
    $game_switches[148] = true
    assert_equal [], listed
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Crystal Caves name the Tesseract spot in both times" do
    [443, 585].each do |map|
      on_map(map)
      silent(3, 33, 49, "Tesseract_Spot_1")
      assert_equal [[33, 49, t(:ins_u1_tesseract_spot)]], listed
    end
  end

  test "Slither Forest says how to cross the boulders only with the assist" do
    on_map(765)
    refute_includes info_key.to_s, t(:ins_u2_slither_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ins_u2_slither_hint), info_key
    $game_self_switches[[765, 2, "A"]] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Slither Forest and mansion texts keep Heart Swap's own name and say where the swap leaves the player" do
    texts = %w[ins_u2_mansion_hint ins_u2_mansion_open_hint ins_u2_slither_hint].product(%w[es en fr de pl pt]).map do |key, lang|
      [key, lang, PokeAccess::I18n.table(lang)[key]]
    end.select { |_key, _lang, text| text && !WORDS.value?(text) }
    skip "keys not in lang/ yet" if texts.empty?
    texts.each { |key, lang, text| assert_includes text, "Heart Swap", "#{lang} #{key}" }
    en = texts.assoc("ins_u2_slither_hint") { |k, l, _t| k == "ins_u2_slither_hint" && l == "en" }
    refute_match(/other side/, en[2]) if en
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("insurgence")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def silent(id, x, y, name = "EV#{id}")
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key; PokeAccess::Info.map_text; end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)] }.sort_by { |x, y, _n| [x, y] }
  end
end
