# The sunken ship's puzzles (games/realidea/shipwreck.rb): the telegraph and the wheel, read each frame while their
# loops run; the sea chart's route, over the wheel and examined in the bag; and the Chinchou puzzle's three fish on
# map 278, said once they settle after each arrow.

# The frames a stand-in loop runs (@steps): each one's ivar changes left on the scene, as the game's own frame work
# leaves them, then the frame drawn and the input read; a :fail frame is the game's loop failing.
module ReaShipLoop
  def actu
    (@steps || []).each do |changes|
      raise ArgumentError, "the game's loop failed" if changes == :fail
      changes.each { |k, v| instance_variable_set(k, v) }
      Graphics.update
      Input.update
    end
  end
end

# The telegraph (Morse) and the wheel (Timon), each down to the blocking loop it runs until it ends.
class Morse
  include ReaShipLoop
end

class Timon
  include ReaShipLoop
end

# Examining an object in the bag (Fusion objetos): Jeremiah's comment over the sea chart or any other object, shown
# as Kernel.pbMessage shows it (through pbMessageDisplay).
def examinarobj(item)
  chart = PBItems.const_defined?(:MAPAMAR) && item == PBItems::MAPAMAR
  Kernel.pbMessageDisplay(nil, chart ? RealideaShipwreckTest::CHART_LINE : RealideaShipwreckTest::OTHER_LINE)
end

# The Chinchou puzzle's arrows (Minijuego gambas): each moves every fish, events 3 to 5, that can go its way (the move
# route it sets, done at once here).
def gambaizda
  (3...6).each { |i| ev = $game_map.events[i]; ev.x -= 1 if ev.passable?(ev.x, ev.y, 4) }
end

def gambadcha
  (3...6).each { |i| ev = $game_map.events[i]; ev.x += 1 if ev.passable?(ev.x, ev.y, 6) }
end

def gambabajo
  (3...6).each { |i| ev = $game_map.events[i]; ev.y += 1 if ev.passable?(ev.x, ev.y, 2) }
end

def gambarriba
  (3...6).each { |i| ev = $game_map.events[i]; ev.y -= 1 if ev.passable?(ev.x, ev.y, 8) }
end

shipwreck = File.join(Harness::ROOT, "games", "realidea", "shipwreck.rb")
eval(Harness.source(shipwreck), TOPLEVEL_BINDING, shipwreck)

