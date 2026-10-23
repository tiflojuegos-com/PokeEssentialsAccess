# The map puzzle beyond any one game: the locator's puzzles category, the controls found among the events, labels,
# the info key, the room's rule and a phase's title as they come, its declarations and the diagnostic's report.
class PuzzlesTest < PokeAccessTest
  Mech = PokeAccess::World::Mechanics
  # The locator's categories as shipped.
  BASE = [:all, :people, :objects, :exits, :signs, :extras, :surfaces].freeze

  test "offers the puzzles category, after the configured ones, while the puzzle has a spot to list" do
    with_categories(BASE.dup) do
      declare_plate
      assert_equal BASE + [:puzzles], PokeAccess::Locator.active_categories
    end
  end

  test "offering the puzzles category leaves the configured categories as they were" do
    with_categories(BASE.dup) do
      declare_plate
      2.times { PokeAccess::Locator.active_categories }
      assert_equal BASE, PokeAccess::Config.categories
    end
  end

  test "offers a configured puzzles category once, last, however often it was configured" do
    with_categories([:all, :puzzles, :people, :puzzles, :objects, :exits, :signs, :extras, :puzzles, :surfaces]) do
      declare_plate
      assert_equal BASE + [:puzzles], PokeAccess::Locator.active_categories
    end
  end

  test "with no puzzle to list, a configured puzzles category is not offered" do
    with_categories(BASE + [:puzzles]) do
      assert_equal BASE, PokeAccess::Locator.active_categories
    end
  end

  test "a puzzle whose only pieces are moving obstacles offers no puzzles category" do
    with_categories(BASE.dup) do
      World.event(:kind => :npc, :id => 1, :x => 4, :y => 4).character_name = "sharpedo"
      Mech.define(:state, $game_map.map_id) { obstacle(/sharpedo/i, :moving => true) }
      assert_equal BASE, PokeAccess::Locator.active_categories
    end
  end

  test "finds as controls the events whose page, fired by the player, writes a watched flag" do
    place(1, page(0, TestCmd.new(122, [132, 132, 0, 0, 1])))
    place(2, page(1, TestCmd.new(121, [312, 312, 0])))
    place(3, page(2, TestCmd.new(121, [310, 315, 1])))
    place(4, page(4, TestCmd.new(122, [132, 132, 0, 0, 0])))
    place(5, page(3, TestCmd.new(121, [312, 312, 0])))
    place(6, page(0, TestCmd.new(201, [0, 5, 1, 1])))
    place(7, page(0, TestCmd.new(101, ["Hm."])), page(4, TestCmd.new(121, [312, 312, 0])))
    place(8, page(0, TestCmd.new(121, [313, 320, 0])), page(0, TestCmd.new(122, [130, 131, 0, 0, 1])))
    declare_ship(true)
    assert_equal [1, 2, 3], Mech.pieces(:control).map { |p| p.ev.id }.sort,
                 "a crank, a valve and a plate; not a parallel or autorun controller, a door, a page that leaves the " \
                 "writing to another, nor flags beside the watched ones"
  end

  test "a declaration that does not ask for controls finds none" do
    place(1, page(0, TestCmd.new(122, [132, 132, 0, 0, 1])))
    declare_ship(false)
    assert_equal [], Mech.pieces(:control)
  end

  test "names each control by the first watched flag its pages write, and no other event" do
    crank = place(1, page(0, TestCmd.new(122, [132, 132, 0, 0, 1])))
    valve = place(2, page(0, TestCmd.new(121, [312, 312, 0])))
    both = place(3, page(0, TestCmd.new(121, [312, 312, 0]), TestCmd.new(122, [132, 132, 0, 0, 1])))
    door = place(4, page(0, TestCmd.new(201, [0, 5, 1, 1])))
    declare_ship(true)
    { crank => t(:ship_crank_red), valve => t(:ship_valve1), both => t(:ship_crank_red) }.each do |ev, said|
      assert_equal said, PokeAccess::Puzzles.label_of(Mech.piece_of(ev).label), "event #{ev.id}"
    end
    assert_nil Mech.piece_of(door), "the door is no piece"
  end

  test "with assist, a grid's info key names every lit cell the letter leaves out, the first one too" do
    PokeAccess::Config.puzzle_assist = true
    [1, 5].each { |s| $game_switches[s] = true }
    Mech.define(:grid, $game_map.map_id) do
      cells 3, [[1, 1], [2, 1], [3, 1], [1, 2], [2, 2], [3, 2], [1, 3], [2, 3], [3, 3]]
      lit { |i| $game_switches[i + 1] }
      active { true }
      target { { :name => "I", :pattern => [false, true, false, false, true, false, false, true, false] } }
    end
    off = t(:puzzle_off)
    on = t(:puzzle_on)
    assert_equal [[t(:puzzle_form, :name => "I"), t(:puzzle_row, :n => 1, :cells => [on, off, off].join(", ")),
                   t(:puzzle_row, :n => 2, :cells => [off, on, off].join(", ")),
                   t(:puzzle_row, :n => 3, :cells => [off, off, off].join(", ")),
                   t(:puzzle_need, :cells => [t(:cell_tc), t(:cell_bc)].join(", ")),
                   t(:puzzle_remove, :cells => t(:cell_tl))].join(". ")],
                 info_key
  end

  test "the info key reads each watched flag, and with assist the hint after them" do
    place(1, page(0, TestCmd.new(122, [132, 132, 0, 0, 1])))
    $game_switches[312] = true
    Mech.define(:state, $game_map.map_id) do
      watch :var => 132, :label => :ship_crank_red, :on => :ship_crank_on, :off => :ship_crank_off
      watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
      controls
      hint "Gira la manivela."
    end
    flags = "#{t(:ship_crank_red)}: #{t(:ship_crank_off)}. #{t(:ship_valve1)}: #{t(:ship_valve_on)}"
    assert_equal [flags], info_key, "without assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal ["#{flags}. Gira la manivela."], info_key, "with it"
  end

  test "resolves a label from a symbol, a string, a symbol with its values, or a lambda asked each time" do
    { :ship_valve1 => t(:ship_valve1), "Placa" => "Placa", [:riddle_sign, { :n => 2 }] => t(:riddle_sign, :n => 2),
      [:ship_valve2] => t(:ship_valve2), nil => "" }.each do |label, said|
      assert_equal said, PokeAccess::Puzzles.label_of(label), label.inspect
    end
    answers = [:ship_valve1, "Placa"]
    asked = lambda { answers.shift }
    assert_equal [t(:ship_valve1), "Placa"], [PokeAccess::Puzzles.label_of(asked), PokeAccess::Puzzles.label_of(asked)]
  end

  test "the diagnostic reports the puzzle's kind, its watched flags with their values and its pieces" do
    World.event(:kind => :npc, :id => 1, :x => 4, :y => 4).character_name = "humo"
    place(2, page(0, TestCmd.new(121, [312, 312, 0])), :x => 6, :y => 4)
    World.event(:kind => :npc, :id => 3, :x => 8, :y => 8).character_name = "sharpedo"
    $game_variables[132] = 1
    declare_ship(true)
    assert_equal ["puzzle: kind=state active=true owns_info=true locator_targets=true",
                  "  watch(2)=#{%w[var132=true sw312=false].inspect}",
                  "  pieces=#{['obstacle:ev1@4,4:' + t(:ship_steam), 'control:ev2@6,4:' + t(:ship_valve1),
                               'obstacle:ev3@8,8:moving'].inspect}"],
                 diagnostic
  end

  test "the diagnostic reports a solved puzzle inactive, the info key no longer its" do
    $game_switches[312] = true
    declare_ship(true)
    assert_equal "puzzle: kind=state active=false owns_info=false locator_targets=false", diagnostic[0]
  end

  test "a profile's test that raises counts as false: the puzzle it would solve stays unsolved" do
    Mech.define(:state, $game_map.map_id) do
      watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
      solved { raise "the game's state is not there" }
    end
    assert_equal "puzzle: kind=state active=true owns_info=true locator_targets=false", diagnostic[0]
  end

  test "the diagnostic reports a puzzle active while one of its phases is live, its title the info key's" do
    declare_plate
    assert_equal "puzzle: kind=state active=true owns_info=true locator_targets=true", diagnostic[0]
    assert_equal ["Pisa la placa"], info_key, "the info key"
  end

  test "the diagnostic reports a puzzle with no phase, watched flag or info line inactive" do
    World.event(:kind => :npc, :id => 1, :x => 4, :y => 4).character_name = "sharpedo"
    Mech.define(:state, $game_map.map_id) { obstacle(/sharpedo/i, :moving => true) }
    assert_equal ["puzzle: kind=state active=false owns_info=false locator_targets=false",
                  "  watch(0)=[]",
                  "  pieces=#{['obstacle:ev1@4,4:moving'].inspect}"],
                 diagnostic
  end

  test "the diagnostic says when the map has no puzzle" do
    assert_equal ["puzzle: none for this map"], diagnostic
  end

  test "on a map with no puzzle, the frame says nothing and no event is a piece" do
    smoke = World.event(:kind => :npc, :id => 1, :x => 4, :y => 4)
    smoke.character_name = "humo"
    PokeAccess::Puzzles.tick
    assert_nothing_spoken
    assert_nil Mech.piece_of(smoke)
    assert_equal [], Mech.pieces
  end

  test "on a map with no puzzle, the puzzles category lists nothing and the info key is not the puzzle's" do
    assert_equal [], PokeAccess::Puzzles.category_targets, "the category's targets"
    assert_equal false, PokeAccess::Puzzles.active?, "whether it answers the info key"
    assert_nil PokeAccess::Puzzles.info_line, "the info key's line"
  end

  test "a puzzle's rule for the room is said once on arrival, queued, while descriptions are said" do
    said = vb_levels do
      Mech.forget
      Mech.define(:state, $game_map.map_id) { arrival_hint "Las trampas se mueven al pisarlas." }
      SpeakCapture.clear
      2.times { PokeAccess::Puzzles.tick }
      SpeakCapture.log.dup
    end
    rule = [["Las trampas se mueven al pisarlas.", false]]
    assert_equal [[], [], rule], said, "brief, medium and full"
  end

  test "a phase of the puzzle that opens says its title, queued" do
    Mech.define(:state, $game_map.map_id) { phase lambda { $game_switches[1] }, :title => "Pisa la placa" }
    PokeAccess::Puzzles.tick
    SpeakCapture.clear
    $game_switches[1] = true
    PokeAccess::Puzzles.tick
    assert_equal [["Pisa la placa", false]], SpeakCapture.log
  end

  test "a declaration of a kind no mechanic answers to is no puzzle" do
    World.event(:kind => :npc, :id => 1, :x => 4, :y => 4).character_name = "humo"
    Mech.declare($game_map.map_id, :kind => :riddle, :obstacles => [{ :match => /humo/i, :kind => :wall }])
    PokeAccess::Puzzles.tick
    assert_nothing_spoken
    assert_nil Mech.instance
    assert_equal [], Mech.pieces
  end

  test "a new declaration for the map the player is on replaces its puzzle at once" do
    place(1, page(0, TestCmd.new(122, [132, 132, 0, 0, 1])))
    declare_ship(false)
    assert_equal [], Mech.pieces(:control), "declared without controls"
    declare_ship(true)
    assert_equal [1], Mech.pieces(:control).map { |p| p.ev.id }, "declared again with them"
  end

  test "leaving for a map with no puzzle drops the puzzle of the last one" do
    World.event(:kind => :npc, :id => 1, :x => 4, :y => 4).character_name = "humo"
    declare_ship(false)
    assert_equal 1, Mech.pieces.length, "on the puzzle's map"
    $game_map.map_id = 2
    assert_equal [], Mech.pieces, "on the next map"
    assert_nil Mech.instance
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the locator's configured categories set to list, the shipped ones put back after.
  def with_categories(list)
    was = PokeAccess::Config.categories
    PokeAccess::Config.categories = list
    yield
  ensure
    PokeAccess::Config.categories = was
  end

  # Declares on the test map a puzzle whose one live phase, titled, names a floor plate.
  def declare_plate
    Mech.define(:state, $game_map.map_id) do
      phase lambda { true }, :title => "Pisa la placa", :spots => [{ :at => [1, 1], :label => "Placa" }]
    end
  end

  # Declares on the test map a puzzle watching the red crank (variable 132) and the first valve (switch 312), solved
  # once the valve is open, its steam jets walls and its Sharpedo moving traps; with controls, found among the events.
  def declare_ship(controls)
    Mech.define(:state, $game_map.map_id) do
      watch :var => 132, :label => :ship_crank_red, :on => :ship_crank_on, :off => :ship_crank_off
      watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
      self.controls if controls
      obstacle(/humo/i, :label => :ship_steam)
      obstacle(/sharpedo/i, :moving => true)
      solved { $game_switches[312] }
    end
  end

  # An event page fired by trigger (0 action button, 1 player touch, 2 event touch, 3 autorun, 4 parallel) running
  # the given commands.
  def page(trigger, *commands)
    TestPage.new(:trigger => trigger, :list => commands)
  end

  # Places an event with the given pages on the test map; opts :x and :y, the top left by default.
  def place(id, *pages)
    opts = pages.last.is_a?(Hash) ? pages.pop : {}
    ev = TestGameEvent.new(:id => id, :x => opts.fetch(:x, id), :y => opts.fetch(:y, 1), :pages => pages)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # What the info key says on the map.
  def info_key
    PokeAccess::Locator.refresh_info
    SpeakCapture.clear
    PokeAccess::Keys.info_key
    SpeakCapture.lines
  end

  # The diagnostic's puzzle section, line by line.
  def diagnostic
    out = []
    PokeAccess::Keys.diag_puzzle(out)
    out
  end
end
