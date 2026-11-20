# Insurgence's second optional puzzles (games/insurgence/puzzles/: holon_mountain, ancient_tower, holon_lake, murk_forest,
# broadcast_tower, helios_sewers) on the shipped profile over events shaped like the game's: what a seeing player hears
# from the rods, rifts, ring and statues, and what the puzzle assist adds.
class InsurgenceOpt2PuzzlesTest < PokeAccessTest
  MAPS = [455, 549, 365, 366, 368, 367, 646, 793, 750, 662, 663, 180]
  KEYS = %w[ins_o2_rod ins_o2_rod_charged ins_o2_rod_hint ins_o2_rod_seedot ins_o2_rock_button_hint ins_u1_tesseract_spot
            ins_o2_tess_spot_go ins_o2_rift ins_o2_rift_hint ins_o2_tower_pits ins_o2_tower_rocks ins_o2_sediment
            ins_o2_sediment_hint ins_o2_murk_statue_hint ins_o2_bt_statue_hint ins_o2_helios_statue_hint]
  STATUE_KEYS = %w[ins_o2_murk_statue_hint ins_o2_bt_statue_hint ins_o2_helios_statue_hint]
  SWITCHES = [520, 521, 522]

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
    KEYS.each { |k| table[k] ||= k }
    table["ins_o2_spiders"] ||= "Spiders"
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

  test "the lightning rods are named by their charge without repeating the battle, and the assist alone says what charges them" do
    on_map(455)
    silent(18, 65, 22)
    silent(20, 66, 22)
    assert_equal [[65, 22, t(:ins_o2_rod)], [66, 22, t(:ins_o2_rod)]], listed
    assert_equal [], frame
    $game_switches[521] = true
    assert_equal [], frame
    assert_equal [[65, 22, t(:ins_o2_rod_charged)], [66, 22, t(:ins_o2_rod_charged)]], listed
    refute_includes info_key.to_s, t(:ins_o2_rod_seedot)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key.to_s, t(:ins_o2_rod_seedot)
    $game_switches[521] = false
    assert_includes info_key.to_s, t(:ins_o2_rod_hint)
  end

  test "the hidden button engraved in the rock is named with the assist alone, the Tesseract spot shares the earlier key" do
    on_map(549)
    silent(12, 26, 50, "button")
    silent(16, 50, 16, "Tesseract_Spot_1")
    assert_equal [[50, 16, t(:ins_u1_tesseract_spot)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[26, 50, t(:ins_o2_rock_button_hint)], [50, 16, t(:ins_o2_tess_spot_go)]],
                 listed.sort_by { |x, _y, _n| x }
    $game_switches[520] = true
    assert_equal [[50, 16, t(:ins_o2_tess_spot_go)]], listed
  end

  test "the Ancient Tower rifts go once their platform is there, and the floors say their rule on arrival" do
    PokeAccess::Config.verbosity = :full
    on_map(366)
    assert_equal [t(:ins_o2_tower_pits)], frame
    silent(1, 13, 22, "Tesseract_Spot_2")
    assert_equal [[13, 22, t(:ins_o2_rift)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[13, 22, t(:ins_o2_rift_hint)]], listed
    $game_self_switches[[366, 1, "A"]] = true
    assert_equal [], listed
    on_map(646)
    assert_equal [t(:ins_o2_tower_rocks)], frame
  end

  test "the sediment ring is listed on the seabed and the assist tells where Dive surfaces" do
    PokeAccess::Config.verbosity = :full
    on_map(793)
    assert_equal [[33, 30, t(:ins_o2_sediment)], [36, 27, t(:ins_o2_sediment)], [36, 33, t(:ins_o2_sediment)],
                  [39, 30, t(:ins_o2_sediment)]], listed
    assert_equal [], frame
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    on_map(793)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, t(:ins_o2_sediment_hint)
  end

  test "the Murk Forest statue says where its sealed item lies with the assist, the spiders count with it" do
    on_map(750)
    silent(24, 8, 19, "HeartSwap_S", "manaphy_statue")
    refute_includes listed.map(&:last), t(:ins_o2_murk_statue_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[8, 19, t(:ins_o2_murk_statue_hint)]], listed
    assert_equal [], frame
    $game_self_switches[[750, 6, "A"]] = true
    assert_equal [t(:puzzle_progress, :label => t(:ins_o2_spiders), :n => 1, :of => 6)], frame
    PokeAccess::Config.puzzle_assist = false
    $game_self_switches[[750, 7, "A"]] = true
    assert_equal [], frame
    $game_self_switches[[750, 23, "B"]] = true
    refute_includes listed.map(&:last), t(:ins_o2_murk_statue_hint)
  end

  test "the Broadcast Tower spot and statue and the Helios Sewers statue are plain without the assist" do
    [[662, 25, 61, 79, "Tesseract_Spot_1", :ins_u1_tesseract_spot, :ins_o2_tess_spot_go],
     [663, 26, 50, 65, "HeartSwap_S", :ins_manaphy_statue, :ins_o2_bt_statue_hint],
     [180, 19, 85, 58, "HeartSwap_S", :ins_manaphy_statue, :ins_o2_helios_statue_hint]].each do |map, id, x, y, name, plain, hint|
      on_map(map)
      silent(id, x, y, name, name == "HeartSwap_S" ? "manaphy_statue" : "")
      assert_equal [[x, y, t(plain)]], listed, "map #{map}" if name != "HeartSwap_S"
      refute_includes listed.map(&:last), t(hint), "map #{map}" if name == "HeartSwap_S"
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[x, y, t(hint)]], listed, "map #{map}"
    end
  end

  test "the texts say that Heart Swap keeps its English name and that pits drop the player on foot" do
    texts = STATUE_KEYS.product(%w[fr de]).map { |key, lang| [key, lang, PokeAccess::I18n.table(lang)[key]] }
    texts = texts.select { |key, _lang, text| text && text != key }
    pits = PokeAccess::I18n.table("en")["ins_o2_tower_pits"]
    pits = nil if pits == "ins_o2_tower_pits"
    skip "keys not in lang/ yet" if texts.empty? && pits.nil?
    texts.each do |key, lang, text|
      assert_includes text, "Heart Swap", "#{lang} #{key}"
      refute_match(/Échange Cœur|Herztausch/, text, "#{lang} #{key}")
    end
    pit_text = pits.to_s
    assert_match(/on foot/, pit_text) if pits
    refute_match(/turns/, pit_text)
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

  def silent(id, x, y, name = "EV#{id}", sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)] }.sort_by { |x, y, _n| [x, y] }
  end
end
