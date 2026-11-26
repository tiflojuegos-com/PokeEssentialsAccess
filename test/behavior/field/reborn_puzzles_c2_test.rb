# Pokemon Reborn's puzzles of part C2 (games/reborn/puzzles/): Victory Road's logic blocks, minecarts and levers, gem
# rooms (crystals, Decidueye's arrow, the Amethyst orb), Labradorra's chest and the Glass Workstation's floor. Without the
# assist, what the screen shows; with it, the way.
class RebornPuzzlesC2Test < PokeAccessTest
  SWITCHES = [1098, 1158, 1160, 1218, 2226]
  VARS = [501, 503, 520, 521]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::RebornVrGemRooms.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "A logic block says its gem, quality and value as the game reads them, and the assist where it goes" do
    on_map(789, 15, 16)
    %w[SIZE: Miniscule Small Medium Large].each_with_index { |w, k| place(42 + k, 16 + k, 10, "EV0#{42 + k}", "\"#{w}\"") }
    ruby = place(5, 16, 12, "Tuner R-1")
    amethyst = place(17, 16, 15, "Tuner P-1")
    assert_equal "{rbc2_logic_block gem={rbc2_gem_ruby} quality=SIZE: value={rbc2_logic_none}}",
                 PokeAccess::Puzzles.piece_name(ruby)
    ruby.x = 17
    assert_equal "{rbc2_logic_block gem={rbc2_gem_ruby} quality=SIZE: value=Miniscule}", PokeAccess::Puzzles.piece_name(ruby)
    assert_equal "{rbc2_logic_block gem={rbc2_gem_amethyst} quality=SIZE: value={rbc2_logic_none}}",
                 PokeAccess::Puzzles.piece_name(amethyst)
    refute_includes info_key, "rbc2_logic_count"
    PokeAccess::Config.puzzle_assist = true
    name = "{rbc2_logic_block gem={rbc2_gem_ruby} quality=SIZE: value=Miniscule}"
    assert_equal "{rbc2_logic_push_right count=2 name=#{name} value=Medium}", PokeAccess::Puzzles.piece_name(ruby)
    ruby.x = 19
    assert_equal "{rbc2_logic_placed name={rbc2_logic_block gem={rbc2_gem_ruby} quality=SIZE: value=Medium}}",
                 PokeAccess::Puzzles.piece_name(ruby)
    assert_equal 1, PokeAccess::RebornVrLogic.placed
    refute PokeAccess::RebornVrLogic.all_placed?
    amethyst.x = 20
    assert_equal 2, PokeAccess::RebornVrLogic.placed
  end

  test "A minecart is named by its load, and the assist says where it would go with the levers as they stand" do
    on_map(790, 61, 46)
    cart = place_cart(41, 58, 52)
    assert_equal "{rbc2_cart}", PokeAccess::Puzzles.piece_name(cart)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{rbc2_cart_takes name={rbc2_cart} where=3 {dir_left}, 2 {dir_up}}", PokeAccess::Puzzles.piece_name(cart)
    $game_switches[1160] = true
    assert_equal "{rbc2_cart_takes name={rbc2_cart} where=4 {dir_right}, 3 {dir_up}}", PokeAccess::Puzzles.piece_name(cart)
    $game_variables[503] = 1
    assert_equal "{rbc2_cart_takes name={rbc2_cart} where=1 {dir_down}}", PokeAccess::Puzzles.piece_name(cart)
    $game_variables[503] = 2
    assert_equal "{rbc2_cart_still name={rbc2_cart}}", PokeAccess::Puzzles.piece_name(cart)
    cart.character_name = "minecart3"
    assert_equal "{rbc2_cart_still name={rbc2_cart_blast}}", PokeAccess::Puzzles.piece_name(cart)
  end

  test "A lever says whether its switch is on" do
    on_map(790, 56, 41)
    off = TestPage.new(:trigger => 0, :list => [TestCmd.new(121, [1160, 1160, 0]), TestCmd.new(0, [])])
    on = TestPage.new(:trigger => 0, :condition => { :switch1_valid => true, :switch1_id => 1160 },
                      :list => [TestCmd.new(121, [1160, 1160, 1]), TestCmd.new(0, [])])
    lever = TestGameEvent.new(:id => 33, :x => 57, :y => 41, :name => "EV033", :pages => [off, on], :active_page => off)
    $game_map.events[33] = lever
    World.next_frame
    assert_equal "{rbc2_lever_off}", PokeAccess::Puzzles.piece_name(lever)
    $game_switches[1160] = true
    assert_equal "{rbc2_lever_on}", PokeAccess::Puzzles.piece_name(lever)
  end

  test "A key crystal says once its switch is on" do
    on_map(804, 43, 63)
    crystal = place(27, 43, 62, "EV027")
    assert_equal "{rbc2_crystal}", PokeAccess::Puzzles.piece_name(crystal)
    $game_switches[1218] = true
    assert_equal "{rbc2_crystal_on}", PokeAccess::Puzzles.piece_name(crystal)
  end

  test "Decidueye's arrow is said once a shot as it falls down the player's column" do
    rooms = PokeAccess::RebornVrGemRooms
    on_map(805, 30, 40)
    arrow = place(102, 0, 1, "Arrow")
    assert_empty spoken { rooms.tick }
    arrow.x = 31
    arrow.y = 22
    assert_empty spoken { rooms.tick }
    arrow.x = 30
    assert_equal ["{rbc2_emerald_arrow}"], spoken { rooms.tick }
    arrow.y = 30
    assert_empty spoken { rooms.tick }
    arrow.x = 0
    arrow.y = 1
    rooms.tick
    arrow.x = 30
    arrow.y = 22
    assert_equal ["{rbc2_emerald_arrow}"], spoken { rooms.tick }
    arrow.x = 0
    arrow.y = 1
    rooms.tick
    PokeAccess::Config.puzzle_assist = true
    arrow.x = 30
    arrow.y = 22
    assert_equal ["{rbc2_emerald_arrow}. {rb3_dodge_column}"], spoken { rooms.tick }, "the dodge, with the assist alone"
  end

  test "The Amethyst Room lists the flashing crystal and counts the broken ones up to five" do
    on_map(806, 30, 30)
    $game_variables[520] = 3
    World.next_frame
    assert_includes listed, [35, 32, "{rbc2_amethyst_crystal}"]
    assert_includes info_key, "rbc2_amethyst_count"
    $game_variables[520] = 5
    World.next_frame
    assert_includes listed, [26, 47, "{rbc2_amethyst_crystal}"]
    assert_equal 2, PokeAccess::RebornVrGemRooms.broken
    $game_variables[520] = 9
    assert_equal 5, PokeAccess::RebornVrGemRooms.broken
    World.next_frame
    refute(listed.any? { |t| t[2] == "{rbc2_amethyst_crystal}" })
  end

  test "Labradorra's foes are named by species, and the assist says which is nearest the chest" do
    on_map(779, 26, 50)
    blaziken = place(78, 25, 70, "5-Blaziken", "text", "pkmn_blaziken")
    knight = place(88, 30, 45, "4-KnightA", "text", "trchar148")
    assert_equal "Blaziken", PokeAccess::Puzzles.piece_name(blaziken)
    assert_equal "{rbc2_labradorra_knight}", PokeAccess::Puzzles.piece_name(knight)
    refute_includes info_key, "rbc2_labradorra_nearest"
    PokeAccess::Config.puzzle_assist = true
    line = "{rbc2_labradorra_nearest count=5 name={rbc2_labradorra_knight} where=4 {dir_right}, 5 {dir_up}}"
    assert_includes info_key, line
    $game_switches[1098] = true
    refute_includes info_key, "rbc2_labradorra_nearest"
  end

  test "The Glass Workstation's floor is named until Rock Smash breaks it into a hole" do
    on_map(732, 58, 28)
    glass = place(52, 58, 27, "Glass")
    assert_equal "{rbc2_glass_floor}", PokeAccess::Puzzles.piece_name(glass)
    $game_self_switches[[732, 52, "A"]] = true
    assert_equal "{rbc2_glass_hole}", PokeAccess::Puzzles.piece_name(glass)
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbc2_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbc2_kept_t)
    i18n.send(:remove_method, :rbc2_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, text = "text", sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, [text]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A cart shaped as map 790's fourth: from station 0 up three with the player, then left three to station 1 with lever
  # 1160 off or right three to station 2 with it on; past the branches the player jumps out, down at station 1 (read as
  # the page has just set it), ahead elsewhere.
  def place_cart(id, x, y)
    use = TestPage.new(:trigger => 0, :sprite => "minecart1", :list => [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])])
    ride = TestPage.new(:trigger => 4, :sprite => "minecart1", :condition => { :self_switch_valid => true, :self_switch_ch => "A" },
                        :list => [
                          TestCmd.new(355, ["hookBeforeMineCart"]),
                          TestCmd.new(209, [-1, moves(12)]),
                          TestCmd.new(111, [1, 503, 0, 0, 0], 0),
                          TestCmd.new(209, [0, moves(4, 4, 4)], 1),
                          TestCmd.new(209, [-1, moves(4, 4, 4)], 1),
                          TestCmd.new(111, [0, 1160, 0], 1),
                          TestCmd.new(209, [0, moves(3, 3, 3)], 2),
                          TestCmd.new(209, [-1, moves(3, 3, 3)], 2),
                          TestCmd.new(122, [503, 503, 0, 0, 2], 2),
                          TestCmd.new(411, [], 1),
                          TestCmd.new(209, [0, moves(2, 2, 2)], 2),
                          TestCmd.new(209, [-1, moves(2, 2, 2)], 2),
                          TestCmd.new(122, [503, 503, 0, 0, 1], 2),
                          TestCmd.new(412, [], 1),
                          TestCmd.new(411, [], 0),
                          TestCmd.new(412, [], 0),
                          TestCmd.new(111, [1, 503, 0, 1, 0], 0),
                          TestCmd.new(209, [-1, moves(16, 12)], 1),
                          TestCmd.new(411, [], 0),
                          TestCmd.new(209, [-1, moves(12)], 1),
                          TestCmd.new(412, [], 0),
                          TestCmd.new(0, [])
                        ])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Cart3", :pages => [use, ride], :active_page => use)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def moves(*codes)
    TestMoveRoute.new(codes.map { |c| TestMoveCmd.new(c) } + [TestMoveCmd.new(0)])
  end

  def spoken
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
