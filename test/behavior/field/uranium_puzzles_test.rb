# Pokemon Uranium's story-blocking puzzles on the shipped profile (games/uranium/puzzles): the gyms of Burole, Vinoville,
# Amatree, Venesi, Snowbank and Tsukinami, Nuclear Plant Zeta's levers and the wire puzzle of Urayne and the Memory Banks;
# what each says with no help and what the assist adds.
class UraniumPuzzlesTest < PokeAccessTest
  SWITCHES = [62, 67, 79, 80, 81, 87, 88, 89, 90, 91, 92, 93, 94, 112]
  VARIABLES = [108, 121, 126]
  WIRE_VARS = [:@@endPointStates, :@@startPoints, :@@currentColor, :@@wireStates]
  MEMORY_BANK_B = [
    "############", "###........#", "#.a.c......#", "#..........#", "#.######...#", "#.....#....#", "#####.#....#", "#####.#....#",
    "#####.#....#", "#####.#....#", "#####.#....#", "#####.#b...#", "#####.#....#", "#####.#C...#", "#####.#B..##",
    "#####.#A.###", "#####.##.###", "#####....###", "############"
  ]

  # The game's table of wire colours: the colour 1 on the cells given, 0 elsewhere.
  class WireStates
    def initialize(cells); @cells = cells; end
    def [](x, y); @cells.include?([x, y]) ? 1 : 0; end
  end

  # A map's layers with the wire template's tile on the cells given.
  class WireTiles
    def initialize(cells); @cells = cells; end
    def [](x, y, z); z == 0 && @cells[[x, y]] ? 1051 : 0; end
  end

  URAYNE_WIRES = [
    ".......", "#a...A.", ".b...B.", ".c...C#", ".d...D.", "......."
  ]
  GEM_ROCKS = [5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 20]

  test "Burole says the rule on arriving and, with the assist alone, lists the rock that holds the gem" do
    lines = arrival(66) { $game_variables[108] = 3 }
    assert_includes lines, t(:ura_pz_burole_rule)
    GEM_ROCKS.each_with_index { |id, i| place(id, 2 + i, 5, [TestCmd.new(101, ["rock"])], "fk107-rocksmash") }
    assert_equal [], listed.select { |r| r[2] == t(:ura_pz_gem_rock) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[4, 5, t(:ura_pz_gem_rock)]], listed.select { |r| r[2] == t(:ura_pz_gem_rock) }
    $game_self_switches[[66, 7, "A"]] = true
    assert_empty listed.select { |r| r[2] == t(:ura_pz_gem_rock) }
    $game_variables[108] = 0
    $game_self_switches[[66, 7, "A"]] = false
    assert_equal [[2 + GEM_ROCKS.index(19), 5, t(:ura_pz_gem_rock)]], listed.select { |r| r[2] == t(:ura_pz_gem_rock) }
    $game_switches[67] = true
    assert_empty listed.select { |r| r[2] == t(:ura_pz_gem_rock) }
  end

  test "Vinoville names its buttons, says the rule, lists the safe path with the assist alone and why the basement is reached" do
    lines = arrival(148)
    assert_includes lines, t(:ura_pz_vino_rule)
    place(14, 25, 54, [TestCmd.new(101, ["push"])])
    place(54, 17, 21, [TestCmd.new(101, ["switch"])])
    [1, 2, 3].each { |id| tile(id, 27, 54 - id, 389) }
    frame
    assert_equal t(:ura_pz_button), PokeAccess::Puzzles.piece_name($game_map.events[14])
    assert_equal t(:ura_pz_vino_switch), PokeAccess::Puzzles.piece_name($game_map.events[54])
    plain = listed.length
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_equal plain + 3, listed.length
    assert_includes info_key, t(:ura_pz_vino_hint)
    $game_switches[80] = true
    frame
    assert_includes info_key, t(:ura_pz_vino_final_hint)
    refute_includes info_key, t(:ura_pz_vino_hint)
    PokeAccess::Config.puzzle_assist = false
    refute_includes info_key, t(:ura_pz_vino_final_hint)
  end

  test "Vinoville says a fall from the floor above for each landing of the basement, and not for the entrance stairs" do
    on_map(162)
    [[19, 28], [27, 13], [27, 38], [27, 50], [35, 28]].each do |to|
      assert_equal t(:ura_pz_vino_fall), PokeAccess::Puzzles.sent_back_line([30, 30, 148], to, :map)
    end
    assert_nil PokeAccess::Puzzles.sent_back_line([32, 55, 148], [27, 53], :map)
    assert_nil PokeAccess::Puzzles.sent_back_line([30, 30, 999], [19, 28], :map)
  end

  test "Amatree counts the boulders on their tile and, with the assist, lists the tile of the first one left" do
    arrival(69)
    place(9, 17, 30, [TestCmd.new(101, ["push"])], "HGSS_267")
    place(1, 12, 24, [TestCmd.new(101, ["push"])], "HGSS_267")
    frame
    assert_equal [t(:puzzle_progress, :label => t(:ura_pz_boulders), :n => 1, :of => 7)], frame { $game_switches[87] = true }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_pz_boulder_hint)
    assert_includes listed.map { |r| r[2] }, t(:ura_pz_boulder_goal)
    assert_equal [11, 24], listed.select { |r| r[2] == t(:ura_pz_boulder_goal) }.map { |r| [r[0], r[1]] }[0]
  end

  test "Amatree points at the boulders in the order the game numbers its puzzles, the fifth after the fourth" do
    arrival(69)
    [[9, 17, 30], [1, 12, 24], [26, 7, 29], [69, 11, 14], [2, 23, 24], [111, 24, 10], [123, 7, 8]].each do |id, x, y|
      place(id, x, y, [TestCmd.new(101, ["push"])], "HGSS_267")
    end
    frame
    PokeAccess::Config.puzzle_assist = true
    goals = [[87, [17, 29]], [88, [11, 24]], [89, [6, 29]], [90, [12, 14]], [91, [24, 24]], [92, [24, 9]], [93, [6, 8]]]
    goals.each do |switch, goal|
      assert_equal [goal], listed.select { |r| r[2] == t(:ura_pz_boulder_goal) }.map { |r| [r[0], r[1]] }, "before switch #{switch}"
      $game_switches[switch] = true
      frame
    end
  end

  test "Venesi tells the leader apart with the assist alone, and says why the fake leader's battle drops the player" do
    lines = arrival(147)
    assert_includes lines, t(:ura_pz_venesi_rule)
    place(24, 42, 7, [TestCmd.new(101, ["leader"])], "PU-Rosalind")
    refute_includes listed.map { |r| r[2] }, t(:ura_pz_venesi_leader)
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed.map { |r| r[2] }, t(:ura_pz_venesi_leader)
    PokeAccess::Config.puzzle_assist = false
    assert_nil PokeAccess::Puzzles.sent_back_line([30, 9, 147], [42, 11])
    fake = place(7, 41, 8, [TestCmd.new(101, ["fake leader"])], "PU-Iago")
    fire(fake)
    assert_equal t(:ura_pz_venesi_fall), PokeAccess::Puzzles.sent_back_line([30, 9, 147], [42, 11])
    assert_nil PokeAccess::Puzzles.sent_back_line([30, 9, 147], [43, 11])
  end

  test "Snowbank names its acolytes and buttons, and says each trial's rule on entering its part of the room" do
    arrival(137)
    place(13, 13, 65, [TestCmd.new(101, ["acolyte"])], "PU-Acolyte")
    place(8, 65, 61, [TestCmd.new(101, ["push"])])
    frame
    assert_equal t(:ura_pz_snow_reset), PokeAccess::Puzzles.piece_name($game_map.events[13])
    assert_equal t(:ura_pz_button), PokeAccess::Puzzles.piece_name($game_map.events[8])
    $game_player.x = 10
    $game_player.y = 60
    assert_includes frame, t(:ura_pz_snow_rocks_title)
    $game_player.x = 66
    $game_player.y = 60
    assert_includes frame, t(:ura_pz_snow_path_title)
  end

  test "Snowbank names the second acolyte, lists the safe path with the assist alone and says why a trap sends the player back" do
    arrival(137)
    place(27, 39, 72, [TestCmd.new(101, ["acolyte"])], "PU-Acolyte")
    [37, 40, 41].each_with_index { |id, i| tile(id, 62 + i, 50, 389) }
    trap = place(83, 66, 62, [TestCmd.new(101, ["trap"])])
    $game_player.x = 66
    $game_player.y = 60
    frame
    assert_equal t(:ura_pz_snow_reset), PokeAccess::Puzzles.piece_name($game_map.events[27])
    assert_empty listed.select { |r| r[2] == t(:ura_pz_vino_way) }
    PokeAccess::Config.puzzle_assist = true
    assert_equal 3, listed.select { |r| r[2] == t(:ura_pz_vino_way) }.length
    PokeAccess::Config.puzzle_assist = false
    assert_nil PokeAccess::Puzzles.sent_back_line([70, 50, 137], [67, 62])
    fire(trap)
    assert_equal t(:ura_pz_snow_sent), PokeAccess::Puzzles.sent_back_line([70, 50, 137], [67, 62])
    assert_nil PokeAccess::Puzzles.sent_back_line([70, 50, 137], [68, 62])
  end

  test "Snowbank's ice trial names its acolyte too" do
    arrival(141)
    place(12, 81, 18, [TestCmd.new(101, ["acolyte"])], "PU-Acolyte")
    frame
    assert_equal t(:ura_pz_snow_reset), PokeAccess::Puzzles.piece_name($game_map.events[12])
  end

  test "Snowbank's ice trial says its rule and the jump's tile, with where it lands for the assist alone" do
    lines = arrival(141)
    assert_includes lines, t(:ura_pz_snow_ice_rule)
    place(17, 58, 19, [TestCmd.new(101, ["jump"])])
    frame
    assert_equal t(:ura_pz_snow_jump), PokeAccess::Puzzles.piece_name($game_map.events[17])
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ura_pz_snow_jump_to), PokeAccess::Puzzles.piece_name($game_map.events[17])
  end

  test "Tsukinami says each tile's colour as it is stood on, going by its graphic" do
    arrival(175)
    white = tile(2, 11, 59, 1622)
    black = tile(3, 10, 59, 1630)
    [white, black].each { |ev| ev.instance_variable_set(:@name, "tile1") }
    frame
    states = PokeAccess::World::Mechanics.instances.map { |inst| inst.spec[:tile_state] }.compact
    assert_equal [true, false], [states[0].call(white), states[0].call(black)]
  end

  test "Tsukinami's info key counts the black tiles and goes quiet once the gym's puzzles are done" do
    on_map(175)
    tile(2, 11, 59, 1622).instance_variable_set(:@name, "tile1")
    tile(3, 10, 59, 1630).instance_variable_set(:@name, "tile1")
    tile(4, 9, 59, 1630).instance_variable_set(:@name, "tile1")
    PokeAccess::World::Mechanics.forget
    World.next_frame
    $game_variables[121] = 2
    assert_includes info_key, t(:puzzle_progress, :label => t(:ura_pz_tiles_black), :n => 2, :of => 3)
    $game_variables[121] = 4
    refute_includes info_key.to_s, t(:ura_pz_tiles_black)
  end

  test "Zeta names its levers by colour and place, says the rule in the south, and gives each stage's step with the assist" do
    lines = arrival(189)
    assert_includes lines, t(:ura_pz_zeta_rule)
    place(14, 9, 25, [TestCmd.new(101, ["lever"])], "PU-levers")
    place(16, 10, 25, [TestCmd.new(101, ["lever"])], "PU-levers")
    place(15, 8, 25, [TestCmd.new(101, ["lever"])], "PU-levers")
    place(25, 13, 27, [TestCmd.new(101, ["breaker"])], "PU-levers")
    frame
    assert_equal [t(:ura_pz_zeta_lever_green), t(:ura_pz_zeta_lever_red), t(:ura_pz_zeta_lever_blue), t(:ura_pz_zeta_breaker)],
                 [14, 16, 15, 25].map { |id| PokeAccess::Puzzles.piece_name($game_map.events[id]) }
    refute_includes info_key.to_s, t(:ura_pz_zeta_hint_south)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:ura_pz_zeta_hint_south)
    $game_variables[126] = 4
    frame
    assert_includes info_key, t(:ura_pz_zeta_hint_sectors)
    $game_variables[126] = 5
    frame
    assert_includes info_key, t(:ura_pz_zeta_hint_east)
    refute_includes info_key, t(:ura_pz_zeta_hint_sectors)
    $game_variables[126] = 6
    frame
    assert_includes info_key, t(:ura_pz_zeta_hint_west)
    $game_variables[126] = 7
    frame
    assert_includes info_key, t(:ura_pz_zeta_hint_door)
    [8, 9].each do |ended|
      $game_variables[126] = ended
      frame
      refute_includes info_key.to_s, t(:ura_pz_zeta_hint_door)
    end
  end

  test "the wire puzzle names the nodes whose page starts a wire, counts the joined ends and says the circuit being drawn" do
    wire_game
    lines = arrival(268)
    assert_includes lines, t(:ura_wire_rule)
    start = wire_node(10, 11, 15, "WireStartA", "A")
    ends = wire_node(11, 12, 24, "WireEndA:32A:33A", "A")
    wire_node(12, 11, 14, "WireStartC", "C")
    memory = place(13, 13, 24, [TestCmd.new(101, ["memory"])], "itemball")
    memory.instance_variable_set(:@name, "WireEndC:27C:33A")
    frame
    assert_equal t(:ura_wire_start, :circuit => "A"), PokeAccess::Puzzles.piece_name(start)
    assert_equal t(:ura_wire_end, :circuit => "A"), PokeAccess::Puzzles.piece_name(ends)
    assert_equal t(:ura_wire_end, :circuit => "C"), PokeAccess::Puzzles.piece_name(memory)
    assert_equal 3, listed.length
    before = wire_tables
    assert_includes info_key, t(:ura_wire_connections, :connected => 0, :total => 2)
    WirePuzzle.send(:class_variable_set, :@@endPointStates, { [1, 12, 24] => false })
    WirePuzzle.send(:class_variable_set, :@@startPoints, [nil, [[11, 15]], [], [], []])
    WirePuzzle.send(:class_variable_set, :@@currentColor, 1)
    drawn = wire_tables
    assert_includes info_key, PokeAccess.sentences([t(:ura_wire_drawing, :circuit => "A"),
                                       t(:ura_wire_connections, :connected => 0, :total => 2)])
    WirePuzzle.joins = true
    assert_includes info_key, PokeAccess.sentences([t(:ura_wire_drawing, :circuit => "A"),
                                       t(:ura_wire_connections, :connected => 1, :total => 2)])
    assert_equal drawn, wire_tables
    refute_equal before, drawn
  end

  test "the free camera says the circuit of each tile with a wire drawn, and nothing of the bare ones" do
    on_map(268)
    page = TestPage.new(:trigger => 1, :list => [TestCmd.new(0, [])])
    [[150, 14, 8], [151, 15, 8]].each do |id, x, y|
      $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "WireSegment", :tile_id => 400,
                                               :pages => [page], :active_page => page)
    end
    World.next_frame
    $game_self_switches[[268, 150, "B"]] = true
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y).uniq }
    assert_equal [[t(:ura_wire_cell, :circuit => "B")], [], []], [lines[14, 8], lines[15, 8], lines[16, 8]]
    $game_map.map_id = 250
    assert_equal [], lines[14, 8], "the segment's self switch is of another map"
  end

  test "a solved memory bank says nothing of the wires, though the game has emptied its tables" do
    wire_game
    arrival(268)
    wire_node(11, 12, 24, "WireEndA:32A:33A", "A")
    wire_node(13, 13, 24, "WireEndC:27C:33A", "C")
    frame
    assert_includes info_key, t(:ura_wire_connections, :connected => 0, :total => 2)
    [[32, "A"], [33, "A"], [27, "C"]].each { |id, letter| $game_self_switches[[268, id, letter]] = true }
    refute_includes info_key.to_s, t(:ura_wire_connections, :connected => 0, :total => 2)
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    refute_includes frame, t(:ura_wire_rule)
    $game_self_switches[[268, 27, "C"]] = false
    assert_includes info_key, t(:ura_wire_connections, :connected => 0, :total => 2)
  end

  test "Urayne's wires speak near the nodes or while the game has the puzzle set up, and not across the map" do
    wire_game
    arrival(250)
    wire_node(53, 31, 75, "WireStartA", "A")
    wire_node(61, 35, 75, "WireEndA:67B", "A")
    assert_empty frame
    far = t(:ura_wire_connections, :connected => 0, :total => 1)
    refute_includes info_key.to_s, far
    $game_player.x = 20
    $game_player.y = 60
    refute_includes info_key.to_s, far
    $game_player.x = 30
    $game_player.y = 77
    assert_includes info_key, far
    assert_includes info_key, t(:ura_wire_rule)
    $game_player.x = 5
    $game_player.y = 5
    refute_includes info_key.to_s, far
    WirePuzzle.send(:class_variable_set, :@@wireStates, Object.new)
    assert_includes info_key, far
    $game_self_switches[[250, 67, "B"]] = true
    refute_includes info_key.to_s, far
  end

  test "with the assist the wire puzzle lays out each circuit's tiles, joined by walking, with no cell shared" do
    wire_game
    arrival(269)
    wire_bank(MEMORY_BANK_B)
    refute_includes info_key, PokeAccess::UraniumWire.hint
    PokeAccess::Config.puzzle_assist = true
    paths, circuits, erase = PokeAccess::UraniumWire.plan
    refute erase
    assert_equal %w[A B C], circuits.map { |letter, from, to| letter }
    assert_includes info_key, PokeAccess::UraniumWire.hint
    assert_equal 3, PokeAccess::UraniumWire.hint.scan(t(:ura_wire_path, :circuit => "X", :side => "Y", :steps => "Z")[/\A\S+/]).length
    cells = {}
    circuits.each do |letter, from, to|
      path = paths[letter]
      assert PokeAccess::UraniumWire.beside?(path.first, from)
      assert PokeAccess::UraniumWire.beside?(path.last, to)
      path.each_cons(2) { |a, b| assert_equal 1, (a[0] - b[0]).abs + (a[1] - b[1]).abs }
      path.each do |cell|
        assert @wire_cells[cell], "off the wires: #{cell.inspect}"
        refute cells[cell], "shared: #{cell.inspect}"
        cells[cell] = letter
      end
    end
  end

  test "in Urayne, where there is no panel, the layout paints over the wire that boxed another in and never says to reset" do
    wire_game
    arrival(250)
    wire_bank(URAYNE_WIRES, 30, 74)
    PokeAccess::Config.puzzle_assist = true
    WirePuzzle.send(:class_variable_set, :@@startPoints, [nil, [[31, 75]], [], [], []])
    WirePuzzle.singleton_class.send(:define_method, :checkConnection) { |from, to, color| color == 1 }
    detour = [[32, 75], [32, 76], [33, 76], [34, 76], [34, 75]]
    WirePuzzle.send(:class_variable_set, :@@wireStates, WireStates.new(detour))
    paths, circuits, erase = PokeAccess::UraniumWire.plan
    refute erase
    assert_equal %w[A B C D], circuits.map { |letter, from, to| letter }
    refute_includes info_key, t(:ura_wire_redo)
    cells = {}
    paths.values.each { |path| path.each { |cell| refute cells[cell]; cells[cell] = true } }
  end

  test "the wire layout goes round the circuits already joined, and tells to erase the wires when they leave no way" do
    wire_game
    arrival(269)
    wire_bank(MEMORY_BANK_B)
    PokeAccess::Config.puzzle_assist = true
    WirePuzzle.send(:class_variable_set, :@@startPoints, [nil, [[16, 9]], [[21, 18]], [[18, 9]], []])
    WirePuzzle.singleton_class.send(:define_method, :checkConnection) { |from, to, color| color == 1 }
    WirePuzzle.send(:class_variable_set, :@@wireStates, WireStates.new((19..24).map { |x| [x, 24] }))
    paths, circuits, erase = PokeAccess::UraniumWire.plan
    refute erase
    assert_equal %w[B C], circuits.map { |letter, from, to| letter }
    refute paths.values.flatten(1).any? { |cell| cell[1] == 24 && cell[0].between?(19, 24) }
    WirePuzzle.send(:class_variable_set, :@@wireStates, WireStates.new([[22, 20], [21, 19]]))
    paths, circuits, erase = PokeAccess::UraniumWire.plan
    assert erase
    assert_equal %w[A B C], circuits.map { |letter, from, to| letter }
    assert_includes info_key, t(:ura_wire_redo)
  end

  private

  # The game's WirePuzzle as far as the mod reads it: its class variables, empty as before a wire is drawn.
  def wire_game
    Object.const_set(:WirePuzzle, Module.new) unless defined?(::WirePuzzle)
    WirePuzzle.module_eval do
      class << self
        attr_accessor :joins
        def checkConnection(_start, _finish, _color); joins; end
      end
    end
    WirePuzzle.send(:class_variable_set, :@@endPointStates, {})
    WirePuzzle.send(:class_variable_set, :@@startPoints, [nil, [], [], [], []])
    WirePuzzle.send(:class_variable_set, :@@currentColor, nil)
    WirePuzzle.send(:class_variable_set, :@@wireStates, nil)
    WirePuzzle.joins = false
  end

  def wire_bank(rows, ox = 14, oy = 7)
    @wire_cells = {}
    rows.each_with_index do |row, dy|
      row.split("").each_with_index do |char, dx|
        x = ox + dx
        y = oy + dy
        @wire_cells[[x, y]] = true if char == "."
        wire_node(100 + dy * 20 + dx, x, y, "WireStart#{char.upcase}", char.upcase) if char =~ /[a-d]/
        wire_node(100 + dy * 20 + dx, x, y, "WireEnd#{char}:S#{char}", char) if char =~ /[A-D]/
      end
    end
    template = TestGameEvent.new(:id => 25, :x => 31, :y => 0, :name => "WireTemplate", :tile_id => 1051)
    $game_map.events[25] = template
    @saved_map = [$game_map.width, $game_map.height, $game_map.instance_variable_get(:@data)]
    $game_map.width = 136
    $game_map.height = 150
    $game_map.instance_variable_set(:@data, WireTiles.new(@wire_cells))
    World.next_frame
  end

  def wire_tables
    WIRE_VARS.map { |name| Marshal.load(Marshal.dump(WirePuzzle.send(:class_variable_get, name))) }
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  def teardown
    Object.send(:remove_const, :WirePuzzle) if defined?(::WirePuzzle)
    if @saved_map
      $game_map.width, $game_map.height = @saved_map[0], @saved_map[1]
      $game_map.instance_variable_set(:@data, @saved_map[2])
    end
    PokeAccess::UraniumWire.instance_variable_set(:@plan_key, nil)
    super
  end

  def wire_node(id, x, y, name, circuit)
    page = TestPage.new(:trigger => 0, :sprite => "itemball",
                        :list => [TestCmd.new(355, ["WirePuzzle.setColor(:#{circuit})"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def on_map(map)
    Harness.load_puzzles("uranium")
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARIABLES.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def tile(id, x, y, tile_id)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :tile_id => tile_id, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
