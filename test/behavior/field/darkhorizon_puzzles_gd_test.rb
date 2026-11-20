# Dark Horizon's story puzzles (games/darkhorizon/puzzles/) on the shipped profile over events shaped like the game's: the
# dusty lever and the tile door of Obscura Lab, the Shadow Lab's card and codes, the Shadow Factory's key cards, the gem
# bases, the Phantom Path's reset, the box room and the teleporter room of Shadow HQ, Mirage Mansion's library and the stone
# tablet of Faraway Island. What is heard without the puzzle assist is the room and its state; the answers come with it. A hint
# is read as the info key says it, and the words one picks are checked by the texts it asks for. Gamedata pass.
class DarkhorizonPuzzlesGdTest < PokeAccessTest
  MAPS = [83, 84, 95, 101, 103, 104, 105, 111, 112, 113, 115, 118, 151, 152, 153, 160, 165]
  SWITCHES = [105, 119, 138, 139, 140, 141, 142, 143, 172, 187, 215, 344, 345]
  TEMPLATES = { "dh_x_lab_order" => "lab order", "dh_x_lab_w_card" => "lab where card", "dh_x_lab_w_code1" => "lab where code one",
                "dh_x_lab_w_code4" => "lab where code four", "dh_x_lab_w_end" => "lab where end" }

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
    @x = $game_player.x
    @y = $game_player.y
    stub_missing_keys
  end

  def teardown
    World.clear_events
    SWITCHES.each { |i| $game_switches[i] = false }
    [29, 31].each { |i| $game_variables[i] = 0 }
    $game_self_switches = @selfs
    $bag = @bag
    $game_player.x = @x
    $game_player.y = @y
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    drop_stubbed_keys
    super
  end

  test "the dusty lever is named, the unpowered room says why the door stays shut and the assist adds the lever" do
    on_map(83)
    event(39, 11, 5, :sprite => "VisualsInteriorBig1")
    assert_equal [[11, 5, t(:dh_pz_lever)]], listed
    assert_equal t(:dh_pz_no_power), info_key
    refute_includes info_key, t(:dh_pz_lever_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:dh_pz_no_power)}. #{t(:dh_pz_lever_hint)}", info_key
    $game_switches[119] = true
    refute_includes info_key.to_s, t(:dh_pz_no_power)
  end

  test "the tile door says after its second message that the code is a tile puzzle, and the other doors say nothing" do
    on_map(84)
    event(48, 105, 5, :sprite => "DoorSpecial7")
    list = [TestCmd.new(101, ["The door is locked."]), TestCmd.new(101, ["A code seems to secure the door."]), TestCmd.new(0, [])]
    assert_nil read_text(list, 0, 48)
    assert_equal t(:dh_pz_tile_door), read_text(list, 1, 48)
  end

  test "the Shadow Lab says the card and codes held, names its doors by the code only with the assist and the paper while it gives one" do
    on_map(101)
    event(43, 68, 6, :sprite => "DoorSpecial4")
    assert_equal [[68, 6, t(:dh_pz_lab_door)]], listed
    assert_equal t(:dh_pz_lab_card, :card => t(:dh_pz_no)), info_key
    $game_switches[143] = true
    $game_switches[139] = true
    $game_switches[141] = true
    assert_equal t(:dh_pz_lab_card, :card => t(:dh_pz_yes)), info_key
    refute_includes info_key, "1, 3"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[68, 6, t(:dh_pz_lab_door_code, :n => 1)]], listed
    assert_includes info_key, t(:dh_pz_lab_info, :card => t(:dh_pz_yes), :codes => "1, 3")
    on_map(103)
    event(29, 75, 15, :sprite => "SupportChar3")
    assert_equal [[75, 15, t(:dh_pz_lab_paper)]], listed
    $game_switches[139] = true
    assert_equal [], listed
  end

  test "the Shadow Lab's hint gives the whole order while nothing is held, then the next piece and where it is" do
    on_map(105)
    event(18, 34, 3, :sprite => "DoorSpecial4")
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([t(:dh_x_lab_order), t(:dh_pz_lab_h_card), t(:dh_x_lab_w_card)]), hint_text
    $game_switches[143] = true
    assert_equal PokeAccess.sentences([t(:dh_pz_lab_h_code1), t(:dh_x_lab_w_code1)]), hint_text
    [139, 140, 141].each { |i| $game_switches[i] = true }
    assert_equal PokeAccess.sentences([t(:dh_pz_lab_h_code4), t(:dh_x_lab_w_code4)]), hint_text
    $game_switches[142] = true
    assert_equal PokeAccess.sentences([t(:dh_pz_lab_h_end), t(:dh_x_lab_w_end)]), hint_text
    on_map(104)
    event(42, 68, 8, :trigger => 1)
    assert_equal [], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[68, 8, t(:dh_pz_lab_code2_spot)]], listed
    $game_switches[140] = true
    assert_equal [], listed
  end

  test "the factory's doors name their key card only with the assist, the card on the floor is listed and the info key says the cards held" do
    on_map(95)
    $bag = FakeBag.new([])
    [[37, 58, 7], [38, 43, 14], [39, 36, 14]].each { |id, x, y| event(id, x, y, :sprite => "DoorSpecial4") }
    assert_equal [[36, 14, t(:dh_pz_fac_door)], [43, 14, t(:dh_pz_fac_door)], [58, 7, t(:dh_pz_fac_door)]], listed
    assert_equal t(:dh_pz_fac_info, :list => t(:dh_pz_none)), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[36, 14, door(1)], [43, 14, door(1)], [58, 7, door(2)]], listed
    assert_equal PokeAccess.sentences([t(:dh_pz_fac_h1), t(:dh_pz_fac_h2), t(:dh_pz_fac_h3)]), hint_text
    $bag = FakeBag.new([:KEY_FACTORY_2])
    assert_equal PokeAccess.sentences([t(:dh_pz_fac_h1), t(:dh_pz_fac_h3)]), hint_text
    assert_equal t(:dh_pz_fac_info, :list => "2"), PokeAccess::Info.map_text.split(". ").first
    $bag = FakeBag.new([:KEY_FACTORY_1, :KEY_FACTORY_2, :KEY_FACTORY_3])
    assert_equal t(:dh_pz_fac_h_done), hint_text
  end

  test "the factory's info key and hint stop once the factory is done" do
    on_map(95)
    $bag = FakeBag.new([:KEY_FACTORY_2])
    event(37, 58, 7, :sprite => "DoorSpecial4")
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:dh_pz_fac_info, :list => "2")
    $game_switches[105] = true
    refute_includes PokeAccess::Info.map_text.to_s, t(:dh_pz_fac_info, :list => "2")
    assert_equal [[58, 7, door(2)]], listed
  end

  test "the gem bases are named, the count of gems set is said by its value and the assist says who has each missing gem" do
    on_map(111)
    event(18, 49, 6)
    event(19, 53, 6)
    assert_equal [[49, 6, t(:dh_pz_gem_base)], [53, 6, t(:dh_pz_gem_base)]], listed
    frame
    assert_equal [t(:puzzle_value, :label => t(:dh_pz_gems_placed), :v => 1)], frame { $game_variables[29] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[49, 6, t(:dh_pz_base_ruby)], [53, 6, t(:dh_pz_base_sapphire)]], listed
    $bag = FakeBag.new([:RUBY])
    $game_self_switches[[111, 19, "A"]] = true
    assert_equal PokeAccess.sentences([t(:dh_pz_gem_have, :gem => t(:dh_pz_gem_ruby)), t(:dh_pz_gem_emerald_from), t(:dh_pz_gems_open_phantom)]),
                 hint_text
    on_map(113)
    event(22, 34, 5)
    assert_equal [[34, 5, t(:dh_pz_gem_base)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[34, 5, t(:dh_pz_base_emerald)]], listed
    [18, 19].each { |id| $game_self_switches[[111, id, "A"]] = true }
    assert_equal PokeAccess.sentences([t(:dh_pz_gem_emerald_from), t(:dh_pz_gems_open_exit)]), hint_text
    $bag = FakeBag.new([:EMERALD])
    assert_equal PokeAccess.sentences([t(:dh_pz_gem_have, :gem => t(:dh_pz_gem_emerald)), t(:dh_pz_gems_open_exit)]), hint_text
  end

  test "the Phantom Path says a step off the path sent the player back, and its rule only once" do
    on_map(112)
    assert_equal [t(:dh_pz_phantom_fell)], jumped(8, 10, 9, 17)
    refute_includes jumped(8, 10, 9, 12), t(:dh_pz_phantom_fell)
    assert_equal [], jumped(9, 12, 9, 13)
    PokeAccess::Config.verbosity = :full
    on_map(112)
    assert_equal [t(:dh_pz_phantom_rule)], frame
    on_map(112)
    assert_equal [], frame
    $game_switches[215] = true
    on_map(112)
    assert_equal [], frame
  end

  test "the box room says its rule on entering it while the chest is shut, and gives the pushes with the assist" do
    on_map(115)
    $game_player.x = 60
    $game_player.y = 8
    frame
    $game_player.x = 73
    $game_player.y = 7
    assert_equal [t(:dh_pz_boxes_rule)], frame
    assert_equal t(:dh_pz_boxes_rule), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:dh_pz_boxes_rule)}. #{t(:dh_pz_boxes_hint)}", info_key
    PokeAccess::DHBoxes::HOME.each { |id, xy| event(id, xy[0], xy[1]) }
    assert_equal "#{t(:dh_pz_boxes_rule)}. #{t(:dh_pz_boxes_hint)}", info_key
    $game_map.events[50].y = 10
    assert_equal PokeAccess.sentences([t(:dh_pz_boxes_rule), t(:dh_pz_boxes_reset), t(:dh_pz_boxes_hint)]), info_key
    $game_map.events[50].y = 9
    assert_equal "#{t(:dh_pz_boxes_rule)}. #{t(:dh_pz_boxes_hint)}", info_key
    $game_self_switches[[115, 68, "A"]] = true
    assert_equal [], frame
  end

  test "the teleporter room says a floor tile moved the player, names the panel and the laser until it is off" do
    on_map(118)
    event(35, 18, 10)
    event(37, 13, 10)
    event(41, 12, 21, :trigger => 1)
    assert_equal [[13, 10, t(:dh_pz_laser)], [18, 10, t(:dh_pz_laser_panel)]], listed.reject { |r| r[0] == 12 }
    assert_equal t(:dh_pz_laser_on), info_key
    assert_equal t(:dh_pz_wallclock), teleported(41, [12, 21, 118], [26, 19, 118])
    assert_nil teleported(35, [12, 21, 118], [26, 19, 118])
    PokeAccess::Config.puzzle_assist = true
    assert_equal "#{t(:dh_pz_laser_on)}. #{t(:dh_pz_tele_hint)}", info_key
    $game_switches[172] = true
    assert_equal [[18, 10, t(:dh_pz_laser_panel)]], listed
  end

  test "the library counts the journal pages by value, lists those unread and says the pages left and the answering shelf only with the assist" do
    on_map(151)
    event(15, 7, 10)
    event(19, 32, 5)
    assert_equal [[7, 10, t(:dh_pz_journal_page)]], listed
    frame
    assert_equal [t(:puzzle_value, :label => t(:dh_pz_journal_pages), :v => 1)], frame { $game_variables[31] = 1 }
    $game_self_switches[[151, 15, "A"]] = true
    assert_equal [], listed
    $game_variables[31] = 4
    assert_equal [[32, 5, t(:dh_pz_journal_page)]], listed
    on_map(152)
    event(23, 22, 5)
    event(24, 11, 4)
    assert_equal [[11, 4, t(:dh_pz_journal_page)], [22, 5, t(:dh_pz_journal_page)]], listed
    $game_self_switches[[152, 23, "A"]] = true
    assert_equal [[11, 4, t(:dh_pz_journal_page)]], listed
  end

  test "the library's hint counts the pages left in plural, names the library only while its page is unread, and then the shelf" do
    on_map(151)
    event(15, 7, 10)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[:dh_pz_pages_hint, { :n => 5 }], [:dh_pz_pages_library, { :n => 5 }]], hint_calls
    [[151, 15], [151, 19], [152, 23], [152, 24]].each { |m, e| $game_self_switches[[m, e, "A"]] = true }
    assert_equal [[:dh_pz_pages_hint, { :n => 1 }], [:dh_pz_pages_library, { :n => 1 }]], hint_calls
    $game_self_switches[[153, 24, "A"]] = true
    $game_self_switches[[152, 24, "A"]] = false
    assert_equal [[:dh_pz_pages_hint, { :n => 1 }]], hint_calls
    $game_self_switches[[152, 24, "A"]] = true
    assert_equal [], hint_calls
    assert_equal t(:dh_pz_book_hint), hint_text
  end

  test "the three bookshelves read alike, and with the assist only the answering one is named and the others left out" do
    on_map(153)
    event(3, 27, 6, :tile_id => 449)
    event(4, 28, 6, :tile_id => 449)
    event(5, 26, 6, :tile_id => 449)
    assert_equal [[26, 6, t(:dh_pz_shelf)], [27, 6, t(:dh_pz_shelf)], [28, 6, t(:dh_pz_shelf)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[26, 6, t(:dh_pz_shelf)], [27, 6, t(:dh_pz_shelf)], [28, 6, t(:dh_pz_shelf)]].reject { |r| r[0] != 27 }, listed
    [[153, 24], [151, 15], [151, 19], [152, 23], [152, 24]].each { |m, e| $game_self_switches[[m, e, "A"]] = true }
    assert_equal [[27, 6, t(:dh_pz_shelf_book)]], listed
  end

  test "the stone tablet is named, its map and the clearing say the sides in the info key and the hints come only with the assist" do
    on_map(165)
    event(4, 9, 6)
    assert_equal [[9, 6, t(:dh_pz_tablet)]], listed
    assert_equal side(:dh_pz_west, :dh_pz_side_left), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([side(:dh_pz_west, :dh_pz_side_left), t(:dh_pz_tablet_hint)]), info_key
    $game_switches[345] = true
    refute_includes info_key.to_s, t(:dh_pz_tablet_hint)
    on_map(160)
    assert_equal PokeAccess.sentences([side(:dh_pz_east, :dh_pz_side_left), side(:dh_pz_west, :dh_pz_side_left)]), info_key
    $game_switches[344] = true
    assert_equal PokeAccess.sentences([side(:dh_pz_east, :dh_pz_side_done), side(:dh_pz_west, :dh_pz_side_left)]), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:dh_pz_faraway_h_west)
    $game_switches[345] = true
    assert_equal t(:dh_pz_faraway_h_exit), hint_text
    $game_switches[344] = true
    refute_includes info_key.to_s, t(:dh_pz_east)
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

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

  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("darkhorizon")
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
    [29, 31].each { |i| $game_variables[i] = 0 }
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  def event(id, x, y, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :tile_id => opts.fetch(:tile_id, 0), :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def door(n); t(:dh_pz_fac_door_card, :n => n); end

  def hint_text; PokeAccess::Puzzles.label_of(mechanics.instances.first.spec[:hint]); end

  def side(label, state); "#{t(label)}: #{t(state)}"; end

  def hint_calls
    calls = []
    i18n = PokeAccess::I18n
    real = i18n.method(:t)
    i18n.singleton_class.send(:define_method, :t) { |*args| calls.push(args) && real.call(*args) }
    begin
      hint_text
    ensure
      i18n.singleton_class.send(:define_method, :t) { |*args| real.call(*args) }
    end
    calls.select { |k, _v| k.to_s =~ /pages/ }
  end

  def jumped(x, y, tx, ty)
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.clear
    $game_player.x = tx
    $game_player.y = ty
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.log.map { |line, _interrupt| line }
  end

  def info_key; PokeAccess::Info.map_text; end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def teleported(id, from, to)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar($game_map.events[id], :@list), id)
    PokeAccess::Puzzles.sent_back_line(from, to)
  end

  def read_text(list, i, id)
    int = Object.new
    { :@list => list, :@index => i, :@event_id => id, :@branch => { 0 => nil } }.each { |k, v| int.instance_variable_set(k, v) }
    PokeAccess::Puzzles::Reach.forget
    PokeAccess::Puzzles::Reach.before_text(int)
    PokeAccess.take_tail
  end

  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
