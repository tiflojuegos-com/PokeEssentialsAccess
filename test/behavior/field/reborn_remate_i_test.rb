# Pokemon Reborn's puzzle of the remate I (games/reborn/puzzles/glass_blocks.rb): the psychic glass blocks of the Glass
# Workstation's main floor (map 732), planned with both partners from the blocks' variables and Glaceon's channels.
class RebornRemateITest < PokeAccessTest
  SWITCHES = [410, 946, 947, 953, 957, 958, 964, 965]
  VARS = [391, 404, 405, 406, 407] + (396..403).to_a + (408..421).to_a

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @dir = $game_player.direction
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bags = [$bag, $PokemonBag]
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $bag, $PokemonBag = @bags
    $game_player.x, $game_player.y = @at
    $game_player.direction = @dir
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
    refute_includes info_key.to_s, "rbri_"
  end

  test "After freeing Espeon, Glaceon is first taken west of block 1, then Espeon raises it" do
    story(22, 28, 408 => 1)
    glaceon_waits(24, 28)
    assert_includes info_key, "{rbri_leave_fetch where="
    $game_switches[946] = true
    $game_switches[947] = false
    espeon_waits(23, 29)
    refresh
    assert_includes info_key, "{rbri_leave_west}"
    walk(17, 30)
    assert_includes info_key, "{rbri_leave_west_here}"
    $game_switches[946] = false
    glaceon_waits(16, 30)
    refresh
    assert_includes info_key, "{rbri_fetch where="
    $game_switches[947] = true
    $game_variables[406] = 0
    walk(20, 31)
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_up} face={dir_right} left=3 n=1}"
    assert_includes listed, [20, 31, "{rbrc_glass_spot dir={dir_up} n=1}"]
  end

  test "With block 1 up, Glaceon freezes channel 397 and Espeon moves block 10 left to the glass floor" do
    story(48, 36, 408 => 0)
    espeon_waits(16, 30)
    $game_switches[947] = false
    $game_switches[946] = true
    refresh
    assert_includes info_key, "{rbri_step_freeze_here face={dir_up} left=2}"
    assert_equal :rbb_glass_channel_next, PokeAccess::RebornGlassPaths.channel_label(397)
    $game_variables[397] = 60
    walk(47, 30)
    assert_includes info_key, "{rbri_fetch where="
    assert_includes info_key, "who={rbri_espeon}}"
    $game_switches[946] = false
    $game_switches[947] = true
    glaceon_waits(16, 31)
    refresh
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_left} face={dir_up} left=1 n=10}"
    $game_variables[417] = 1
    walk(48, 30)
    assert_includes info_key, "{rbri_goal_glass where="
  end

  test "Glaceon left north of raised block 1 with channel 397 molten is said to be cut off" do
    story(20, 31, 408 => 0)
    glaceon_waits(24, 28)
    refresh
    assert_includes info_key, "{rbri_glaceon_cut}"
  end

  test "A layout off the plan asks to undo the last move, and the assist alone gives the plan" do
    story(20, 31, 408 => 1, 409 => 1, 410 => 1)
    PokeAccess::Config.puzzle_assist = false
    glaceon_waits(16, 30)
    refresh
    refute_includes info_key, "rbri_off_plan"
    assert_includes info_key, "{rbri_glass_rule}"
    moved = "{rbri_glass_moved_item dir={dir_down} n=1}, {rbri_glass_moved_item dir={dir_up} n=2}, " \
            "{rbri_glass_moved_item dir={dir_down} n=3}"
    assert_includes info_key, "{rbri_glass_moved_list list=#{moved}}"
    refute_includes info_key, "rbrc_glass_home"
    PokeAccess::Config.puzzle_assist = true
    refresh
    assert_includes info_key, "{rbri_off_plan}"
  end

  test "After the reader, the doors' plan starts with block 11 back up, and the blocks are told by name and place" do
    story(43, 25, 408 => 1, 416 => 1, 417 => 2, 418 => 1, 420 => 1, 421 => 1)
    $game_variables[397] = 60
    $game_variables[403] = 60
    $game_switches[957] = true
    $game_switches[958] = true
    glaceon_waits(41, 22)
    ev = place(146, 46, 29, "GB10CoreA", "text", "glass5")
    piece = place(148, 47, 29, "GB10B", "text", "")
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_up} face={dir_right} left=4 n=11}"
    gb = PokeAccess::RebornGlassBlocks
    assert_equal "{rbrc_glass_block n=10}", gb.label(ev)
    assert_equal "{rbrc_glass_block n=10}", gb.label(piece)
    assert_equal "{rbrc_glass_wait}", gb.use_line(ev)
    $game_variables[391] = 47
    refresh
    assert_nil gb.phase
  end

  test "The layout passed twice, before and after block 12 goes right and back, is told apart by the player's side" do
    reader(37, 28, 408 => 1, 416 => 1, 417 => 2)
    glaceon_waits(16, 30)
    assert_includes info_key, "{rbrc_glass_step dir={dir_right} face={dir_up} left=6 n=12 where="
    glaceon_waits(41, 22)
    walk(42, 23)
    assert_includes info_key, "{rbrc_glass_step dir={dir_down} face={dir_right} left=4 n=11 where="
  end

  test "Before block 12 goes back, Glaceon is left in the pocket's nook, and Espeon out of the way before fetching it" do
    reader(41, 26, 408 => 1, 416 => 1, 417 => 2, 419 => 1)
    glaceon_waits(16, 30)
    assert_includes info_key, "{rbri_nook_fetch n=12 where="
    assert_includes listed, [16, 30, "{rbri_spot_partner who={rbb_glass_glaceon}}"]
    $game_switches[946] = true
    $game_switches[947] = false
    $game_variables[404] = 0
    espeon_waits(16, 31)
    refresh
    assert_includes info_key, "{rbri_nook_leave n=12 where="
    assert_includes listed, [41, 22, "{rbri_spot_leave who={rbb_glass_glaceon}}"]
    $game_switches[946] = false
    $game_switches[947] = true
    $game_variables[406] = 0
    glaceon_waits(41, 22)
    walk(42, 23)
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_left} face={dir_down} left=5 n=12}"
    $game_variables[419] = 0
    $game_variables[418] = 1
    walk(43, 23)
    assert_includes info_key, "{rbri_clear_leave need={rbb_glass_glaceon} where="
    assert_includes listed, [43, 15, "{rbri_spot_leave who={rbri_espeon}}"]
    $game_switches[947] = false
    espeon_waits(43, 15)
    walk(41, 23)
    assert_includes info_key, "{rbri_fetch where=1 {dir_up} who={rbb_glass_glaceon}}"
  end

  test "For the doors, Glaceon left north of block 11 is fetched to the nook before the block goes up" do
    story(40, 9, 408 => 1, 416 => 1, 417 => 2, 418 => 1, 420 => 1, 421 => 1)
    $game_variables[397] = 60
    $game_variables[403] = 60
    $game_switches[957] = true
    $game_switches[958] = true
    glaceon_waits(42, 16)
    assert_includes info_key, "{rbri_nook_fetch n=11 where="
    $game_variables[402] = 60
    refresh
    assert_includes info_key, "{rbri_nook_fetch n=11 where="
  end

  test "One move off the way keeps a plan: channel 402 frozen early, or every block back in its place" do
    reader(42, 23, 408 => 1, 416 => 1, 417 => 2)
    $game_variables[402] = 60
    glaceon_waits(41, 22)
    assert_includes info_key, "{rbrc_glass_step dir={dir_down} face={dir_right} left=4 n=11 where="
    reader(20, 31, {})
    glaceon_waits(16, 30)
    assert_includes info_key, "{rbrc_glass_step dir={dir_down} face={dir_right} left=9 n=9 where="
    refute_includes info_key, "rbri_off_plan"
  end

  test "Glaceon shut out of the pocket is said, with the move that opens it again" do
    reader(42, 23, 408 => 1, 416 => 1, 417 => 2)
    glaceon_waits(16, 30)
    assert_includes info_key, "{rbri_cut_pocket_here dir={dir_right} face={dir_down} n=12}"
    $game_variables[418] = 1
    walk(43, 24)
    assert_includes info_key, "{rbri_cut_pocket dir={dir_up} face={dir_right} n=11 where="
  end

  test "A partner waiting on the next move's tile is fetched first, and Glaceon's west spot is listed" do
    story(22, 29, 408 => 1)
    glaceon_waits(20, 31)
    assert_includes info_key, "{rbri_in_way where="
    assert_includes info_key, "who={rbb_glass_glaceon}}"
    $game_switches[946] = true
    $game_switches[947] = false
    $game_variables[404] = 0
    espeon_waits(23, 29)
    refresh
    assert_includes listed, [16, 30, "{rbri_spot_leave who={rbb_glass_glaceon}}"]
  end

  test "Block 6 moved up before channel 397 is moved back first, so Glaceon's west spot stays at hand" do
    story(30, 38, 413 => 1)
    glaceon_waits(16, 30)
    assert_includes info_key, "{rbrc_glass_step_here dir={dir_down} face={dir_left} left=3 n=6}"
  end

  private

  def reader(x, y, blocks)
    story(x, y, blocks)
    $game_variables[397] = 60
    $game_switches[957] = true
    card = Object.new
    card.define_singleton_method(:pbQuantity) { |item| item == :METEORCARD ? 1 : 0 }
    card.define_singleton_method(:quantity) { |item| item == :METEORCARD ? 1 : 0 }
    $bag = card
    $PokemonBag = card
    refresh
  end

  def story(x, y, blocks)
    on_map(732, x, y)
    $game_variables[391] = 23
    [396, 398, 399, 400].each { |v| $game_variables[v] = 60 }
    blocks.each { |v, n| $game_variables[v] = n }
    $game_switches[410] = true
    $game_switches[947] = true
    PokeAccess::Config.puzzle_assist = true
    refresh
  end

  def glaceon_waits(x, y)
    $game_variables[404] = x
    $game_variables[405] = y
    refresh
  end

  def espeon_waits(x, y)
    $game_variables[406] = x
    $game_variables[407] = y
  end

  def walk(x, y)
    $game_player.x = x
    $game_player.y = y
    refresh
  end

  def refresh
    PokeAccess::Caches.reset_all
    World.next_frame
  end

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbri_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbri_kept_t)
    i18n.send(:remove_method, :rbri_kept_t)
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

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
