# Pokemon Infinite Fusion's unconfirmed Kanto puzzles (games/infinitefusion/puzzles/): the Ruins of Alph tablets, Cerulean
# Cave's holes, Berry Forest's lost children and impostor and the Old Shipwreck's barrels, on the shipped profile over events
# shaped like the game's. Gamedata pass.
class InfinitefusionUncPuzzlesGdTest < PokeAccessTest
  MAPS = [345, 347, 348, 352, 353, 322, 323, 619, 806]
  SWITCHES = [340, 548, 860, 861, 871]
  VARS = [156, 188]
  TEMPLATES = { "ifu_alph_tablet_letter" => "tablet %{letter}", "ifu_alph_hint" => "order %{order}, next %{next}" }

  class << self
    attr_accessor :declared
  end

  def setup
    super
    stub_missing_keys
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    VARS.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    drop_stubbed_keys
    super
  end

  test "Ruins of Alph names each tablet and the assist alone gives its letter, the order and the next one" do
    on_map(347)
    put(1, 9, 6)
    frame
    assert_equal [[9, 6, t(:ifu_alph_tablet)]], listed
    refute_includes info_key, "ABDECBA".split("").join(", ")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[9, 6, t(:ifu_alph_tablet_letter, :letter => "B")]], listed
    $game_variables[156] = 0
    assert_includes info_key, t(:ifu_alph_hint, :order => "A, B, D, E, C, B, A", :next => "A")
    $game_variables[156] = "AB"
    assert_includes info_key, t(:ifu_alph_hint, :order => "A, B, D, E, C, B, A", :next => "D")
    $game_variables[156] = "ABDECB"
    assert_includes info_key, t(:ifu_alph_hint, :order => "A, B, D, E, C, B, A", :next => "A")
  end

  test "Ruins of Alph stops listing and hinting once the Hidden Chamber is open" do
    on_map(353)
    put(1, 9, 6)
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_equal [[9, 6, t(:ifu_alph_tablet_letter, :letter => "E")]], listed
    $game_switches[340] = true
    frame
    assert_empty listed
    refute_includes info_key, "A, B, D, E, C, B, A"
  end

  test "Cerulean Cave lists its holes as holes, a row as one, and the assist marks the one that is needed" do
    on_map(323)
    [[5, 25, 6], [6, 8, 16], [23, 16, 25], [24, 17, 25], [25, 18, 25]].each { |id, x, y| put(id, x, y, :tile_id => 582) }
    frame
    assert_equal [[8, 16, t(:ifu_cerulean_hole)], [17, 25, t(:ifu_cerulean_hole)], [25, 6, t(:ifu_cerulean_hole)]], listed
    refute_includes info_key, t(:ifu_cerulean_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ifu_cerulean_right_hole), listed.find { |x, y, _n| [x, y] == [8, 16] }[2]
    assert_includes info_key, t(:ifu_cerulean_hint)
  end

  test "Cerulean Cave says a fall from the second floor onto the first, and nothing for the stairs" do
    on_map(322)
    sent = lambda { |from, to| PokeAccess::Puzzles.sent_back_line(from, to, :map) }
    [[18, 25], [30, 4], [6, 18], [25, 16], [33, 24], [33, 20], [6, 7]].each do |at|
      assert_equal t(:ifu_cerulean_fell), sent.call([8, 16, 323], at)
    end
    [[34, 3], [6, 4], [28, 14], [6, 16], [12, 26]].each { |at| assert_nil sent.call([8, 16, 323], at) }
    assert_nil sent.call([8, 16, 324], [18, 25])
  end

  test "Berry Forest names its children, counts the lost ones found and keeps the impostor's editor name out" do
    on_map(619)
    [[24, 25, 12], [25, 51, 25], [26, 11, 8], [27, 22, 28], [28, 32, 20]].each { |id, x, y| put(id, x, y) }
    [[14, 16, 17], [15, 14, 18], [16, 15, 20], [17, 17, 20], [19, 15, 17], [20, 16, 20]].each { |id, x, y| put(id, x, y) }
    put(18, 14, 19, :name => "fake kid")
    frame
    assert_equal [t(:ifu_berry_kid_lost)] * 5, listed.map { |_x, _y, n| n }
    $game_variables[188] = 2
    assert_equal [t(:puzzle_progress, :label => t(:ifu_berry_kids), :n => 2, :of => 5)], frame
    $game_switches[548] = true
    names = listed.map { |_x, _y, n| n }
    assert_equal 7, names.count(t(:ifu_berry_camp_kid))
    refute_includes names.join, "fake"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[14, 19, t(:ifu_berry_impostor)]], listed.select { |_x, _y, n| n == t(:ifu_berry_impostor) }
  end

  test "Berry Forest tells the step the search is at with the assist, and stops once the forest is clear" do
    on_map(619)
    put(14, 16, 17)
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_includes info_key, t(:ifu_berry_hint_ask)
    $game_switches[861] = true
    assert_includes info_key, t(:ifu_berry_hint_search)
    $game_variables[188] = 5
    assert_includes info_key, t(:ifu_berry_hint_count)
    $game_switches[548] = true
    assert_includes info_key, t(:ifu_berry_hint_impostor)
    $game_switches[860] = true
    frame
    refute_includes info_key, t(:ifu_berry_hint_impostor)
  end

  test "Old Shipwreck calls its barrels barrels, though the editor named them like rocks, and never lists them as a puzzle" do
    on_map(806)
    put(3, 19, 7, :name => "StrengthBoulder", :sprite => "BARREL")
    put(17, 29, 6, :name => "StrengthBoulder", :tile_id => 2027)
    frame
    assert_empty listed
    assert_equal [t(:ifu_barrel)] * 2, [3, 17].map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
  end

  private

  def stub_missing_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed = TEMPLATES.keys.reject { |key| table.key?(key) }
    @stubbed.each { |key| table[key] = TEMPLATES[key] }
  end

  def drop_stubbed_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |key| table.delete(key) }
  end

  def mechanics; PokeAccess::World::Mechanics; end

  def t(*args); PokeAccess::I18n.t(*args); end

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("infinitefusion")
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
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key; PokeAccess::Info.map_text; end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
