# Fire Ash's puzzles that stand in the story's way (games/fireash/puzzles/): Vermilion's trash cans, the gyms of pads, ladders
# and doors, Nacrene's bookcases, Cinnabar's mansion and lava switch and Route 20's Serena, on the shipped profile over events
# shaped like the game's. What is heard without the puzzle assist is the room and its state; the answers come with it.
# Gamedata pass.
class FireashPuzzlesGdTest < PokeAccessTest
  MAPS = [112, 136, 189, 190, 191, 192, 193, 413, 442, 611, 673, 840, 865]
  CAN_AT = { 15 => [18, 11], 16 => [18, 13], 17 => [16, 13], 18 => [14, 11], 19 => [14, 13], 20 => [12, 13], 21 => [12, 11],
             22 => [10, 11], 23 => [10, 13], 24 => [8, 13], 25 => [8, 11], 26 => [6, 13], 28 => [6, 11], 29 => [16, 11] }
  CANS = CAN_AT.keys

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
    [6, 43, 44, 59, 60, 61, 119, 215, 270, 271].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Config.verbosity = :full
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Vermilion lists its fourteen trash cans, with the assist only the two that work, and says which row a switch turns off" do
    on_map(112)
    CANS.each { |id| can(id, *CAN_AT[id]) }
    assert_equal [t(:fa_trash_can)], listed.map { |_x, _y, n| n }.uniq
    assert_equal 14, listed.length
    assert_equal [t(:fa_surge_rule)], frame
    assert_equal [t(:fa_surge_row_one)], frame { $game_switches[43] = true }
    assert_equal [t(:fa_surge_row_two)], frame { $game_switches[44] = true }
    $game_switches[43] = $game_switches[44] = false
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[6, 11, t(:fa_trash_can_switch)], [14, 11, t(:fa_trash_can_switch)]], listed
    assert_includes info_key, t(:fa_surge_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:fa_surge_hint)
  end

  test "Saffron's pads are named, the ones nearing Sabrina told apart with the assist, and a jump says why" do
    on_map(136)
    pad(3, 29, 27, 136, [19, 23])
    pad(4, 19, 23, 136, [29, 27])
    assert_equal [[19, 23, t(:fa_pad)], [29, 27, t(:fa_pad)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[19, 23, t(:fa_pad_towards)], [29, 27, t(:fa_pad)]], listed
    fire(@events[4])
    assert_equal t(:fa_pad_sent), PokeAccess::Puzzles.sent_back_line([19, 23, 136], [29, 27, 136])
  end

  test "Saffron's shortcut pad, once its self switch is on, changes which pads near Sabrina" do
    on_map(136)
    pad(4, 19, 23, 136, [29, 27])
    pad(3, 29, 27, 136, [19, 23])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[19, 23, t(:fa_pad_towards)], [29, 27, t(:fa_pad)]], listed
    $game_self_switches[[136, 42, "A"]] = true
    assert_equal [[19, 23, t(:fa_pad)], [29, 27, t(:fa_pad_towards)]], listed
  end

  test "Sabrina's second fight ends the rule of the pads" do
    on_map(136)
    pad(4, 19, 23, 136, [29, 27])
    assert_equal [t(:fa_pads_rule)], frame
    $game_self_switches[[136, 39, "B"]] = true
    mechanics.forget
    assert_equal [], frame
  end

  test "Mossdeep's one-way pad says so when used, the others as any pad" do
    on_map(442)
    pad(7, 35, 8, 442, [13, 25])
    pad(1, 10, 25, 442, [8, 9])
    frame
    fire(@events[7])
    assert_equal t(:fa_pad_oneway), PokeAccess::Puzzles.sent_back_line([35, 8, 442], [13, 25, 442])
    fire(@events[1])
    assert_equal t(:fa_pad_sent), PokeAccess::Puzzles.sent_back_line([10, 25, 442], [8, 9, 442])
  end

  test "Mossdeep names the one-way pad as any pad even with the assist, and a pad inside its room says nothing of another room" do
    on_map(442)
    pad(7, 35, 8, 442, [13, 25])
    pad(5, 38, 19, 442, [40, 30])
    assert_equal [[35, 8, t(:fa_pad)], [38, 19, t(:fa_pad)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[35, 8, t(:fa_pad)], [38, 19, t(:fa_pad)]], listed
    frame
    fire(@events[5])
    assert_nil PokeAccess::Puzzles.sent_back_line([38, 19, 442], [40, 30, 442])
  end

  test "Lavaridge's ladders are told by the assist and Valerie's pads likewise" do
    on_map(413)
    pad(1, 9, 23, 413, [38, 24])
    pad(2, 39, 24, 413, [10, 23])
    assert_equal [[9, 23, t(:fa_ladder)], [39, 24, t(:fa_ladder)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[9, 23, t(:fa_ladder_towards)], [39, 24, t(:fa_ladder)]], listed
    on_map(840)
    pad(4, 19, 23, 840, [29, 23])
    pad(3, 29, 23, 840, [19, 23])
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[19, 23, t(:fa_pad_towards)], [29, 23, t(:fa_pad)]], listed
  end

  test "Valerie's gym does not name its trainers as pads" do
    on_map(840)
    pad(4, 19, 23, 840, [29, 23])
    [6, 12, 14].each_with_index { |id, i| put(id, 25, 22 + i, :trigger => 2, :sprite => "trchar007") }
    assert_equal [[19, 23, t(:fa_pad)]], listed
  end

  test "Fantina's five doors are numbered, and the assist says the second is hers" do
    on_map(611)
    { 3 => 16, 9 => 20, 10 => 24, 11 => 28, 12 => 32 }.each { |id, x| pad(id, x, 41, 611, [24, 11]) }
    assert_equal %w[fa_door_1 fa_door_2 fa_door_3 fa_door_4 fa_door_5].map { |k| t(k.to_sym) }, listed.map { |_x, _y, n| n }
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:fa_door_2_right), listed[1][2]
    put(13, 3, 11, :trigger => 1, :list => [TestCmd.new(201, [0, 611, 16, 41, 8, 0]), TestCmd.new(0, [])])
    assert_equal t(:fa_pad_back), listed.find { |x, _y, _n| x == 3 }[2]
    PokeAccess::Config.puzzle_assist = false
    assert_equal t(:fa_pad), listed.find { |x, _y, _n| x == 3 }[2]
    PokeAccess::Config.puzzle_assist = true
    fire(@events[9])
    assert_equal t(:fa_door_sent), PokeAccess::Puzzles.sent_back_line([20, 41, 611], [24, 11, 611])
  end

  test "Nacrene's bookcases are listed alike, with the assist only the one with the switch, and nothing once it is on" do
    on_map(673)
    [9, 13, 14, 16, 17, 21, 25].each_with_index { |id, i| put(id, 10 + i, 11) }
    assert_equal [t(:fa_bookcase)], listed.map { |_x, _y, n| n }.uniq
    assert_equal 7, listed.length
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[16, 11, t(:fa_bookcase_switch)]], listed
    $game_switches[215] = true
    assert_equal [], listed
  end

  test "Cinnabar's lava switch is listed from Blaine's first fight until it is pressed" do
    on_map(193)
    put(28, 12, 65, :trigger => 1)
    assert_equal [], listed
    $game_switches[60] = true
    assert_equal [[12, 65, t(:fa_lava_switch)]], listed
    $game_switches[61] = true
    assert_equal [], listed
  end

  test "the mansion's stairs say where they go, and with the assist the ones that near the basement" do
    on_map(190)
    pad(1, 14, 6, 191, [15, 6])
    pad(4, 8, 17, 189, [13, 17])
    assert_equal [[8, 17, t(:fa_stairs_1f)], [14, 6, t(:fa_stairs_3f)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[8, 17, t(:fa_stairs_1f)], [14, 6, t(:fa_mansion_towards, :label => t(:fa_stairs_3f))]], listed
    mechanics.forget
    assert_equal [t(:fa_mansion_rule)], frame
    $game_switches[59] = true
    assert_equal [[8, 17, t(:fa_stairs_1f)], [14, 6, t(:fa_stairs_3f)]], listed
  end

  test "the mansion's third floor names its stairs and leaves the items it holds alone" do
    on_map(191)
    pad(3, 42, 27, 190, [46, 17])
    put(4, 47, 21, :sprite => "Object ball")
    put(5, 47, 22)
    assert_equal [[42, 27, t(:fa_stairs_2f)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[42, 27, t(:fa_mansion_towards, :label => t(:fa_stairs_2f))]], listed
  end

  test "Route 20 says with the assist alone to go to Serena between Wulfric's two fights" do
    on_map(865)
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::Puzzles.active?
    $game_switches[270] = true
    assert PokeAccess::Puzzles.active?
    assert_includes info_key, t(:fa_route20_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key.to_s, t(:fa_route20_hint)
    $game_switches[271] = true
    refute PokeAccess::Puzzles.active?
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("fireash")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
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

  # An event on the map: the pages given, else one with the trigger, sprite and commands of opts.
  def put(id, x, y, opts = {})
    pages = opts.fetch(:pages) do
      [TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                    :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))]
    end
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => opts.fetch(:tile_id, 0), :pages => pages)
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # A touch event that only transfers to the tile to of a map, as the pads, ladders and doors.
  def pad(id, x, y, map, to)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(201, [0, map, to[0], to[1], 8, 0]), TestCmd.new(0, [])])
  end

  # One of Vermilion's trash cans: the two that work turn on their switch, the rest only say a line.
  def can(id, x, y)
    switch = { 18 => 43, 28 => 44 }[id]
    commands = switch ? [TestCmd.new(101, ["..."]), TestCmd.new(121, [switch, switch, 0])] : [TestCmd.new(101, ["..."])]
    put(id, x, y, :list => commands + [TestCmd.new(0, [])])
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
