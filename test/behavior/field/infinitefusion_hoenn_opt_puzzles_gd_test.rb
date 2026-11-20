# Pokemon Infinite Fusion Hoenn's optional puzzles (games/infinitefusion_hoenn/puzzles/ trick_house, illusion_grove, mud_slopes
# and side_stairs): what is named and said without the assist and what the assist adds. Gamedata pass.
class InfinitefusionHoennOptPuzzlesGdTest < PokeAccessTest
  TEMPLATES = { "if_ho_panel" => "panel %{n}", "if_ho_door" => "door %{n}", "if_ho_code_cols" => "left %{left} right %{right}" }

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    $PokemonGlobal.singleton_class.send(:attr_accessor, :bicycle)
    stub_missing_keys
  end

  def teardown
    World.clear_events
    [1031, 1043].each { |i| $game_variables[i] = 0 }
    $game_switches[2154] = false
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    $game_player.singleton_class.send(:remove_method, :direction) rescue nil
    mechanics.forget
    PokeAccess::Caches.reset_all
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    drop_stubbed_keys
    super
  end

  test "the Trick Master's dresser is named once its page runs, and the assist alone says what to do" do
    on_map(99)
    assert_equal [], listed
    put(11, 13, 7)
    assert_equal [[13, 7, t(:if_ho_dresser)]], listed
    refute_includes PokeAccess::Info.map_text.to_s, t(:if_ho_dresser_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Info.map_text, PokeAccess.sentences([t(:if_ho_trick_info), t(:if_ho_dresser_hint)])
    $game_variables[1043] = 2
    refute_includes PokeAccess::Info.map_text.to_s, t(:if_ho_dresser_hint)
  end

  test "the garden's scroll and door are named, the code is said as it is found and the rule needs the assist" do
    on_map(108)
    put(13, 17, 21)
    put(19, 29, 4)
    assert_equal [[17, 21, t(:if_ho_scroll)], [29, 4, t(:if_ho_code_door)]], listed
    assert_equal [], frame
    assert_equal ["#{t(:if_ho_code)}: #{t(:if_ho_code_found)}"], frame { $game_switches[2154] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Info.map_text, t(:if_ho_garden_hint_door)
    $game_self_switches[[108, 19, "A"]] = true
    refute_includes PokeAccess::Info.map_text.to_s, t(:if_ho_garden_hint_door)
  end

  test "the panels and doors of the dark rooms are numbered, a wrong code is said and the assist gives each code by columns" do
    on_map(107)
    load_color_door
    { 1 => [12, 6], 7 => [18, 8], 8 => [24, 10] }.each { |id, (x, y)| put(id, x, y, 1) }
    { 5 => [12, 8], 6 => [18, 10], 9 => [24, 12] }.each { |id, (x, y)| put(id, x, y) }
    names = listed.map { |_x, _y, n| n }
    panels = names.grep(/#{t(:if_ho_panel, :n => '')}/)
    doors = names.grep(/#{t(:if_ho_door, :n => '')}/)
    assert_equal [1, 2, 3].map { |n| t(:if_ho_panel, :n => n) }, panels
    assert_equal [1, 2, 3].map { |n| t(:if_ho_door, :n => n) }, doors
    assert_equal %w[1 2 3], panels.map { |n| n[/\d+/] }
    assert_equal %w[1 2 3], doors.map { |n| n[/\d+/] }
    frame
    assert_equal [], fire(1)
    PokeAccess::Config.puzzle_assist = true
    cols = lambda { |l, r| t(:puzzle_answer, :a => t(:if_ho_code_cols, :left => l, :right => r)) }
    colour = lambda { |*c| c.map { |k| t(k) }.join(", ") }
    assert_equal [cols.call(colour.call(:if2_col_blue, :if2_col_blue, :if2_col_red), colour.call(:if2_col_blue, :if2_col_green, :if2_col_yellow))], fire(1)
    assert_equal [cols.call(colour.call(:if2_col_yellow, :if2_col_yellow, :if2_col_green), colour.call(:if2_col_green, :if2_col_red, :if2_col_green))], fire(8)
    $game_self_switches[[107, 9, "A"]] = true
    assert_equal [], fire(8)
    assert_equal t(:if_ho_wrong_code), PokeAccess::Puzzles.sent_back_line([12, 6, 107], [12, 5, 107], :forced)
  end

  test "the grove's silent jumps are explained, and the Zorua, their count and the legendary passages need the assist" do
    on_map(97)
    [[3, 39, 8], [56, 10, 29], [57, 11, 29], [32, 45, 11]].each { |id, x, y| put(id, x, y, 1) }
    $game_player.moveto(39, 8) rescue nil
    fire(3)
    assert_equal t(:if_ho_grove_moved), PokeAccess::Puzzles.sent_back_line([39, 8, 97], [50, 22, 97])
    assert_equal [], listed
    assert_equal [], fire(56)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[45, 11, t(:if_ho_zorua)]], listed
    assert_equal [t(:if_ho_legend_west)], fire(56)
    assert_equal [t(:if_ho_legend_east)], fire(57)
    assert_includes PokeAccess::Info.map_text, "#{t(:if_ho_zorua_count)}: 0"
    assert_includes frame { $game_variables[1031] = 9 }.join(" "), "#{t(:if_ho_zorua_count)}: 7"
  end

  test "the grove's free camera says a jump with the assist alone, and none while the Zoroark hat is worn" do
    on_map(97)
    put(3, 39, 8, 1)
    put(56, 10, 29, 1)
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y).uniq }
    assert_equal [], lines[39, 8]
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[t(:cam_warp)], []], [lines[39, 8], lines[10, 29]]
    Object.const_set(:HAT_ZOROARK, :zoroark)
    Object.send(:define_method, :isWearingHat) { |hat| hat == :zoroark }
    assert_equal [], lines[39, 8]
  ensure
    Object.send(:remove_method, :isWearingHat) if Object.method_defined?(:isWearingHat)
    Object.send(:remove_const, :HAT_ZOROARK) if Object.const_defined?(:HAT_ZOROARK)
  end

  test "a mud slope is named by its end, a slide is said and a climb on a bike is not" do
    on_map(31)
    put(10, 71, 9, 1, "mudbottom1")
    put(24, 71, 8, 1, "mudtop1")
    assert_equal [[71, 8, t(:if_ho_mud_top)], [71, 9, t(:if_ho_mud_bottom)]], listed
    facing(8)
    fire(10)
    assert_equal t(:if_ho_mud_slid), PokeAccess::Puzzles.sent_back_line([71, 9, 31], [71, 10, 31], :forced)
    $PokemonGlobal.bicycle = true
    assert_nil PokeAccess::Puzzles.sent_back_line([71, 9, 31], [71, 7, 31], :forced)
    facing(2)
    fire(24)
    assert_equal t(:if_ho_mud_slid), PokeAccess::Puzzles.sent_back_line([71, 8, 31], [71, 10, 31], :forced)
    assert_equal [], fire(10)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:if_ho_mud_bike)], fire(10)
  end

  test "the side stairs are named, and the rule is said once on arriving, by the way each map's stairs go" do
    assert_equal [t(:if_ho_side_stairs_rule)], arrive(78)
    put(8, 19, 15, 1)
    put(9, 19, 14, 1)
    assert_equal [[19, 14, t(:if_ho_side_stairs)], [19, 15, t(:if_ho_side_stairs)]], listed
    assert_equal [], fire(8)
    assert_equal [], arrive(78)
    assert_equal [t(:if_ho_side_stairs_rule)], arrive(28)
    put(22, 36, 9, 1)
    put(23, 36, 8, 1)
    assert_equal [[36, 8, t(:if_ho_side_stairs)], [36, 9, t(:if_ho_side_stairs)]], listed
    assert_equal [t(:if_ho_side_stairs_both_rule)], arrive(88)
    [[9, 8, 14], [10, 8, 13], [11, 9, 36], [12, 9, 37], [13, 9, 38]].each { |id, x, y| put(id, x, y, 1) }
    assert_equal 5, listed.length
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  def stub_missing_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed = TEMPLATES.keys.reject { |key| table.key?(key) }
    @stubbed.each { |key| table[key] = TEMPLATES[key] }
  end

  def drop_stubbed_keys
    table = PokeAccess::I18n.table(PokeAccess::I18n::REFERENCE)
    @stubbed.each { |key| table.delete(key) }
  end

  def on_map(map)
    Harness.load_puzzles("infinitefusion_hoenn")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def load_color_door
    path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "color_door.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  end

  def put(id, x, y, trigger = 0, name = "EV#{id}")
    page = TestPage.new(:trigger => trigger, :sprite => "", :list => [TestCmd.new(101, ["x"])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    World.next_frame
    PokeAccess::Puzzles.tick
  end

  def arrive(map)
    on_map(map)
    frame { World.next_frame }
  end

  def facing(direction)
    $game_player.define_singleton_method(:direction) { direction }
  end

  def fire(id)
    SpeakCapture.clear
    ev = $game_map.events[id]
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), id)
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
