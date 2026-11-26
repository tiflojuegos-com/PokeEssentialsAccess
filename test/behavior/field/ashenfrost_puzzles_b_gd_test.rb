# Pokemon Ashen Frost's story puzzles, part B (games/ashenfrost/puzzles/): the archives' hidden children, Truffles' green
# smells in the theatre, the smuggling tunnels' coloured spikes, Mordecai's cell, Priya's condo, the logging camp's hatchet
# and Purrloin, and the abandoned tunnels. Without the assist, what the screen shows; with it, the way. Gamedata pass.
class AshenFrostPuzzlesBGdTest < PokeAccessTest
  SWITCHES = [71, 83, 115, 142, 143, 144]
  VARS = [78, 122, 403]

  def setup
    super
    keyed
    Harness.load_puzzles("ashenfrost")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "the tunnels' plan gives the four presses of the way to Francis, each from where the last left the player" do
    tunnels = PokeAccess::AshenSmugglingTunnels
    on_map(405, 46, 7)
    assert_equal [3, :lower], tunnels.next_press
    $game_switches[142] = true
    at(24, 13)
    assert_equal [5, :raise], tunnels.next_press
    $game_switches[142] = false
    $game_switches[144] = true
    at(24, 19)
    assert_equal 4, tunnels.state
    assert_equal [22, :lower], tunnels.next_press
    $game_self_switches[[405, 23, "A"]] = true
    assert_equal 20, tunnels.state
    assert_equal [5, :lower], tunnels.next_press
    $game_switches[142] = true
    $game_switches[144] = false
    at(23, 15)
    assert_equal :open, tunnels.next_press
    at(0, 0)
    assert_nil tunnels.next_press, "off the parts the plan knows, nothing"
  end

  test "the tunnels name the switches and spikes by colour, say each colour as it moves, and the next press only with the assist" do
    on_map(405, 46, 7)
    red = place(3, 24, 6, "Red Switch")
    spikes = place(4, 24, 9, "Red Spikes")
    master = place(27, 43, 6, "Red Switch")
    assert_equal "{afb_switch_red n=1}", PokeAccess::Puzzles.piece_name(red)
    assert_equal "{afb_switch_master}", PokeAccess::Puzzles.piece_name(master)
    assert_equal "{afb_spikes_named spikes={afb_spikes_red n=} state={afb_spikes_up}}", PokeAccess::Puzzles.piece_name(spikes)
    frame
    lines = frame { $game_switches[142] = true }
    assert(lines.any? { |l| l.include?("afb_spikes_red") && l.include?("afb_spikes_down") }, lines.inspect)
    refute(lines.any? { |l| l.include?("afb_tunnels_next") }, "no press without the assist")
    assert_equal "{afb_spikes_named spikes={afb_spikes_red n=} state={afb_spikes_down}}", PokeAccess::Puzzles.piece_name(spikes)
    $game_switches[142] = false
    frame
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afb_tunnels_next action={afb_action_lower} switch={afb_switch_red n=1}}"
    assert_equal({ :switch => 142, :to => true }, PokeAccess::AshenSmugglingTunnels.choice(3))
    assert_nil PokeAccess::AshenSmugglingTunnels.choice(5), "not the switch to press now"
  end

  test "past Francis the tunnels lead to the exit, and nothing once it is taken" do
    on_map(405, 23, 15)
    $game_switches[142] = true
    $game_self_switches[[405, 23, "A"]] = true
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afb_tunnels_to_francis}"
    $game_self_switches[[405, 71, "A"]] = true
    assert_includes frame, "{afb_tunnels_to_exit}"
    $game_self_switches[[405, 70, "A"]] = true
    refute(frame.any? { |l| l.include?("afb_tunnels") })
  end

  test "the archives count the children found only with the assist, and stop at three" do
    on_map(351, 10, 10)
    kid = place(13, 4, 15, "Kid")
    assert_equal "{afb_hiding_kid}", PokeAccess::Puzzles.piece_name(kid)
    frame
    assert_equal [], frame { $game_variables[78] = 1 }
    PokeAccess::Config.puzzle_assist = true
    frame
    assert_includes frame { $game_variables[78] = 2 }, "{puzzle_progress label={afb_kids_found} n=2 of=3}"
    $game_variables[78] = 3
    frame
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Truffles' green smells are named, the sniffed ones leave the lists and are counted with the assist alone" do
    on_map(398, 20, 11)
    $game_switches[71] = true
    one = place(40, 12, 11, "Francis Smell 1")
    two = place(41, 6, 20, "Francis Smell 2")
    assert_equal "{afb_green_smell}", PokeAccess::Puzzles.piece_name(one)
    $game_self_switches[[398, 40, "A"]] = true
    $game_variables[403] = 1
    assert_equal [two, one].map(&:id).sort, smell_targets.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal [41], smell_targets
    $game_variables[403] = 5
    assert_equal 4, PokeAccess::AshenTheatreSmells.found
    assert_includes frame, "{afb_smells_done}"
    $game_switches[115] = true
    refute_includes frame, "{afb_smells_done}"
  end

  test "Mordecai's cell says the next thing to use with the assist, in the game's order" do
    on_map(453, 8, 5)
    assert_equal [], frame.select { |l| l.include?("afb_cell_next") }
    PokeAccess::Config.puzzle_assist = true
    steps = []
    steps << frame
    [[5, "B"], [8, "A"], [17, "B"], [11, "A"], [6, "A"]].each do |ev, letter|
      $game_self_switches[[453, ev, letter]] = true
      steps << frame
    end
    %w[toilet shelf tile bench sink sewer].each_with_index do |step, i|
      assert_includes steps[i], "{afb_cell_next_#{step}}"
    end
    assert_includes PokeAccess::Info.map_text.to_s, "{afb_cell_next_sewer}", "the sink emptied, the sewer still to take"
    PokeAccess::World::Mechanics.forget
    assert_includes frame, "{afb_cell_next_sewer}", "and again on coming back"
    $game_self_switches[[454, 1, "A"]] = true
    refute_includes PokeAccess::Info.map_text.to_s, "afb_cell_next", "out in the courthouse"
  end

  test "Priya's condo takes the vent and the hanger in either order before the closet, the rope and the mannequin" do
    basement = PokeAccess::AshenPriyaBasement
    on_map(15, 12, 10)
    assert_equal :panel, basement.step
    $game_self_switches[[15, 2, "A"]] = true
    assert_equal :panel, basement.step, "a hanger taken first leaves the vent to fix"
    $game_self_switches = {}
    $game_self_switches[[15, 9, "A"]] = true
    assert_equal :hanger, basement.step
    $game_self_switches[[15, 2, "A"]] = true
    assert_equal :closet, basement.step
    $game_self_switches[[15, 7, "A"]] = true
    assert_equal :rope, basement.step
    $game_self_switches[[15, 7, "B"]] = true
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afb_priya_next_mannequin}"
    $game_self_switches[[15, 10, "A"]] = true
    assert_nil basement.step
  end

  test "the camp names the hatchet's stump, leads the errand with the assist and sends Mordecai to the well after the Purrloin" do
    on_map(54, 25, 14)
    stump = place(1, 11, 14, "Hatchet A")
    assert_equal "{afb_hatchet}", PokeAccess::Puzzles.piece_name(stump)
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{afb_camp_hatchet}"
    $game_self_switches[[54, 1, "A"]] = true
    assert_equal "{afb_stump}", PokeAccess::Puzzles.piece_name(stump)
    assert_includes frame, "{afb_camp_back}"
    $game_self_switches[[54, 8, "A"]] = true
    $game_switches[83] = true
    $game_variables[122] = 2
    assert_includes frame, "{afb_camp_purrloin}"
    $game_variables[122] = 3
    refute_includes frame, "{afb_camp_purrloin}"
  end

  test "the abandoned tunnels tell the jumps on arrival until the chase is over, and the studio with the assist" do
    PokeAccess::Config.verbosity = :full
    on_map(56, 18, 34)
    $game_variables[122] = 3
    assert(frame.any? { |l| l.include?("afb_tunnels_hops") })
    PokeAccess::Config.puzzle_assist = true
    on_map(56, 18, 34)
    PokeAccess::Config.puzzle_assist = true
    $game_variables[122] = 3
    assert(frame.any? { |l| l.include?("afb_tunnels_studio") })
    $game_variables[122] = 4
    on_map(56, 18, 34)
    $game_variables[122] = 4
    refute(frame.any? { |l| l.include?("afb_tunnels_hops") })
  end

  private

  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :afb_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :afb_kept_t)
    i18n.send(:remove_method, :afb_kept_t)
  end

  def on_map(map, x, y)
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_map.map_id = map
    at(x, y)
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def at(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  def place(id, x, y, name)
    page = TestPage.new(:trigger => 0, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The theatre's green smells the puzzles category lists, by event id.
  def smell_targets
    PokeAccess::Caches.reset_all
    smells = { [12, 11] => 40, [6, 20] => 41, [21, 5] => 42, [24, 12] => 43 }
    PokeAccess::Puzzles.category_targets.map { |tg| smells[[tg.x, tg.y]] }.compact.uniq
  end
end
