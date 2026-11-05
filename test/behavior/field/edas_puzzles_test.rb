# Edas' puzzles on the shipped profile: the order of Villa Nos' doors and edges, the ghosts, notes and drawer of the Mansion of memory,
# the crossroads of Carcitoma and the lookout of Cima Azur, each as it is heard without the puzzle assist and with it.
class EdasPuzzlesTest < PokeAccessTest
  VILLAGE = 51
  LIBRARY = 59
  ORDER = 97
  DOORS = { 3 => [9, 10, "doors10", :edas_nos_door_church], 5 => [11, 22, "doors5", :edas_nos_door_lab],
            13 => [20, 10, "doors5", :edas_nos_door_warehouse] }
  EDGES = { 12 => [14, 5, :edas_nos_exit_north], 16 => [15, 5, :edas_nos_exit_north], 4 => [15, 28, :edas_nos_exit_south],
            10 => [14, 28, :edas_nos_exit_south], 6 => [4, 16, :edas_nos_exit_west], 17 => [4, 17, :edas_nos_exit_west],
            7 => [25, 16, :edas_nos_exit_east], 15 => [25, 17, :edas_nos_exit_east] }
  HINTS = [[5, :edas_nos_hint_lab], [10, :edas_nos_hint_south], [13, :edas_nos_hint_warehouse], [6, :edas_nos_hint_west],
           [3, :edas_nos_hint_church], [12, :edas_nos_hint_north]]
  GHOSTS = [[57, 13], [58, 7], [56, 3], [56, 5]]
  WHERE = [:edas_mansion_where_wardrobe, :edas_mansion_where_dining, :edas_mansion_where_lampent,
           :edas_mansion_where_banette]

  test "Villa Nos names its doors by building and its edges by side, and keeps them out of the puzzles list" do
    on_village
    DOORS.each do |id, (_x, _y, _sprite, key)|
      assert_equal t(key), PokeAccess::Locator.target_name($game_map.events[id]), "door #{id}"
    end
    EDGES.each do |id, (_x, _y, key)|
      assert_equal t(key), PokeAccess::Locator.target_name($game_map.events[id]), "edge #{id}"
    end
    refute PokeAccess::Puzzles.has_locator_targets?
    exits = PokeAccess::Locator.candidates(:exits).map { |target| PokeAccess::Locator.target_name(target) }
    assert_equal [:edas_nos_door_church, :edas_nos_door_lab, :edas_nos_door_warehouse, :edas_nos_exit_east,
                  :edas_nos_exit_north, :edas_nos_exit_south, :edas_nos_exit_west].map { |key| t(key) }.sort, exits.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[11, 22, t(:puzzle_right_way)]], listed
  end

  test "Villa Nos leaves the order to the sign without the assist, and says why the player is back in the south" do
    on_village(0)
    assert_equal [t(:edas_nos_rule)], @arrival
    [1, 2, 3, 1, 6, 1].each { |step| assert_equal [], tick { $game_variables[ORDER] = step }, "V97 at #{step}" }
    assert_equal t(:edas_nos_rule), info_key
    assert_equal t(:edas_nos_back), PokeAccess::Puzzles.sent_back_line([11, 22, VILLAGE], [14, 29, VILLAGE])
    assert_equal t(:edas_nos_back), PokeAccess::Puzzles.sent_back_line([14, 32, VILLAGE], [14, 27, VILLAGE])
    assert_nil PokeAccess::Puzzles.sent_back_line([14, 29, VILLAGE], [5, 5, VILLAGE])
  end

  test "Villa Nos counts the steps, tells the next exit and lists the right way, all with the assist alone" do
    on_village
    HINTS.each_with_index do |(event, hint), i|
      $game_variables[ORDER] = i + 1
      refute_includes info_key, t(hint), "step #{i} without the assist"
      assert_empty listed, "step #{i} without the assist"
      PokeAccess::Config.puzzle_assist = true
      assert_includes info_key, t(hint), "step #{i}"
      target = $game_map.events[event]
      assert_equal [[target.x, target.y, t(:puzzle_right_way)]], listed, "step #{i}"
      PokeAccess::Config.puzzle_assist = false
    end
    on_village(0, true)
    assert_equal [t(:edas_nos_rule), t(:edas_nos_hint_lab)], @arrival
    assert_equal [], tick { $game_variables[ORDER] = 1 }, "the opening scene's own step"
    assert_equal [steps(1), t(:edas_nos_hint_south)], tick { $game_variables[ORDER] = 2 }
    assert_equal [steps(2), t(:edas_nos_hint_warehouse)], tick { $game_variables[ORDER] = 3 }
    assert_equal PokeAccess.sentences([steps(2), t(:edas_nos_hint_warehouse), t(:edas_nos_rule)]), info_key
    assert_equal [PokeAccess.sentences([t(:edas_nos_reset), steps(0)]), t(:edas_nos_hint_lab)],
                 tick { $game_variables[ORDER] = 1 }
    assert_equal [], tick { $game_variables[ORDER] = 1 }, "a mistake at the start has nothing to take away"
  end

  test "the library names its ghosts and its drawer, and the drawer says its word with the assist alone" do
    on_mansion(LIBRARY)
    ghosts = { 30 => [32, 8], 31 => [31, 7], 32 => [30, 8], 35 => [31, 9] }
    ghosts.each { |id, (x, y)| place(id, x, y, [TestCmd.new(0, [])], :sprite => "200", :name => "Mis") }
    drawer = place(12, 31, 5, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ghosts.each_key { |id| assert_equal t(:edas_mansion_ghost), PokeAccess::Locator.target_name($game_map.events[id]) }
    assert_equal t(:edas_mansion_drawer), PokeAccess::Locator.target_name(drawer)
    named = ghosts.values.map { |x, y| [x, y, t(:edas_mansion_ghost)] }.push([31, 5, t(:edas_mansion_drawer)])
    assert_equal named.sort_by { |x, y, _name| [x, y] }, listed
    assert_equal [], tick { fire(drawer) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_answer, :a => "SARA")], tick { fire(drawer) }
    $game_switches[97] = true
    assert_equal [[30, 8, t(:edas_mansion_ghost)], [31, 7, t(:edas_mansion_ghost)], [31, 9, t(:edas_mansion_ghost)],
                  [32, 8, t(:edas_mansion_ghost)]], listed, "the drawer is dropped once Alter is beaten"
  end

  test "the mansion counts the ghosts as they drop their notes, and says where the rest are with the assist" do
    on_mansion(55)
    assert_equal [], tick { $game_switches[301] = true }, "the hint of the hunt's start is the assist's"
    assert_equal [t(:edas_mansion_fled)], tick { $game_switches[218] = true }
    assert_equal [mansion_ghosts(1)], tick { drop(0) }
    assert_equal [mansion_ghosts(2)], tick { drop(1) }
    assert_equal [mansion_ghosts(3)], tick { drop(2) }
    assert_equal mansion_ghosts(3), info_key
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([mansion_ghosts(3), left([3])]), info_key
    assert_equal [PokeAccess.sentences([mansion_ghosts(4), t(:edas_mansion_hint_word)])], tick { drop(3) }
  end

  test "the mansion tells where the ghosts are from the start with the assist, and which ones are left" do
    on_mansion(56)
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:edas_mansion_hint_start)], tick { $game_switches[301] = true }
    assert_equal t(:edas_mansion_hint_start), info_key
    assert_equal [PokeAccess.sentences([t(:edas_mansion_fled), left([0, 1, 2, 3])])], tick { $game_switches[218] = true }
    drop(0)
    drop(2)
    assert_equal PokeAccess.sentences([mansion_ghosts(2), left([1, 3])]), info_key
    on_mansion(58, true) { $game_switches[301] = $game_switches[218] = true }
    assert_equal [left([0, 1, 2, 3])], @arrival, "a room entered mid-hunt says only the hint"
  end

  test "the mansion lists the ghost in the wardrobe with the assist alone, only while it is there" do
    on_mansion(57)
    place(13, 39, 19, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])], :sprite => "Armario")
    $game_switches[218] = true
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[39, 19, t(:edas_mansion_wardrobe_spot)]], listed
    $game_self_switches[[57, 13, "A"]] = true
    assert_empty listed
  end

  test "the mansion says nothing of what waits once the drawer opens without the assist, and with it points at the fight" do
    on_mansion(LIBRARY)
    $game_switches[218] = true
    GHOSTS.length.times { |i| drop(i) }
    tick
    { 19 => [8, 7, "Alter", "SheanCuadro", :edas_mansion_alter], 21 => [9, 10, "Sara", "SaraEvento", :edas_mansion_sara],
      22 => [8, 10, "Cosette", "CosetteEvento", :edas_mansion_cosette],
      23 => [7, 10, "Shean PreIsekai", "SheanEvento", :edas_mansion_shean] }.each do |id, (x, y, sprite, name, key)|
      person = place(id, x, y, [TestCmd.new(0, [])], :sprite => sprite, :name => name)
      assert_equal t(key), PokeAccess::Locator.target_name(person)
    end
    assert_equal [], tick { $game_switches[95] = true }
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[8, 12, t(:edas_mansion_alter_spot)]], listed
    assert_equal t(:edas_mansion_hint_alter), info_key
    $game_switches[95] = false
    tick
    assert_equal [t(:edas_mansion_hint_alter)], tick { $game_switches[95] = true }
    assert_equal [], tick { $game_switches[97] = true }
    assert_empty listed
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the crossroads of fools says its rule on arriving, and on landing at the foot of the room the miss or the hits so far, the total with the assist alone" do
    on_map(114) { $game_variables[56] = 0 }
    assert_equal [t(:edas_carc_rule)], @arrival
    assert_equal [], tick { $game_variables[56] = 2 }
    assert_equal PokeAccess.sentences([t(:edas_carc_right), tally(2)]), landing
    assert_includes info_key, tally(2)
    PokeAccess::Config.puzzle_assist = true
    assert_equal PokeAccess.sentences([t(:edas_carc_right), hits(2)]), landing
    assert_includes info_key, hits(2)
    $game_variables[56] = 0
    assert_equal t(:edas_carc_reset), landing
    assert_nil PokeAccess::Puzzles.sent_back_line([10, 9, 114], [10, 12, 114])
  end

  test "a signpost of the crossroads says with the assist alone the town the door wants, as its own menu names it" do
    on_map(114) { $game_variables[56] = 0 }
    place(2, 12, 12, sign_list)
    [[3, "Town Three"], [1, "Town One"]].each do |value, town|
      place(7, 10, 9, door_list(value), :trigger => 1)
      PokeAccess::Config.puzzle_assist = false
      assert_nil sign_says, "door #{value} without the assist"
      PokeAccess::Config.puzzle_assist = true
      assert_equal t(:puzzle_answer, :a => town), sign_says, "door #{value} with it"
    end
  end

  test "once what waits beyond the last door is beaten the crossroads say no more on arriving or on the info key, until a wrong town starts them over" do
    on_map(114) do
      $game_variables[56] = 5
      $game_switches[162] = true
    end
    assert_empty @arrival
    assert_nil PokeAccess::Puzzles.info_line
    place(2, 12, 12, sign_list)
    place(7, 10, 9, door_list(1), :trigger => 1)
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
    assert_equal t(:puzzle_answer, :a => "Town One"), sign_says
    $game_variables[56] = 0
    assert_equal t(:edas_carc_reset), landing
    assert_includes info_key, hits(0)
    on_map(114) { $game_switches[162] = true }
    assert_equal [t(:edas_carc_rule)], @arrival
  end

  test "Cima Azur names the two lookout tiles of its cliff edge for the lists" do
    on_map(41) do
      place(1, 7, 9, [TestCmd.new(101, ["view"])], :trigger => 1)
      place(2, 8, 9, [TestCmd.new(101, ["view"])], :trigger => 1)
    end
    assert_equal [[7, 9, t(:edas_lookout)], [8, 9, t(:edas_lookout)]], listed
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def hits(n)
    t(:puzzle_progress, :label => t(:edas_carc_hits), :n => n, :of => 6)
  end

  def tally(n)
    t(:puzzle_value, :label => t(:edas_carc_hits), :v => n)
  end

  def landing
    PokeAccess::Puzzles.sent_back_line([10, 9, 114], [10, 26, 114])
  end

  # What the assist promises for after the message that opens a signpost's menu.
  def sign_says
    list = sign_list
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, 2)
    int.instance_variable_set(:@list, list)
    int.instance_variable_set(:@index, 1)
    PokeAccess::Puzzles::Answers.forget
    PokeAccess::Puzzles::Answers.before_text(int)
    PokeAccess.take_tail
  ensure
    int.instance_variable_set(:@list, nil)
  end

  def sign_list
    [TestCmd.new(118, ["a1"]), TestCmd.new(101, ["Where?\\ch[1,-1,Town"]), TestCmd.new(401, ["One,Town Two,Town"]),
     TestCmd.new(401, ["Three,Leave]"]),
     TestCmd.new(111, [1, 1, 0, 0, 0]), TestCmd.new(122, [57, 57, 0, 0, 1], 1), TestCmd.new(412, []),
     TestCmd.new(111, [1, 1, 0, 1, 0]), TestCmd.new(122, [57, 57, 0, 0, 2], 1), TestCmd.new(412, []),
     TestCmd.new(111, [1, 1, 0, 2, 0]), TestCmd.new(122, [57, 57, 0, 0, 3], 1), TestCmd.new(412, []),
     TestCmd.new(0, [])]
  end

  def door_list(value)
    [TestCmd.new(111, [1, 57, 0, value, 0]), TestCmd.new(122, [56, 56, 0, 0, 1], 1), TestCmd.new(411, []),
     TestCmd.new(122, [56, 56, 0, 0, 0], 1), TestCmd.new(412, []), TestCmd.new(0, [])]
  end

  def declare
    was = $VERBOSE
    $VERBOSE = nil
    Harness.load_puzzles("edas")
  ensure
    $VERBOSE = was
  end

  def on_map(map, assist = false)
    declare
    PokeAccess::Config.puzzle_assist = assist
    World.clear_events
    [95, 97, 162, 218, 301].each { |s| $game_switches[s] = false }
    $game_variables[ORDER] = 0
    $game_self_switches = {}
    PokeAccess::Puzzles::Auto.forget
    $game_map.map_id = map
    yield if block_given?
    World.next_frame
    @arrival = tick
  end

  def on_village(order = 1, assist = false)
    on_map(VILLAGE, assist) do
      $game_variables[ORDER] = order
      DOORS.each do |id, (x, y, sprite, _key)|
        place(id, x, y, transfer(VILLAGE, 14, 29), :sprite => sprite, :trigger => 1, :name => "Puerta Iglesia")
      end
      EDGES.each { |id, (x, y, _key)| place(id, x, y, transfer(VILLAGE, 14, 29), :trigger => 1, :name => "Exit") }
    end
  end

  def on_mansion(map, assist = false, &state)
    on_map(map, assist, &state)
  end

  def transfer(map, x, y)
    [TestCmd.new(201, [0, map, x, y, 8, 1]), TestCmd.new(0, [])]
  end

  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :name => opts.fetch(:name, "EV#{id}"))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def drop(index)
    map, event = GHOSTS[index]
    $game_self_switches[[map, event, "A"]] = true
  end

  def steps(n)
    t(:puzzle_progress, :label => t(:edas_nos_steps), :n => n, :of => 6)
  end

  def mansion_ghosts(n)
    t(:puzzle_progress, :label => t(:edas_mansion_ghosts), :n => n, :of => 4)
  end

  def left(indexes)
    PokeAccess.sentences([t(:edas_mansion_left), PokeAccess::Routes::Text.and_list(indexes.map { |i| t(WHERE[i]) })])
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _name| [x, y] }
  end
end