class RealideaShipwreckTest < PokeAccessTest
  Ship = PokeAccess::RealideaShipwreck
  # What Jeremiah says over the sea chart, and over an object he has nothing to say about.
  CHART_LINE = "Parece el recorrido que tomó el barco antes de hundirse."
  OTHER_LINE = "No tengo mucho que decir sobre ese objeto..."
  # The Chinchou puzzle as the profile declared it on map 278, kept before the first test clears the declarations.
  FISH_PUZZLE = PokeAccess::World::Mechanics.declared(278)
  # The telegraph's answer: twelve symbols.
  ANSWER = %w[punto raya raya punto punto punto punto punto raya punto raya raya]
  # The wheel's answer: six headings, as its log paints them.
  HEADINGS = ["[O]", "[NO]", "[NE]", "[E]", "[S]", "[E]"]
  # The telegraph's guide (GUIA2) as it paints the alphabet.
  GUIDE = "A: punto raya. B: raya punto punto punto. C: raya punto raya punto. D: raya punto punto. E: punto. " \
          "F: punto punto raya punto. G: raya raya punto. H: punto punto punto punto. I: punto punto. " \
          "J: punto raya raya raya. K: raya punto raya. L: punto raya punto punto. M: raya raya. N: raya punto. " \
          "O: raya raya raya. P: punto raya raya punto. Q: raya raya punto raya. R: punto raya punto. " \
          "S: punto punto punto. T: raya. U: punto punto raya. V: punto punto punto raya. W: punto raya raya. " \
          "X: raya punto punto raya. Y: raya punto raya raya. Z: raya raya punto punto"
  # The sea chart's red line from Esoteria to Kanto, leg by leg.
  ROUTE = "oeste, noroeste, noreste, este, sur, este"
  # The names the fish are said by: the species their sprites show (170 and 318), as the gen-6 stub names them.
  CHINCHOU = "Especie170"
  CARVANHA = "Especie318"
  # The dialogue reader's half-second guard: the line it said last, when, and as led.
  DIALOGUE_GUARD = [:@last_say, :@last_say_t, :@last_led]

  # A sprite as the readers see it: shown or not.
  Sprite = Struct.new(:visible)

  # A fish event: where it stands, its charset and name, whether it is still moving and whether its way is blocked.
  class Fish
    attr_accessor :id, :x, :y, :character_name, :name, :moving, :blocked
    def initialize(id, x, y, graphic)
      @id = id
      @x = x
      @y = y
      @character_name = graphic
      @name = "GAMBA"
      @moving = false
      @blocked = false
    end
    def moving?; @moving; end
    def passable?(_x, _y, _dir); !@blocked; end
  end

  test "opening, the telegraph says its painted keys and the arrows that enter a symbol unheld, once and queued" do
    scene = telegraph
    Ship.morse(scene)
    Ship.morse(scene)
    assert_equal [["#{t(:rea_morse_keys)}. #{t(:rea_morse_arrows)}", false]], SpeakCapture.log
  end

  test "its opening line adds the guide's key once the guide is owned and, with the assist, the answer's length" do
    keys = t(:rea_morse_keys)
    guide_key = t(:rea_morse_guide_key)
    arrows = t(:rea_morse_arrows)
    goal = t(:rea_morse_goal, :n => 12)
    { [true, false] => "#{keys}. #{guide_key}. #{arrows}", [false, true] => "#{keys}. #{arrows}. #{goal}",
      [true, true] => "#{keys}. #{guide_key}. #{arrows}. #{goal}" }.each do |(guide, assist), line|
      PokeAccess::Config.puzzle_assist = assist
      SpeakCapture.clear
      Ship.morse(telegraph(:guide_owned => guide))
      assert_equal [[line, false]], SpeakCapture.log, "with the guide owned: #{guide}, the assist: #{assist}"
    end
  end

  test "with key hints off it opens with only what the puzzle assist adds" do
    PokeAccess::Config.verbosity = :brief
    { false => [], true => [[t(:rea_morse_goal, :n => 12), false]] }.each do |assist, said|
      PokeAccess::Config.puzzle_assist = assist
      SpeakCapture.clear
      Ship.morse(telegraph(:guide_owned => true))
      assert_equal said, SpeakCapture.log, "with the assist #{assist}"
    end
  end

  test "the symbols already entered as it opens are not said" do
    Ship.morse(telegraph(:symbols => %w[raya punto], :count => 2))
    assert_equal [[opening_keys, false]], SpeakCapture.log
  end

  test "says each symbol entered with the row and place it is painted in, four to a row" do
    { ["raya", 1] => [1, 1], ["punto", 4] => [1, 4], ["punto", 5] => [2, 1], ["raya", 8] => [2, 4],
      ["raya", 9] => [3, 1] }.each do |(symbol, count), (row, col)|
      line = enter_symbol(symbol, count)
      assert_equal [[t(:rea_morse_slot, :sym => symbol, :row => row, :col => col), true]], line, "#{symbol} at #{count}"
    end
  end

  test "a symbol counted before the first place is said in it, and one with no count by how many there are" do
    assert_equal [[t(:rea_morse_slot, :sym => "raya", :row => 1, :col => 1), true]], enter_symbol("raya", 0)
    assert_equal [[t(:rea_morse_slot, :sym => "punto", :row => 1, :col => 3), true]],
                 enter_symbol("punto", nil, %w[raya raya])
  end

  test "says the symbols cleared, interrupting" do
    scene = telegraph(:symbols => %w[raya punto], :count => 2)
    Ship.morse(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@secuencia, [])
    Ship.morse(scene)
    assert_equal [[t(:rea_morse_clear), true]], SpeakCapture.log
  end

  test "a symbol taken back says nothing" do
    scene = telegraph(:symbols => %w[raya punto], :count => 2)
    Ship.morse(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@secuencia, %w[raya])
    Ship.morse(scene)
    assert_nothing_spoken
  end

  test "with the puzzle assist, says each symbol's place in the answer" do
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[t(:rea_morse, :sym => "punto", :n => 1, :tot => 12), true]], enter_symbol("punto", 1)
  end

  test "M shows the guide: its alphabet as painted and the key that closes it, said each time it opens" do
    scene = telegraph
    Ship.morse(scene)
    SpeakCapture.clear
    guide = scene.instance_variable_get(:@sprites)["help"]
    [true, false, true].each do |shown|
      guide.visible = shown
      Ship.morse(scene)
    end
    assert_equal [["#{GUIDE}. #{t(:rea_morse_guide_close)}", true]] * 2, SpeakCapture.log
  end

  test "with key hints off the guide is said without its closing key" do
    PokeAccess::Config.verbosity = :brief
    scene = telegraph
    Ship.morse(scene)
    scene.instance_variable_get(:@sprites)["help"].visible = true
    Ship.morse(scene)
    assert_equal [[GUIDE, true]], SpeakCapture.log
  end

  test "without a symbol list the telegraph still says its keys" do
    scene = telegraph
    scene.instance_variable_set(:@secuencia, nil)
    Ship.morse(scene)
    assert_equal [[opening_keys, false]], SpeakCapture.log
  end

  test "a telegraph without its sprites says only its keys" do
    Ship.morse(scene_with(telegraph_ivars.merge(:@sprites => {})))
    assert_equal [[opening_keys, false]], SpeakCapture.log
  end

  test "says each of the wheel's compass points as its direction word, and one it does not name as painted" do
    { "N" => t(:dir_n), "NE" => t(:dir_ne), "E" => t(:dir_e), "SE" => t(:dir_se), "S" => t(:dir_s), "SO" => t(:dir_so),
      "O" => t(:dir_o), "NO" => t(:dir_no), "X" => "X" }.each do |point, word|
      SpeakCapture.clear
      Ship.timon(wheel(:headings => [point]))
      assert_equal [[word, true]], SpeakCapture.log, "for #{point}"
    end
  end

  test "with the game in English, says the points English.dat renames as their direction words, entries too" do
    { "NW" => t(:dir_no), "W" => t(:dir_o), "SW" => t(:dir_so) }.each do |point, word|
      SpeakCapture.clear
      Ship.timon(wheel(:headings => [point]))
      assert_equal [[word, true]], SpeakCapture.log, "for #{point}"
    end
    assert_equal [t(:dir_o), t(:dir_no)], ["[W]", "[NW]"].map { |entry| Ship.point_word(entry) }, "the log's entries"
  end

  test "says the heading, interrupting, only when the wheel turns" do
    scene = wheel
    Ship.timon(scene)
    Ship.timon(scene)
    scene.instance_variable_set(:@posiciones, %w[E NE N NO O SO S SE])
    Ship.timon(scene)
    assert_equal [[t(:dir_se), true], [t(:dir_e), true]], SpeakCapture.log
  end

  test "an empty or missing heading is not said, and the rest of the wheel still is" do
    [[], nil, [""]].each do |headings|
      SpeakCapture.clear
      Ship.timon(wheel(:headings => headings, :compass => true))
      assert_equal [[t(:rea_timon_empty), false], [t(:rea_timon_key_enter), false]], SpeakCapture.log,
                   "with the headings #{headings.inspect}"
    end
  end

  test "with the compass it opens with the heading, the empty log and the keys its panel paints" do
    Ship.timon(wheel(:compass => true, :chart_owned => true))
    keys = "#{t(:rea_timon_key_enter)}. #{t(:rea_timon_key_chart)}"
    assert_equal [[t(:dir_se), true], [t(:rea_timon_empty), false], [keys, false]], SpeakCapture.log
  end

  test "its keys name only what its panel paints: entering a heading with the compass, the chart once owned" do
    { [false, true] => [[t(:dir_se), true], [t(:rea_timon_key_chart), false]],
      [true, false] => [[t(:dir_se), true], [t(:rea_timon_empty), false], [t(:rea_timon_key_enter), false]],
      [false, false] => [[t(:dir_se), true]] }.each do |(compass, chart), said|
      SpeakCapture.clear
      Ship.timon(wheel(:compass => compass, :chart_owned => chart))
      assert_equal said, SpeakCapture.log, "with the compass #{compass} and the chart #{chart}"
    end
  end

  test "with key hints off it opens without its keys" do
    PokeAccess::Config.verbosity = :brief
    Ship.timon(wheel(:compass => true, :chart_owned => true))
    assert_equal [[t(:dir_se), true], [t(:rea_timon_empty), false]], SpeakCapture.log
  end

  test "says each heading entered with its place in the log, queued, and the log emptied" do
    scene = wheel(:compass => true)
    Ship.timon(scene)
    SpeakCapture.clear
    [%w[[NO]], %w[[NO] [E]], []].each do |log|
      scene.instance_variable_set(:@combinaciontimon, log)
      Ship.timon(scene)
    end
    assert_equal [[t(:rea_timon_entry, :dir => t(:dir_no), :n => 1), false],
                  [t(:rea_timon_entry, :dir => t(:dir_e), :n => 2), false], [t(:rea_timon_empty), false]],
                 SpeakCapture.log
  end

  test "with the puzzle assist each heading entered is said out of the answer's length" do
    PokeAccess::Config.puzzle_assist = true
    scene = wheel(:compass => true)
    Ship.timon(scene)
    SpeakCapture.clear
    scene.instance_variable_set(:@combinaciontimon, %w[[NO]])
    Ship.timon(scene)
    assert_equal [[t(:rea_timon, :dir => t(:dir_no), :n => 1, :tot => 6), false]], SpeakCapture.log
  end

  test "a wheel without its sprites says only its heading" do
    scene = scene_with(wheel_ivars.merge(:@sprites => {}))
    Ship.timon(scene)
    scene.instance_variable_set(:@combinaciontimon, %w[[NO]])
    Ship.timon(scene)
    assert_equal [[t(:dir_se), true]], SpeakCapture.log
  end

  test "with the compass but no log to read, the wheel says its heading and keys" do
    Ship.timon(scene_with(wheel_ivars(:compass => true).merge(:@combinaciontimon => nil)))
    assert_equal [[t(:dir_se), true], [t(:rea_timon_key_enter), false]], SpeakCapture.log
  end

  test "without the compass the headings entered are not said" do
    scene = wheel
    Ship.timon(scene)
    scene.instance_variable_set(:@combinaciontimon, %w[[NO]])
    Ship.timon(scene)
    assert_equal [[t(:dir_se), true]], SpeakCapture.log
  end

  test "F opens the chart: its red line leg by leg and the key that closes it, said each time it opens" do
    scene = wheel(:compass => true, :chart_owned => true)
    Ship.timon(scene)
    SpeakCapture.clear
    [true, false, true].each do |shown|
      scene.instance_variable_get(:@sprites)["mapa"].visible = shown
      Ship.timon(scene)
    end
    assert_equal [["#{t(:rea_chart_route, :list => ROUTE)}. #{t(:rea_chart_back)}", true]] * 2, SpeakCapture.log
  end

  test "with key hints off the chart is said without its closing key" do
    PokeAccess::Config.verbosity = :brief
    scene = wheel(:compass => true, :chart_owned => true)
    Ship.timon(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@sprites)["mapa"].visible = true
    Ship.timon(scene)
    assert_equal [[t(:rea_chart_route, :list => ROUTE), true]], SpeakCapture.log
  end

  test "while its loop runs the telegraph is read each frame, and not once the loop is over" do
    game = loop_of(Morse, [telegraph_ivars, { :@secuencia => %w[raya], :@numero => 1 }, {}, {},
                           { :@secuencia => %w[raya punto], :@numero => 2 }, {}, { :@secuencia => [] }])
    game.actu
    assert_equal [[opening_keys, false], [t(:rea_morse_slot, :sym => "raya", :row => 1, :col => 1), true],
                  [t(:rea_morse_slot, :sym => "punto", :row => 1, :col => 2), true], [t(:rea_morse_clear), true]],
                 SpeakCapture.log
    SpeakCapture.clear
    game.instance_variable_set(:@secuencia, %w[raya])
    Input.update
    assert_nothing_spoken "the loop is over"
  end

  test "while its loop runs the wheel is read each frame, and not once the loop is over" do
    game = loop_of(Timon, [wheel_ivars, { :@posiciones => %w[E NE N NO O SO S SE] }])
    game.actu
    assert_equal [[t(:dir_se), true], [t(:dir_e), true]], SpeakCapture.log
    SpeakCapture.clear
    game.instance_variable_set(:@posiciones, %w[NE N NO O SO S SE E])
    Input.update
    assert_nothing_spoken "the loop is over"
  end

  test "a loop that fails still lets the reader go" do
    game = loop_of(Timon, [wheel_ivars, :fail])
    assert_raises(ArgumentError) { game.actu }
    SpeakCapture.clear
    game.instance_variable_set(:@posiciones, %w[E NE N NO O SO S SE])
    Input.update
    assert_nothing_spoken
  end

  test "examining the sea chart in the bag says its route before Jeremiah speaks" do
    with_sea_chart(7777) { examine(7777) }
    assert_equal [[t(:rea_chart_route, :list => ROUTE), true], [CHART_LINE, false]], SpeakCapture.log
  end

  test "examining any other object, or with no sea chart in the game, says only what the game says" do
    with_sea_chart(7777) { examine(7776) }
    examine(7777)
    assert_equal [[OTHER_LINE, false]] * 2, SpeakCapture.log
  end

  test "is asleep off map 278 or with switch 366 off, and runs with both" do
    { [278, true] => true, [278, false] => false, [1, true] => false }.each do |(map, switch), runs|
      $game_map.map_id = map
      $game_switches[366] = switch
      assert_equal runs, Ship.fish_active?, "on map #{map} with the switch #{switch}"
    end
  end

  test "off, it says nothing however the fish move" do
    fish = fish_board
    $game_switches[366] = false
    frames(1)
    fish[0].x = 17
    frames(10)
    assert_nothing_spoken
  end

  test "while the game settles the puzzle, lost, won or left, it says nothing over the game's messages" do
    [359, 360, 365].each do |switch|
      Ship.fish_reset
      fish = fish_board
      frames(1)
      $game_switches[switch] = true
      fish[0].x = 17
      frames(10)
      $game_switches[switch] = false
      assert_nothing_spoken "with the switch #{switch} on"
    end
  end

  test "its title says what the arrows move, the key to leave, the painted board and where each fish stands" do
    fish_board
    assert_equal [t(:rea_fish_intro), t(:rea_fish_exit), t(:rea_fish_board), *start_places].join(". "), Ship.fish_title
  end

  test "with key hints off its title leaves out the key to leave" do
    PokeAccess::Config.verbosity = :brief
    fish_board
    assert_equal [t(:rea_fish_intro), t(:rea_fish_board), *start_places].join(". "), Ship.fish_title
  end

  test "with none of its fish on the map, its title says what the arrows move, the key to leave and the board" do
    $game_map.map_id = 278
    assert_equal [t(:rea_fish_intro), t(:rea_fish_exit), t(:rea_fish_board)].join(". "), Ship.fish_title
  end

  test "a fish whose sprite names no species is said by its event's name, and one the map lacks is left out" do
    fish = fish_board
    fish[0].character_name = "pez_rojo"
    $game_map.events.delete(5)
    assert_equal [t(:rea_fish_intro), t(:rea_fish_exit), t(:rea_fish_board), fish_at("GAMBA", 1, 6),
                  fish_at(CARVANHA, 2, 5)].join(". "), Ship.fish_title
  end

  test "once moved, the fish are said where they stand after six frames standing still, interrupting" do
    chinchou_fish, carvanha_fish, _other = fish_board
    frames(1)
    chinchou_fish.x = 17
    carvanha_fish.x = 16
    frames(6)
    assert_nothing_spoken "while they settle"
    frames(1)
    assert_equal [[places([fish_at(CHINCHOU, 1, 5), fish_at(CARVANHA, 2, 4), fish_at(CARVANHA, 4, 6)]), true]],
                 SpeakCapture.log
  end

  test "a fish still moving holds the line back" do
    fish = fish_board
    frames(1)
    fish[0].x = 17
    fish[0].moving = true
    frames(10)
    assert_nothing_spoken "while it moves"
    fish[0].moving = false
    frames(6)
    assert_equal [[places([fish_at(CHINCHOU, 1, 5), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 4, 6)]), true]],
                 SpeakCapture.log
  end

  test "says nothing more while the fish stay where they were last said" do
    fish = fish_board
    frames(1)
    fish[0].x = 17
    frames(7)
    SpeakCapture.clear
    frames(10)
    assert_nothing_spoken
  end

  test "a fish a current carried is said as carried" do
    [38, 39, 40].each do |current|
      Ship.fish_reset
      $game_map.clear_grid
      SpeakCapture.clear
      ride_current(fish_board, current)
      assert_equal [[places([fish_at(CHINCHOU, 1, 6), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 6, 1, true)]), true]],
                   SpeakCapture.log, "on terrain #{current}"
    end
  end

  test "a current's carry is said once: the next time the fish is said where it stands" do
    fish = fish_board
    ride_current(fish, 38)
    SpeakCapture.clear
    fish[2].x = 14
    frames(7)
    assert_equal [[places([fish_at(CHINCHOU, 1, 6), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 6, 2)]), true]],
                 SpeakCapture.log
  end

  test "a fish that stops on a current is said where it stands, not as carried" do
    fish = fish_board
    $game_map.set_terrain(13, 9, 38)
    frames(1)
    fish[2].x = 13
    frames(7)
    assert_equal [[places([fish_at(CHINCHOU, 1, 6), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 4, 1)]), true]],
                 SpeakCapture.log
  end

  test "an arrow that moves no fish says so once they settle, and only once" do
    %w[gambaizda gambadcha gambabajo gambarriba].each do |arrow|
      Ship.fish_reset
      SpeakCapture.clear
      fish_board.each { |f| f.blocked = true }
      frames(1)
      send(arrow)
      frames(5)
      assert_nothing_spoken "#{arrow}: while they would settle"
      frames(10)
      assert_equal [[t(:rea_fish_stuck), true]], SpeakCapture.log, "#{arrow}: then that none moved, once"
    end
  end

  test "an arrow that moves a fish says where the three are, not that none moved" do
    fish = fish_board
    fish[1].blocked = true
    fish[2].blocked = true
    frames(1)
    gambabajo
    frames(7)
    assert_equal [[places([fish_at(CHINCHOU, 2, 6), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 4, 6)]), true]],
                 SpeakCapture.log
  end

  test "forgets where the fish were when the puzzle goes off or the map changes" do
    { "switch 366 off" => lambda { $game_switches[366] = false; frames(1); $game_switches[366] = true },
      "a map change" => lambda { PokeAccess::Caches.reset_all } }.each do |what, forget|
      Ship.fish_reset
      SpeakCapture.clear
      fish = fish_board
      frames(1)
      fish[0].x = 17
      frames(1)
      forget.call
      frames(10)
      assert_nothing_spoken "after #{what} the fish are taken where they stand"
    end
  end

  test "its green circle is a locator spot only while the puzzle runs" do
    PokeAccess::World::Mechanics.declare(278, FISH_PUZZLE)
    $game_map.map_id = 278
    spots = [false, true, false].map do |running|
      $game_switches[366] = running
      PokeAccess::Puzzles.category_targets.map { |s| [s.x, s.y, s.name] }
    end
    assert_equal [[], [[16, 11, t(:rea_fish_circle)]], []], spots
  end

  test "while it runs, the info key reads its title, and nothing before" do
    PokeAccess::World::Mechanics.declare(278, FISH_PUZZLE)
    fish_board
    lines = [false, true].map do |running|
      $game_switches[366] = running
      PokeAccess::Puzzles.info_line
    end
    assert_equal [nil, [t(:rea_fish_intro), t(:rea_fish_exit), t(:rea_fish_board), *start_places].join(". ")], lines
  end

  test "the board it describes names the two corals the picture leaves uncrossed" do
    assert_includes t(:rea_fish_board), "Coral sin tachar: fila 1, columna 1, y fila 2, columna 4"
  end

  private

  # A text of the mod's in Spanish.
  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # The telegraph's opening line with its guide not yet owned and no assist: the painted keys, then the arrows.
  def opening_keys
    "#{t(:rea_morse_keys)}. #{t(:rea_morse_arrows)}"
  end

  # The telegraph's state as it opens: the symbols entered and their count (none by default), the answer, and the
  # guide hidden, owned or not.
  def telegraph_ivars(opts = {})
    { :@secuencia => opts.fetch(:symbols, []), :@secuenciacorrecta => ANSWER, :@numero => opts.fetch(:count, 0),
      :@sprites => { "help" => Sprite.new(false), "help1" => Sprite.new(opts[:guide_owned]) } }
  end

  # The telegraph's scene as it opens (see telegraph_ivars).
  def telegraph(opts = {})
    scene_with(telegraph_ivars(opts))
  end

  # What the telegraph says as a symbol is entered after those already there, with @numero at count.
  def enter_symbol(symbol, count, before = [])
    scene = telegraph(:symbols => before.dup, :count => before.length)
    Ship.morse(scene)
    SpeakCapture.clear
    scene.instance_variable_get(:@secuencia).push(symbol)
    scene.instance_variable_set(:@numero, count)
    Ship.morse(scene)
    SpeakCapture.log.dup
  end

  # The wheel's state as it opens: its compass points (heading south-east by default), an empty log, the answer, and
  # the compass and the chart owned or not.
  def wheel_ivars(opts = {})
    { :@posiciones => opts.fetch(:headings, %w[SE E NE N NO O SO S]), :@combinaciontimon => [],
      :@combinacion => HEADINGS,
      :@sprites => { "extra" => Sprite.new(opts[:compass]), "extra1" => Sprite.new(opts[:chart_owned]),
                     "mapa" => Sprite.new(false) } }
  end

  # The wheel's scene as it opens (see wheel_ivars).
  def wheel(opts = {})
    scene_with(wheel_ivars(opts))
  end

  # A scene holding ivars.
  def scene_with(ivars)
    scene = Object.new
    ivars.each { |k, v| scene.instance_variable_set(k, v) }
    scene
  end

  # The telegraph or the wheel with the frames its loop is to run.
  def loop_of(klass, steps)
    game = klass.new
    game.instance_variable_set(:@steps, steps)
    game
  end

  # Runs the block with the game's items holding the sea chart under id, taken out after.
  def with_sea_chart(id)
    PBItems.const_set(:MAPAMAR, id)
    yield
  ensure
    PBItems.send(:remove_const, :MAPAMAR)
  end

  # Examines item in the bag with the dialogue's half-second guard as a fresh mod has it, so a line said just before is
  # said again; the guard is put back after.
  def examine(item)
    kept = DIALOGUE_GUARD.map { |ivar| PokeAccess.instance_variable_get(ivar) }
    DIALOGUE_GUARD.each { |ivar| PokeAccess.instance_variable_set(ivar, nil) }
    examinarobj(item)
  ensure
    DIALOGUE_GUARD.zip(kept) { |ivar, value| PokeAccess.instance_variable_set(ivar, value) }
  end

  # The puzzle's three fish (the Chinchou, then the two Carvanha) where it starts them on map 278, switch 366 on.
  def fish_board
    fish = [Fish.new(3, 18, 6, "170"), Fish.new(4, 17, 7, "318"), Fish.new(5, 18, 9, "318")]
    $game_map.map_id = 278
    fish.each { |f| $game_map.events[f.id] = f }
    $game_switches[366] = true
    fish
  end

  # Runs n of the puzzle's frames.
  def frames(n)
    n.times { Ship.poll }
  end

  # A fish as said where it stands on the painted grid, or carried there by a current.
  def fish_at(name, row, col, carried = false)
    t(carried ? :rea_fish_drift : :rea_fish_at, :name => name, :row => row, :col => col)
  end

  # The fish said one after another.
  def places(lines)
    lines.join(". ")
  end

  # The three fish where the puzzle starts them.
  def start_places
    [fish_at(CHINCHOU, 1, 6), fish_at(CARVANHA, 2, 5), fish_at(CARVANHA, 4, 6)]
  end

  # The last fish rides a current: onto a tile of the given terrain at (13, 9), then carried down to (13, 11), where
  # it settles.
  def ride_current(fish, current)
    $game_map.set_terrain(13, 9, current)
    frames(1)
    fish[2].x = 13
    frames(1)
    fish[2].y = 11
    frames(7)
  end
end
