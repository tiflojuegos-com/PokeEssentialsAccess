# GS Vitro's puzzles after its 1.2.3: the switch that resets the room of doors, the boulders of Blackthorn that the leader's and
# Lola's wins drop with no fall, Morty's walkway in the dark, whose edge sends the player back and the routes keep off, the
# Ruins of Alph, the Hidden Tower, the Sinjoh circles and the Farfetch'd of Ilex Forest; and the keyboard set on a new game.

# The game's flag of a new game and its option of text entry, as 0120_PField_Metadata and 0170_PScreen_Options keep them.
class PokemonTemp
  attr_accessor :begunNewGame unless method_defined?(:begunNewGame)
end

class PokemonSystem
  attr_accessor :keyboardEntry unless method_defined?(:keyboardEntry)
end

text_entry = File.join(Harness::ROOT, "games", "vitro", "text_entry.rb")
eval(Harness.source(text_entry), TOPLEVEL_BINDING, text_entry)

class VitroPulidoTest < PokeAccessTest
  # A walkway as the map draws it: 'e' an edge tile (terrain tag 2), the way to Morty's tile (6, 1) along the floor below.
  WALKWAY = ['########',
             '#@eeee##',
             '#.####.#',
             '#......#',
             '########']

  # A TileWorld whose 'e' tiles carry terrain tag 2, each on a tile id of its own as the engine keeps them.
  class EdgeWorld < TileWorld
    # The ground layer's tile ids: 3 on an edge, 1 elsewhere.
    class EdgeData
      def initialize(world); @world = world; end
      def [](x, y, layer); layer == 0 ? (@world.cell(x, y) == "e" ? 3 : 1) : 0; end
    end

    def data; @data ||= EdgeData.new(self); end
    def terrain_tag(x, y, *_); cell(x, y) == "e" ? 2 : 0; end
  end

  test "the room of doors names its reset switch" do
    Harness.load_puzzles("vitro")
    $game_map.map_id = 128
    ev = TestGameEvent.new(:id => 46, :x => 18, :y => 4)
    assert_equal t(:vitro_doors_reset), PokeAccess::VitroDoorPuzzle.name(ev)
  end

  test "Blackthorn says a boulder's fall, and nothing when Debora's or Lola's win turns its switch on" do
    on_map(86)
    tick
    [[4, []], [30, []], [12, [["#{t(:vitro_rock)}: #{t(:vitro_rock_fell)}", false]]]].each_with_index do |(used, said), i|
      $game_map.events[used] = TestGameEvent.new(:id => used, :x => 2 + used % 20, :y => 2)
      PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, used)
      $game_switches[89 + i] = true
      assert_equal said, tick, "with event #{used} last used"
    end
  end

  test "the exit door's tile is named as the exit, not as the edge" do
    Harness.load_puzzles("vitro")
    rows = Array.new(49) { '#' * 14 }
    rows[47] = '#' * 12 + '@#'
    rows[48] = '###e' + '#' * 8 + 'e#'
    on_edge_world(35, rows) do
      assert_equal :vitro_ecruteak_exit_tile, PokeAccess::World::Terrain.label(12, 48)
      assert_nil PokeAccess::World::Terrain.label(3, 48), "an edge far off in the dark is no surface"
      PokeAccess::Config.set(:puzzle_assist, true)
      assert_equal :vitro_ecruteak_edge, PokeAccess::World::Terrain.label(3, 48)
    end
  ensure
    PokeAccess::Config.set(:puzzle_assist, false)
  end

  test "Morty's walkway is a wall to the routes with the assist alone, on his map alone, and its edge is named in the light" do
    Harness.load_puzzles("vitro")
    on_edge_world(35) do
      PokeAccess::Config.set(:puzzle_assist, false)
      assert_equal [6, 6, 6, 6], PokeAccess::Routes::Planner.walk(6, 1).route.to_a, "in the dark, as a sighted player walks it"
      assert_equal :vitro_ecruteak_edge, PokeAccess::World::Terrain.label(3, 1), "two tiles off, in the light round the player"
      assert_nil PokeAccess::World::Terrain.label(5, 1), "past the light"
      PokeAccess::Config.set(:puzzle_assist, true)
      assert_equal [2, 2, 6, 6, 6, 6, 6, 8], PokeAccess::Routes::Planner.walk(6, 1).route.to_a
      assert_equal :vitro_ecruteak_edge, PokeAccess::World::Terrain.label(5, 1)
      refute_equal :vitro_ecruteak_edge, PokeAccess::World::Terrain.label(1, 3)
      PokeAccess::Config.set(:puzzle_assist, false)
    end
    on_edge_world(36) do
      assert_equal [6, 6, 6, 6], PokeAccess::Routes::Planner.walk(6, 1).route.to_a
      refute_equal :vitro_ecruteak_edge, PokeAccess::World::Terrain.label(3, 1)
    end
  end

  test "Morty's gym gives its rule, with the assist alone the way to him, and is quiet with the badge" do
    Harness.load_puzzles("vitro")
    PokeAccess::Config.puzzle_assist = false
    $game_switches[7] = false
    on_edge_world(35) do
      tick
      way = t(:vitro_ecruteak_way, :steps => PokeAccess::Routes::Text.steps([2, 2, 6, 6, 6, 6, 6, 8]))
      assert_includes PokeAccess::Puzzles.info_line, t(:vitro_ecruteak_rule)
      refute_includes PokeAccess::Puzzles.info_line, way
      PokeAccess::Config.puzzle_assist = true
      assert_includes PokeAccess::Puzzles.info_line, way
      $game_switches[7] = true
      refute PokeAccess::Puzzles.active?
    end
  end

  test "arriving at Morty's gym says the walkway's rule" do
    on_map(35)
    assert_includes tick, [t(:vitro_ecruteak_rule), false]
  end

  test "a step onto Morty's edge is said as the fall back to the entrance, and the guide in the void is not listed" do
    on_map(35)
    assert_equal t(:vitro_ecruteak_fell), PokeAccess::Puzzles.sent_back_line([5, 22, 35], [12, 42, 35])
    assert_nil PokeAccess::Puzzles.sent_back_line([5, 22, 35], [12, 41, 35])
    page = TestPage.new(:trigger => 0, :sprite => "Consejitos", :list => [TestCmd.new(101, ["guide"])])
    was = $PokemonGlobal
    $PokemonGlobal = Struct.new(:escapePoint).new([])
    assert_equal t(:vitro_ecruteak_exit_back), PokeAccess::Puzzles.sent_back_line([12, 48, 35], [12, 42, 35])
    $PokemonGlobal.escapePoint = [29, 10, 5, 2]
    assert_equal t(:vitro_ecruteak_exit_rope), PokeAccess::Puzzles.sent_back_line([12, 47, 35], [12, 42, 35])
    $PokemonGlobal = was
    $game_map.events[14] = TestGameEvent.new(:id => 14, :x => 0, :y => 48, :pages => [page], :active_page => page)
    World.next_frame
    assert PokeAccess::Locator.hidden?($game_map.events[14])
  end

  test "the Ruins of Alph list the tile puzzles and the walls, say a wall that opens, count the puzzles, and give the walls' keys with the assist alone" do
    on_map(50)
    [1, 55].each_with_index { |id, i| place(id, 24 + 17 * i, 8, [TestCmd.new(355, ["pbTilePuzzle(1)"])]) }
    [38, 46, 47, 48].each_with_index { |id, i| place(id, 24 + 17 * i, 3, [TestCmd.new(355, ["UnownMessage.new"])], "Paredes") }
    walls = (1..4).map { |n| t(:vitro_alph_wall, :n => n) }
    assert_equal ([t(:vitro_alph_tile_puzzle)] * 2 + walls).sort, listed
    tick
    $game_switches[67] = true
    assert_equal [[t(:vitro_alph_wall_opened, :n => 2), false]], tick
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, 48)
    $game_switches[66] = true
    assert_equal [], tick, "wall 4 opened as it was read: core tells that"
    $game_switches[72] = true
    assert_equal ([t(:vitro_alph_tile_puzzle)] + walls).sort, listed, "a solved puzzle's floor is a hole now"
    assert_includes info_key, t(:vitro_alph_solved)
    refute_includes info_key, t(:vitro_alph_walls_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:vitro_alph_walls_hint)
  end

  test "the chamber's door gives, with the assist alone, the way to Green and then talking to him, and nothing once open" do
    on_map(52)
    $game_variables[44] = 0
    refute_includes info_key.to_s, t(:vitro_alph_door_later)
    PokeAccess::Config.puzzle_assist = true
    [[0, :vitro_alph_door_later], [2, :vitro_alph_door_green]].each do |value, key|
      $game_variables[44] = value
      assert_includes info_key, t(key)
    end
    $game_variables[44] = 3
    refute PokeAccess::Puzzles.active?
  end

  test "the pillar's answer is the word its page compares, on the info key with the assist alone" do
    on_map(155)
    check = TestCmd.new(111, [12, 'unownWord == _I("WORD") || unownWord == "OTHER"'])
    place(3, 60, 9, [TestCmd.new(355, ["showBlocUnown"]), check])
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:vitro_alph_pillar_answer, :word => "WORD"), info_key
  end

  test "the Hidden Tower says, with the assist alone, what brings Rayquaza out, until Kyogre and Groudon are caught" do
    on_map(132)
    refute PokeAccess::Puzzles.active?
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:vitro_tower_hint), info_key
    $game_switches[148] = true
    $game_switches[149] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the Sinjoh circles are named by their legendary until one is chosen" do
    on_map(154)
    $game_variables[45] = 1
    [[6, 53, 14], [11, 60, 14], [12, 57, 9]].each { |id, x, y| place(id, x, y, [TestCmd.new(102, [["yes", "no"]])]) }
    keys = [:vitro_sinjoh_dialga, :vitro_sinjoh_palkia, :vitro_sinjoh_giratina]
    assert_equal keys.map { |k| t(k) }.sort, listed
    $game_variables[45] = 7
    assert_equal [], listed
  end

  test "a new game starts with the keyboard for text, and a game already going keeps its choice" do
    was = $PokemonSystem
    $PokemonSystem = PokemonSystem.new
    $PokemonSystem.keyboardEntry = 1
    temp = PokemonTemp.new
    temp.begunNewGame = false
    assert_equal 1, $PokemonSystem.keyboardEntry, "a load leaves it"
    temp.begunNewGame = true
    assert_equal 0, $PokemonSystem.keyboardEntry
    $PokemonSystem.keyboardEntry = 1
    temp.begunNewGame = true
    assert_equal 1, $PokemonSystem.keyboardEntry, "set again during the same new game"
  ensure
    $PokemonSystem = was
  end

  test "a Farfetch'd on screen is said where it stands and the way it looks as that changes, the tile behind with the assist" do
    on_map(59)
    $game_variables[32] = 10
    bird = place(36, 20, 66, [TestCmd.new(355, ["facing_away_from_player?(36)"])], "083")
    bird.direction = 4
    $game_player.y = 64
    assert_equal [], tick, "off screen"
    $game_player.x = 15
    assert_equal [[bird_line(bird), false]], tick
    assert_equal [], tick
    bird.direction = 2
    assert_equal [[bird_line(bird), false]], tick
    refute_includes info_key, t(:vitro_ilex_hint_above)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:vitro_ilex_hint_above)
    bird.direction = 4
    tick
    floor = t(:vitro_ilex_hint_floor, :x => 19, :y => 70, :dir => PokeAccess::Routes::Text.toward(2))
    assert_includes info_key, floor, "its back to the wall on its right: the floor to the south turns it down"
    $game_player.x = 1
    assert_equal [], tick, "off screen"
    $game_switches[117] = true
    refute PokeAccess::Puzzles.active?
  end

  test "with the assist a Farfetch'd is sent on toward the corner it is caught at, turned there by its floor and caught from behind" do
    on_map(59)
    $game_variables[32] = 10
    ilex = PokeAccess::VitroIlex
    first = place(36, 10, 56, [], "083")
    second = place(39, 35, 43, [], "083")
    first.direction = 6
    assert_equal [:vitro_ilex_hint_drive, { :x => 11, :y => 56, :cx => 10, :cy => 66 }], ilex.hint(36)
    first.x = 20
    first.direction = 2
    assert_equal [:vitro_ilex_hint_drive, { :x => 19, :y => 56, :cx => 20, :cy => 66 }], ilex.hint(36)
    first.y = 66
    first.direction = 8
    assert_equal [:vitro_ilex_hint_floor, { :x => 19, :y => 70, :dir => PokeAccess::Routes::Text.toward(2) }], ilex.hint(36)
    first.x = 10
    first.direction = 2
    assert_equal :vitro_ilex_hint_above, ilex.hint(36)
    second.direction = 2
    assert_equal [:vitro_ilex_hint_drive, { :x => 35, :y => 44, :cx => 45, :cy => 43 }], ilex.hint(39)
    second.y = 53
    assert_equal [:vitro_ilex_hint_drive, { :x => 35, :y => 52, :cx => 45, :cy => 53 }], ilex.hint(39)
    second.x = 45
    assert_equal [:vitro_ilex_hint_drive, { :x => 44, :y => 53, :cx => 45, :cy => 43 }], ilex.hint(39)
    second.y = 43
    floor = [:vitro_ilex_hint_floor, { :x => 48, :y => 43, :dir => PokeAccess::Routes::Text.toward(6) }]
    [2, 4, 8].each do |d|
      second.direction = d
      assert_equal floor, ilex.hint(39), "looking #{d}: the tile behind is a wall or reached only across a floor that turns it"
    end
    second.direction = 6
    assert_equal :vitro_ilex_hint_left_north, ilex.hint(39)
  end

  private

  def bird_line(ev)
    name = PokeAccess::Locator.sprite_species(ev.character_name) || PokeAccess::Locator.target_name(ev)
    t(:vitro_ilex_bird, :name => name, :at => PokeAccess::Routes::Text.steps([2, 2, 6, 6, 6, 6, 6]),
                        :dir => PokeAccess::Routes::Text.toward(ev.direction))
  end

  def place(id, x, y, list, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }.sort
  end

  def info_key
    PokeAccess::Info.map_text
  end

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  def on_map(map)
    Harness.load_puzzles("vitro")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    [7, 11, 66, 67, 68, 69, 72, 73, 74, 75, 89, 90, 91, 117, 118, 148, 149].each { |s| $game_switches[s] = false }
    [32, 44, 45].each { |v| $game_variables[v] = 0 }
    $game_player.x = 1
    $game_player.y = 1
    World.next_frame
  end

  # Runs the block on rows (WALKWAY unless given) as map map_id, putting the real map and player back.
  def on_edge_world(map_id, rows = WALKWAY)
    old_map = $game_map
    old_player = $game_player
    world = EdgeWorld.new(rows, map_id)
    $game_map = world
    $game_player = TileWorldPlayer.new(world.start[0], world.start[1])
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
    yield
  ensure
    $game_map = old_map
    $game_player = old_player
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
  end

  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end
end
