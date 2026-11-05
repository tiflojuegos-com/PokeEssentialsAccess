# The verbs a profile declares a puzzle with: several mechanics on a map, names and hidden events, counts, what watched flags
# say, obstacles picked by more than their graphic, why the game moved the player, what using an event or getting to a point of
# its page says, and a grid of events.
class PuzzleVerbsTest < PokeAccessTest
  MAP = 700
  SWITCH = 3100
  VAR = 3100

  test "two parts of a map each speak, and declaring a part again replaces it alone" do
    on_map do
      mechanics.define(:state, MAP, :part => :first) { watch :switch => SWITCH, :label => "A", :on => "on", :off => "off" }
      mechanics.define(:state, MAP, :part => :second) { watch :switch => SWITCH + 1, :label => "B", :on => "on", :off => "off" }
      assert_equal 2, mechanics.instances.length
      frame
      assert_equal(["A: on", "B: on"], frame { $game_switches[SWITCH] = $game_switches[SWITCH + 1] = true })
      mechanics.define(:state, MAP, :part => :second) { watch :switch => SWITCH + 1, :label => "C", :on => "on", :off => "off" }
      assert_equal ["A: on", "C: on"], info_lines_of_parts
    end
  end

  test "a profile declares a part through its own verb" do
    on_map do
      definition = PokeAccess::Game::Definition.allocate
      definition.mechanic(:state, MAP, :part => :first) { watch :switch => SWITCH, :label => "A", :on => "on", :off => "off" }
      definition.mechanic(:state, MAP, :part => :second) { watch :switch => SWITCH + 1, :label => "B", :on => "on", :off => "off" }
      assert_equal 2, mechanics.instances.length
    end
  end

  test "a count takes ids: a pattern has nothing to match while a profile loads" do
    assert_raises(ArgumentError) { mechanics.counter(:selfs => [/torch/, "A"]) }
    assert_raises(ArgumentError) { mechanics.counter(:switches => /torch/) }
    assert_equal [{ :self => [4, "A"] }, { :self => [5, "A"] }], mechanics.counter(:selfs => [4..5, "A"])[:flags]
  end

  test "a name's lambda follows the assist as it is read, with no event changing" do
    on_map do
      silent_event(50, 1, 1)
      mechanics.define(:state, MAP) { name 50, lambda { |ev| PokeAccess::Puzzles.assist? ? "Right #{ev.id}" : "Plain #{ev.id}" } }
      assert_equal ["Plain 50"], PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["Right 50"], PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
    end
  end

  test "a name with :when is listed while its test holds, and keeps its name" do
    on_map do
      silent_event(50, 1, 1)
      mechanics.define(:state, MAP) { name 50, "Torch", :when => lambda { |ev| !$game_switches[SWITCH] && ev.id == 50 } }
      assert_equal ["Torch"], PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
      $game_switches[SWITCH] = true
      assert_equal [], PokeAccess::Puzzles.category_targets
      assert_equal "Torch", PokeAccess::Puzzles.piece_name($game_map.events[50])
    end
  end

  test "an arrival rule with :once is said the first time alone, and stays in the info key" do
    on_map do
      mechanics.define(:state, MAP) do
        watch :switch => SWITCH, :label => "A", :on => "on", :off => "off"
        arrival_hint "The rule", :once => true
      end
      assert_equal ["The rule"], frame
      mechanics.forget
      assert_equal [], frame, "back in the room"
      assert_includes PokeAccess::Puzzles.info_line, "The rule"
    end
  end

  test "a name with :when => false names and lists nothing by itself" do
    on_map do
      silent_event(50, 1, 1)
      mechanics.define(:state, MAP) { name 50, "Sara", :when => false }
      assert_equal [], PokeAccess::Puzzles.category_targets
      assert_equal "Sara", PokeAccess::Puzzles.piece_name($game_map.events[50])
    end
  end

  test "a count reads the self switches of another map when it names one" do
    on_map do
      $game_self_switches[[MAP + 1, 13, "A"]] = true
      mechanics.define(:state, MAP) { count "Ghosts", :selfs => [[13, 14], "A", MAP + 1] }
      assert_equal PokeAccess::I18n.t(:puzzle_progress, :label => "Ghosts", :n => 1, :of => 2), PokeAccess::Puzzles.info_line
    end
  end

  test "a name on an obstacle is said beside it" do
    on_map do
      silent_event(50, 1, 0)
      $game_map.events[50].character_name = "object_wall"
      mechanics.define(:state, MAP) do
        obstacle(/object_wall/, :label => "Wall")
        name 50, "Gate"
      end
      said = frame { $game_player.x = 1; $game_player.y = 1 }
      assert_equal 1, said.select { |l| l.include?("Gate") }.length, said.inspect
    end
  end

  test "an arrival rule is not said once the puzzle is solved" do
    on_map do
      $game_switches[SWITCH] = true
      mechanics.define(:state, MAP) do
        arrival_hint "The rule"
        solved(nil) { $game_switches[SWITCH] }
      end
      assert_equal [], frame
    end
  end

  test "a line of on_use is read as the event is used, and an empty one says nothing" do
    on_map do
      silent_event(50, 1, 1)
      mechanics.define(:state, MAP) { on_use 50, lambda { $game_switches[SWITCH] ? "Held" : "" } }
      frame
      assert_equal [], frame { mechanics.used($game_map.events[50]) }, "nothing to say"
      $game_switches[SWITCH] = true
      said = frame do
        mechanics.used($game_map.events[50])
        $game_switches[SWITCH] = false
      end
      assert_equal ["Held"], said, "what it read before the page changed it"
    end
  end

  test "a count can read what a lambda says" do
    on_map do
      n = 1
      mechanics.define(:state, MAP) { count "Boxes", :of => 3, :value => lambda { n } }
      frame
      n = 2
      assert_equal [PokeAccess::I18n.t(:puzzle_progress, :label => "Boxes", :n => 2, :of => 3)], frame
    end
  end

  test "a quiet watch says nothing and stays out of the info key" do
    on_map do
      mechanics.define(:state, MAP) { watch :switch => SWITCH, :label => "A", :on => "on", :off => "off", :quiet => true }
      frame
      assert_equal [], frame { $game_switches[SWITCH] = true }
      assert_equal false, PokeAccess::Puzzles.active?
    end
  end

  test "the info key joins the line of every part that answers it" do
    on_map do
      mechanics.define(:state, MAP, :part => :first) { watch :switch => SWITCH, :label => "A", :on => "on", :off => "off" }
      mechanics.define(:state, MAP, :part => :second) { watch :switch => SWITCH + 1, :label => "B", :on => "on", :off => "off" }
      $game_switches[SWITCH] = true
      assert_equal "A: on. B: off", PokeAccess::Puzzles.info_line
    end
  end

  test "a name lists an invisible event and names it everywhere; with the assist alone when it asks" do
    on_map do
      plaque = silent_event(21, 4, 4)
      secret = silent_event(22, 6, 4)
      mechanics.define(:state, MAP) do
        name 21, "Plaque"
        name 22, "Secret", :assist => true
      end
      assert_equal [[4, 4, "Plaque"]], listed
      assert_equal "Plaque", PokeAccess::Puzzles.piece_name(plaque)
      assert_nil PokeAccess::Puzzles.piece_name(secret)
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[4, 4, "Plaque"], [6, 4, "Secret"]], listed
      assert_equal "Secret", PokeAccess::Puzzles.piece_name(secret)
    end
  end

  test "a name takes a range, a list or a pattern, numbers in reading order and asks a lambda for each" do
    on_map do
      silent_event(31, 9, 2)
      silent_event(32, 3, 2)
      silent_event(33, 3, 1)
      silent_event(40, 7, 7, :name => "Bin")
      silent_event(41, 8, 7)
      mechanics.define(:state, MAP) do
        name 31..33, [:puzzle_progress, { :label => "S", :of => 3 }], :numbered => true
        name(/\ABin\z/, "A bin")
        name [41], lambda { |ev| "Tile #{ev.x}" }
      end
      expected = [[3, 1, "S: 1 de 3"], [3, 2, "S: 2 de 3"], [7, 7, "A bin"], [8, 7, "Tile 8"], [9, 2, "S: 3 de 3"]]
      assert_equal expected.map { |x, y, _n| [x, y] }, listed.map { |x, y, _n| [x, y] }
      assert_equal "A bin", listed.assoc(7)[2]
      assert_equal "Tile 8", listed.assoc(8)[2]
      assert_equal t(:puzzle_progress, :label => "S", :n => 1, :of => 3), listed.find { |r| r[1] == 1 }[2]
      assert_equal t(:puzzle_progress, :label => "S", :n => 3, :of => 3), listed.assoc(9)[2]
    end
  end

  test "an event whose page has run out and is not drawn leaves the list" do
    on_map do
      spent = TestGameEvent.new(:id => 25, :x => 2, :y => 2, :pages => [TestPage.new(:list => [TestCmd.new(0, [])])])
      $game_map.events[25] = spent
      mechanics.define(:state, MAP) { name 25, "Gone" }
      assert_equal [], mechanics.pieces(:named)
    end
  end

  test "hide leaves events out of the lists, with the assist alone when it asks" do
    on_map do
      always = silent_event(26, 2, 2)
      false_exit = silent_event(27, 3, 3)
      mechanics.define(:state, MAP) do
        hide 26
        hide 27, :assist => true
      end
      assert_equal [true, false], [PokeAccess::Locator.hidden?(always), PokeAccess::Locator.hidden?(false_exit)]
      PokeAccess::Config.puzzle_assist = true
      assert_equal true, PokeAccess::Locator.hidden?(false_exit)
    end
  end

  test "a count of a variable less its start says each step, and the info key reads it" do
    on_map do
      $game_variables[VAR] = 1
      mechanics.define(:state, MAP) { count "Books", :var => VAR, :from => 1, :of => 9 }
      frame
      assert_equal [t(:puzzle_progress, :label => "Books", :n => 2, :of => 9)], frame { $game_variables[VAR] = 3 }
      assert_equal t(:puzzle_progress, :label => "Books", :n => 2, :of => 9), PokeAccess::Puzzles.info_line
    end
  end

  test "a count of switches and of self switches counts those on, out of how many there are" do
    on_map do
      silent_event(50, 1, 1)
      silent_event(51, 2, 1)
      mechanics.define(:state, MAP) do
        count "Levers", :switches => SWITCH..(SWITCH + 2)
        count "Tiles", :selfs => [50..51, "A"], :announce => false
      end
      frame
      assert_equal [t(:puzzle_progress, :label => "Levers", :n => 1, :of => 3)], frame { $game_switches[SWITCH + 1] = true }
      assert_equal [], frame { $game_self_switches[[MAP, 50, "A"]] = true }, "one that does not announce"
      assert_equal PokeAccess.sentences([t(:puzzle_progress, :label => "Levers", :n => 1, :of => 3),
                                         t(:puzzle_progress, :label => "Tiles", :n => 1, :of => 2)]),
                   PokeAccess::Puzzles.info_line
    end
  end

  test "a count that falls says it starts over, its own line, or nothing with reset false" do
    on_map do
      $game_variables[VAR] = 2
      $game_variables[VAR + 1] = 2
      $game_variables[VAR + 2] = 2
      mechanics.define(:state, MAP) do
        count "A", :var => VAR, :of => 4
        count "B", :var => VAR + 1, :of => 4, :reset => "Wrong order"
        count "C", :var => VAR + 2, :of => 4, :reset => false
      end
      frame
      assert_equal [PokeAccess.sentences([t(:puzzle_reset), t(:puzzle_progress, :label => "A", :n => 0, :of => 4)])],
                   frame { $game_variables[VAR] = 0 }
      assert_equal [PokeAccess.sentences(["Wrong order", t(:puzzle_progress, :label => "B", :n => 0, :of => 4)])],
                   frame { $game_variables[VAR + 1] = 0 }
      assert_equal [], frame { $game_variables[VAR + 2] = 0 }
    end
  end

  test "a phase's counter keeps quiet as it falls, unless it asks to say so" do
    on_map do
      $game_variables[VAR] = 2
      mechanics.define(:state, MAP) do
        phase lambda { true }, :title => "T", :quiet => true, :progress => { :var => VAR, :of => 4, :label => "P" }
      end
      frame
      assert_equal [], frame { $game_variables[VAR] = 1 }
    end
  end

  test "a watched variable says its word, its number or a line of its own" do
    on_map do
      mechanics.define(:state, MAP) do
        watch :var => VAR, :label => "Shelf", :words => { 1 => "up", 2 => "down" }
        watch :var => VAR + 1, :label => "Temperature", :number => true
        watch :var => VAR + 2, :say => "The forest changed"
        watch :switch => SWITCH, :say => "A crash far away"
      end
      frame
      assert_equal ["Shelf: up"], frame { $game_variables[VAR] = 1 }
      assert_equal ["Shelf: down"], frame { $game_variables[VAR] = 2 }
      assert_equal ["Temperature: 30"], frame { $game_variables[VAR + 1] = 30 }
      assert_equal ["The forest changed"], frame { $game_variables[VAR + 2] = 1 }
      assert_equal ["The forest changed"], frame { $game_variables[VAR + 2] = 2 }
      assert_equal [], frame { $game_variables[VAR + 2] = 0 }, "back to 0"
      assert_equal ["A crash far away"], frame { $game_switches[SWITCH] = true }
      assert_equal [], frame { $game_switches[SWITCH] = false }, "turned off"
      assert_equal "Shelf: down. Temperature: 30", PokeAccess::Puzzles.info_line, "what only says a line is no readout"
    end
  end

  test "a watched event says as it comes to be drawn or stops" do
    on_map do
      candle = silent_event(60, 1, 1, :sprite => "")
      mechanics.define(:state, MAP) { watch :event => 60, :label => "Candle", :on => "lit", :off => "out" }
      frame
      assert_equal ["Candle: lit"], frame { candle.character_name = "vela" }
      assert_equal ["Candle: out"], frame { candle.character_name = "" }
    end
  end

  test "an obstacle may be picked by its tile, its id or its own name, and names the walls it takes" do
    on_map do
      by_tile = drawn_event(70, 2, 2, :tile_id => 462)
      by_id = drawn_event(71, 3, 2, :sprite => "whatever")
      by_name = drawn_event(72, 4, 2, :sprite => "other", :name => "Lazer")
      plain = drawn_event(73, 5, 2, :sprite => "other", :name => "Rock")
      mechanics.define(:state, MAP) do
        obstacle({ :tile => 462 }, :label => "Statue")
        obstacle :events => 71, :label => "Gate"
        obstacle :named => /Lazer/, :label => "Ray"
      end
      assert_equal "Statue", PokeAccess::Puzzles.piece_name(by_tile)
      assert_equal "Gate", PokeAccess::Puzzles.piece_name(by_id)
      assert_equal "Ray", PokeAccess::Puzzles.piece_name(by_name)
      assert_nil PokeAccess::Puzzles.piece_name(plain)
    end
  end

  test "a name goes before an obstacle's label on the wall it picks" do
    on_map do
      wall = drawn_event(74, 2, 2, :sprite => "barrera")
      mechanics.define(:state, MAP) do
        obstacle(/barrera/, :label => "Barrier")
        name 74, "North gate"
      end
      assert_equal "North gate", PokeAccess::Puzzles.piece_name(wall)
    end
  end

  test "sent_back says why by where the teleport lands and leaves from, and by the event last used" do
    on_map do
      trap = silent_event(80, 5, 5)
      mechanics.define(:state, MAP) do
        sent_back "The guard caught you", :to => [1, 1], :events => 80
        sent_back "You fell", :to => [2, 2], :from => [4, 8, 4, 8]
      end
      assert_nil PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [1, 1, MAP]), "before the event is used"
      fire(trap)
      assert_equal "The guard caught you", PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [1, 1, MAP])
      assert_equal "You fell", PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [2, 2, MAP])
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, MAP], [2, 2, MAP]), "from elsewhere"
    end
  end

  test "sent_back with :maps speaks of a transfer from those maps alone, and without it of none" do
    on_map do
      mechanics.define(:state, MAP) do
        sent_back "Wrong way", :to => [1, 1], :maps => 130..132
        sent_back "Inside", :to => [2, 2]
      end
      assert_equal "Wrong way", PokeAccess::Puzzles.sent_back_line([9, 9, 131], [1, 1, MAP], :map)
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, 140], [1, 1, MAP], :map), "from another map"
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, 131], [3, 3, MAP], :map), "landing elsewhere"
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, 131], [2, 2, MAP], :map), "one with no :maps is not of a transfer"
      assert_nil PokeAccess::Puzzles.sent_back_line([9, 9, MAP], [1, 1, MAP]), "one with :maps is not of a teleport"
      assert_equal "Inside", PokeAccess::Puzzles.sent_back_line([9, 9, MAP], [2, 2, MAP])
    end
  end

  test "sent_back with :forced speaks of the end of a move route alone, and a lambda can name where it left the player" do
    on_map do
      web = silent_event(80, 5, 5)
      mechanics.define(:state, MAP) do
        sent_back lambda { "Landed #{$game_player.x}" }, :events => 80, :forced => true
        sent_back "Teleported", :to => [7, 7]
      end
      frame
      fire(web)
      step(9, 9)
      assert_equal "Landed 9", PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [9, 9, MAP], :forced)
      assert_nil PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [9, 9, MAP]), "not of a teleport"
      assert_equal "Teleported", PokeAccess::Puzzles.sent_back_line([5, 5, MAP], [7, 7, MAP])
    end
  end

  test "on_use says a line as the event is used, and answer says it with the assist alone" do
    on_map do
      sign = silent_event(90, 2, 2)
      door = silent_event(91, 3, 2)
      mechanics.define(:state, MAP) do
        on_use 90, "The plate reads ABCD"
        answer 91, "1234"
      end
      frame
      assert_equal ["The plate reads ABCD"], frame { fire(sign) }
      assert_equal [], frame { fire(door) }, "the answer without the assist"
      PokeAccess::Config.puzzle_assist = true
      assert_equal [t(:puzzle_answer, :a => "1234")], frame { fire(door) }
    end
  end

  test "on_use's lambda with one parameter gets the event used, and one with none nothing" do
    on_map do
      first = silent_event(90, 2, 2)
      second = silent_event(91, 3, 2)
      mechanics.define(:state, MAP) do
        on_use 90..91, lambda { |ev| "Event #{ev.id}" }
        on_use 91, lambda { "Plain" }
      end
      frame
      assert_equal ["Event 90"], frame { fire(first) }
      assert_equal ["Event 91", "Plain"], frame { fire(second) }
    end
  end

  test "on_reach says a line as the branch a menu took starts, by its place or its words, and not on another's" do
    on_map do
      silent_event(90, 2, 2)
      list = [TestCmd.new(102, [%w[Yes No], 2]), TestCmd.new(402, [0, "Yes"]), TestCmd.new(0, [], 1),
              TestCmd.new(402, [1, "No"]), TestCmd.new(0, [], 1), TestCmd.new(404, []), TestCmd.new(0, [])]
      mechanics.define(:state, MAP) do
        on_reach 90, { :choice => 0 }, "They sing"
        on_reach 90, { :choice => /\ANo/ }, lambda { |ev| "Refused #{ev.id}" }
        on_reach 90, { :choice => 1 }, "Hint", :assist => true
      end
      assert_equal ["They sing"], reached(list, 1, 0)
      assert_equal [], reached(list, 3, 0), "the When of an option not taken"
      assert_equal ["Refused 90"], reached(list, 3, 1)
      PokeAccess::Config.puzzle_assist = true
      assert_equal ["Refused 90", "Hint"], reached(list, 3, 1)
    end
  end

  test "on_reach says a line right after a Show Text, by its place among the page's or its words, and the core's line goes on" do
    on_map do
      silent_event(90, 2, 2)
      list = [TestCmd.new(101, ["First"]), TestCmd.new(401, ["line"]), TestCmd.new(101, ["Second"]), TestCmd.new(0, [])]
      mechanics.define(:state, MAP) do
        on_reach 90, { :text => 1 }, "After second"
        on_reach 90, { :text => /First line/ }, "After first"
      end
      assert_equal "After first", read_text(list, 0)
      assert_equal "After second", read_text(list, 2)
      assert_nil read_text(list, 2), "the engine trying the same text again"
      PokeAccess::Puzzles::Reach.forget
      PokeAccess.after_next_line("Earlier")
      assert_equal "Earlier. After second", read_text(list, 2)
    end
  end

  test "a page of another event says nothing of on_reach, nor a map with no declaration" do
    on_map do
      silent_event(90, 2, 2)
      silent_event(91, 3, 2)
      list = [TestCmd.new(101, ["First"]), TestCmd.new(0, [])]
      assert_nil read_text(list, 0, 90), "nothing declared"
      mechanics.define(:state, MAP) { on_reach 90, { :text => 0 }, "Here" }
      PokeAccess::Puzzles::Reach.forget
      assert_nil read_text(list, 0, 91)
    end
  end

  test "a watched variable with :from reads on from it, and what it opens is told by that threshold" do
    on_map do
      mechanics.define(:state, MAP) { watch :var => VAR, :from => 3, :label => "A", :on => "on", :off => "off" }
      frame
      assert_equal [], frame { $game_variables[VAR] = 2 }
      assert_equal ["A: on"], frame { $game_variables[VAR] = 3 }
      assert_equal [], frame { $game_variables[VAR] = 5 }
      assert_equal ["A: off"], frame { $game_variables[VAR] = 1 }
    end
  end

  test "a spot may ask for the assist, a test, or to be stood on" do
    on_map do
      open = false
      mechanics.define(:state, MAP) do
        spot :at => [1, 1], :label => "Hole", :assist => true
        spot :at => [2, 1], :label => "Door", :when => lambda { open }
        spot :at => [3, 1], :label => "Plate", :onto => true
      end
      assert_equal [[3, 1, "Plate"]], listed
      assert_equal true, PokeAccess::Puzzles.onto?(PokeAccess::Puzzles.category_targets[0])
      open = true
      PokeAccess::Config.puzzle_assist = true
      assert_equal [[1, 1, "Hole"], [2, 1, "Door"], [3, 1, "Plate"]], listed
    end
  end

  test "a grid of events says row, column and state underfoot, lists what is left and counts it" do
    on_map do
      $game_player.x = 0
      $game_player.y = 0
      (0...4).each { |i| touch_event(100 + i, 10 + i % 2, 20 + i / 2) }
      mechanics.define(:grid, MAP) do
        tiles 100..103, :self => "A", :label => "Tile", :count => "Stepped", :words => { true => "stepped", false => "free" }
      end
      frame
      assert_equal 4, listed.length
      frame { step(11, 20) }
      frame
      assert_equal ["#{t(:puzzle_tile_at, :r => 1, :c => 2)}: free"], frame
      assert_equal ["#{t(:puzzle_tile_at, :r => 1, :c => 2)}: stepped"], frame { $game_self_switches[[MAP, 101, "A"]] = true }
      assert_equal 3, listed.length, "what is done leaves the list"
      assert_equal PokeAccess.sentences([t(:puzzle_progress, :label => "Stepped", :n => 1, :of => 4),
                                         "#{t(:side_left)}: free", "#{t(:side_down)}: free"]),
                   PokeAccess::Puzzles.info_line
    end
  end

  test "a grid of events takes its state from a block, and stops once solved" do
    on_map do
      (0...2).each { |i| touch_event(110 + i, 10 + i, 20, :sprite => "white") }
      solved = false
      mechanics.define(:grid, MAP) do
        tiles(110..111, :words => { :white => "white", :black => "black" }, :done => :black, :count => "Black") do |ev|
          ev.character_name == "white" ? :white : :black
        end
        solved("All black") { solved }
      end
      frame
      assert_equal true, PokeAccess::Puzzles.active?
      solved = true
      assert_equal ["All black"], frame
      assert_equal false, PokeAccess::Puzzles.active?
    end
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  def mechanics; PokeAccess::World::Mechanics; end

  # Runs the block on a map of its own, with nothing declared and everything put back after.
  def on_map
    was_map = $game_map.map_id
    was_selfs = $game_self_switches
    defs = mechanics.instance_variable_get(:@defs).dup
    x = $game_player.x
    y = $game_player.y
    $game_self_switches = {}
    $game_map.map_id = MAP
    PokeAccess::Caches.reset_all
    mechanics.forget
    yield
  ensure
    World.clear_events
    (SWITCH..(SWITCH + 3)).each { |i| $game_switches[i] = false }
    (VAR..(VAR + 3)).each { |i| $game_variables[i] = 0 }
    $game_self_switches = was_selfs
    mechanics.instance_variable_set(:@defs, defs)
    $game_map.map_id = was_map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
  end

  # An action-button event with no graphic whose page does something, on (x, y).
  def silent_event(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(121, [5, 5, 0]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => [page])
  end

  # An event drawn with a sheet or a tile, on (x, y).
  def drawn_event(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :tile_id => opts.fetch(:tile_id, 0),
                           :pages => [page])
    $game_map.events[id] = ev
  end

  # A touch event on (x, y).
  def touch_event(id, x, y, opts = {})
    page = TestPage.new(:trigger => 1, :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
  end

  def step(x, y)
    $game_player.x = x
    $game_player.y = y
  end

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

  # What each mechanic of the map says to the info key.
  def info_lines_of_parts
    mechanics.instances.map { |inst| PokeAccess::Puzzles.line_of(inst) }
  end

  # What is said as an interpreter of event id, its branch at indent 0 the one given, gets to the command at list[i].
  def reached(list, i, taken, id = 90)
    SpeakCapture.clear
    PokeAccess::Puzzles::Reach.before_when(page_at(list, i, id, taken))
    SpeakCapture.lines
  end

  # What is promised for after the Show Text at list[i] of a page of event id.
  def read_text(list, i, id = 90)
    PokeAccess::Puzzles::Reach.before_text(page_at(list, i, id, nil))
    PokeAccess.take_tail
  end

  # An interpreter of event id at list[i], with the option taken at indent 0.
  def page_at(list, i, id, taken)
    int = Object.new
    { :@list => list, :@index => i, :@event_id => id, :@branch => { 0 => taken } }.each { |k, v| int.instance_variable_set(k, v) }
    int
  end

  # The puzzles category as [x, y, name], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
