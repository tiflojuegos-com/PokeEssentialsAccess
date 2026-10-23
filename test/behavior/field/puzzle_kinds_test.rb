# Pokemon Z's map puzzles as its shipped profile declares them (the rune grid, the palace busts, the ship's cranks,
# valves and obstacles): said by the map frame from arrival on, by the info key and in the locator's puzzles category.
class PuzzleKindsTest < PokeAccessTest
  # The rune grid's map, the variable holding its stage (1 to 3 while a letter is asked for, 4 and up once done) and
  # the switches that mark the Y, the Z and the win.
  GRID_MAP = 119
  STAGE = 95
  Y_DONE = 190
  Z_DONE = 193
  WON = 194
  # The tile each rune lies on and its spoken name, in reading order.
  RUNE_TILES = [[13, 11], [15, 11], [17, 11], [13, 13], [15, 13], [17, 13], [13, 15], [15, 15], [17, 15]].freeze
  RUNES = [:cell_tl, :cell_tc, :cell_tr, :cell_ml, :cell_c, :cell_mr, :cell_bl, :cell_bc, :cell_br].freeze
  # The runes each letter lights.
  X_RUNES = [:cell_tl, :cell_tr, :cell_c, :cell_bl, :cell_br].freeze
  Y_RUNES = [:cell_tl, :cell_tr, :cell_c, :cell_bc].freeze
  Z_RUNES = [:cell_tl, :cell_tc, :cell_tr, :cell_c, :cell_bl, :cell_bc, :cell_br].freeze
  # The switches lit so that each rune's switch reads apart from the next number's: the top centre, middle left,
  # centre, bottom left and bottom right runes.
  ALTERNATE = [173, 175, 184, 186, 188].freeze
  # The switches of the runes that form the X.
  X_SWITCHES = [172, 174, 184, 186, 188].freeze
  # The ship's three decks and the palace room with two busts.
  SHIP_MAPS = [143, 144, 145].freeze
  PALACE_MAP = 191

  # The shipped profile's puzzle declarations on the maps these tests visit, as [map, declaration]: the profile is
  # evaluated once, through the harness (so a mutant of it is the one tested), and its declarations kept.
  def self.z_puzzles
    @z_puzzles ||= begin
      path = File.join(Harness::ROOT, "games", "pokemon_z", "puzzles.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      ([GRID_MAP, PALACE_MAP, 172] + SHIP_MAPS).map { |m| [m, PokeAccess::World::Mechanics.declared(m)] }
    end
  end
  private_class_method :z_puzzles

  def setup
    super
    self.class.send(:z_puzzles).each { |map, spec| PokeAccess::World::Mechanics.declare(map, spec) }
  end

  test "walking into the rune room says the letter to form, queued, once" do
    enter(GRID_MAP, 5, 5) { $game_variables[STAGE] = 1 }
    assert_equal [[t(:puzzle_form, :name => "X"), false]], SpeakCapture.log, "on arrival"
    assert_equal [], frame, "the next frame"
  end

  test "a puzzle that starts with the player in the room says its first letter as the one to form" do
    enter(GRID_MAP, 5, 5) { $game_variables[STAGE] = 0 }
    assert_equal [t(:puzzle_form, :name => "X")], frame { $game_variables[STAGE] = 1 }
  end

  test "stepping onto a rune plays its tone, panned by its column and pitched by its row, and says nothing yet" do
    enter_runes
    played = capture_se do
      [[13, 11], [15, 13], [17, 15]].each { |x, y| assert_equal [], frame { step_to(x, y) }, "onto #{x}, #{y}" }
    end
    assert_equal [["pa_guide_l", 140], ["pa_guide_c", 110], ["pa_guide_r", 85]], played
  end

  test "stepping off a rune and back onto it plays its tone again" do
    enter_runes
    played = capture_se do
      frame { step_to(13, 11) }
      frame { step_to(12, 11) }
      frame { step_to(13, 11) }
    end
    assert_equal [["pa_guide_l", 140], ["pa_guide_l", 140]], played
  end

  test "a rune is said, interrupting, with its state once the game's toggle has settled" do
    enter_runes
    frame { step_to(13, 11) }
    assert_equal [], frame, "one frame on"
    frame
    assert_equal [[rune(:cell_tl, false), true]], SpeakCapture.log, "two frames on"
    assert_equal [], frame, "and not again"
  end

  test "a rune lit under a player standing on it is said at once" do
    enter_runes
    frame { step_to(15, 13) }
    2.times { frame }
    assert_equal [rune(:cell_c, true)], frame { $game_switches[184] = true }
  end

  test "a formed letter announces the next one" do
    enter_runes
    assert_equal [t(:puzzle_next, :name => "Y")], frame { $game_switches[Y_DONE] = true }, "the Y"
    assert_equal [t(:puzzle_next, :name => "Z")], frame { $game_switches[Z_DONE] = true }, "the Z"
  end

  test "with assist, each new letter lists the runes it lights" do
    PokeAccess::Config.puzzle_assist = true
    enter(GRID_MAP, 5, 5) { $game_variables[STAGE] = 1 }
    assert_equal ["#{t(:puzzle_form, :name => 'X')}. #{t(:puzzle_light, :cells => names(X_RUNES))}"], SpeakCapture.lines
    assert_equal ["#{t(:puzzle_next, :name => 'Y')}. #{t(:puzzle_light, :cells => names(Y_RUNES))}"],
                 frame { $game_switches[Y_DONE] = true }
    assert_equal ["#{t(:puzzle_next, :name => 'Z')}. #{t(:puzzle_light, :cells => names(Z_RUNES))}"],
                 frame { $game_switches[Z_DONE] = true }
  end

  test "the info key reads the letter and the runes row by row" do
    ALTERNATE.each { |s| $game_switches[s] = true }
    enter_runes
    assert_equal [[t(:puzzle_form, :name => "X"), alternate_rows].join(". ")], info_key
  end

  test "with assist, the info key adds the runes still to light and those to put out" do
    PokeAccess::Config.puzzle_assist = true
    ALTERNATE.each { |s| $game_switches[s] = true }
    enter_runes
    assert_equal [[t(:puzzle_form, :name => "X"), alternate_rows,
                   t(:puzzle_need, :cells => names([:cell_tl, :cell_tr])),
                   t(:puzzle_remove, :cells => names([:cell_tc, :cell_ml]))].join(". ")],
                 info_key
  end

  test "with assist, the info key says when the runes already match the letter" do
    PokeAccess::Config.puzzle_assist = true
    X_SWITCHES.each { |s| $game_switches[s] = true }
    enter_runes
    rows = [t(:puzzle_row, :n => 1, :cells => states(true, false, true)),
            t(:puzzle_row, :n => 2, :cells => states(false, true, false)),
            t(:puzzle_row, :n => 3, :cells => states(true, false, true))]
    assert_equal [[t(:puzzle_form, :name => "X"), *rows, t(:puzzle_match)].join(". ")], info_key
  end

  test "the locator lists the runes by name, on their tiles" do
    enter_runes
    assert_equal RUNE_TILES.each_with_index.map { |(x, y), i| [x, y, t(RUNES[i])] }.sort, puzzle_targets
  end

  test "the locator leads the player onto each rune" do
    enter_runes
    assert_equal [true] * 9, PokeAccess::Puzzles.category_targets.map { |tg| PokeAccess::Locator.onto?(tg) }
  end

  test "the win is said once" do
    enter_runes
    frame { $game_switches[WON] = true }
    assert_equal [[t(:puzzle_solved), false]], SpeakCapture.log
    assert_equal [], frame, "and not again"
  end

  test "the runes the game puts out after the win, the stage not yet past the last letter, say nothing" do
    enter_runes
    frame { $game_switches[Y_DONE] = true; $game_switches[Z_DONE] = true }
    frame { step_to(17, 15) }
    2.times { frame }
    assert_equal [rune(:cell_br, true)], frame { $game_switches[188] = true }, "the rune that forms the Z"
    assert_equal [t(:puzzle_solved)], frame { $game_switches[WON] = true }, "the win"
    assert_equal [], frame { [172, 173, 174, 175, 184, 185, 186, 187, 188].each { |s| $game_switches[s] = false } },
                 "the runes put out before the transfer"
  end

  test "reaching the stage past the last letter is the win too" do
    enter(GRID_MAP, 5, 5) do
      $game_variables[STAGE] = 3
      $game_switches[Y_DONE] = true
      $game_switches[Z_DONE] = true
    end
    assert_equal [t(:puzzle_solved)], frame { $game_variables[STAGE] = 4 }
  end

  test "walking into a solved rune room says nothing" do
    { "the win's switch" => [1, true], "the stage past the last" => [4, false] }.each do |what, (stage, won)|
      SpeakCapture.clear
      enter(GRID_MAP, 5, 5) do
        $game_variables[STAGE] = stage
        $game_switches[WON] = won
      end
      assert_equal [], SpeakCapture.lines + frame, what
    end
  end

  test "outside its stages, a rune plays no tone and says nothing, and the info key is not the grid's" do
    { "before the first" => 0, "past the last" => 4 }.each do |what, stage|
      SpeakCapture.clear
      enter(GRID_MAP, 5, 5) { $game_variables[STAGE] = stage }
      played = capture_se do
        3.times { |i| assert_equal [], frame { step_to(13, 11) if i == 0 }, "#{what}, frame #{i}" }
      end
      assert_equal [], played, what
      assert_nil PokeAccess::Puzzles.info_line, what
    end
  end

  test "a stage that drops back before the first says nothing" do
    enter_runes
    assert_equal [], frame { $game_variables[STAGE] = 0 }
  end

  test "coming back into the rune room takes its puzzle afresh, the letter said again" do
    enter_runes
    $game_map.map_id = 2
    assert_equal [], frame, "on a map with no puzzle"
    $game_map.map_id = GRID_MAP
    assert_equal [t(:puzzle_form, :name => "X")], frame
  end

  test "walking into the palace says nothing of its busts" do
    enter_palace
    assert_equal [], SpeakCapture.lines + frame
  end

  test "a turned bust says where it faces, interrupting" do
    bust, = enter_palace
    frame { bust.direction = 6 }
    assert_equal [["#{t(:statue_bust)}: #{t(:face_east)}", true]], SpeakCapture.log
  end

  test "with assist, a turned bust says whether it faces right, or where it should face" do
    PokeAccess::Config.puzzle_assist = true
    west, north = enter_palace
    assert_equal ["#{t(:statue_bust)}: #{t(:face_west)}. #{t(:statue_ok)}"], frame { west.direction = 4 },
                 "the west one"
    assert_equal ["#{t(:statue_bust)}: #{t(:face_east)}. #{t(:statue_goal, :dir => t(:face_north))}"],
                 frame { north.direction = 6 },
                 "the north one"
  end

  test "the info key says the bust in front, with assist where it should face" do
    PokeAccess::Config.puzzle_assist = true
    _west, north = enter_palace
    north.direction = 6
    frame
    facing(8) do
      step_to(12, 8)
      assert_equal ["#{t(:statue_bust)}: #{t(:face_east)} (#{t(:statue_goal, :dir => t(:face_north))})"], info_key
    end
  end

  test "with no bust in front, the info key says every bust, nearest first with where it stands" do
    PokeAccess::Config.puzzle_assist = true
    west, north = enter_palace
    west.direction = 4
    north.direction = 6
    frame
    assert_equal ["#{bust_where('2 up', :face_east)} (#{t(:statue_goal, :dir => t(:face_north))}). " \
                  "#{bust_where('6 right, 43 down', :face_west)} (#{t(:statue_ok)})"],
                 info_key
  end

  test "without assist, the info key says where each bust stands and faces, nearest first" do
    west, = enter_palace
    west.direction = 4
    frame
    assert_equal ["#{bust_where('2 up', :face_south)}. #{bust_where('6 right, 43 down', :face_west)}"], info_key
  end

  test "the locator lists the busts on their tiles" do
    enter_palace
    assert_equal [[12, 7, t(:statue_bust)], [18, 52, t(:statue_bust)]], puzzle_targets
  end

  test "the palace's other room has its bust face east" do
    PokeAccess::Config.puzzle_assist = true
    bust = nil
    enter(172, 30, 30) { bust = statue(1, 35, 11) }
    assert_equal ["#{t(:statue_bust)}: #{t(:face_east)}. #{t(:statue_ok)}"], frame { bust.direction = 6 }
  end

  test "the last bust turned right in the palace's other room is the win, not said again back in the palace" do
    bust = nil
    enter(172, 30, 30) do
      bust = statue(1, 35, 11)
      $game_variables[163] = 1
      $game_variables[164] = 1
    end
    assert_equal ["#{t(:statue_bust)}: #{t(:face_east)}", t(:puzzle_solved)],
                 frame { bust.direction = 6; $game_variables[162] = 1 }, "the last bust, in the other room"
    $game_switches[398] = true
    enter_palace
    assert_equal [], SpeakCapture.lines + frame, "back in the palace, the prize's switch on"
  end

  test "once the palace is solved, turning a bust away and back is no second win" do
    bust = nil
    enter(172, 30, 30) do
      bust = statue(1, 35, 11)
      bust.direction = 6
      [162, 163, 164].each { |v| $game_variables[v] = 1 }
      $game_switches[398] = true
    end
    frame { bust.direction = 2; $game_variables[162] = 0 }
    assert_equal ["#{t(:statue_bust)}: #{t(:face_east)}"], frame { bust.direction = 6; $game_variables[162] = 1 }
  end

  test "on each deck of the ship, coming beside an obstacle says it and its side, queued, once while there" do
    SHIP_MAPS.each do |map|
      enter(map, 3, 5) { ship_obstacle(1, 6, 5, "humo") }
      assert_equal [], SpeakCapture.lines, "map #{map}: away from it"
      frame { step_to(5, 5) }
      assert_equal [[beside(:ship_steam, :side_right), false]], SpeakCapture.log, "map #{map}: beside it"
      assert_equal [], frame, "map #{map}: still beside it"
    end
  end

  test "arriving beside an obstacle warns, and coming back beside it warns again" do
    enter(143, 5, 5) { ship_obstacle(1, 6, 5, "humo") }
    assert_equal [beside(:ship_steam, :side_right)], SpeakCapture.lines, "arriving beside it"
    assert_equal [], frame { step_to(4, 5) }, "a step away"
    assert_equal [beside(:ship_steam, :side_right)], frame { step_to(5, 5) }, "beside it again"
  end

  test "a Sharpedo moving up beside a player standing still is said as a moving trap, with its side" do
    shark = nil
    enter(143, 9, 7) { shark = ship_obstacle(2, 9, 9, "sharpedo") }
    assert_equal [], SpeakCapture.lines, "away from the shark"
    assert_equal [beside(:obstacle_trap, :side_down)], frame { shark.y = 8 }
  end

  test "a Sharpedo moving up beside a player already beside a steam jet is said, the jet not again" do
    shark = nil
    enter(143, 9, 7) do
      ship_obstacle(1, 10, 7, "humo")
      shark = ship_obstacle(2, 9, 9, "sharpedo")
    end
    assert_equal [beside(:ship_steam, :side_right)], SpeakCapture.lines, "arriving beside the jet"
    assert_equal [beside(:obstacle_trap, :side_down)], frame { shark.y = 8 }
  end

  test "a Sharpedo sending the player back to the deck's entrance is said as its doing, not as a bare teleport" do
    enter(144, 10, 10) { ship_obstacle(7, 11, 10, "sharpedo") }
    assert_equal [[t(:ship_sharpedo_back), false]], teleported(10, 10, 4, 8), "touched by the Sharpedo"
    plain = PokeAccess::Locator.teleport_line(4 - 10, 8 - 12, 4, 8)
    assert_equal [[plain, false]], teleported(10, 12, 4, 8), "with no Sharpedo beside"
  end

  test "a steam jet that comes on beside a player standing still warns" do
    jet = nil
    enter(143, 5, 5) { jet = ship_obstacle(1, 6, 5, "") }
    assert_equal [], SpeakCapture.lines, "the jet off"
    jet.character_name = "humo"
    World.next_frame
    assert_equal [beside(:ship_steam, :side_right)], frame
  end

  test "a crank beside the player is no obstacle" do
    enter(143, 5, 5) { ship_control(1, 6, 5, TestCmd.new(122, [132, 132, 0, 0, 1])) }
    assert_equal [], SpeakCapture.lines + frame
  end

  test "the locator lists the ship's cranks and valves by name and its steam jets, touching ones as one" do
    enter(143, 3, 3) do
      ship_control(1, 8, 3, TestCmd.new(122, [132, 132, 0, 0, 1]))
      ship_control(2, 9, 6, TestCmd.new(121, [312, 312, 0]))
      ship_obstacle(3, 5, 8, "humo")
      ship_obstacle(4, 6, 9, "humo")
      ship_obstacle(5, 12, 12, "humo")
      ship_obstacle(6, 14, 2, "sharpedo")
    end
    assert_equal [[5, 8, t(:ship_steam)], [8, 3, t(:ship_crank_red)], [9, 6, t(:ship_valve1)], [12, 12, t(:ship_steam)]],
                 puzzle_targets,
                 "the Sharpedo, which move, are left out"
  end

  test "on the ship, the locator leads onto a floor plate, and up to a crank or a steam jet" do
    enter(143, 3, 3) do
      ship_control(1, 8, 3, TestCmd.new(122, [132, 132, 0, 0, 1]))
      plate = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [312, 312, 0])])
      $game_map.events[2] = TestGameEvent.new(:id => 2, :x => 9, :y => 6, :pages => [plate])
      ship_obstacle(3, 5, 8, "humo")
    end
    onto = PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, PokeAccess::Locator.onto?(tg)] }
    assert_equal [[5, 8, false], [8, 3, false], [9, 6, true]], onto.sort
  end

  test "the info key on the ship reads each crank and valve" do
    $game_variables[132] = 1
    $game_variables[134] = 1
    $game_switches[313] = true
    enter(143, 3, 5)
    assert_equal [["#{t(:ship_crank_red)}: #{t(:ship_crank_on)}", "#{t(:ship_crank_green)}: #{t(:ship_crank_off)}",
                   "#{t(:ship_crank_blue)}: #{t(:ship_crank_on)}", "#{t(:ship_valve1)}: #{t(:ship_valve_off)}",
                   "#{t(:ship_valve2)}: #{t(:ship_valve_on)}"].join(". ")],
                 info_key
  end

  test "with assist, the info key on the ship says how it works after the cranks and valves" do
    PokeAccess::Config.puzzle_assist = true
    enter(143, 3, 5) do
      ship_control(1, 8, 3, TestCmd.new(122, [132, 132, 0, 0, 1]))
      ship_obstacle(2, 5, 8, "humo")
    end
    flags = { :ship_crank_red => :ship_crank_off, :ship_crank_green => :ship_crank_off,
              :ship_crank_blue => :ship_crank_off, :ship_valve1 => :ship_valve_off, :ship_valve2 => :ship_valve_off }
    said = flags.map { |what, state| "#{t(what)}: #{t(state)}" } + [t(:ship_hint)]
    assert_equal [said.join(". ")], info_key
  end

  test "opening both of the ship's valves says each, then that the way to the captain is open" do
    enter(143, 3, 5)
    assert_equal ["#{t(:ship_valve2)}: #{t(:ship_valve_on)}"], frame { $game_switches[313] = true }, "the second valve"
    assert_equal ["#{t(:ship_valve1)}: #{t(:ship_valve_on)}", t(:ship_solved)], frame { $game_switches[312] = true },
                 "then the first"
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # What is said of a group of obstacles beside the player: its name (an i18n key), then the sides it is on.
  def beside(name, *sides)
    "#{t(name)}, #{PokeAccess::Routes::Text.and_list(sides.map { |s| t(s) })}"
  end

  # The spoken names of the given runes, joined.
  def names(runes)
    runes.map { |r| t(r) }.join(", ")
  end

  # A row of runes' states as the info key reads them.
  def states(*lit)
    lit.map { |on| t(on ? :puzzle_on : :puzzle_off) }.join(", ")
  end

  # The grid's rows with the ALTERNATE switches on.
  def alternate_rows
    [t(:puzzle_row, :n => 1, :cells => states(false, true, false)),
     t(:puzzle_row, :n => 2, :cells => states(true, true, false)),
     t(:puzzle_row, :n => 3, :cells => states(true, false, true))].join(". ")
  end

  # A rune's spoken name and state.
  def rune(name, lit)
    "#{t(name)}, #{t(lit ? :puzzle_on : :puzzle_off)}"
  end

  # Walks the player onto map at (x, y) once the block has set the room up, and runs the arrival's map frame through
  # its navigation stage, where the puzzles step is, its speech left in SpeakCapture.
  def enter(map, x, y)
    $game_map.map_id = map
    step_to(x, y)
    yield if block_given?
    World.next_frame
    PokeAccess::Caches.reset_all
    SpeakCapture.clear
    PokeAccess::Frame.run_stage(:nav)
  end

  # Walks into the rune room off the grid at its first stage, the arrival's letter heard and cleared.
  def enter_runes
    enter(GRID_MAP, 5, 5) { $game_variables[STAGE] = 1 }
    SpeakCapture.clear
  end

  # Walks into the palace room with its two busts, both facing down, and answers them: [the one at 18, 52, whose goal
  # is west; the one at 12, 7, whose goal is north]. A boy stands there too.
  def enter_palace
    busts = nil
    enter(PALACE_MAP, 12, 9) do
      busts = [statue(1, 18, 52), statue(2, 12, 7)]
      World.event(:kind => :npc, :id => 3, :x => 3, :y => 3).character_name = "boy"
    end
    busts
  end

  # A bust as the info key says it from afar: its offset, as "2 up" or "6 right, 43 down", and its facing key.
  def bust_where(offset, face)
    dist = offset.split(", ").map { |leg| n, way = leg.split(" "); "#{n} #{t(:"dir_#{way}")}" }.join(", ")
    t(:statue_where, :label => t(:statue_bust), :dist => dist, :dir => t(face))
  end

  # A bust with the given id on (x, y), wearing one of the two graphics the busts use.
  def statue(id, x, y)
    ev = World.event(:kind => :npc, :id => id, :x => x, :y => y)
    ev.character_name = id.odd? ? "malvoBusto" : "malvoBusto2"
    ev
  end

  # An event of the ship wearing graphic, on (x, y).
  def ship_obstacle(id, x, y, graphic)
    ev = World.event(:kind => :npc, :id => id, :x => x, :y => y)
    ev.character_name = graphic
    ev
  end

  # A crank or valve of the ship on (x, y): its page, fired by the action button, runs command.
  def ship_control(id, x, y, command)
    page = TestPage.new(:trigger => 0, :sprite => "manivela", :list => [command])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
  end

  def step_to(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # What the map frame's teleport check says when the player, seen on (x, y), is next seen on (tx, ty) of the map.
  def teleported(x, y, tx, ty)
    step_to(x, y)
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.clear
    step_to(tx, ty)
    PokeAccess::Locator.announce_internal_teleport
    SpeakCapture.log
  end

  # Runs the block with the player facing dir, then facing down again.
  def facing(dir)
    $game_player.direction = dir
    yield
  ensure
    $game_player.direction = 2
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # What the info key says on the map.
  def info_key
    PokeAccess::Locator.refresh_info
    SpeakCapture.clear
    PokeAccess::Keys.info_key
    SpeakCapture.lines
  end

  # What the locator lists in its puzzles category, as [x, y, name] per target, sorted; nil while the category is not
  # offered. The category shown is put back after.
  def puzzle_targets
    loc = PokeAccess::Locator
    return nil unless loc.active_categories.include?(:puzzles)
    shown = loc.instance_variable_get(:@cat_id)
    begin
      loc.instance_variable_set(:@cat_id, :puzzles)
      loc.rebuild_targets
      loc.instance_variable_get(:@targets).map { |tg| [tg.x, tg.y, loc.target_name(tg)] }.sort
    ensure
      loc.instance_variable_set(:@cat_id, shown)
    end
  end

  # The sound effects the block plays, as [file name, pitch]; the game's Audio.se_play put back after.
  def capture_se
    played = []
    real = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*a| played.push([a[0][/[^\/]+\z/], a[2]]) }
    yield
    played
  ensure
    Audio.define_singleton_method(:se_play, real)
  end
end
