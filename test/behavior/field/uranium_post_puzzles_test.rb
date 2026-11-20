# Pokemon Uranium's puzzles after the story (games/uranium/puzzles): the Temple of Aotius, the Temple of Mutios, the cracked
# ice of the Forgotten Span and the Lava Vent; what each says with no help and what the assist adds.
class UraniumPostPuzzlesTest < PokeAccessTest
  test "the Temple of Aotius names its levers and says its rule only while the flames stand" do
    lines = arrival(262)
    assert_includes lines, t(:ura_pp_aotius_rule)
    lever = place(60, 19, 21, "Lever")
    frame
    assert_equal t(:ura_pp_aotius_lever, :n => 1), PokeAccess::Puzzles.piece_name(lever)
    refute_includes arrival(262) { $game_switches[233] = true }, t(:ura_pp_aotius_rule)
  end

  test "the cracked ice of the Forgotten Span is named but not listed, and its rule is said once" do
    [246, 245].each do |map|
      PokeAccess::Puzzles.instance_variable_set(:@told, nil)
      refute_includes arrival(map) { $game_variables[131] = 11 }, t(:ura_pp_ice_rule) if map == 245
      PokeAccess::Puzzles.instance_variable_set(:@told, nil)
      assert_includes arrival(map) { $game_variables[131] = 12 }, t(:ura_pp_ice_rule)
      tile = place(9, 52, 35, "Cracked Ice")
      frame
      assert_equal t(:ura_pp_ice_name), PokeAccess::Puzzles.piece_name(tile)
      assert_empty listed
    end
  end

  test "the Temple of Mutios counts the correct tiles and, with the assist alone, lists them" do
    refute_includes arrival(257), picross_rule
    lines = frame { $game_player.x = 65; $game_player.y = 14 }
    assert_includes lines, picross_rule
    refute_includes frame, picross_rule
    place(73, 68, 16, "Correct")
    place(126, 66, 16, "inCorrect")
    frame
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[68, 16, t(:ura_pp_picross_cell)]], listed
    PokeAccess::Config.puzzle_assist = false
    $game_variables[42] = 3
    assert_includes info_key, t(:ura_pp_picross_done)
    PokeAccess::UraniumMutios.forget
    done = arrival(257) { $game_self_switches[[257, 74, "A"]] = true; $game_player.x = 65; $game_player.y = 14 }
    refute_includes done, picross_rule
  end

  test "the free camera gives each Mutios tile's row and column, flagged or gone, and the clues go by their digit" do
    on_map(257)
    cell = place(73, 68, 16, "Correct")
    place(126, 66, 16, "inCorrect")
    bingo(200, 75, 17, 2, 2)
    bingo(201, 68, 27, 4, 0)
    bingo(202, 60, 10, 2, 1)
    World.next_frame
    frame
    lines = lambda { |x, y| PokeAccess::Camera.tile_lines(x, y).uniq }
    corner = t(:ura_pp_picross_place, :row => 1, :col => 3)
    assert_equal [[corner], [t(:ura_pp_picross_place, :row => 1, :col => 1)], []], [lines[68, 16], lines[66, 16], lines[75, 16]]
    $game_self_switches[[257, 73, "A"]] = true
    assert_equal [corner, t(:mg_marked)], lines[68, 16]
    cell.character_name = ""
    assert_equal [corner, t(:mg_tile_clear)], lines[68, 16]
    names = [200, 201, 202].map { |id| PokeAccess::Locator.target_name($game_map.events[id]) }
    assert_equal [t(:ura_pp_picross_row, :n => 2, :clues => 2), t(:ura_pp_picross_col, :n => 3, :clues => 4), "EV"], names
    assert_includes PokeAccess::CameraText.parts(75, 17), names[0]
    assert_empty listed
  end

  test "the Lava Vent names its plugs, keeps its outlets out of the list and says its rule" do
    lines = arrival(244)
    assert_includes lines, t(:ura_pp_lava_rule)
    plug = place(30, 20, 22, "Plug 1")
    outlet = place(22, 20, 25, "Outlet 1")
    frame
    assert_equal t(:ura_pp_lava_plug), PokeAccess::Puzzles.piece_name(plug)
    assert_equal t(:ura_pp_lava_outlet), PokeAccess::Puzzles.piece_name(outlet)
    assert_equal [[20, 22, t(:ura_pp_lava_plug)]], listed
  end

  test "the Temple of Aotius reads the levers off the switches and names the flames by row and column" do
    Harness.load_puzzles("uranium")
    aotius = PokeAccess::UraniumAotius
    [87, 93, 90, 91, 92].each { |id| $game_switches[id] = false }
    assert_equal 0, aotius.mask
    $game_switches[87] = true
    $game_switches[91] = true
    $game_switches[92] = true
    assert_equal 2 | 8, aotius.mask
    $game_switches[92] = false
    assert_equal 2 | 4 | 8, aotius.mask
    assert_equal t(:ura_pp_aotius_cell, :row => 4, :col => 1), aotius.cell(10, 12)
    cells = aotius.safe_order.map { |spot| aotius.cell(spot[0], spot[1]) }.join("; ")
    assert_equal t(:ura_pp_aotius_safe, :cells => cells), aotius.safe_way
    $game_switches[232] = true
    assert_equal "", aotius.hint
    [87, 91, 232].each { |id| $game_switches[id] = false }
  end

  test "the Temple of Mutios says the picross clues by row and column and where the player stands" do
    on_map(257)
    [[75, 16, 4, 1], [75, 17, 4, 1], [76, 17, 2, 1]].each_with_index { |c, i| bingo(200 + i, c[0], c[1], c[2], c[3]) }
    bingo(210, 66, 26, 4, 2)
    bingo(211, 68, 26, 4, 2)
    bingo(212, 68, 27, 2, 2)
    $game_player.x = 67
    $game_player.y = 17
    World.next_frame
    mutios = PokeAccess::UraniumMutios
    lines = mutios.clue_lines
    assert_includes lines[0], t(:ura_pp_picross_row, :n => 1, :clues => "5")
    assert_includes lines[0], t(:ura_pp_picross_row, :n => 2, :clues => "5, 1")
    assert_includes lines[1], t(:ura_pp_picross_col, :n => 3, :clues => "6, 2")
    assert_includes lines[1], t(:ura_pp_picross_col, :n => 2, :clues => "")
    assert_equal t(:ura_pp_picross_place, :row => 2, :col => 2), mutios.place
    $game_player.x = 60
    assert_nil mutios.place
  end

  test "the Lava Vent plugs say how they seal an outlet with the assist alone and its jets are avoided" do
    on_map(244)
    plug = place(168, 16, 32, "Plug 3")
    blast = place(149, 15, 32, "Blast 3")
    blast.instance_variable_set(:@list, [TestCmd.new(117, [88]), TestCmd.new(0, [])])
    frame
    assert PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(15, 32)]
    refute PokeAccess::Routes::Controls.keep_off[PokeAccess::Routes.pkey(16, 32)]
    assert_equal t(:ura_pp_lava_plug), PokeAccess::Puzzles.piece_name(plug)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:ura_pp_lava_plug_3), PokeAccess::Puzzles.piece_name(plug)
    PokeAccess::Config.puzzle_assist = false
  end

  test "the Sunken Ship lists the door that goes on for the room the player stands in, with the assist alone" do
    assert_includes arrival(249), t(:ura_pp_ship_rule)
    door(10, 14, 39)
    door(12, 25, 61)
    $game_player.x = 12
    $game_player.y = 42
    World.next_frame
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    World.next_frame
    assert_equal [[14, 39, t(:puzzle_right_way)]], listed
    $game_player.x = 20
    $game_player.y = 63
    World.next_frame
    assert_equal [[25, 61, t(:puzzle_right_way)]], listed
    $game_switches[159] = true
    World.next_frame
    assert_empty listed
    $game_switches[159] = false
    PokeAccess::Config.puzzle_assist = false
  end

  test "the tide currents of the Shattered Seas are named" do
    on_map(218)
    tide = place(93, 90, 79, "Tide")
    frame
    assert_equal t(:ura_pp_tide), PokeAccess::Puzzles.piece_name(tide)
  end

  test "the Palace of Dreams says its rule once and walks the stages of its doors with the assist" do
    assert_includes arrival(212), t(:ura_pp_palace_rule)
    palace = PokeAccess::UraniumPalace
    steps = [[0, 1, :ura_pp_palace_go_north], [1, 2, :ura_pp_palace_go_south], [1, 3, :ura_pp_palace_redraw],
             [3, 0, :ura_pp_palace_go_south], [4, 0, :ura_pp_palace_go_north], [5, 0, :ura_pp_palace_go_south],
             [6, 1, :ura_pp_palace_go_left], [7, 2, :ura_pp_palace_go_center], [7, 3, :ura_pp_palace_go_right],
             [8, 0, :ura_pp_palace_block]]
    steps.each do |stage, door, key|
      $game_variables[35] = stage
      $game_variables[91] = door
      assert_equal t(key), palace.hint, "stage #{stage}, door #{door}"
    end
    $game_variables[35] = 2
    assert_includes palace.hint, t(:ura_pp_palace_simon)
    $game_variables[30] = 22
    $game_variables[35] = 0
    $game_variables[91] = 2
    assert_equal t(:ura_pp_palace_boulder), palace.hint
    $game_variables[30] = 21
  end

  test "following the Palace hint through the pages of its doors always ends in the room of the boulder" do
    arrival(212)
    palace = PokeAccess::UraniumPalace
    doors = { t(:ura_pp_palace_go_south) => :south, t(:ura_pp_palace_go_north) => :center,
              t(:ura_pp_palace_go_left) => :left, t(:ura_pp_palace_go_center) => :center,
              t(:ura_pp_palace_go_right) => :right, t(:ura_pp_palace_block) => :south,
              t(:ura_pp_palace_redraw) => :center }
    60.times do |seed|
      rng = Random.new(seed)
      $game_variables[30] = 21
      $game_variables[35] = 0
      $game_variables[91] = 1 + rng.rand(2)
      steps = 0
      until $game_variables[30] >= 22 || steps > 40
        text = palace.hint
        text = text.split(". ").last if text.include?(t(:ura_pp_palace_simon))
        door = doors[text]
        assert door, "no door for #{text.inspect}"
        palace_page(door, rng)
        steps += 1
      end
      assert_operator $game_variables[30], :>=, 22, "seed #{seed}"
      assert_equal t(:ura_pp_palace_boulder), palace.hint
    end
    $game_variables[30] = 21
  end

  test "the Palace of Dreams says the lit doors as the last rounds start and keeps Antarki's line for the early stages" do
    arrival(212)
    $game_variables[35] = 0
    assert_equal t(:ura_pp_palace_north), PokeAccess::UraniumPalace.north_line
    assert_equal "", PokeAccess::UraniumPalace.triple_line
    $game_variables[35] = 6
    assert_equal "", PokeAccess::UraniumPalace.north_line
    assert_equal t(:ura_pp_palace_triple), PokeAccess::UraniumPalace.triple_line
  end

  private

  def palace_var(id); $game_variables[id].to_i; end

  def palace_set(stage, door = nil)
    $game_variables[35] = stage
    $game_variables[91] = door if door
  end

  def palace_page(door, rng)
    case door
    when :south then palace_south(rng)
    when :center then palace_center(rng)
    when :left then palace_side(1, rng)
    when :right then palace_side(3, rng)
    end
  end

  def palace_south(rng)
    if palace_var(30) == 22
      palace_set(0)
      $game_variables[30] = 21
    end
    if palace_var(35) == 9
      palace_set(0)
      $game_variables[30] = 21
    end
    if palace_var(35) == 8
      $game_variables[30] = 22
      palace_set(9)
    end
    stage = palace_var(35)
    door = palace_var(91)
    stage = 0 if stage >= 6
    stage += 1 if stage == 5
    stage = 0 if stage == 4
    stage += 1 if stage == 3
    stage += 1 if stage == 2
    stage = (door == 2 ? 2 : 0) if stage == 1
    stage += 1 if stage == 0 && door == 2
    palace_set(stage)
    return if stage >= 7
    return palace_set(stage, 1 + rng.rand(3)) if stage >= 5
    return if stage >= 2 && stage <= 4
    palace_set(stage, 1 + rng.rand(2))
  end

  def palace_center(rng)
    if palace_var(35) == 8
      $game_variables[30] = 22
      return
    end
    stage = palace_var(35)
    door = palace_var(91)
    stage = door == 2 ? stage + 1 : 0 if stage >= 6
    stage = 0 if stage == 5
    stage += 1 if stage == 4
    stage = 0 if stage == 3
    stage = 0 if stage == 2
    if stage == 1
      stage = 2 if door == 1
      stage = 0 if door == 2
    end
    stage += 1 if stage == 0 && door == 1
    palace_set(stage)
    return if stage >= 8 || (stage >= 3 && stage < 6)
    return palace_set(stage, 1 + rng.rand(3)) if stage >= 6
    return if stage == 2
    palace_set(stage, 1 + rng.rand(2))
  end

  def palace_side(want, rng)
    stage = palace_var(35)
    return unless stage >= 6 && stage < 8
    stage = palace_var(91) == want ? stage + 1 : 0
    palace_set(stage)
    palace_set(stage, 1 + rng.rand(3)) if stage >= 6
  end

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The Picross rule with the keys the game's own sign names: C works a tile, Z (its A) held flags one.
  def picross_rule
    t(:ura_pp_picross_rule, :act => "C", :flag => "Z")
  end

  def arrival(map)
    on_map(map)
    yield if block_given?
    PokeAccess::Puzzles.instance_variable_set(:@told, nil)
    frame
  end

  def on_map(map)
    Harness.load_puzzles("uranium")
    PokeAccess::UraniumMutios.forget
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_switches[233] = false
    $game_variables[42] = 0
    $game_map.map_id = map
    $game_player.x = 5
    $game_player.y = 5
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name)
    page = TestPage.new(:trigger => 0, :sprite => "itemball", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def door(id, x, y)
    page = TestPage.new(:trigger => 1, :list => [TestCmd.new(355, ["Kernel.pbTransferUnderwater(249,1,1)"])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV", :pages => [page], :active_page => page)
    World.next_frame
  end

  def bingo(id, x, y, direction, pattern)
    page = TestPage.new(:trigger => 0, :sprite => "bingo", :direction => direction, :pattern => pattern)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV", :pages => [page], :active_page => page)
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
