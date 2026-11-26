# Pokemon Ashen Frost's optional puzzles of part G (games/ashenfrost/puzzles/): the Boulder Phase, the Timburr's logs,
# Serenity Labs, Support, the two rooms of the Eastridge Escape Room, the blue lanterns, the Power Plant, Spurl Home, the
# Shadebloom Tunnels and the Fossil Lab. Without the assist, what the screen shows; with it, the way.
class AshenfrostPuzzlesGGdTest < PokeAccessTest
  SWITCHES = [130, 412, 413, 414, 415, 416, 417]
  VARS = [47, 73, 74, 94, 133, 268, 308, 359, 399]
  # Room I's pads as the map lays them out (event => [x, y, the keys it jumps on, in the order its page checks them]), and
  # what each numbered pad's page writes to variable 47: {event => [value it waits for, value it sets]}.
  PADS = { 7 => [9, 16, [6]], 4 => [11, 16, [6, 4]], 9 => [13, 16, [2, 8, 6, 4]], 5 => [15, 16, [6, 4]],
           10 => [17, 16, [2, 8, 6, 4]], 6 => [19, 16, [6, 4]], 8 => [21, 16, [4]], 11 => [13, 14, [2]], 12 => [17, 14, [2]],
           13 => [13, 18, [8]], 14 => [17, 18, [8]] }
  STEPS = { 13 => [0, 1], 4 => [1, 2], 9 => [2, 3], 6 => [3, 4], 11 => [4, 5] }
  # Room II's doors, read from map 136: where each sends the player.
  DOOR_DESTS = { 9 => [25, 11], 10 => [6, 11], 11 => [6, 11], 12 => [25, 11], 13 => [25, 11], 14 => [44, 11],
                 15 => [6, 11], 16 => [6, 30], 17 => [44, 11], 18 => [25, 30], 19 => [6, 11], 20 => [44, 11],
                 21 => [44, 30], 22 => [44, 11], 23 => [25, 11] }
  JUMP = { 2 => [0, 2], 4 => [-2, 0], 6 => [2, 0], 8 => [0, -2] }

  def setup
    super
    keyed
    Harness.load_puzzles("ashenfrost")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @bag = $bag
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $bag = @bag
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the Boulder Phase names the storage door while the old man waits, and the assist sets the boulder's goal" do
    on_map(781, 8, 25)
    place(21, 6, 29, "StrengthRock", 2, "Object_Boulder_Grey")
    refute_includes info_key, "afg_bp_"
    $game_self_switches[[781, 20, "A"]] = true
    assert_includes info_key, "{afg_bp_title}"
    assert_includes listed, [7, 11, "{afg_bp_door}"]
    refute(listed.any? { |_x, _y, name| name == "{afg_bp_goal}" })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [7, 12, "{afg_bp_goal}"]
    $game_self_switches[[781, 23, "B"]] = true
    refute_includes info_key, "afg_bp_"
  end

  test "the Timburr's piles are named, and the info key follows the first and then the second" do
    on_map(346, 12, 25)
    $game_variables[94] = 6
    pile = place(30, 9, 24, "PushTree", 1)
    assert_equal "{afg_tl_log}", PokeAccess::Puzzles.piece_name(pile)
    assert_includes info_key, "{afg_tl_first}"
    $game_self_switches[[346, 32, "A"]] = true
    assert_includes info_key, "{afg_tl_second}"
    $game_self_switches[[346, 32, "B"]] = true
    refute_includes info_key, "afg_tl_"
  end

  test "Serenity Labs counts the ladder pieces and the welded sewers, and the assist names the rooms left" do
    on_map(325, 20, 30)
    $game_variables[73] = 4
    assert_equal "{afg_sl_piece}", PokeAccess::Puzzles.piece_name(place(15, 15, 4, "Ladder.noshadow", 0))
    assert_includes info_key, "{puzzle_progress label={afg_sl_pieces} n=2 of=5}"
    $game_variables[73] = 8
    refute_includes info_key, "afg_sl_pieces"
    door = place(32, 31, 25, "Door", 1, "doors23")
    [130, 412, 416].each { |s| $game_switches[s] = true }
    $game_variables[74] = 4
    assert_equal "{afg_sl_sewer}", PokeAccess::Puzzles.piece_name(door)
    assert_includes info_key, "{puzzle_progress label={afg_sl_welded} n=4 of=6}"
    refute_includes info_key, "afg_sl_sewers_hint"
    PokeAccess::Config.puzzle_assist = true
    with_map_names(320 => "Infirmary", 325 => "Shipyard") do
      assert_includes info_key, "{afg_sl_sewers_hint rooms={list_and last=Shipyard rest=Infirmary}}"
    end
    $game_variables[74] = 6
    refute_includes info_key, "afg_sl_"
  end

  test "Support names the blocked door, and the assist follows the donations, the woman and the door" do
    on_map(680, 46, 8)
    assert_equal "{afg_su_door}", PokeAccess::Puzzles.piece_name(place(47, 50, 15, "Weird Door", 1))
    $game_self_switches[[680, 45, "A"]] = true
    $game_self_switches[[680, 45, "B"]] = true
    refute_includes info_key, "afg_su_"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afg_su_donate n=2}"
    $game_variables[268] = 2
    assert_includes info_key, "{afg_su_step}"
    $game_variables[268] = 3
    refute_includes info_key, "afg_su_"
    on_map(679, 20, 30)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[268] = 1
    assert_includes info_key, "{afg_su_woman}"
  end

  test "Room I names its pads by the row, says its rule, and the assist's order is the one the pads' pages climb" do
    on_map(135, 15, 21)
    names = {}
    PADS.each { |id, pad| names[id] = PokeAccess::Puzzles.piece_name(place(id, pad[0], pad[1], id.to_s)) }
    assert_equal ["{afg_er1_pad n=1}", "{afg_er1_pad n=3}", "{afg_er1_pad n=7}", "{afg_er1_pad_above n=3}",
                  "{afg_er1_pad_below n=5}"], [names[7], names[9], names[8], names[11], names[14]]
    assert_includes info_key, "{afg_er1_rule}"
    refute_includes info_key, "afg_er1_step"
    PokeAccess::Config.puzzle_assist = true
    ordered = (0..4).map do |k|
      $game_variables[47] = k
      line = info_key
      PokeAccess::AshenJumpRoom::ORDER.find { |_pad, hint| line.include?("{#{hint}}") }[0]
    end
    assert_equal [13, 4, 9, 6, 11], ordered
    assert_equal ordered, STEPS.keys.sort_by { |id| STEPS[id][0] }
    assert_equal 5, play_jumps([[8, 16], [6, 6, 2, 8, 4, 6, 6, 6, 6, 6, 6]], [[22, 16], [4, 4, 4, 4, 8]])
    $game_variables[47] = 5
    refute_includes info_key, "afg_er1_"
  end

  test "Room II names its doors by their side, and the assist's door in each room leads to the next one" do
    on_map(136, 6, 11)
    assert_equal "{afg_er2_door_right}", PokeAccess::Puzzles.piece_name(place(14, 26, 6, "Right- Correct", 2))
    assert_includes info_key, "{afg_er2_rule}"
    refute_includes info_key, "afg_er2_left"
    hints = { :left => :afg_er2_left, :right => :afg_er2_right, :up => :afg_er2_up }
    at = [6, 11]
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::AshenDoorRoom::ROOMS.each_with_index do |room, k|
      assert_equal k, room_of(at)
      $game_player.x, $game_player.y = at
      assert_includes info_key, "{#{room[2]}}", "room #{k + 1}"
      assert_equal hints[PokeAccess::AshenDoorRoom::DOORS[room[1]]], room[2]
      doors = DOOR_TILES.keys.select { |d| room_of(DOOR_TILES[d]) == k }
      assert_equal 3, doors.length
      (doors - [room[1]]).each { |d| assert_operator room_of(DOOR_DESTS[d]), :<=, k, "door #{d} goes back" }
      at = DOOR_DESTS[room[1]]
      assert_equal k + 1, room_of(at), "door #{room[1]} leads on"
    end
    assert_equal [44, 30], at
    $game_player.x, $game_player.y = at
    refute_includes info_key, "afg_er2_left"
  end

  test "the blue lanterns are named and counted for anyone, and the assist marks the next of its round" do
    on_map(733, 58, 50)
    lanterns = [[36, 52, 63], [40, 48, 32], [44, 41, 3], [48, 26, 29], [52, 14, 8]].map { |id, x, y| place(id, x, y, "Lantern") }
    assert_equal "{afg_nl_lantern}", PokeAccess::Puzzles.piece_name(lanterns[0])
    $game_variables[308] = 1
    $game_self_switches[[733, 36, "A"]] = true
    assert_includes info_key, "{puzzle_progress label={afg_nl_lit} n=1 of=5}"
    refute(listed.any? { |_x, _y, name| name == "{afg_nl_next}" })
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, [48, 32, "{afg_nl_next}"]
    $game_variables[308] = 6
    refute_includes info_key, "afg_nl_"
  end

  test "the Power Plant names the machines, and the assist counts the four steps to the office" do
    on_map(789, 30, 30)
    assert_equal "{afg_pp_machine}", PokeAccess::Puzzles.piece_name(place(27, 61, 21, "Machine", 0, "HiddenItem_Sparkle"))
    $game_variables[359] = 11
    refute_includes info_key, "afg_pp_taps"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{puzzle_progress label={afg_pp_taps} n=2 of=4}"
    assert_includes info_key, "{afg_pp_hint}"
    $game_variables[359] = 13
    refute_includes info_key, "afg_pp_"
  end

  test "Spurl Home's assist follows the cup, the water, the fire and the roof to the meeting room, and starts over when caught" do
    on_map(66, 7, 12)
    $bag = FakeBag.new([])
    refute_includes info_key, "afg_gr_"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{afg_gr_cup}"
    $bag = FakeBag.new([:TEACUP])
    assert_includes info_key, "{afg_gr_water}"
    $bag = FakeBag.new([:TEACUP, :CUPWATER])
    assert_includes info_key, "{afg_gr_fire}"
    $bag = FakeBag.new([:TEACUP])
    $game_self_switches[[66, 3, "A"]] = true
    assert_includes info_key, "{afg_gr_chimney}"
    $game_variables[133] = 1
    walk_to(70, 20, 15)
    assert_includes info_key, "{afg_gr_chimney}", "on the roof, on the way"
    $game_variables[133] = 0
    walk_to(71, 9, 6)
    assert_includes info_key, "{afg_gr_meeting}", "the study, with 133 back at 0 as map 70's event 4 leaves it"
    walk_to(68, 22, 6)
    assert_includes info_key, "{afg_gr_meeting}"
    assert_includes listed, [12, 6, "{afg_gr_meeting_door}"]
    walk_to(66, 7, 12)
    assert_includes info_key, "{afg_gr_chimney}", "a guard's catch"
    walk_to(72, 13, 9)
    walk_to(68, 6, 13)
    assert_includes info_key, "{afg_gr_chimney}", "the foyer by the hall is not past the roof"
    refute_includes listed, [12, 6, "{afg_gr_meeting_door}"]
    walk_to(71, 9, 6)
    assert_includes info_key, "{afg_gr_meeting}"
    walk_to(68, 22, 6)
    assert_includes info_key, "{afg_gr_meeting}"
    saved = $PokemonGlobal
    $PokemonGlobal = saved.dup
    walk_to(68, 22, 6)
    assert_includes info_key, "{afg_gr_either}", "a save loaded in the foyer, the study not known"
    assert_includes listed, [12, 6, "{afg_gr_meeting_door}"]
  ensure
    $PokemonGlobal = saved if saved
  end

  test "the Shadebloom Tunnels' switch is named with the assist alone, until the spikes are down" do
    on_map(677, 30, 20)
    switch = place(10, 33, 27, "Switch")
    assert_nil PokeAccess::Puzzles.piece_name(switch)
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{afg_sv_switch}", PokeAccess::Puzzles.piece_name(switch)
    assert_includes info_key, "{afg_sv_hint}"
    $game_self_switches[[677, 9, "A"]] = true
    refute_includes info_key, "afg_sv_"
  end

  test "the Fossil Lab names the eyes for anyone, and the assist goes from the scent to each pair of eyes" do
    on_map(802, 30, 10)
    assert_equal "{afg_fl_eyes}", PokeAccess::Puzzles.piece_name(place(17, 33, 5, "Eyes 1", 0, "142_1_Shadow"))
    scent = place(18, 33, 7, "Find 1")
    assert_nil PokeAccess::Puzzles.piece_name(scent)
    refute_includes info_key, "afg_fl_step"
    PokeAccess::Config.puzzle_assist = true
    assert_equal "{afg_fl_scent}", PokeAccess::Puzzles.piece_name(scent)
    [[1, :afg_fl_step1], [2, :afg_fl_step2], [3, :afg_fl_step3]].each do |v, key|
      $game_variables[399] = v
      assert_includes info_key, "{#{key}}"
    end
    $game_variables[399] = 4
    refute_includes info_key, "afg_fl_"
  end

  private

  # A bag holding the given items.
  class FakeBag
    def initialize(items); @items = items; end
    def has?(item); @items.include?(item); end
  end

  # Plays Room I from each shore tile in turn, walking onto the row's end and then holding at each landing the next key
  # given, as the pads' pages read it: a pad sets variable 47 when it waits for its value, and jumps two tiles only on a
  # key it checks. A run ends on a landing with no key it jumps on; the value 47 ends at.
  def play_jumps(*runs)
    v = 0
    runs.each do |shore, keys|
      x = shore[0] + (shore[0] < 13 ? 1 : -1)
      y = shore[1]
      (keys + [nil]).each do |key|
        id = PADS.keys.find { |i| PADS[i][0] == x && PADS[i][1] == y }
        flunk "no pad at #{x}, #{y}" unless id
        v = STEPS[id][1] if STEPS[id] && STEPS[id][0] == v
        break unless PADS[id][2].include?(key)
        x += JUMP[key][0]
        y += JUMP[key][1]
      end
    end
    v
  end

  # Room II's doors as map 136 lays them.
  DOOR_TILES = { 9 => [5, 6], 10 => [6, 5], 11 => [7, 6], 12 => [24, 6], 13 => [25, 5], 14 => [26, 6], 15 => [43, 6],
                 16 => [44, 5], 17 => [45, 6], 18 => [5, 25], 19 => [7, 25], 20 => [6, 24], 21 => [24, 25], 22 => [25, 24],
                 23 => [26, 25] }

  # The place of a tile among Room II's rooms with a choice, from 0; their number for the last room, the way out's.
  def room_of(tile)
    rooms = PokeAccess::AshenDoorRoom::ROOMS
    k = rooms.index { |r| tile[0] >= r[0][0] && tile[0] <= r[0][1] && tile[1] >= r[0][2] && tile[1] <= r[0][3] }
    k || rooms.length
  end

  # Runs the block with Locator.map_name answering the given names.
  def with_map_names(names)
    loc = PokeAccess::Locator.singleton_class
    loc.send(:alias_method, :afg_kept_map_name, :map_name)
    loc.send(:define_method, :map_name) { |id| names[id] }
    yield
  ensure
    loc.send(:alias_method, :map_name, :afg_kept_map_name)
    loc.send(:remove_method, :afg_kept_map_name)
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afg_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afg_kept_t)
    i18n.send(:remove_method, :afg_kept_t)
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

  # The player taken to (x, y) of another map, as a transfer does: the switches, variables and bag as they stand.
  def walk_to(map, x, y)
    World.clear_events
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
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
