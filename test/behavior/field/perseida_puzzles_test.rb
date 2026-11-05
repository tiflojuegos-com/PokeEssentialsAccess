# Perseida's story-blocking puzzles on the shipped profile (games/perseida/puzzles): the gyms of Libra and Cetus and the two
# tests of the Bard's temple, each as it is heard without the puzzle assist and with it.
class PerseidaPuzzlesTest < PokeAccessTest
  SWITCHES = [7, 90, 120, 121, 122, 123, 129, 130, 131]
  VARIABLES = [64, 68, 69]
  EXITS = {
    19 => [13, 4, :perseida_libra_road_rails, false], 20 => [2, 10, :perseida_libra_road_sand, false],
    9 => [23, 10, :perseida_libra_road_crystals, true], 21 => [47, 4, :perseida_libra_road_rails, false],
    22 => [57, 10, :perseida_libra_road_stone, false], 11 => [47, 16, :perseida_libra_road_sand, true],
    23 => [57, 36, :perseida_libra_road_rails, false], 25 => [47, 43, :perseida_libra_road_rails, false],
    13 => [36, 36, :perseida_libra_road_clear, true], 24 => [2, 36, :perseida_libra_road_rails, false],
    26 => [13, 44, :perseida_libra_road_stone, false], 15 => [13, 30, :perseida_libra_road_crystals, true]
  }
  BACK = { 10 => [36, 10], 12 => [47, 30], 14 => [23, 36], 16 => [30, 67] }
  HOLES = { 1 => [13, 4], 7 => [2, 8], 8 => [5, 4], 9 => [16, 8] }
  STATUE_NAMES = { 1 => "Jumpluff", 7 => "Pyroar", 8 => "Roserade", 9 => "Spheal" }
  CRIES = { 5 => [14, 14, 35, 29], 4 => [6, 14, 133, 28], 3 => [12, 14, 590, 30], 2 => [4, 14, 459, 27] }

  test "Libra names each exit by the floor of its way, so the trainers' hints can be followed, and the doors back" do
    on_map(54)
    assert_equal [t(:perseida_libra_rule)], @arrival
    EXITS.each { |id, (x, y, _road, _right)| door(id, x, y) }
    BACK.each { |id, (x, y)| door(id, x, y) }
    EXITS.each do |id, (_x, _y, road, _right)|
      assert_equal t(:perseida_libra_exit, :road => t(road)), PokeAccess::Puzzles.piece_name($game_map.events[id]), "exit #{id}"
    end
    BACK.each_key { |id| assert_equal t(:perseida_libra_back), PokeAccess::Puzzles.piece_name($game_map.events[id]) }
    names = listed.map { |row| row[2] }
    assert_equal 16, names.length
    assert_includes names, t(:perseida_libra_exit, :road => t(:perseida_libra_road_crystals))
  end

  test "Libra tells with the assist alone which exits go on and which are traps" do
    on_map(54)
    EXITS.each { |id, (x, y, _road, _right)| door(id, x, y) }
    PokeAccess::Config.puzzle_assist = true
    EXITS.each do |id, (_x, _y, road, right)|
      key = right ? :perseida_libra_exit_right : :perseida_libra_exit_trap
      assert_equal t(key, :road => t(road)), PokeAccess::Puzzles.piece_name($game_map.events[id]), "exit #{id}"
    end
    assert_equal 4, EXITS.values.select { |row| row[3] }.length
  end

  test "Cetus names the walls by their color and Karliah's tiles and says which switch is on" do
    on_map(91, 2)
    assert_equal [t(:perseida_cetus_rule)], @arrival
    { 8 => ["Rojo", :perseida_cetus_wall_red], 6 => ["Azul", :perseida_cetus_wall_blue],
      17 => ["Amarillo", :perseida_cetus_wall_yellow] }.each do |id, (color, key)|
      wall = place(id, 2, 12, [TestCmd.new(0, [])], "Muros Gym", color)
      assert_equal t(key), PokeAccess::Puzzles.piece_name(wall), color
    end
    { 45 => [5, 15], 75 => [5, 4], 33 => [5, 5] }.each do |id, (x, y)|
      spot = place(id, x, y, [TestCmd.new(117, [52])])
      assert_equal t(:perseida_cetus_karliah), PokeAccess::Puzzles.piece_name(spot), "EV#{id}"
      assert_includes listed, [x, y, t(:perseida_cetus_karliah)]
    end
    assert_equal [t(:perseida_cetus_blue_on)], tick { $game_switches[130] = true }
    assert_equal [t(:perseida_cetus_red_on)], tick { $game_switches[130] = false; $game_switches[129] = true }
    assert_equal [], tick { $game_switches[129] = false }
  end

  test "Cetus says the switch on in each room's line and, with the assist, the colors to ask Karliah for" do
    on_map(91, 2)
    refute_includes info_key, t(:perseida_cetus_hint1)
    assert_includes info_key, t(:perseida_cetus_title, :n => 1, :color => t(:perseida_cetus_none))
    tick { $game_switches[129] = true }
    assert_includes info_key, t(:perseida_cetus_title, :n => 1, :color => t(:perseida_cetus_red))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:perseida_cetus_hint1)
    $game_player.x = 22
    assert_includes info_key, t(:perseida_cetus_title, :n => 2, :color => t(:perseida_cetus_red))
    assert_includes info_key, t(:perseida_cetus_hint2)
    $game_variables[64] = 2
    refute PokeAccess::Puzzles.active?
    on_map(105, 9)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:perseida_cetus_title, :n => 3, :color => t(:perseida_cetus_none))
    assert_includes info_key, t(:perseida_cetus_hint3)
    $game_variables[64] = 3
    refute PokeAccess::Puzzles.active?
  end

  test "the Bard's statues are counted, their holes listed and, with the assist, named and followed one by one" do
    on_map(135, 5, 68 => 5)
    assert_equal [t(:perseida_bard_statues_rule)], @arrival
    statues = HOLES.keys.map { |id| push_statue(id) }
    assert_equal [[2, 8], [5, 4], [13, 4], [16, 8]].map { |x, y| [x, y, t(:perseida_bard_hole)] }, listed
    assert_equal [t(:puzzle_progress, :label => t(:perseida_bard_statues), :n => 1, :of => 4)], tick { $game_switches[121] = true }
    assert_equal [[2, 8], [5, 4], [13, 4], [16, 8]].map { |x, y| [x, y, t(:perseida_bard_hole)] }.reject { |r| r[0] == 2 }, listed
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:perseida_bard_push_hint, :statue => "Jumpluff")
    jumpluff = statues[0]
    jumpluff.x = 11
    dist = PokeAccess::Puzzles.offset_phrase(2, -2)
    assert_includes tick, t(:puzzle_track_goal, :label => "Jumpluff", :dist => dist, :goal => t(:perseida_bard_hole_of, :statue => "Jumpluff"))
    assert_includes listed, [13, 4, t(:perseida_bard_hole_of, :statue => "Jumpluff")]
    assert_equal 1, listed.select { |r| r[0] == 13 && r[1] == 4 }.length
    assert_includes listed, [5, 4, t(:perseida_bard_hole_of, :statue => "Roserade")]
    jumpluff.x = 13
    jumpluff.y = 4
    assert_includes tick, t(:puzzle_track_in, :label => "Jumpluff", :goal => t(:perseida_bard_hole_of, :statue => "Jumpluff"))
  end

  test "Libra says its rule on arriving until the leader's medal scene is over" do
    on_map(54)
    assert_equal [t(:perseida_libra_rule)], @arrival
    on_map(54) { $game_self_switches[[54, 6, "B"]] = true }
    assert_equal [t(:perseida_libra_rule)], @arrival, "the medal is not given yet"
    on_map(54) { $game_self_switches[[54, 6, "C"]] = true }
    assert_empty @arrival
  end

  test "Cetus says its rule on arriving and keeps its room on the info key until the leader's medal is won, then neither" do
    [91, 105].each do |map|
      on_map(map, 2)
      assert_equal [t(:perseida_cetus_rule)], @arrival, "map #{map} before"
      refute_nil PokeAccess::Puzzles.info_line, "map #{map} before"
      on_map(map, 2) { $game_switches[7] = true }
      assert_empty @arrival, "map #{map} after"
      assert_nil PokeAccess::Puzzles.info_line, "map #{map} after"
    end
  end

  test "the Bard's statues say their rule on arriving and answer the info key until the scene of the fourth has run, then neither" do
    on_map(135, 5, 68 => 5, 69 => 4)
    assert_equal [t(:perseida_bard_statues_rule)], @arrival
    refute_nil PokeAccess::Puzzles.info_line
    on_map(135, 5, 68 => 5, 69 => 5)
    assert_empty @arrival
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the north room's statues say and list nothing while the door of the cries is shut, and speak once it opens" do
    on_map(135)
    assert_equal [t(:perseida_bard_cries_rule)], @arrival
    HOLES.each_key { |id| push_statue(id) }
    PokeAccess::Config.puzzle_assist = true
    assert_empty listed.select { |row| HOLES.values.include?([row[0], row[1]]) }
    refute_includes info_key.to_s, t(:perseida_bard_push_hint, :statue => "Jumpluff")
    assert_includes tick { $game_variables[68] = 5 }, t(:perseida_bard_push_hint, :statue => "Jumpluff")
    assert_includes listed, [13, 4, t(:perseida_bard_hole_of, :statue => "Jumpluff")]
    assert_includes listed, [2, 8, t(:perseida_bard_hole_of, :statue => "Pyroar")]
  end

  test "the Bard's statues that cry are named by their Pokemon, the order of the cries told with the assist alone" do
    on_map(135)
    CRIES.each { |id, (x, y, _species, _tile)| place(id, x, y, [TestCmd.new(0, [])], "EstatuasBardo") }
    slab = place(26, 9, 17, [TestCmd.new(101, ["..."])])
    assert_equal t(:perseida_bard_slab), PokeAccess::Puzzles.piece_name(slab)
    CRIES.each do |id, (_x, _y, species, _tile)|
      name = PokeAccess::Data.species_name(species)
      assert_equal t(:perseida_bard_cry_statue, :species => name), PokeAccess::Puzzles.piece_name($game_map.events[id])
    end
    PokeAccess::Config.puzzle_assist = true
    [5, 4, 3, 2].each_with_index do |id, i|
      name = PokeAccess::Data.species_name(CRIES[id][2])
      assert_equal t(:perseida_bard_cry_statue_nth, :species => name, :n => i + 1), PokeAccess::Puzzles.piece_name($game_map.events[id])
    end
    names = [5, 4, 3, 2].map { |id| PokeAccess::Data.species_name(CRIES[id][2]) }
    assert_includes info_key, t(:perseida_bard_cries_hint, :order => PokeAccess::Routes::Text.and_list(names))
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:perseida_bard_cries_hint, :order => PokeAccess::Routes::Text.and_list(names))
  end

  test "the cries count the tiles lit, say when a mistake starts the order again and stop answering once the door opens" do
    on_map(135)
    tiles = CRIES.values.map { |_x, _y, _species, id| tile_event(id) }
    assert_includes info_key, t(:puzzle_progress, :label => t(:perseida_bard_cries), :n => 0, :of => 4)
    assert_equal [t(:puzzle_progress, :label => t(:perseida_bard_cries), :n => 1, :of => 4)], tick { tiles[0].tile_id = 822 }
    assert_equal [t(:puzzle_progress, :label => t(:perseida_bard_cries), :n => 2, :of => 4)], tick { tiles[1].tile_id = 822 }
    lines = tick { tiles.each { |ev| ev.tile_id = 0 } }
    assert_equal [PokeAccess.sentences([t(:puzzle_reset), t(:puzzle_progress, :label => t(:perseida_bard_cries), :n => 0, :of => 4)])], lines
    tick { tiles.each { |ev| ev.tile_id = 822 } }
    $game_variables[68] = 5
    refute_includes info_key, t(:perseida_bard_cries)
  end

  class Asking
    def initialize(id, list); @event_id = id; @list = list; @index = 0; end
    def running?; true; end
  end

  MENSA_RIGHT = { 28 => [[:switch, 80], "Yes"], 32 => [[:switch, 81], "Yes"], 36 => [[:switch, 82], "Yes"],
                  29 => [[:var, 66], "No"], 30 => [[:var, 66], "No"], 31 => [[:var, 66], "No"], 33 => [[:var, 66], "No"],
                  34 => [[:var, 66], "No"], 35 => [[:var, 66], "No"] }

  test "the Mensa gym's people answer their question with the assist alone: yes to the right one, no to the rest" do
    on_map(157)
    MENSA_RIGHT.each do |id, (write, right)|
      question = asking(id, write)
      PokeAccess::Config.puzzle_assist = false
      PokeAccess::Puzzles::Answers.forget
      SpeakCapture.clear
      PokeAccess::Puzzles::Answers.say(question, 0)
      assert_equal [], SpeakCapture.lines, "event #{id} without the assist"
      PokeAccess::Config.puzzle_assist = true
      PokeAccess::Puzzles::Answers.forget
      PokeAccess::Puzzles::Answers.say(question, 0)
      assert_equal [t(:puzzle_answer, :a => right)], SpeakCapture.lines, "event #{id} with it"
    end
  end

  test "the Elemental Altar counts the stones offered with the assist alone" do
    on_map(94, 5, 39 => 0)
    assert_equal [], tick { $game_variables[39] = 1 }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [t(:puzzle_progress, :label => t(:perseida_altar_stones), :n => 2, :of => 7)], tick { $game_variables[39] = 2 }
  end

  test "the Furnex statues say with the assist alone the room their flame wants, even from the nested menu, and none once it is out" do
    on_map(129)
    [[10, 13, 2, "Room B"], [14, 7, 5, "Room E"]].each do |guide, flame, right, room|
      place(flame, 10, 13, flame_list(right))
      place(guide, 10, 19, rooms_menu)
      PokeAccess::Config.puzzle_assist = false
      assert_equal [], said_on_menus(guide), "statue #{guide} without the assist"
      PokeAccess::Config.puzzle_assist = true
      said = said_on_menus(guide)
      assert_includes said, t(:puzzle_answer, :a => room), "statue #{guide} with it"
      assert_equal 1, said.length - (right > 3 ? 1 : 0), "statue #{guide}: the way to the nested menu, then the room"
    end
    assert_equal [t(:puzzle_answer, :a => "More"), t(:puzzle_answer, :a => "Room E")], said_on_menus(14)
    place(13, 10, 13, [TestCmd.new(0, [])])
    assert_equal [], said_on_menus(10)
    twin = place(8, 11, 37, [TestCmd.new(0, [])], "Estatua Antigua", "2")
    assert_equal t(:perseida_furnex_statue), PokeAccess::Locator.target_name(twin)
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def asking(id, write)
    kind, number = write
    set = kind == :switch ? TestCmd.new(121, [number, number, 0], 1) : TestCmd.new(122, [number, number, 1, 0, 1], 1)
    list = [TestCmd.new(102, [["Yes", "No"], 0]), TestCmd.new(402, [0]), set, TestCmd.new(402, [1]), TestCmd.new(404, []),
            TestCmd.new(0, [])]
    place(id, 5, 5 + id, list)
    Asking.new(id, list)
  end

  # What the assist says as each menu of an event's page opens, in order.
  def said_on_menus(id)
    list = PokeAccess.ivar($game_map.events[id], :@list)
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    int.instance_variable_set(:@list, list)
    SpeakCapture.clear
    list.each_index { |i| PokeAccess::Puzzles::Answers.say(int, i) if list[i].code == 102 }
    SpeakCapture.log.map { |line| line[0] }
  ensure
    int.instance_variable_set(:@list, nil)
  end

  def rooms_menu
    [TestCmd.new(102, [["Room A", "Room B", "Room C", "More"], 0]),
     TestCmd.new(402, [0]), TestCmd.new(122, [37, 37, 0, 0, 1], 1),
     TestCmd.new(402, [1]), TestCmd.new(122, [37, 37, 0, 0, 2], 1),
     TestCmd.new(402, [2]), TestCmd.new(122, [37, 37, 0, 0, 3], 1),
     TestCmd.new(402, [3]), TestCmd.new(102, [["Room D", "Room E", "Back"], 0], 1),
     TestCmd.new(402, [0], 1), TestCmd.new(122, [37, 37, 0, 0, 4], 2),
     TestCmd.new(402, [1], 1), TestCmd.new(122, [37, 37, 0, 0, 5], 2),
     TestCmd.new(402, [2], 1), TestCmd.new(404, [], 1),
     TestCmd.new(404, []), TestCmd.new(0, [])]
  end

  def flame_list(right)
    list = []
    (1..5).each do |value|
      list.push(TestCmd.new(111, [1, 37, 0, value, 0]))
      list.push(value == right ? TestCmd.new(122, [38, 38, 0, 0, 1], 1) : TestCmd.new(355, ["pbDoubleWildBattle"], 1))
      list.push(TestCmd.new(412, []))
    end
    list.push(TestCmd.new(0, []))
  end

  def on_map(map, x = 5, vars = {})
    Harness.load_puzzles("perseida")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    vars.each { |v, n| $game_variables[v] = n }
    yield if block_given?
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
    @arrival = tick
  end

  def place(id, x, y, list, sprite = "", name = nil, trigger = 0)
    page = TestPage.new(:trigger => trigger, :sprite => sprite, :list => list)
    opts = { :id => id, :x => x, :y => y, :pages => [page], :active_page => page }
    opts[:name] = name if name
    ev = TestGameEvent.new(opts)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def door(id, x, y)
    place(id, x, y, [TestCmd.new(201, [0, 54, 13, 17, 0, 0])], "", nil, 1)
  end

  def push_statue(id)
    x, y = { 1 => [10, 6], 7 => [3, 5], 8 => [14, 7], 9 => [5, 8] }[id]
    place(id, x, y, [TestCmd.new(355, ["pbPushThisBoulder"])], "EstatuasBardo", STATUE_NAMES[id], 2)
  end

  def tile_event(id)
    ev = place(id, 4, 18, [TestCmd.new(0, [])])
    ev.tile_id = 0
    ev
  end

  def tick
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
