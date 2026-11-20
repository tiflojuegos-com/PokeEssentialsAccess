# Pokemon Infinite Fusion's optional Kanto puzzles (games/infinitefusion/puzzles/): Mt. Moon's sky, Lavender's bell, Route 13's
# Rhyhorn, Creepy House, the Power Plant gate, Seafoam's ice walls, Vermilion's truck and the Bell Tower, on the shipped
# profile over events shaped like the game's. Gamedata pass.
class InfinitefusionOpt1PuzzlesGdTest < PokeAccessTest
  MAPS = [50, 437, 714, 198, 52, 808, 19, 652, 649, 650, 830, 828]
  SWITCHES = [1058, 1120, 159, 297, 528, 592, 593, 615, 622, 623, 624, 625, 750, 751, 752, 753, 754, 755, 756, 757, 758, 976, 1051, 1052, 1053, 1054, 1055, 1056, 1057, 1058]
  VARS = [5, 129, 130, 206, 222, 233, 301, 302, 303, 304, 305, 306, 307, 308, 320]

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
    VARS.each { |i| $game_variables[i] = 0 }
    SWITCHES.each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Lavender's bell is named without the assist and the clock hint comes with it, until the tomb opens" do
    on_map(50)
    put(11, 40, 7)
    frame
    assert_equal [[40, 7, t(:ifo_bell)]], listed
    refute_includes info_key, t(:ifo_bell_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifo_bell_hint)
    $game_switches[159] = true
    frame
    assert_empty listed
    refute_includes info_key, t(:ifo_bell_hint)
  end

  test "Route 13's Rhyhorn and its towel are listed once the villager asked, with the push hint on the assist alone" do
    on_map(437)
    put(42, 16, 32, :sprite => "111", :name => "StrengthBoulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"]), TestCmd.new(0, [])])
    frame
    assert_empty listed.select { |_x, _y, n| [t(:ifo_rhyhorn), t(:ifo_towel)].include?(n) }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifo_rhyhorn_ask)
    $game_switches[592] = true
    frame
    names = listed.map { |_x, _y, n| n }
    assert_includes names, t(:ifo_rhyhorn)
    assert_includes names, t(:ifo_towel)
    assert_equal [[19, 29]], listed.select { |_x, _y, n| n == t(:ifo_towel) }.map { |x, y, _n| [x, y] }
    assert_includes info_key, t(:ifo_rhyhorn_push)
    $game_switches[593] = true
    frame
    assert_empty listed.select { |_x, _y, n| [t(:ifo_rhyhorn), t(:ifo_towel)].include?(n) }
  end

  test "Creepy House names its dolls and pianos and the assist says which entrance a doll waits for" do
    on_map(714)
    [[6, 26, 22], [10, 1, 3], [12, 31, 3], [14, 14, 23]].each { |id, x, y| put(id, x, y, :tile_id => 2976, :name => "doll") }
    [[5, 2, 13], [18, 2, 14], [19, 4, 10]].each { |id, x, y| put(id, x, y) }
    [[7, 18, 14], [11, 11, 6], [13, 18, 8], [45, 14, 15]].each { |id, x, y| put(id, x, y) }
    frame
    refute_includes info_key, t(:ifo_doll_wait_classroom)
    PokeAccess::Config.puzzle_assist = true
    $game_self_switches[[714, 6, "A"]] = true
    assert_includes info_key, t(:ifo_doll_wait_classroom)
    $game_switches[625] = true
    refute_includes info_key, t(:ifo_doll_wait_classroom)
    $game_self_switches[[714, 6, "B"]] = true
    assert_includes info_key, t(:ifo_doll_leave)
    $game_self_switches[[714, 6, "C"]] = true
    $game_variables[233] = 4
    assert_includes info_key, t(:ifo_doll_last)
    names = listed.map { |_x, _y, n| n }
    assert_equal 3, names.count(t(:ifo_piano))
    assert_equal 4, names.count(t(:ifo_entrance_classroom)) + names.count(t(:ifo_entrance_bathroom)) + names.count(t(:ifo_entrance_library)) + names.count(t(:ifo_entrance_hall))
  end

  test "Creepy House says the classroom doll is gone when a piano switched it off before it was found, and not otherwise" do
    on_map(714)
    [[6, 26, 22], [10, 1, 3]].each { |id, x, y| put(id, x, y, :tile_id => 2976, :name => "doll") }
    PokeAccess::Config.puzzle_assist = true
    $game_variables[5] = [10, 12, 14]
    assert_includes info_key, t(:ifo_doll_lost)
    $game_variables[5] = [6, 12, 14]
    refute_includes info_key, t(:ifo_doll_lost)
    $game_variables[5] = [10, 12, 14]
    $game_self_switches[[714, 6, "A"]] = true
    refute_includes info_key, t(:ifo_doll_lost)
    $game_self_switches[[714, 6, "A"]] = false
    $game_self_switches[[714, 6, "B"]] = true
    refute_includes info_key, t(:ifo_doll_lost)
    $game_self_switches = {}
    $game_variables[5] = [14, 6, 12]
    $game_self_switches[[714, 10, "A"]] = true
    refute_includes info_key, t(:ifo_doll_lost)
  end

  test "the Power Plant gate has named terminals, counts the batteries with the assist and says how many are left" do
    on_map(198)
    [[90, 33, 27], [96, 32, 27]].each { |id, x, y| put(id, x, y) }
    [[92, 34, 26], [93, 35, 26], [94, 36, 26]].each { |id, x, y| put(id, x, y, :tile_id => 1929) }
    frame
    names = listed.map { |_x, _y, n| n }
    assert_equal 2, names.count(t(:ifo_pp_terminal))
    assert_equal 1, names.count(t(:ifo_pp_gate))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ifo_pp_hint, :n => 5)
    $game_variables[129] = 9
    assert_includes info_key, t(:ifo_pp_hint, :n => 3)
    $game_variables[129] = 20
    assert_includes info_key, t(:ifo_pp_open)
    $game_switches[297] = true
    refute_includes info_key, t(:ifo_pp_open)
  end

  test "Seafoam's ice wall transfers are named by what they do and a row is one target" do
    on_map(808)
    [[4, 13, 25], [5, 12, 25], [6, 14, 25], [7, 15, 25]].each { |id, x, y| put(id, x, y, :trigger => 0) }
    [[8, 12, 21], [9, 13, 21], [10, 15, 21], [11, 14, 21]].each { |id, x, y| put(id, x, y, :trigger => 0) }
    frame
    names = listed.map { |_x, _y, n| n }
    assert_equal [1, 1], [names.count(t(:ifo_ice_up)), names.count(t(:ifo_ice_down))]
    assert_nil Harness.declared(52)
  end

  test "Vermilion's truck is named on the assist alone and the hint stops once it is pushed" do
    on_map(19)
    put(33, 45, 38)
    frame
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[45, 38, t(:ifo_truck)]], listed
    assert_includes info_key, t(:ifo_truck_hint)
    $game_switches[976] = true
    assert_empty listed
  end

  test "the Bell Tower names its switches and bells and says the free side as the bells flip it" do
    on_map(652)
    [[4, 5, 4], [7, 13, 3], [11, 4, 9], [12, 12, 14]].each { |id, x, y| put(id, x, y) }
    $game_switches[528] = true
    frame
    names = listed.map { |_x, _y, n| n }
    assert_equal [2, 2], [names.count(t(:ifo_bt_switch)), names.count(t(:ifo_bt_bell))]
    assert_equal ["#{t(:ifo_bt_side)}: #{t(:ifo_bt_right)}"], frame { $game_switches[528] = false }
    assert_equal ["#{t(:ifo_bt_side)}: #{t(:ifo_bt_left)}"], frame { $game_switches[528] = true }
    PokeAccess::Config.puzzle_assist = true
    $game_variables[206] = 5
    assert_includes info_key, t(:puzzle_progress, :label => t(:ifo_bt_switches), :n => 2, :of => 2)
  end

  test "the sky lists its stars, says the constellations done and with the assist names them and the Mew rule" do
    on_map(830)
    [[1, 14, 11], [2, 15, 10], [107, 20, 20], [327, 36, 30]].each { |id, x, y| put(id, x, y, :trigger => 1) }
    frame
    assert_equal [t(:ifo_star)] * 4, listed.map { |_x, _y, n| n }
    $game_self_switches[[830, 1, "A"]] = true
    frame
    assert_equal 3, listed.length
    assert_equal ["#{t(:ifo_constellations)}: 1"], frame { $game_variables[320] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed.map { |_x, _y, n| n }, t(:ifo_star_of, :species => PokeAccess::Data.species_name(:WARTORTLE).to_s)
    left = { :IVYSAUR => 10, :WARTORTLE => 10, :ARCANINE => 10, :MACHOKE => 16, :RAPIDASH => 30, :GYARADOS => 8, :ARTICUNO => 10, :MEW => 10 }
    list = [:IVYSAUR, :WARTORTLE, :ARCANINE, :MACHOKE, :RAPIDASH, :GYARADOS, :ARTICUNO, :MEW].map { |s| "#{PokeAccess::Data.species_name(s)} #{left[s]}" }
    assert_includes info_key, t(:ifo_stars_left, :list => list.join(", "))
    $game_variables[302] = 7
    $game_switches[1051] = true
    left.delete(:IVYSAUR)
    left[:WARTORTLE] = 3
    rest = [:WARTORTLE, :ARCANINE, :MACHOKE, :RAPIDASH, :GYARADOS, :ARTICUNO, :MEW].map { |s| "#{PokeAccess::Data.species_name(s)} #{left[s]}" }
    assert_includes info_key, t(:ifo_stars_left, :list => rest.join(", "))
    $game_variables[320] = 8
    $game_variables[222] = 12
    assert_includes info_key, t(:ifo_mew_rule, :karma => 12)
  end

  test "the sky's hint says Mew's stars wait for another telescope visit when the seventh constellation was just completed" do
    on_map(830)
    PokeAccess::Config.puzzle_assist = true
    wait = t(:ifo_stars_left_mew, :list => "\0").split("\0").last
    stars = t(:ifo_stars_left, :list => "\0").split("\0").first
    $game_variables[320] = 7
    assert_includes info_key, wait
    $game_switches[1120] = true
    assert_includes info_key, stars
    refute_includes info_key, wait
    $game_switches[1120] = false
    $game_variables[320] = 6
    refute_includes info_key, wait
    $game_variables[320] = 7
    $game_switches[1058] = true
    refute_includes info_key, wait
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

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

  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                        :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
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
