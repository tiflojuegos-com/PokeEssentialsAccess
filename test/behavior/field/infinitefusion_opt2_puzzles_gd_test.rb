# Pokemon Infinite Fusion's optional puzzles of the second batch (games/infinitefusion/puzzles/): the Lake of Rage's stones,
# the Dragon's Den whirlpools, the Azure Flute's circle, the Submerged Temple's slots and sharks and the three chambers of
# the Sealed Chamber, on the shipped profile over events shaped like the game's. Gamedata pass.
class InfinitefusionOpt2PuzzlesGdTest < PokeAccessTest
  MAPS = [645, 638, 335, 694, 811, 812, 815, 813]
  SWITCHES = [470, 521, 684, 685, 686, 729, 742, 745]

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
    $game_variables[1122] = 0
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the Lake of Rage's frozen stones are one object, with the sealed exit told on arriving and the way out with the assist" do
    on_map(645)
    [[9, 52, 37], [10, 52, 36], [11, 51, 36], [12, 51, 37]].each { |id, x, y| put(id, x, y, :list => choice_list) }
    assert_equal [t(:ifp_lake_frozen_rule)], frame
    assert_equal [t(:ifp_lake_thaw_stone)], listed.map { |_x, _y, n| n }
    refute_includes info_key, t(:ifp_lake_frozen_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifp_lake_frozen_hint)
  end

  test "the thawed lake's stones are named alike and one object per group" do
    on_map(638)
    [[6, 27, 36], [8, 26, 36], [10, 27, 37], [16, 26, 37], [9, 9, 35]].each { |id, x, y| put(id, x, y) }
    assert_equal [t(:ifp_lake_freeze_stone)], listed.map { |_x, _y, n| n }
  end

  test "the Dragon's Den whirlpools are traps, announced on arriving, and a forced push up is said" do
    on_map(335)
    [[8, 5, 15], [9, 6, 15], [6, 4, 8]].each { |id, x, y| put(id, x, y, :sprite => "Whirlpool") }
    assert_equal [t(:ifp_whirlpool_rule)], frame
    assert_equal [], listed
    assert_equal [8, 9, 10], Harness.declared(335)[:obstacles].map { |o| o[:events].keys }.flatten.sort[0, 3]
    assert_equal t(:ifp_whirlpool_push), PokeAccess::Locator.cause_line([5, 15, 335], [5, 14, 335], :forced)
  end

  test "the Azure Flute's circle is named by the item and the rising stair is told, the way to use it with the assist" do
    on_map(694)
    put(1, 19, 27, :list => choice_list)
    item = PokeAccess::Data.item_name(:AZUREFLUTE).to_s
    assert_equal [t(:ifp_circle)], listed.map { |_x, _y, n| n }
    refute_includes info_key, t(:ifp_azure_hint, :item => item)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:ifp_azure_circle, :item => item)], listed.map { |_x, _y, n| n }
    assert_includes info_key, t(:ifp_azure_hint, :item => item)
    assert_equal [t(:ifp_azure_stairs)], frame { $game_switches[521] = true }
    refute_includes info_key, t(:ifp_azure_hint, :item => item)
  end

  test "the tunnel's sharks are announced in 812 until the tunnel is done and in 815 only when the entrance from 812 was taken" do
    on_map(812)
    assert_equal [t(:ifp_shark_rule)], frame
    on_map(812)
    $game_switches[742] = true
    assert_empty frame
    on_map(815)
    assert_empty frame
    on_map(815)
    $game_switches[745] = true
    assert_equal [t(:ifp_shark_tunnel_rule)], frame
  end

  test "the braille pictures say what they spell with the Regi tablet and are only an inscription without it" do
    declare_puzzles
    handlers = PokeAccess::PictureCues::HANDLERS
    was = handlers.dup
    handlers.clear
    Harness.load_puzzles("infinitefusion")
    names = %w[braille_lore1a braille_lore4b braille_icesteel braille_rockice braille_steelrock]
    refute names.any? { |n| PokeAccess::PictureCues::TEXTS.key?(n) }
    texts = [/thousand years/, /titans now rest/, /rock bottom/, /stones must queue/, /untarnished/]
    names.each_with_index do |name, i|
      assert_equal [t(:ifp_braille)], shown(name, 0), name
      assert_match texts[i], shown(name, 1).join, name
      assert_equal 1, shown(name, 1).length, name
    end
  ensure
    handlers.replace(was)
  end

  test "the temple's slots are named by door and give their types with the assist alone, and an opened door is told" do
    on_map(811)
    [[1, 41, 21], [6, 42, 21], [17, 18, 27], [20, 19, 27], [18, 64, 27], [22, 65, 27]].each { |id, x, y| put(id, x, y, :list => choice_list) }
    names = listed.map { |_x, _y, n| n }.sort
    assert_equal [t(:ifp_slot_top), t(:ifp_slot_left), t(:ifp_slot_right)].sort, names
    PokeAccess::Config.puzzle_assist = true
    typed = lambda do |slot, a, b|
      t(:ifp_slot_typed, :slot => t(slot), :a => PokeAccess::Data.type_name(a).to_s, :b => PokeAccess::Data.type_name(b).to_s)
    end
    assert_equal [typed.call(:ifp_slot_top, :ICE, :ROCK), typed.call(:ifp_slot_left, :STEEL, :ROCK),
                  typed.call(:ifp_slot_right, :STEEL, :ICE)].sort, listed.map { |_x, _y, n| n }.sort
    PokeAccess::Config.puzzle_assist = false
    assert_equal [t(:ifp_door_top_active)], frame { $game_switches[729] = true }
  end

  test "the tunnel's sharks are traps and the transfer back to the labyrinth is told only when a shark did it" do
    on_map(812)
    put(6, 41, 19, :name => "sharpedo", :sprite => "SHARPEDO")
    assert_equal [t(:ifp_shark_rule)], frame
    assert_equal [], listed
    back = lambda { |from, to| PokeAccess::Locator.cause_line(from, to, :map) }
    assert_equal t(:ifp_shark_back), back.call([40, 19, 812], [58, 9, 606])
    assert_equal t(:ifp_shark_back), back.call([44, 5, 815], [58, 9, 606])
    assert_nil back.call([33, 20, 812], [58, 9, 606]), "the tunnel's own exit door"
    assert_nil back.call([40, 19, 812], [4, 9, 811])
  end

  test "the left chamber's plates are named by metal, its rule is told inside and the right ones counted with the assist" do
    on_map(813)
    plates = { 75 => [16, 21, 848], 77 => [20, 21, 841], 67 => [22, 21, 862], 76 => [18, 21, 872] }
    plates.each { |id, (x, y, tile)| put(id, x, y, :tile_id => tile) }
    expected = [t(:ifp_plate_bronze), t(:ifp_plate_gold), t(:ifp_plate_silver), t(:ifp_plate_stone)].sort
    assert_equal expected, listed.map { |_x, _y, n| n }.sort
    assert_equal [t(:ifp_steel_rock_title)], frame { stand(18, 24) }
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[813, 75, "A"]] = true
    lines = frame
    assert_includes lines, t(:puzzle_progress, :label => t(:ifp_plates_right), :n => 1, :of => 6)
  end

  test "the middle chamber counts the rocks in the column with the assist and tells the statue's unlocking" do
    on_map(813)
    [1, 2, 3].each { |id| put(id, 39, 15 + id, :name => "StrengthBoulder") }
    assert_equal [t(:ifp_rock_ice_title)], frame { stand(42, 22) }
    PokeAccess::Config.puzzle_assist = true
    frame
    @events[1].x = 42; @events[1].y = 14
    @events[2].x = 42; @events[2].y = 15
    assert_includes frame, t(:puzzle_progress, :label => t(:ifp_rocks_in_column), :n => 2, :of => 7)
    PokeAccess::Config.puzzle_assist = false
    assert_includes frame { $game_switches[685] = true }, t(:ifp_chamber_middle_open)
  end

  test "the right chamber counts the plates stepped on in the order's string, with the assist alone" do
    on_map(813)
    put(87, 65, 25, :tile_id => 862)
    put(66, 64, 23, :tile_id => 872)
    PokeAccess::Config.puzzle_assist = true
    frame { stand(65, 27); $game_variables[1122] = "" }
    assert_includes frame { $game_variables[1122] = "ss" }, t(:puzzle_progress, :label => t(:ifp_plates_order), :n => 2, :of => 7)
    $game_variables[1122] = 0
  end

  test "the braille inscriptions are named" do
    on_map(813)
    [[97, 14, 18], [98, 15, 18], [99, 16, 18]].each { |id, x, y| put(id, x, y) }
    assert_equal [t(:ifp_braille)], listed.map { |_x, _y, n| n }
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def mechanics; PokeAccess::World::Mechanics; end

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
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def shown(name, tablets)
    bag = Struct.new(:count) { def pbQuantity(_item); count; end }.new(tablets)
    was = $PokemonBag
    $PokemonBag = bag
    SpeakCapture.clear
    pic = Game_Picture.new
    pic.show(name)
    pic.erase
    SpeakCapture.log.map { |line| line[0] }
  ensure
    $PokemonBag = was
  end

  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  def choice_list
    [TestCmd.new(101, ["Touch it?"]), TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]), TestCmd.new(404)]
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
