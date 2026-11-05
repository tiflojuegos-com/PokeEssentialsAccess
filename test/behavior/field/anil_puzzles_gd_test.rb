# Anil's puzzles that stand in the story's way (games/anil/puzzles/): Blaine's riddle doors, Vermilion's bins, Saffron's pads,
# the Burned Mansion's statues and Viridian's keys, on the shipped profile over events shaped like the game's. What is heard
# without the puzzle assist is the room and its state; the answers come with it. Gamedata pass.
class AnilPuzzlesGdTest < PokeAccessTest
  TileGraphic = Struct.new(:character_name, :pattern, :tile_id)
  MAPS = [56, 119, 120, 121, 122, 127, 128, 131, 182, 213, 186, 190, 198]

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
    [64, 126, 128, 129, 130].each { |i| $game_variables[i] = 0 }
    [196, 202, 203, 204, 205, 206, 210, 226, 227, 228, 269, 270].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Config.verbosity = :full
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Blaine's doors are named by their room, count the rooms crossed and say why the player was moved" do
    on_map(131)
    { 14 => [5, 27], 16 => [9, 27], 17 => [13, 27], 21 => [31, 27], 54 => [57, 5] }.each { |id, (x, y)| door(id, x, y) }
    assert_equal [[5, 27, door_name(1)], [9, 27, door_name(1)], [13, 27, door_name(1)], [31, 27, door_name(2)],
                  [57, 5, door_name(5)]], listed
    frame
    assert_equal PokeAccess.sentences([rooms(0), t(:anil_riddle_rule)]), info_key
    assert_equal [rooms(1)], frame { $game_variables[64] = 1 }
    fire(@events[14])
    assert_equal t(:anil_riddle_passed), PokeAccess::Puzzles.sent_back_line([5, 27, 131], [35, 37, 131])
    fire(@events[54])
    assert_equal t(:anil_riddle_leader), PokeAccess::Puzzles.sent_back_line([57, 5, 131], [9, 15, 131])
    assert_equal [rooms(5)], frame { $game_variables[64] = 5 }
    refute PokeAccess::Puzzles.active?
  end

  test "Blaine's doors say with the assist alone the right option of the riddle asked, in the game's words" do
    on_map(131)
    door(14, 5, 27)
    add = TestCmd.new(122, [62, 62, 1, 0, 1], 1)
    list = [TestCmd.new(101, ["Which one?"], 0), TestCmd.new(102, [%w[Arcanine Magmar Rapidash], 1], 0),
            TestCmd.new(402, [0, "Arcanine"], 0), add, TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Magmar"], 0), TestCmd.new(0, [], 1),
            TestCmd.new(402, [2, "Rapidash"], 0), add, TestCmd.new(0, [], 1), TestCmd.new(404, [], 0), TestCmd.new(0, [], 0)]
    interpreter = Object.new
    { :@list => list, :@index => 0, :@event_id => 14 }.each { |k, v| interpreter.instance_variable_set(k, v) }
    frame
    PokeAccess::Puzzles::Answers.before_text(interpreter)
    assert_nil PokeAccess.take_tail
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Puzzles::Answers.before_text(interpreter)
    assert_equal t(:puzzle_answer, :a => "Magmar"), PokeAccess.take_tail
  end

  test "Vermilion's bins are named by row and column, the ones with a switch told apart with the assist" do
    on_map(56)
    (16..30).each { |id| bin(id) }
    $game_variables[126] = 7
    $game_variables[128] = 12
    names = lambda { listed.map { |_x, _y, name| name } }
    assert_equal 15, names.call.length
    assert_equal t(:anil_bin, :r => 1, :c => 1), listed.first[2]
    assert_equal t(:anil_bin, :r => 3, :c => 5), listed.last[2]
    assert_equal 15, names.call.count { |n| n =~ /\A#{Regexp.escape(t(:anil_bin, :r => 0, :c => 0)[0, 3])}/ }
    refute_includes names.call, t(:anil_bin_switch, :r => 2, :c => 2)
    PokeAccess::Config.puzzle_assist = true
    assert_includes names.call, t(:anil_bin_switch, :r => 2, :c => 2)
    assert_includes names.call, t(:anil_bin_switch, :r => 3, :c => 2)
    assert_equal 2, names.call.count { |n| n =~ /interruptor|switch/ }
    $game_variables[126] = 3
    $game_variables[128] = 0
    assert_includes names.call, t(:anil_bin_switch, :r => 1, :c => 3)
    assert_equal 1, names.call.count { |n| n =~ /interruptor|switch/ }
  end

  test "Vermilion counts the bins found, says when they are dealt again, and drops the barrier's name on a wall" do
    on_map(56)
    (16..30).each { |id| bin(id) }
    wall = barrier(10, 8)
    frame
    assert_equal t(:anil_bin_barrier), PokeAccess::Puzzles.piece_name(wall)
    assert_equal PokeAccess.sentences([found(0), t(:anil_bin_rule)]), info_key
    assert_equal [found(1)], frame { $game_variables[130] = 1 }
    assert_equal [PokeAccess.sentences([t(:puzzle_reset), found(0)])], frame { $game_variables[130] = 0 }
    assert_equal [found(1)], frame { $game_variables[130] = 1 }
    assert_equal [found(2)], frame { $game_variables[130] = 2 }
    refute PokeAccess::Puzzles.active?
  end

  test "Saffron's pads are named, the way to the leader marked with the assist, and a pad says why the player moved" do
    on_map(127)
    { 7 => [49, 42], 8 => [42, 42], 9 => [49, 38], 10 => [42, 38] }.each { |id, (x, y)| pad(id, x, y) }
    assert_equal [[42, 38, t(:anil_pad)], [42, 42, t(:anil_pad)], [49, 38, t(:anil_pad)], [49, 42, t(:anil_pad_exit)]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[42, 38, t(:anil_pad_towards)], [42, 42, t(:anil_pad)], [49, 38, t(:anil_pad)],
                  [49, 42, t(:anil_pad_exit)]], listed
    fire(@events[10])
    assert_equal t(:anil_pad_sent), PokeAccess::Puzzles.sent_back_line([42, 38, 127], [48, 8, 127])
    on_map(128)
    pad(3, 10, 6)
    assert_equal [[10, 6, t(:anil_pad_in)]], listed
  end

  test "Saffron's way to the leader has one pad out of the first room and three or one in the others" do
    pads = PokeAccess::AnilPads
    rooms = [[7, 8, 9, 10], [11, 12, 13, 14], [34, 35, 36, 37], [15, 16, 17, 18], [30, 31, 32, 33], [19, 20, 21, 22],
             [23, 24, 25, 26]]
    rooms.each { |room| assert room.any? { |id| pads::TOWARDS_LEADER.include?(id) }, "room #{room.inspect}" }
    assert_equal [10], rooms[0] & pads::TOWARDS_LEADER
    assert_equal [29], [27, 28, 29, 42] & pads::TOWARDS_LEADER
    assert_equal pads::TOWARDS_LEADER, pads::TOWARDS_LEADER.uniq
  end

  test "the Burned Mansion's statues are told apart by floor, say the walls they move and, as the core does, what opened" do
    on_map(119)
    PokeAccess::Config.verbosity = :medium
    statue(20, 7, 5, 202)
    walls = [wall_tile(21, 26, 19, 3015, 202), wall_tile(22, 27, 19, 3015, 202)]
    frame
    assert_includes listed, [7, 5, t(:anil_statue_floor, :n => 1)]
    pressed = PokeAccess.sentences(["#{t(:anil_statue_floor, :n => 1)}: #{t(:anil_statue_on)}",
                                    t(:ctrl_group, :what => t(:anil_tile_wall), :changes => t(:ctrl_quit, :n => 2))])
    fire(@events[20])
    $game_switches[202] = true
    walls.each { |wall| wall.tile_id = 0 }
    assert_equal [pressed, t(:chg_open_one)], frames(PokeAccess::Puzzles::Auto::SETTLE)
  end

  test "the side floors' statues say with the assist what they open, the second floor's that it cuts the way up" do
    { 119 => [20, 7, 5, 202, :anil_mansion_opens_one], 120 => [18, 6, 20, 203, :anil_mansion_opens_cut],
      121 => [17, 20, 6, 204, :anil_mansion_opens_two] }.each do |map, (id, x, y, switch, opens)|
      on_map(map)
      statue(id, x, y, switch)
      frame
      refute_includes info_key, t(opens), "map #{map} without the assist"
      refute_includes info_key, t(:anil_mansion_side_hint), "map #{map} without the assist"
      PokeAccess::Config.puzzle_assist = true
      assert_includes info_key, t(opens), "map #{map}"
      assert_includes info_key, t(:anil_mansion_side_hint), "map #{map}"
    end
  end

  test "the Burned Mansion's fourth floor tells its statues apart and, with the assist, which to press next" do
    on_map(122)
    statue(35, 28, 42, 205)
    statue(36, 39, 5, 206)
    frame
    assert_equal [[28, 42, t(:anil_statue_south)], [39, 5, t(:anil_statue_north)]], listed.sort_by { |x, _y, _n| x }
    refute_includes info_key, t(:anil_mansion_hint_south)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:anil_mansion_hint_south)
    frame { $game_switches[205] = true }
    assert_includes info_key, t(:anil_mansion_hint_north)
    frame { $game_switches[206] = true }
    assert_includes info_key, t(:anil_mansion_hint_open)
  end

  test "Saffron's pads say their rule on entering until Sabrina's medal is won, then not even that" do
    on_map(127)
    assert_equal [t(:anil_pads_rule)], frame
    on_map(127)
    $game_switches[196] = true
    assert_empty frame
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "every floor of the Burned Mansion says its rule on entering until Surya is beaten, and only her floor's info key ends with her" do
    { 119 => [20, 7, 5, 202], 120 => [18, 6, 20, 203], 121 => [17, 20, 6, 204], 122 => [35, 28, 42, 205] }.each do |map, (id, x, y, switch)|
      on_map(map)
      statue(id, x, y, switch)
      assert_equal [t(:anil_mansion_rule)], frame, "map #{map} before"
      refute_nil PokeAccess::Puzzles.info_line, "map #{map} before"
      on_map(map)
      $game_switches[210] = true
      statue(id, x, y, switch)
      assert_empty frame, "map #{map} after"
      assert_equal map == 122, PokeAccess::Puzzles.info_line.nil?, "map #{map} after"
      $game_switches[210] = false
    end
  end

  test "Viridian's keys and two-key door are named, the keys counted and the sliding floor explained" do
    on_map(182)
    tile_event(8, 15, 24, 5186)
    tile_event(9, 35, 21, 5184)
    door(16, 5, 5)
    door(20, 6, 5)
    frame
    assert_equal [[5, 5, t(:anil_two_key_door)], [6, 5, t(:anil_two_key_door)], [15, 24, t(:anil_key_red)],
                  [35, 21, t(:anil_key_blue)]], listed
    assert_equal PokeAccess.sentences([keys(0), t(:anil_slide_rule)]), info_key
    assert_equal [keys(1)], frame { $game_switches[226] = true }
    assert_equal [keys(2)], frame { $game_switches[227] = true }
    $game_switches[228] = true
    refute PokeAccess::Puzzles.active?
  end

  test "each room says its rule on entering in full, queued, and the other levels leave it to the info key" do
    { 131 => :anil_riddle_rule, 56 => :anil_bin_rule, 127 => :anil_pads_rule, 119 => :anil_mansion_rule,
      182 => :anil_slide_rule }.each do |map, rule|
      on_map(map)
      PokeAccess::Config.verbosity = :full
      assert_equal [t(rule)], frame, "map #{map}"
      on_map(map)
      PokeAccess::Config.verbosity = :medium
      assert_equal [], frame, "map #{map} at medium"
    end
    PokeAccess::Config.verbosity = :full
  end

  test "the Secret Warehouse's door is named and, with the assist, the passwords known are counted" do
    on_map(213)
    put(4, 31, 28, :trigger => 1)
    frame
    assert_equal [[31, 28, t(:anil_password_door)]], listed
    refute_includes info_key, t(:anil_passwords)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, passwords(0)
    assert_empty frame { $game_switches[269] = true }
    assert_includes info_key, passwords(1)
    $game_switches[270] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the Guardian Bird altars are named on each island where the game hides one" do
    { 186 => [13, 38, 13], 190 => [8, 24, 11], 198 => [29, 57, 68] }.each do |map, (id, x, y)|
      on_map(map)
      put(id, x, y, :list => [TestCmd.new(101, ["..."]), TestCmd.new(355, ["pbItemBall(:PLUMAZAPDOS)"]), TestCmd.new(0, [])])
      frame
      assert_equal [[x, y, t(:anil_altar)]], listed, "map #{map}"
    end
  end

  private

  # The Secret Warehouse's count of passwords known, as said.
  def passwords(n); t(:puzzle_progress, :label => t(:anil_passwords), :n => n, :of => 2); end

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("anil")
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

  # A touch event with a text and a transfer, as Blaine's and Viridian's doors.
  def door(id, x, y)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(101, ["..."]), TestCmd.new(201, [0, 131, 35, 37, 8, 0]), TestCmd.new(0, [])])
  end

  # A touch event that only transfers, as Saffron's pads.
  def pad(id, x, y)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(201, [0, 127, 12, 38, 8, 0]), TestCmd.new(0, [])])
  end

  # One of Vermilion's bins (events 16 to 30) at its place in the grid, writing V129.
  def bin(id)
    n = id - 15 - 1
    put(id, 4 + 3 * (n % 5), 14 + 3 * (n / 5), :list => [TestCmd.new(122, [129, 129, 0, 0, n + 1]), TestCmd.new(0, [])])
  end

  # A piece of the electric barrier on row 9.
  def barrier(id, x)
    put(id, x, 9, :sprite => "rayosBarrera", :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
  end

  # A statue that turns the switch on and, on a second page, off.
  def statue(id, x, y, switch)
    on = TestCmd.new(121, [switch, switch, 0])
    off = TestCmd.new(121, [switch, switch, 1])
    first = TestPage.new(:trigger => 0, :sprite => "estatuaPersian", :list => [TestCmd.new(101, ["..."]), on, TestCmd.new(0, [])])
    second = TestPage.new(:trigger => 0, :sprite => "estatuaPersian", :list => [TestCmd.new(101, ["..."]), off, TestCmd.new(0, [])],
                          :condition => { :switch1_valid => true, :switch1_id => switch })
    put(id, x, y, :pages => [first, second])
  end

  # A wall drawn from a tile that the switch takes away.
  def wall_tile(id, x, y, tile, switch)
    drawn = TestPage.new(:trigger => 0, :list => [TestCmd.new(0, [])])
    drawn.graphic = TileGraphic.new("", 0, tile)
    gone = TestPage.new(:trigger => 0, :list => [TestCmd.new(0, [])], :condition => { :switch1_valid => true, :switch1_id => switch })
    put(id, x, y, :tile_id => tile, :pages => [drawn, gone])
  end

  # An event drawn from a tile, as a key on the floor.
  def tile_event(id, x, y, tile)
    drawn = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    drawn.graphic = TileGraphic.new("", 0, tile)
    put(id, x, y, :tile_id => tile, :pages => [drawn])
  end

  # What a riddle door of a room is called.
  def door_name(room); t(:anil_riddle_door, :n => room); end

  # Blaine's count of rooms crossed, as said.
  def rooms(n); t(:puzzle_progress, :label => t(:anil_riddle_rooms), :n => n, :of => 5); end

  # Vermilion's count of bins found, as said.
  def found(n); t(:puzzle_progress, :label => t(:anil_bin_found), :n => n, :of => 2); end

  # Viridian's count of keys, as said.
  def keys(n); t(:puzzle_progress, :label => t(:anil_keys), :n => n, :of => 2); end

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

  # What the next n map frames say, the events synced on each.
  def frames(n)
    SpeakCapture.clear
    n.times do
      PokeAccess::World::Epoch.tick if PokeAccess::World::Epoch.respond_to?(:tick)
      PokeAccess::World::Events.sync(true)
      PokeAccess::Puzzles.tick
    end
    SpeakCapture.lines
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
