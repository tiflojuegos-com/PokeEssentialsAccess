# What a map with no puzzle declared tells by itself (Puzzles::Auto): what a control the player uses opens or closes, at the
# :map_changes reading's level; its silent controls, in the puzzles category; and with the assist, the answer an entry compares.
class PuzzleAutoTest < PokeAccessTest
  MAP = 701
  SWITCH = 3200

  test "a lever that takes a rock away says a way has opened and where" do
    on_map(:full) do
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      step(5, 6)
      assert_equal ["#{t(:chg_where, :what => t(:chg_open_one), :dist => dist(4, -3))}"], used(lever) { gone(rock) }
    end
  end

  test "at medium it says what happened and not where; at brief, nothing" do
    on_map(:medium) do
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      assert_equal [t(:chg_open_one)], used(lever) { gone(rock) }
    end
    on_map(:brief) do
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      assert_equal [], used(lever) { gone(rock) }
    end
  end

  test "a row of rocks is one way, and rocks apart are several, by the nearest" do
    on_map(:full) do
      lever = lever_at(5, 5)
      row = [rock_at(9, 3, 10), rock_at(10, 3, 11), rock_at(11, 3, 12)]
      step(5, 6)
      assert_equal [t(:chg_where, :what => t(:chg_open_one), :dist => dist(4, -3))], used(lever) { row.each { |r| gone(r) } }
    end
    on_map(:full) do
      lever = lever_at(5, 5)
      far = rock_at(20, 20, 10)
      near = rock_at(6, 9, 11)
      step(5, 6)
      assert_equal [t(:chg_nearest, :what => t(:chg_open_many, :n => 2), :dist => dist(1, 3))],
                   used(lever) { gone(far); gone(near) }
    end
  end

  test "what closes is said after what opens" do
    on_map(:medium) do
      lever = lever_at(5, 5)
      down = rock_at(9, 3, 10)
      up = rock_at(2, 3, 11)
      gone(up)
      settle_events
      assert_equal [PokeAccess.sentences([t(:chg_open_one), t(:chg_shut_one)])],
                   used(lever) { gone(down); drawn(up, "Object rock") }
    end
  end

  test "a grouped name of levers on an auto map is one target, with none of its levers listed again on its own" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever_at(5, 5, 20)
      lever_at(6, 5, 21)
      lever_at(7, 5, 22)
      PokeAccess::World::Mechanics.define(:state, MAP) do
        auto
        name 20..22, "Panel", :grouped => true
      end
      PokeAccess::World::Events.sync(true)
      assert_equal [["Panel", 6]], PokeAccess::Puzzles.category_targets.map { |tg| [tg.name, tg.x] }
    end
  end

  test "something that flickers and ends as it was is no change" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      seen = used(lever) do
        gone(rock)
        PokeAccess::World::Events.sync(true)
        drawn(rock, "Object rock")
      end
      assert_equal [t(:chg_used)], seen
    end
  end

  test "a silent control that changes no wall says it worked; a touch does not, nor one that writes nothing" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever = lever_at(5, 5)
      assert_equal [t(:chg_used)], used(lever)
      plate = lever_at(6, 5, 21, :trigger => 1)
      assert_equal [], used(plate), "a floor sensor stepped on"
      blank = event_at(7, 5, 22, :list => [TestCmd.new(250, ["bump"]), TestCmd.new(0, [])])
      assert_equal [], used(blank), "nothing written"
    end
  end

  test "an event a declaration says is no control is neither listed nor said to have worked, and the rest of the map stays" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      trigger = lever_at(5, 5)
      other = lever_at(6, 5, 21)
      settle_events
      PokeAccess::World::Mechanics.define(:state, MAP) do
        auto
        not_control 20
      end
      PokeAccess::World::Events.sync(true)
      assert_equal [6], PokeAccess::Puzzles::Auto.targets.map { |tg| tg.x }
      assert_equal [], used(trigger)
      assert_equal [t(:chg_used)], used(other)
    end
  end

  test "what the lists would not call a control does not say it worked" do
    on_map(:medium) do
      assert_equal [], used(lever_at(5, 5)), "a write nobody reads"
      reader_of(SWITCH, 30)
      write = TestCmd.new(121, [SWITCH, SWITCH, 0])
      smash = event_at(6, 5, 21, :sprite => "object_rock", :name => "Rock", :list => [TestCmd.new(355, ["pbRockSmash"]), write, TestCmd.new(0, [])])
      assert_equal [], used(smash), "a field obstacle"
      own = event_at(7, 5, 22, :sprite => "object_box", :list => [TestCmd.new(123, ["A", 0]), TestCmd.new(0, [])])
      assert_equal [], used(own), "its own self switch"
    end
  end

  test "what talks through a common event it calls is no silent control" do
    on_map(:medium) do
      was = $data_common_events
      table = Struct.new(:list)
      $data_common_events = { 5 => table.new([TestCmd.new(101, ["Hello"]), TestCmd.new(0, [])]), 6 => table.new([TestCmd.new(250, ["bump"]), TestCmd.new(0, [])]) }
      begin
        reader_of(SWITCH, 30)
        write = TestCmd.new(121, [SWITCH, SWITCH, 0])
        talks = event_at(5, 5, 20, :sprite => "object_box", :list => [write, TestCmd.new(117, [5]), TestCmd.new(0, [])])
        quiet = event_at(6, 5, 21, :sprite => "object_box", :list => [write, TestCmd.new(117, [6]), TestCmd.new(0, [])])
        PokeAccess::World::Events.sync(true)
        assert_equal [6], PokeAccess::Puzzles::Auto.targets.map { |tg| tg.x }
        assert_equal [], used(talks)
        assert_equal [t(:chg_used)], used(quiet)
      ensure
        $data_common_events = was
      end
    end
  end

  test "leaving the map while a control settles says nothing and breaks nothing" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      fire(lever_at(5, 5))
      (PokeAccess::Puzzles::Auto::SETTLE - 1).times { PokeAccess::Puzzles::Auto.tick }
      SpeakCapture.clear
      events = PokeAccess::World::Events
      sync = events.method(:sync)
      begin
        events.define_singleton_method(:sync) { |*_a| PokeAccess::Puzzles::Auto.forget }
        PokeAccess::Puzzles::Auto.tick
      ensure
        events.define_singleton_method(:sync, sync)
      end
      assert_equal [], SpeakCapture.lines
    end
  end

  test "its own change is its own, and what talks with a person is a scene" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever = lever_at(5, 5)
      assert_equal [t(:chg_used)], used(lever) { gone(lever) }, "the lever's own graphic"
      guard = event_at(7, 5, 23, :sprite => "NPC 03", :list => [TestCmd.new(101, ["Go ahead."]), TestCmd.new(0, [])])
      rock = rock_at(9, 3)
      assert_equal [], used(guard) { gone(rock) }, "a person who talks"
    end
  end

  test "a lever that talks still tells what it opened, and a long scene does not" do
    on_map(:medium) do
      lever = event_at(5, 5, 20, :sprite => "object_lever", :list => [TestCmd.new(101, ["Pull it?"]), TestCmd.new(121, [SWITCH, SWITCH, 0]), TestCmd.new(0, [])])
      rock = rock_at(9, 3)
      assert_equal [t(:chg_open_one)], used(lever) { gone(rock) }
      long = event_at(7, 5, 24, :list => [TestCmd.new(101, ["1"]), TestCmd.new(101, ["2"]), TestCmd.new(101, ["3"]), TestCmd.new(101, ["4"]), TestCmd.new(0, [])])
      other = rock_at(9, 7, 25)
      assert_equal [], used(long) { gone(other) }
    end
  end

  test "nothing is said while the event runs, and it waits a moment after" do
    on_map(:medium) do
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      running(true) do
        fire(lever)
        gone(rock)
        assert_equal [], frames(10)
      end
      assert_equal [], frames(PokeAccess::Puzzles::Auto::SETTLE - 1), "just after it ends"
      assert_equal [t(:chg_open_one)], frames(1)
    end
  end

  test "a map that declares a mechanic speaks for itself" do
    on_map(:medium) do
      lever = lever_at(5, 5)
      rock = rock_at(9, 3)
      PokeAccess::World::Mechanics.define(:state, MAP) { watch :switch => SWITCH, :label => "L", :on => "on", :off => "off" }
      assert_equal [], used(lever) { gone(rock) }
      assert_equal [], PokeAccess::Puzzles::Auto.targets
    end
  end

  test "a mechanic that asks for it keeps all this, its names going before what would be listed by itself" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever = lever_at(5, 5, 20, :switch => SWITCH)
      lever_at(6, 5, 21, :switch => SWITCH)
      rock = rock_at(9, 3)
      PokeAccess::World::Mechanics.define(:state, MAP) do
        auto
        name 20, "Red lever"
      end
      PokeAccess::World::Events.sync(true)
      listed = PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.name] }.sort
      assert_equal "Red lever", listed.assoc(5)[1]
      assert_equal 2, listed.length, "the named one only once, and the other by itself"
      assert_equal [t(:chg_open_one)], used(lever) { gone(rock) }
    end
  end

  test "a second mechanic that does not ask for it turns it off" do
    on_map(:medium) do
      PokeAccess::World::Mechanics.define(:state, MAP, :part => :a) { auto }
      assert_equal true, PokeAccess::Puzzles::Auto.on_here?
      PokeAccess::World::Mechanics.define(:state, MAP, :part => :b) { hint "x" }
      assert_equal false, PokeAccess::Puzzles::Auto.on_here?
    end
  end

  test "lists a silent control drawn in the scenery, and one on open floor with the assist alone" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever_at(5, 5, 20, :sprite => "")
      lever_at(6, 5, 21, :sprite => "", :switch => SWITCH)
      lever_at(7, 5, 22, :sprite => "", :switch => SWITCH)
      $game_map.set_tile_blocked(7, 5) if $game_map.respond_to?(:set_tile_blocked)
      PokeAccess::World::Events.sync(true)
      names = PokeAccess::Puzzles::Auto.targets.map { |tg| [tg.x, tg.name] }
      assert_equal false, names.assoc(5) ? true : false, "whose flag nobody reads"
      PokeAccess::Config.puzzle_assist = true
      PokeAccess::World::Events.sync(true)
      names = PokeAccess::Puzzles::Auto.targets.map { |tg| [tg.x, tg.name] }
      assert_equal t(:puzzle_mechanism), names.assoc(6)[1]
    end
  end

  test "lists a drawn plate, by its own name when it has one; not a person, nor a sensor with no graphic" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      lever_at(5, 5, 20, :trigger => 1, :sprite => "object_plate", :switch => SWITCH, :name => "Red plate")
      lever_at(6, 5, 21, :trigger => 1, :sprite => "", :switch => SWITCH)
      lever_at(7, 5, 22, :trigger => 0, :sprite => "NPC 03", :switch => SWITCH)
      PokeAccess::World::Events.sync(true)
      assert_equal [[5, "Red plate"]], PokeAccess::Puzzles::Auto.targets.map { |tg| [tg.x, tg.name] }
    end
  end

  test "lists no field obstacle, no exit, nor what gives an item through a branch on a script" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      write = TestCmd.new(121, [SWITCH, SWITCH, 0])
      event_at(5, 5, 20, :sprite => "object_rock", :name => "Rock", :list => [TestCmd.new(355, ["pbRockSmash"]), write, TestCmd.new(0, [])])
      event_at(6, 5, 21, :list => [write, TestCmd.new(201, [0, 2, 1, 1, 2, 0]), TestCmd.new(0, [])])
      event_at(7, 5, 22, :list => [TestCmd.new(111, [12, "pbReceiveItem(:POTION)"]), write, TestCmd.new(412, []), TestCmd.new(0, [])])
      PokeAccess::World::Events.sync(true)
      assert_equal [], PokeAccess::Puzzles::Auto.targets
    end
  end

  test "floor tiles by the dozen are no controls, and neither is what an event touches" do
    on_map(:medium) do
      reader_of(SWITCH, 30)
      9.times { |i| lever_at(5 + i, 5, 40 + i, :trigger => 1, :sprite => "object_tile", :switch => SWITCH, :name => "Tile") }
      lever_at(5, 8, 60, :trigger => 2, :sprite => "object_tile", :switch => SWITCH)
      PokeAccess::World::Events.sync(true)
      assert_equal [], PokeAccess::Puzzles::Auto.targets
      World.clear_events
      reader_of(SWITCH, 30)
      8.times { |i| lever_at(5 + i, 5, 40 + i, :trigger => 1, :sprite => "object_tile", :switch => SWITCH, :name => "Tile") }
      PokeAccess::World::Events.sync(true)
      assert_equal 8, PokeAccess::Puzzles::Auto.targets.length, "as many as a room of plates may hold"
      World.clear_events
      reader_of(SWITCH, 30)
      9.times { |i| lever_at(5 + i, 5, 40 + i, :trigger => 1, :sprite => "object_tile", :switch => SWITCH) }
      PokeAccess::World::Events.sync(true)
      assert_equal [], PokeAccess::Puzzles::Auto.targets, "the editor's default names say nothing of them"
    end
  end

  test "a variable that notes where someone stands or how many of an item there are is no state of the map" do
    on_map(:medium) do
      page = TestPage.new(:trigger => 0, :sprite => "Object rock", :condition => { :variable_valid => true, :variable_id => 31 }, :list => [TestCmd.new(0, [])])
      $game_map.events[30] = TestGameEvent.new(:id => 30, :x => 30, :y => 30, :pages => [page])
      event_at(5, 5, 20, :sprite => "object_box", :list => [TestCmd.new(122, [31, 31, 0, 6, -1, 0]), TestCmd.new(0, [])])
      event_at(6, 5, 21, :sprite => "object_box", :list => [TestCmd.new(122, [31, 31, 0, 3, 7]), TestCmd.new(0, [])])
      event_at(7, 5, 22, :sprite => "object_box", :list => [TestCmd.new(122, [31, 31, 1, 0, 1]), TestCmd.new(0, [])])
      PokeAccess::World::Events.sync(true)
      assert_equal [7], PokeAccess::Puzzles::Auto.targets.map { |tg| tg.x }
    end
  end

  test "the sheets of people go by many names" do
    ["BW (12)", "BW157", "boy_run", "girl 3", "OW_4", "DP_2", "NB 7", "chica1", "leader_brock", "NPC 01", "trchar001", "trainer_X", "pkmn_abra",
     "pokemon_abra", "Character 01", "HGSS_134", "025", "025_1s"].each { |s| assert PokeAccess::Puzzles::Auto.person_sheet?(s), s }
    ["Object rock", "object_lever", "boyard", "owl", "dpad", "asylum3", "Puertas1", "antorcha", "OBJ_Pokeball", "bwlever", ""].each do |s|
      assert !PokeAccess::Puzzles::Auto.person_sheet?(s), s
    end
  end

  test "with the assist, an entry says the number its page compares, and only once" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      running(true, [TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 6489, 0]), TestCmd.new(0, [])]) do
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say
        PokeAccess::Puzzles::Answers.say
        assert_equal [t(:puzzle_answer, :a => 6489)], SpeakCapture.lines
      end
    end
  end

  test "a number entry a text opens says its answer after the text, and only once" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      list = [TestCmd.new(101, ["Code?"]), TestCmd.new(401, ["Four digits."]), TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 5281, 0]), TestCmd.new(0, [])]
      running(true, list) do
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        assert_equal [], SpeakCapture.lines
        assert_equal t(:puzzle_answer, :a => 5281), PokeAccess.take_tail
        assert_nil PokeAccess.take_tail
      end
    end
  end

  test "a text with no entry after it says nothing, and neither does anything without the assist" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      running(true, [TestCmd.new(101, ["Hello"]), TestCmd.new(111, [1, 5, 0, 5281, 0]), TestCmd.new(0, [])]) do
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        assert_nil PokeAccess.take_tail
      end
      PokeAccess::Config.puzzle_assist = false
      PokeAccess::Puzzles::Answers.forget
      running(true, [TestCmd.new(101, ["Code?"]), TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 5281, 0]), TestCmd.new(0, [])]) do
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        assert_nil PokeAccess.take_tail
      end
    end
  end

  test "a script's entry is read from the script running, and answers by the variable it keeps it in" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      answers = PokeAccess::Puzzles::Answers
      before = [TestCmd.new(355, ["$game_variables[5] = pbChooseNumber(nil, params)"]), TestCmd.new(355, ["pbPokemonMart([:POTION])"]),
                TestCmd.new(111, [1, 5, 0, 77, 0]), TestCmd.new(0, [])]
      running(true, before) do
        $game_system.map_interpreter.instance_variable_set(:@index, 1)
        assert_equal false, answers.scripted_entry?($game_system.map_interpreter), "the script before it opened the entry"
      end
      other = [TestCmd.new(355, ["$game_variables[5] = pbEnterText('Code',0,4)"]), TestCmd.new(111, [12, "$game_player.direction == 8"]), TestCmd.new(0, [])]
      running(true, other) { assert_nil answers.expected, "another thing compared" }
      silly = [TestCmd.new(355, ["pbEnterText('Code',0,4)"]), TestCmd.new(111, [1, 77, 0, 1, 0]), TestCmd.new(0, [])]
      running(true, silly) { assert_nil answers.expected, "it does not tell where it keeps it" }
      kept = [TestCmd.new(355, ["pbSet(1,pbEnterText('Code',0,4))"]), TestCmd.new(111, [12, 'pbGet(1)=="31"']), TestCmd.new(0, [])]
      running(true, kept) { assert_equal "31", answers.expected }
      two = [TestCmd.new(355, ["$game_variables[4] = pbGetPokemon(1)"]), TestCmd.new(655, ["$game_variables[5] = pbEnterText('Code',0,4)"]),
             TestCmd.new(111, [12, '$game_variables[5]=="31"']), TestCmd.new(0, [])]
      running(true, two) do
        $game_system.map_interpreter.instance_variable_set(:@index, 1)
        assert_equal "31", answers.expected, "the variable the entry is assigned to, not one the script set before it"
      end
      last = [TestCmd.new(355, ["pbSet(4,0)"]), TestCmd.new(655, ["pbTextEntry('Code',0,4,5); pbSet(9, 2)"]),
              TestCmd.new(111, [12, '$game_variables[5]=="31"']), TestCmd.new(0, [])]
      running(true, last) do
        $game_system.map_interpreter.instance_variable_set(:@index, 1)
        assert_equal "31", answers.expected, "pbTextEntry keeps it in its last argument"
      end
    end
  end

  test "a comment between a text and its entry changes nothing" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      list = [TestCmd.new(101, ["Code?"]), TestCmd.new(108, ["note"]), TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 5281, 0]), TestCmd.new(0, [])]
      running(true, list) do
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        assert_equal t(:puzzle_answer, :a => 5281), PokeAccess.take_tail
      end
    end
  end

  test "someone who talks and leaves in a scene opens no way, whatever is drawn after" do
    on_map(:medium) do
      guard = event_at(7, 5, 23, :sprite => "NPC 03")
      PokeAccess::World::Events.sync(true)
      trigger = event_at(8, 5, 24, :trigger => 1, :list => [TestCmd.new(101, ["Go ahead."]), TestCmd.new(0, [])])
      assert_equal [], used(trigger) { gone(guard) }
    end
  end

  test "an entry's answer is what its own variable is compared with, up to the next entry" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      other = [TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 6, 0, 77, 0]), TestCmd.new(0, [])]
      running(true, other) { assert_nil PokeAccess::Puzzles::Answers.expected, "another variable" }
      chain = [TestCmd.new(103, [5, 2]), TestCmd.new(111, [1, 5, 0, 18, 0]), TestCmd.new(103, [5, 2]), TestCmd.new(111, [1, 5, 0, 2, 0]), TestCmd.new(0, [])]
      running(true, chain) { assert_equal 18, PokeAccess::Puzzles::Answers.expected, "three codes in a row" }
    end
  end

  test "an entry's answer is 0 only when the branch that compares it rewards the player" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      empty = [TestCmd.new(103, [5, 2]), TestCmd.new(111, [1, 5, 0, 0, 0]), TestCmd.new(101, ["Nothing?"], 1), TestCmd.new(0, [], 1),
               TestCmd.new(412, []), TestCmd.new(111, [1, 5, 0, 7, 0]), TestCmd.new(0, [])]
      running(true, empty) { assert_equal 7, PokeAccess::Puzzles::Answers.expected, "a 0 that checks an entry left empty" }
      prized = { "a self switch" => TestCmd.new(123, ["A", 0], 2), "a switch" => TestCmd.new(121, [40, 40, 0], 2),
                 "an item" => TestCmd.new(111, [12, "pbReceiveItem(:PEARL)"], 2) }
      prized.each do |what, cmd|
        list = [TestCmd.new(103, [5, 1]), TestCmd.new(111, [1, 5, 0, 0, 0]), TestCmd.new(101, ["You got it!"], 1),
                TestCmd.new(111, [12, "true"], 1), cmd, TestCmd.new(0, [], 2), TestCmd.new(412, [], 1), TestCmd.new(0, [])]
        running(true, list) { assert_equal 0, PokeAccess::Puzzles::Answers.expected, "a 0 whose branch gives #{what}" }
      end
      off = [TestCmd.new(103, [5, 1]), TestCmd.new(111, [1, 5, 0, 0, 0]), TestCmd.new(123, ["A", 1], 1), TestCmd.new(0, [])]
      running(true, off) { assert_nil PokeAccess::Puzzles::Answers.expected, "a 0 whose branch turns a self switch off" }
      both = [TestCmd.new(103, [5, 1]), TestCmd.new(111, [1, 5, 0, 0, 0]), TestCmd.new(121, [40, 40, 0], 1), TestCmd.new(0, [], 1),
              TestCmd.new(412, []), TestCmd.new(111, [1, 5, 0, 3, 0]), TestCmd.new(0, [])]
      running(true, both) { assert_equal 3, PokeAccess::Puzzles::Answers.expected, "a rewarded 0 beside another number" }
    end
  end

  test "right_choice says the option whose branch avoids a flag, in the game's words, after the text that opens the menu" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      riddle = event_at(5, 5, 20)
      PokeAccess::World::Mechanics.define(:state, MAP) { right_choice 20, :avoids => { :var => 62 } }
      running(true, [TestCmd.new(101, ["Which one?"])] + menu(["Arcanine", "Magmar"], [[wrong(62)], [TestCmd.new(250, ["ok"], 1)]])) do
        $game_system.map_interpreter.instance_variable_set(:@event_id, riddle.id)
        PokeAccess::Puzzles::Answers.before_text($game_system.map_interpreter)
        assert_equal t(:puzzle_answer, :a => "Magmar"), PokeAccess.take_tail
      end
    end
  end

  test "right_choice goes by what a branch does, and says nothing unless just one is left" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      transfer = TestCmd.new(201, [0, 2, 1, 1, 2, 0], 1)
      fight = TestCmd.new(301, [1, false, false], 1)
      own = TestCmd.new(123, ["A", 0], 1)
      running(true, menu(%w[One Two], [[wrong(62)], []])) do
        $game_system.map_interpreter.instance_variable_set(:@event_id, 20)
        assert_nil PokeAccess::Puzzles::Answers.right_option($game_system.map_interpreter, $game_system.map_interpreter.instance_variable_get(:@list), 0), "no rule"
      end
      right = lambda { |rule, branches| option_for(rule, menu(%w[One Two], branches)) }
      assert_equal "Two", right.call({ :takes => { :switch => 80 } }, [[wrong(90)], [TestCmd.new(121, [80, 80, 0], 1)]])
      assert_equal "Two", right.call({ :avoids => :transfer }, [[transfer], []])
      assert_equal "One", right.call({ :avoids => :battle }, [[], [fight]])
      assert_equal "One", right.call({ :takes => { :self => "A" } }, [[own], []])
      assert_equal "Two", right.call({ :takes => :item }, [[], [TestCmd.new(355, ["pbReceiveItem(:XATTACK)"], 1)]])
      assert_nil right.call({ :avoids => { :var => 62 } }, [[], []]), "both are left"
      assert_nil right.call({ :avoids => { :var => 62 } }, [[wrong(62)], [wrong(62)]]), "none is left"
    end
  end

  test "right_choice goes by the value a branch stores: a number or lambda, or what another event's page takes as right" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      stores = lambda { |n| [TestCmd.new(122, [37, 37, 0, 0, n], 1)] }
      right = lambda { |rule| option_for(rule, menu(%w[One Two], [stores.call(4), stores.call(9)])) }
      assert_equal "Two", right.call(:takes => { :var => 37, :value => 9 })
      assert_equal "One", right.call(:takes => { :var => 37, :value => lambda { 4 } })
      assert_nil right.call(:takes => { :var => 37, :value => 5 }), "no branch stores it"
      flame = [TestCmd.new(111, [1, 37, 0, 4, 0]), TestCmd.new(301, [1, false, false], 1), TestCmd.new(0, [], 1), TestCmd.new(412, []),
               TestCmd.new(111, [1, 37, 0, 9, 0]), TestCmd.new(122, [38, 38, 1, 0, 1], 1), TestCmd.new(0, [], 1), TestCmd.new(412, []),
               TestCmd.new(0, [])]
      event_at(6, 5, 21, :list => flame)
      PokeAccess::World::Events.sync(true)
      assert_equal "One", right.call(:takes => { :var => 37, :compared_by => 21 }), "the first it compares"
      assert_equal "Two", right.call(:takes => { :var => 37, :compared_by => 21, :moving => 38 }), "the one that moves it on"
      assert_nil right.call(:takes => { :var => 37, :compared_by => 21, :moving => 39 })
      assert_nil right.call(:takes => { :var => 37, :compared_by => 99 }), "no such event"
    end
  end

  test "right_choice reads a menu held in a message's words, its branches the comparisons after it, and says it after that message" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      list = [TestCmd.new(118, ["top"]), TestCmd.new(101, ["Where?\\ch[1,-1,Town"]), TestCmd.new(401, ["One,Town Two,Town"]), TestCmd.new(401, ["Three,Leave]"]),
              TestCmd.new(111, [1, 1, 0, 0, 0]), TestCmd.new(122, [57, 57, 0, 0, 1], 1), TestCmd.new(412, []),
              TestCmd.new(111, [1, 1, 0, 1, 0]), TestCmd.new(122, [57, 57, 0, 0, 2], 1), TestCmd.new(412, []),
              TestCmd.new(111, [1, 1, 0, 2, 0]), TestCmd.new(122, [57, 57, 0, 0, 3], 1), TestCmd.new(412, []), TestCmd.new(0, [])]
      PokeAccess::World::Mechanics.define(:state, MAP) { right_choice 20, :takes => { :var => 57, :value => 2 } }
      running(true, list) do
        int = $game_system.map_interpreter
        int.instance_variable_set(:@event_id, 20)
        int.instance_variable_set(:@index, 1)
        PokeAccess::Puzzles::Answers.before_text(int)
        assert_equal t(:puzzle_answer, :a => "Town Two"), PokeAccess.take_tail
      end
      branches = PokeAccess::Puzzles::Answers.text_branches(list, 1, 1)
      assert_equal [0, 1, 2], branches.map { |place, _cmds| place }
      two = list + [TestCmd.new(101, ["Again?\\ch[1,-1,Yes,No]"]), TestCmd.new(111, [1, 1, 0, 0, 0]), TestCmd.new(412, []),
                    TestCmd.new(111, [1, 1, 0, -1, 0]), TestCmd.new(412, [])]
      assert_equal [0, 1, 2], PokeAccess::Puzzles::Answers.text_branches(two, 1, 1).map { |place, _cmds| place }, "stops at the next menu"
      assert_equal [0], PokeAccess::Puzzles::Answers.text_branches(two, 14, 1).map { |place, _cmds| place }, "cancelling is no option"
    end
  end

  test "a menu in a message reaches its comparisons nested in another's else, each nested menu its own" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      list = seal_page
      assert_equal [2, 1], PokeAccess::Puzzles::Answers.text_branches(list, 0, 1).map { |place, _cmds| place }
      assert_equal [0], PokeAccess::Puzzles::Answers.text_branches(list, 2, 1).map { |place, _cmds| place }
      assert_equal [2], PokeAccess::Puzzles::Answers.text_branches(list, 13, 1).map { |place, _cmds| place }
      assert_equal "One", option_for({ :takes => { :switch => 147 } }, list), "the second sequence starts in the else"
      assert_equal "Two", option_for({ :takes => { :switch => 147 } }, list, 13)
      assert_equal "Two", option_for({ :takes => { :switch => 146 } }, list)
      assert_equal "Zero", option_for({ :takes => { :switch => 146 } }, list, 2)
      assert_nil option_for({ :takes => { :switch => 147 } }, list, 29), "a menu whose answer nothing compares"
      reset = [list[0], TestCmd.new(122, [1, 1, 0, 0, 2]), TestCmd.new(111, [1, 1, 0, 2, 0]), TestCmd.new(0, [], 1), TestCmd.new(412, [])]
      assert_equal [], PokeAccess::Puzzles::Answers.text_branches(reset, 0, 1), "a comparison after the variable is set again"
    end
  end

  test "right_choice counts what a branch's jump to a label runs, up to an exit, a menu or a jump back" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      list = koan_page
      assert_equal "Leviathao", option_for({ :takes => { :self => "B" } }, list, 1), "a nested menu's jump"
      assert_equal "Krakanao", option_for({ :takes => { :self => "B" } }, list, 3), "the jump back to the menu is no win"
      assert_equal "Baitatao", option_for({ :takes => { :self => "C" } }, list, 1), "the win's exit keeps the failure out"
      looping = [TestCmd.new(102, [%w[Stay Go], 1]), TestCmd.new(402, [0, "Stay"]), TestCmd.new(119, ["loop"], 1),
                 TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Go"]), TestCmd.new(123, ["A", 0], 1), TestCmd.new(0, [], 1),
                 TestCmd.new(404, []), TestCmd.new(118, ["loop"]), TestCmd.new(119, ["loop"]), TestCmd.new(0, [])]
      assert_equal "Go", option_for({ :takes => { :self => "A" } }, looping), "a label that jumps to itself"
    end
  end

  test "from a label inside a branch the game leaves the block at the branch's end, past its other branches" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      options = [TestCmd.new(102, [%w[A B C], 1]), TestCmd.new(402, [0, "A"]), TestCmd.new(118, ["fail"], 1),
                 TestCmd.new(101, ["Oops."], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "B"]), TestCmd.new(119, ["fail"], 1),
                 TestCmd.new(0, [], 1), TestCmd.new(402, [2, "C"]), TestCmd.new(123, ["A", 0], 1), TestCmd.new(0, [], 1),
                 TestCmd.new(404, []), TestCmd.new(0, [])]
      assert_equal "C", option_for({ :takes => { :self => "A" } }, options), "the label's option is not the others'"
      branch = [TestCmd.new(102, [%w[Go Stay], 1]), TestCmd.new(402, [0, "Go"]), TestCmd.new(119, ["in"], 1), TestCmd.new(0, [], 1),
                TestCmd.new(402, [1, "Stay"]), TestCmd.new(0, [], 1), TestCmd.new(404, []), TestCmd.new(111, [12, "x"]),
                TestCmd.new(118, ["in"], 1), TestCmd.new(101, ["Inside."], 1), TestCmd.new(0, [], 1), TestCmd.new(411, []),
                TestCmd.new(123, ["B", 0], 1), TestCmd.new(0, [], 1), TestCmd.new(412, []), TestCmd.new(123, ["C", 0]),
                TestCmd.new(0, [])]
      assert_nil option_for({ :takes => { :self => "B" } }, branch), "nor is the else of the branch it is in"
      assert_equal "Go", option_for({ :takes => { :self => "C" } }, branch), "what follows the block runs"
    end
  end

  test "a place a message's menu compares twice is one option, doing what both comparisons hold" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      lit = lambda { TestCmd.new(121, [80, 80, 0], 1) }
      list = [TestCmd.new(101, ["Which?\\ch[1,-1,Zero,One]"]), TestCmd.new(111, [1, 1, 0, 1, 0]), lit.call, TestCmd.new(0, [], 1),
              TestCmd.new(412, []), TestCmd.new(111, [1, 1, 0, 1, 0]), lit.call, TestCmd.new(0, [], 1), TestCmd.new(412, []),
              TestCmd.new(111, [1, 1, 0, 0, 0]), TestCmd.new(101, ["Nothing."], 1), TestCmd.new(0, [], 1), TestCmd.new(412, []),
              TestCmd.new(0, [])]
      branches = PokeAccess::Puzzles::Answers.text_branches(list, 0, 1)
      assert_equal [1, 0], branches.map { |place, _cmds| place }
      assert_equal 4, branches[0][1].length, "both comparisons' commands"
      assert_equal "One", option_for({ :takes => { :switch => 80 } }, list)
    end
  end

  test "a message with no menu in its words says nothing of one" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      PokeAccess::World::Mechanics.define(:state, MAP) { right_choice 20, :takes => { :var => 57, :value => 2 } }
      running(true, [TestCmd.new(101, ["Plain"]), TestCmd.new(0, [])]) do
        int = $game_system.map_interpreter
        int.instance_variable_set(:@event_id, 20)
        PokeAccess::Puzzles::Answers.before_text(int)
        assert_nil PokeAccess.take_tail
      end
    end
  end

  test "a menu with no text before it says its option as it runs, and what cancelling does is no branch" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      event_at(5, 5, 20)
      PokeAccess::World::Mechanics.define(:state, MAP) { right_choice 20, :avoids => { :var => 62 } }
      list = menu(%w[One Two], [[wrong(62)], []], [wrong(62)])
      running(true, list) do
        $game_system.map_interpreter.instance_variable_set(:@event_id, 20)
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say($game_system.map_interpreter)
        assert_equal [t(:puzzle_answer, :a => "Two")], SpeakCapture.lines
      end
    end
  end

  test "with the assist, using the event again says the answer again" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      safe = event_at(5, 5, 20, :sprite => "object_box")
      running(true, [TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 6489, 0]), TestCmd.new(0, [])]) do
        PokeAccess::Puzzles::Answers.say
        fire(safe)
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say
        assert_equal [t(:puzzle_answer, :a => 6489)], SpeakCapture.lines
      end
    end
  end

  test "with the assist, a text entry says the word a script compares" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      list = [TestCmd.new(355, ["pbTextEntry('Password',0,12,28)"]), TestCmd.new(111, [12, '$game_variables[28]=="BEAUTY"']), TestCmd.new(0, [])]
      running(true, list) { assert_equal "BEAUTY", PokeAccess::Puzzles::Answers.expected }
    end
  end

  test "a script's entry says its answer only when the running command is what opens it" do
    on_map(:medium) do
      PokeAccess::Config.puzzle_assist = true
      list = [TestCmd.new(355, ["pbPokemonMart([:POTION])"]), TestCmd.new(111, [1, 5, 0, 77, 0]), TestCmd.new(0, [])]
      running(true, list) do
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say_scripted
        assert_equal [], SpeakCapture.lines, "a mart's quantity"
      end
      list = [TestCmd.new(355, ["params = ChooseNumberParams.new"]), TestCmd.new(655, ["$game_variables[5] = pbMessageChooseNumber('Code?', params)"]),
              TestCmd.new(111, [1, 5, 0, 77, 0]), TestCmd.new(0, [])]
      running(true, list) do
        $game_system.map_interpreter.instance_variable_set(:@index, 1)
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say_scripted
        assert_equal [t(:puzzle_answer, :a => 77)], SpeakCapture.lines
      end
    end
  end

  test "no answer for what compares nothing, an empty text, 0 or a menu of numbers; none without the assist" do
    on_map(:medium) do
      none = [[TestCmd.new(103, [5, 4]), TestCmd.new(0, [])],
              [TestCmd.new(355, ["pbEnterText('Name',0,12)"]), TestCmd.new(111, [12, '$game_variables[5]==""'])],
              [TestCmd.new(103, [5, 1]), TestCmd.new(111, [1, 5, 0, 0, 0])],
              [TestCmd.new(103, [5, 1]), TestCmd.new(111, [1, 5, 0, 1, 0]), TestCmd.new(111, [1, 5, 0, 2, 0])]]
      none.each { |list| running(true, list) { assert_nil PokeAccess::Puzzles::Answers.expected, list.inspect } }
      running(true, [TestCmd.new(103, [5, 4]), TestCmd.new(111, [1, 5, 0, 6489, 0])]) do
        SpeakCapture.clear
        PokeAccess::Puzzles::Answers.say
        assert_equal [], SpeakCapture.lines
      end
    end
  end

  private

  def t(*args); PokeAccess::I18n.t(*args); end

  # Runs the block on a map with nothing declared, at a verbosity level, everything put back after.
  def on_map(level)
    was_map = $game_map.map_id
    defs = PokeAccess::World::Mechanics.instance_variable_get(:@defs).dup
    x = $game_player.x
    y = $game_player.y
    PokeAccess::Config.verbosity = level
    $game_map.map_id = MAP
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    PokeAccess::World::Epoch.bump(:map) if PokeAccess::World::Epoch.respond_to?(:bump)
    PokeAccess::Puzzles::Auto.forget
    World.clear_events
    yield
  ensure
    World.clear_events
    PokeAccess::World::Mechanics.instance_variable_set(:@defs, defs)
    PokeAccess::Puzzles::Auto.forget
    $game_switches[SWITCH] = false
    $game_map.map_id = was_map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Config.verbosity = :full
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
  end

  def step(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def dist(dx, dy); PokeAccess::Puzzles.offset_phrase(dx, dy); end

  # An event of one page on (x, y).
  def event_at(x, y, id, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :through => opts.fetch(:through, false),
                        :list => opts.fetch(:list, [TestCmd.new(0, [])]))
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => [page])
  end

  # A menu at the top of a page: its options, each one's commands and those of cancelling.
  def menu(options, branches, cancel = nil)
    list = [TestCmd.new(102, [options, 1], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    if cancel
      list.push(TestCmd.new(403, [], 0))
      list.concat(cancel)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    list.push(TestCmd.new(0, [], 0))
    list
  end

  # What a wrong option does in a riddle: adds to a variable.
  def wrong(var); TestCmd.new(122, [var, var, 1, 0, 1], 1); end

  # The option a rule picks of the menu at list[i] on event 20.
  def option_for(rule, list, i = 0)
    PokeAccess::World::Mechanics.forget
    PokeAccess::World::Mechanics.define(:state, MAP, :part => :quiz) { right_choice(20, rule) }
    running(true, list) do
      $game_system.map_interpreter.instance_variable_set(:@event_id, 20)
      PokeAccess::Puzzles::Answers.right_option($game_system.map_interpreter, list, i)
    end
  end

  # A Show Text with a menu of three symbols, as Uranium's seafloor seal asks five in a row (two here): a right first
  # answer nests the next menu in its branch, the other sequence starts in the first comparison's else, a wrong one
  # jumps to a label whose menu nothing compares. Menus at 0, 2, 13 and 29.
  def seal_page
    ask = lambda { |indent| TestCmd.new(101, ["Which?\\ch[1,-1,Zero,One,Two]"], indent) }
    is = lambda { |value, indent| TestCmd.new(111, [1, 1, 0, value, 0], indent) }
    lit = lambda { |switch, indent| TestCmd.new(121, [switch, switch, 0], indent) }
    miss = lambda { |indent| [TestCmd.new(119, ["dummy"], indent), TestCmd.new(0, [], indent)] }
    [ask.call(0), is.call(2, 0), ask.call(1), is.call(0, 1), lit.call(146, 2), TestCmd.new(0, [], 2), TestCmd.new(411, [], 1)] +
      miss.call(2) + [TestCmd.new(412, [], 1), TestCmd.new(0, [], 1), TestCmd.new(411, []), is.call(1, 1), ask.call(2), is.call(2, 2),
                       lit.call(147, 3), TestCmd.new(0, [], 3), TestCmd.new(411, [], 2)] +
      miss.call(3) + [TestCmd.new(412, [], 2), TestCmd.new(0, [], 2), TestCmd.new(411, [], 1)] + miss.call(2) +
      [TestCmd.new(412, [], 1), TestCmd.new(0, [], 1), TestCmd.new(412, []), TestCmd.new(118, ["dummy"]), ask.call(0),
       TestCmd.new(119, ["dummy"]), TestCmd.new(0, [])]
  end

  # A riddle of Show Choices as Uranium's koan of the Lost Seas asks it: the right answers jump to the win, which sets
  # self switch B and ends the event before the failure's label, which sets C; one option jumps back to the start, before
  # the first menu. Menus at 1 and 3.
  def koan_page
    [TestCmd.new(118, ["start"]), TestCmd.new(102, [["Leviathao", "Baitatao", "Give up"], 1]), TestCmd.new(402, [0, "Leviathao"]),
     TestCmd.new(102, [%w[Krakanao Baitatao], 1], 1), TestCmd.new(402, [0, "Krakanao"], 1), TestCmd.new(119, ["victory"], 2),
     TestCmd.new(0, [], 2), TestCmd.new(402, [1, "Baitatao"], 1), TestCmd.new(119, ["start"], 2), TestCmd.new(0, [], 2),
     TestCmd.new(404, [], 1), TestCmd.new(0, [], 1), TestCmd.new(402, [1, "Baitatao"]), TestCmd.new(119, ["fail"], 1),
     TestCmd.new(0, [], 1), TestCmd.new(402, [2, "Give up"]), TestCmd.new(0, [], 1), TestCmd.new(404, []),
     TestCmd.new(118, ["victory"]), TestCmd.new(123, ["B", 0]), TestCmd.new(115, []), TestCmd.new(118, ["fail"]),
     TestCmd.new(123, ["C", 0]), TestCmd.new(101, ["Wrong."]), TestCmd.new(0, [])]
  end

  # A control that writes a switch and says nothing.
  def lever_at(x, y, id = 20, opts = {})
    event_at(x, y, id, :trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, "object_lever"), :name => opts.fetch(:name, "EV#{id}"),
                       :list => [TestCmd.new(121, [opts.fetch(:switch, SWITCH), opts.fetch(:switch, SWITCH), 0]), TestCmd.new(0, [])])
  end

  # A rock in the way, drawn.
  def rock_at(x, y, id = 10); event_at(x, y, id, :sprite => "Object rock"); end

  # An event that reads a switch in its page's conditions.
  def reader_of(switch, id)
    page = TestPage.new(:trigger => 0, :sprite => "Object rock", :condition => { :switch1_valid => true, :switch1_id => switch }, :list => [TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => 30, :y => 30, :pages => [page])
  end

  def gone(ev); ev.character_name = ""; end

  def drawn(ev, sheet); ev.character_name = sheet; end

  def settle_events; PokeAccess::World::Events.sync(true); end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # What is said once the player has used an event, the block being what it does and its effect settled.
  def used(ev)
    SpeakCapture.clear
    fire(ev)
    yield if block_given?
    frames(PokeAccess::Puzzles::Auto::SETTLE)
  end

  # What the next map frames say, each with a new frame of the events' sync.
  def frames(n)
    SpeakCapture.clear
    n.times do
      PokeAccess::World::Epoch.tick if PokeAccess::World::Epoch.respond_to?(:tick)
      PokeAccess::World::Events.sync(true)
      PokeAccess::Puzzles.tick
    end
    SpeakCapture.lines
  end

  # An interpreter at the first command of a list, running while it has one.
  class Running
    def initialize(list); @list = list; @index = 0; end
    def running?; !@list.nil?; end
  end

  # Runs the block with the map's interpreter running a list at its first command, then stopped; fired events go on it too.
  def running(_on, list = nil)
    was = $game_system.instance_variable_get(:@i)
    $game_system.instance_variable_set(:@i, Running.new(list || [TestCmd.new(0, [])]))
    yield
  ensure
    $game_system.map_interpreter.instance_variable_set(:@list, nil)
    $game_system.instance_variable_set(:@i, was)
  end
end
