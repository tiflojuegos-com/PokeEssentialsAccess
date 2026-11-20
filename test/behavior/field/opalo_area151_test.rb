# Opalo's Área 151 with the puzzle assist: the next step of a shortest way to the roof, by the map, the region the player
# stands in, the lit colour, the cards, the opened doors and the story (variable 249), also back after a defeat by Apolo,
# quiet through scenes, and nothing of it without the assist; the colour panels and the magnetic doors named without it.
class OpaloArea151Test < PokeAccessTest
  test "the colour panels are named, and the way on is told with the assist alone" do
    at(441, 14, 57)
    lift = place(18, 14, 43, [menu("P2", "P3", "Nada")])
    place(17, 15, 43, [menu("P2", "P3", "Nada")])
    panel = place(29, 21, 5, [menu("Rojo", "Verde")])
    door = place(21, 76, 12, [], "", 1106)
    assert_equal t(:op_color_panel), PokeAccess::Puzzles.piece_name(panel)
    assert_equal t(:op_a151_door), PokeAccess::Puzzles.piece_name(door)
    refute_includes info_key.to_s, t(:op_a151_next_lift, :at => from(lift), :choice => "P3")
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:op_a151_next_lift, :at => from(lift), :choice => "P3")
    assert_hint(:op_a151_next_lift, :at => from(lift), :choice => "P3")
    at(450, 33, 24)
    far = place(12, 73, 32, [menu("Rojo", "Verde", "Amarillo")])
    assert_equal t(:op_color_panel), PokeAccess::Puzzles.piece_name(far)
  end

  test "a colour panel is told with the option to choose, in the game's words" do
    PokeAccess::Config.puzzle_assist = true
    at(441, 6, 19, [798])
    panel = place(29, 21, 5, [menu("Rojo", "Verde")])
    place(32, 22, 5, [menu("Rojo", "Verde")])
    assert_includes info_key, t(:op_a151_next_panel, :at => from(panel), :choice => "Verde")
    assert_hint(:op_a151_next_panel, :at => from(panel), :choice => "Verde")
    at(449, 57, 56, [797])
    [16, 17].each { |id| place(id, 38 + id, 47, [menu("Rojo", "Verde", "Amarillo")]) }
    near = place(18, 56, 47, [menu("Rojo", "Verde", "Amarillo")])
    assert_includes info_key, t(:op_a151_next_panel, :at => from(near), :choice => "Amarillo")
    assert_hint(:op_a151_next_panel, :at => from(near), :choice => "Amarillo")
  end

  test "the blue card is fetched, and then the door it opens" do
    PokeAccess::Config.puzzle_assist = true
    at(450, 21, 44, [797])
    card = place(20, 58, 14, [])
    assert_includes info_key, t(:op_a151_next_item, :at => from(card), :item => PokeAccess::OpaloArea151.item_name(:TARAZUL))
    assert_hint(:op_a151_next_item, :at => from(card), :item => PokeAccess::OpaloArea151.item_name(:TARAZUL))
    at(449, 71, 6, [797, 800])
    door = place(38, 66, 16, [], "", 1106)
    place(37, 65, 16, [], "", 1106)
    assert_includes info_key, t(:op_a151_next_door, :at => from(door))
    assert_hint(:op_a151_next_door, :at => from(door))
  end

  test "Genista is the way on past the yellow lasers, and after her the stairs north" do
    PokeAccess::Config.puzzle_assist = true
    at(452, 17, 41, [799, 800, 805])
    row = place(11, 17, 26, [])
    place(12, 18, 26, [])
    place(13, 16, 26, [])
    assert_includes info_key, t(:op_a151_next_genista, :at => from(row))
    assert_hint(:op_a151_next_genista, :at => from(row))
    at(452, 17, 26, [799, 800, 805], 3)
    stairs = place(4, 17, 2, [])
    assert_includes info_key, t(:op_a151_next_exit, :at => from(stairs))
    assert_hint(:op_a151_next_exit, :at => from(stairs))
  end

  test "after the scenes the way to Apolo, the roof door, and Apolo on the roof" do
    PokeAccess::Config.puzzle_assist = true
    done = [799, 800, 801, 805, 810, 831]
    at(454, 81, 16, done, 25)
    door = place(34, 81, 9, [])
    [33, 35].each { |id| place(id, 47 + id, 9, []) }
    assert_includes info_key, t(:op_a151_next_exit, :at => from(door))
    assert_hint(:op_a151_next_exit, :at => from(door))
    at(455, 70, 47, done, 25)
    floor = place(25, 68, 47, [])
    assert_includes info_key, t(:op_a151_next_apolo, :at => from(floor))
    assert_hint(:op_a151_next_apolo, :at => from(floor))
    at(455, 66, 47, done + [832], 30)
    roof = place(8, 66, 37, [])
    place(7, 65, 37, [])
    assert_includes info_key, t(:op_a151_next_exit, :at => from(roof))
    assert_hint(:op_a151_next_exit, :at => from(roof))
    at(456, 13, 18, done + [832], 30)
    apolo = place(5, 23, 15, [])
    assert_includes info_key, t(:op_a151_next_apolo, :at => from(apolo))
    assert_hint(:op_a151_next_apolo, :at => from(apolo))
    $game_variables[251] = 1
    assert_nil PokeAccess::OpaloArea151.next_step(456, 13, 18)
  end

  test "the way never goes through Apolo's scene that sends the player back to the way in" do
    PokeAccess::Config.puzzle_assist = true
    at(441, 52, 47, [798])
    scene = place(58, 51, 47, [])
    pad = place(13, 62, 15, [])
    line = info_key
    assert_includes line, t(:op_a151_next_pad, :at => from(pad))
    assert_hint(:op_a151_next_pad, :at => from(pad))
    refute_includes line, t(:op_a151_next_exit, :at => from(scene))
    at(441, 55, 47, [798], 1)
    place(58, 51, 47, [])
    pad = place(13, 62, 15, [])
    assert_includes info_key, t(:op_a151_next_pad, :at => from(pad))
    assert_hint(:op_a151_next_pad, :at => from(pad))
    assert_equal [], PokeAccess::OpaloArea151::STEPS.select { |s| s[1] == 441 && !(s[2] & (55..61).to_a).empty? }
  end

  test "after a defeat by Apolo the way back to the roof is told, and nothing on the roof while his scene runs" do
    PokeAccess::Config.puzzle_assist = true
    done = [799, 800, 801, 805, 810, 831, 832]
    at(441, 12, 46, done, 30)
    lift = place(19, 8, 35, [])
    place(20, 7, 35, [])
    $game_variables[251] = 10
    assert_includes info_key, t(:op_a151_next_exit, :at => from(lift))
    assert_hint(:op_a151_next_exit, :at => from(lift))
    at(455, 66, 42, done, 30)
    roof = place(8, 66, 37, [])
    place(7, 65, 37, [])
    $game_variables[251] = 10
    assert_includes info_key, t(:op_a151_next_exit, :at => from(roof))
    assert_hint(:op_a151_next_exit, :at => from(roof))
    $game_variables[251] = 10
    assert_nil PokeAccess::OpaloArea151.next_step(456, 13, 18)
    $game_variables[251] = 0
    $game_switches[847] = true
    assert_nil PokeAccess::OpaloArea151.next_step(441, 12, 46)
  end

  test "a step held by an event is dropped on a new map, and a chain of scenes says nothing until it ends" do
    PokeAccess::Config.puzzle_assist = true
    at(454, 81, 46, [799, 800, 801, 805, 810], 3)
    inside = place(38, 81, 47, [])
    assert_includes tick, t(:op_a151_next_exit, :at => from(inside))
    assert_hint(:op_a151_next_exit, :at => from(inside))
    interpreter = $game_system.map_interpreter
    def interpreter.running?; true; end
    assert_equal [], tick { new_map(455, 57, 44) }
    assert_nil PokeAccess::OpaloArea151.step
    assert_equal [], tick { new_map(454, 80, 45); $game_variables[249] = 5 }
    assert_nil PokeAccess::OpaloArea151.step
    assert_equal [], tick { new_map(454, 81, 16); $game_variables[249] = 25; $game_switches[831] = true }
    assert_nil PokeAccess::OpaloArea151.step
    door = place(34, 81, 9, [])
    place(38, 81, 47, [])
    def interpreter.running?; false; end
    said = tick
    assert_includes said, t(:op_a151_next_exit, :at => from(door))
    assert_hint(:op_a151_next_exit, :at => from(door))
  end

  test "a new step is said as it comes, and a scene does not go through the steps it crosses" do
    PokeAccess::Config.puzzle_assist = true
    at(452, 17, 41, [799, 800, 805])
    place(11, 17, 26, [])
    stairs = place(4, 17, 2, [])
    tick
    interpreter = $game_system.map_interpreter
    def interpreter.running?; true; end
    assert_equal [], tick { $game_player.y = 26; $game_variables[249] = 3 }
    def interpreter.running?; false; end
    assert_includes tick, t(:op_a151_next_exit, :at => from(stairs))
    assert_hint(:op_a151_next_exit, :at => from(stairs))
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The assist's line for the step now, by its key and what it is told with.
  def assert_hint(key, vars)
    assert_equal [key, vars], PokeAccess::OpaloArea151.hint
  end

  def from(ev); PokeAccess::Puzzles.offset_phrase(ev.x - $game_player.x, ev.y - $game_player.y); end

  def menu(*words); TestCmd.new(102, [words, words.size]); end

  # Puts the player at (x, y) of map with only the given switches of the area on and variable 249 at story.
  def at(map, x, y, on = [], story = 0)
    assist = PokeAccess::Config.puzzle_assist
    Harness.load_puzzles("opalo")
    PokeAccess::Config.puzzle_assist = assist
    World.clear_events
    $game_map.map_id = map
    ((797..812).to_a + [831, 832, 847]).each { |s| $game_switches[s] = on.include?(s) }
    $game_variables[249] = story
    $game_variables[251] = 0
    $game_self_switches = {}
    $game_player.x = x
    $game_player.y = y
    PokeAccess::OpaloArea151.instance_variable_set(:@step, nil)
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Puzzles::Auto.forget
    World.next_frame
  end

  def place(id, x, y, list, sprite = "", tile = 0)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page, :tile_id => tile)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # Moves the player to (x, y) of a freshly loaded map, as a transfer does, the world settled on it.
  def new_map(map, x, y)
    World.clear_events
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    World.next_frame
    PokeAccess::World::Epoch.settle
  end

  # What the puzzles say on the next map frame, after the block.
  def tick
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup.map { |line| line[0] }
  end

  def info_key; PokeAccess::Info.map_text; end
end
