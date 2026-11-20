# Pokemon Grueling Gold's puzzles on the shipped profile: Violet Gym's two buttons, Cianwood Gym's boulders, buttons and
# holes, the Ruins of Alph's panels, the ice of Mahogany Gym and the Ice Path, and the statues of Team Rocket's hideout,
# each as heard with the puzzle assist and without it.
class GruelingGoldPuzzlesTest < PokeAccessTest
  def setup
    super
    @self_switches = $game_self_switches
    $game_self_switches = {}
  end

  def teardown
    $game_self_switches = @self_switches
    super
  end

  test "Violet Gym lists both buttons and the block, says each press and stops once both are down" do
    on_map(205)
    button(3, 2, 11, 71)
    button(5, 24, 11, 102)
    place(2, 7, 15, [], :tile_id => 390)
    assert_equal [t(:gg_button_west), t(:gg_button_east), t(:gg_violet_block)].sort, names.sort
    assert_equal [[t(:gg_violet_rule), false]], tick, "the rule on arriving"
    $game_switches[71] = true
    assert_equal [[watch_line(:gg_button_west, :gg_pressed), false]], tick
    refute_includes info_key.to_s, t(:gg_violet_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:gg_violet_hint)
    $game_switches[102] = true
    tick
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Cianwood Gym names the holes and buttons for all, and the boulders' roles with the assist alone" do
    on_cianwood
    assert_equal [t(:gg_button_west), t(:gg_button_east), t(:gg_cianwood_hole), t(:gg_cianwood_hole),
                  t(:gg_cianwood_hole)].sort, names.sort
    PokeAccess::Config.puzzle_assist = true
    assert_equal 3, names.count(t(:gg_cianwood_hole_boulder))
    assert_includes names, t(:gg_cianwood_west_boulder)
    assert_includes names, t(:gg_cianwood_east_boulder)
    $game_self_switches[[257, 2, "A"]] = true
    assert_equal 2, names.count(t(:gg_cianwood_hole_boulder)), "a boulder in its hole is floor"
  end

  test "Cianwood Gym tells its rule on the first arrival only, as the gym throws the player out to start over" do
    on_cianwood
    assert_includes tick.map(&:first), t(:gg_cianwood_rule)
    assert_empty leave_and_return(257)
  end

  test "Cianwood Gym's assist walks the plan: the way in, the west boulder, the east one, then the holes" do
    on_cianwood
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "#{t(:gg_cianwood_open_hint)} #{t(:gg_cianwood_reset_hint)}"
    $game_map.events[13].instance_variable_set(:@erased, true)
    move(2, 15, 15)
    assert_includes info_key, t(:gg_cianwood_west_hint)
    move(18, 12, 16)
    assert_includes info_key, t(:gg_cianwood_east_hint)
    move(16, 18, 16)
    $game_switches[129] = true
    assert_includes info_key, t(:gg_cianwood_holes_hint)
    PokeAccess::Config.puzzle_assist = false
    [:gg_cianwood_open_hint, :gg_cianwood_west_hint, :gg_cianwood_east_hint, :gg_cianwood_holes_hint].each do |k|
      refute_includes info_key.to_s, t(k)
    end
  end

  test "Cianwood Gym's way in, on a later visit with the centre boulder already in its hole, leaves out its push" do
    on_cianwood
    PokeAccess::Config.puzzle_assist = true
    $game_switches[129] = true
    $game_variables[36] = 1
    $game_self_switches[[257, 2, "A"]] = true
    assert_includes info_key, t(:gg_cianwood_open_short_hint)
    refute_includes info_key, t(:gg_cianwood_open_hint)
  end

  test "Cianwood Gym says the buttons, the holes opening, each hole filled and the way to Chuck clear" do
    on_cianwood
    tick
    $game_self_switches[[257, 5, "A"]] = true
    assert_equal [[t(:gg_cianwood_west_down), false]], tick
    $game_self_switches[[257, 5, "A"]] = false
    assert_equal [], tick, "a boulder off its button says nothing"
    $game_self_switches[[257, 5, "A"]] = true
    tick
    $game_self_switches[[257, 5, "B"]] = true
    $game_switches[129] = true
    assert_equal [t(:gg_cianwood_holes_open)], tick.map(&:first), "the holes, not the button, once they open"
    assert_includes names, t(:gg_cianwood_hole_open)
    $game_self_switches[[257, 5, "A"]] = false
    $game_self_switches[[257, 5, "B"]] = false
    tick
    $game_self_switches[[257, 5, "B"]] = true
    assert_equal [], tick, "the buttons no longer matter"
    $game_variables[36] = 1
    assert_equal [[t(:puzzle_progress, :label => t(:gg_cianwood_holes_filled), :n => 1, :of => 3), false]], tick
    $game_variables[36] = 3
    assert_includes tick.map(&:first), t(:gg_cianwood_solved)
    refute_includes names, t(:gg_cianwood_hole_open)
  end

  test "the Ruins of Alph list a chamber's panel until it is solved, and count the five with the assist alone" do
    on_map(362)
    place(6, 9, 3, [TestCmd.new(101, ["It appears to be an ancient puzzle."])])
    assert_equal [t(:gg_alph_panel)], names
    $game_variables[40] = 2
    refute_includes info_key.to_s, t(:gg_alph_solved)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:puzzle_progress, :label => t(:gg_alph_solved), :n => 2, :of => 5)
    assert_includes info_key, t(:gg_alph_hint)
    $game_self_switches[[362, 6, "A"]] = true
    assert_empty names
  end

  test "the Kabuto chamber names the secret hole once the fifth panel is solved" do
    on_map(364)
    $game_variables[40] = 5
    place(4, 6, 1, [TestCmd.new(201, [0, 372, 9, 11])], :trigger => 1, :tile_id => 1467)
    assert_includes names, t(:gg_alph_secret_hole)
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "Mahogany Gym and the Ice Path tell the ice rule, and Mahogany's slides go with the assist until the badge" do
    on_map(286)
    assert_equal [[t(:gg_ice_rule), false]], tick, "the Ice Path's rule on arriving"
    assert_empty leave_and_return(286), "and only the first time"
    on_map(284)
    assert_equal [[t(:gg_ice_rule), false]], tick, "Mahogany's rule on arriving"
    refute_includes info_key.to_s, t(:gg_mahogany_hint)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:gg_mahogany_hint)
    $game_switches[10] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Rocket hideout names its statues by whether they still watch, and the computer until it is used" do
    on_map(279)
    (1..5).each { |id| place(id, 10 + id, 1, [], :tile_id => 1700) }
    place(9, 45, 17, [TestCmd.new(101, ["All the statues were deactivated!"])])
    assert_equal ([t(:gg_rocket_statue)] * 5 + [t(:gg_rocket_computer)]).sort, names.sort
    $game_switches[151] = true
    assert_equal 1, names.count(t(:gg_rocket_statue_off))
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:gg_rocket_hint)
    $game_switches[143] = true
    assert_equal [t(:gg_rocket_statue_off)] * 5, names
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "walks keep off the Rocket hideout's alarm tiles with the puzzle assist alone, and never off a used one" do
    on_map(279)
    place(10, 46, 3, [TestCmd.new(101, ["Intruder alert!"])], :trigger => 1)
    place(24, 14, 3, [], :trigger => 0)
    kept = lambda do
      off = PokeAccess::Routes::Controls.keep_off
      [[46, 3], [14, 3]].map { |x, y| off[PokeAccess::Routes.pkey(x, y)] ? true : false }
    end
    seen = kept.call
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[false, false], [true, false]], [seen, kept.call]
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A watched flag's line as said when it changes.
  def watch_line(label, word)
    t(:puzzle_value, :label => t(label), :v => t(word))
  end

  # Declares the shipped puzzles and puts the player on map with every flag of these puzzles off.
  def on_map(map)
    Harness.load_puzzles("gruelinggold")
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    [10, 71, 102, 129, 143, 151, 152, 153, 154, 155].each { |s| $game_switches[s] = false }
    [36, 40].each { |v| $game_variables[v] = 0 }
    World.next_frame
  end

  # Cianwood Gym as the player enters it: the boulders, the rocks and the holes where the map puts them.
  def on_cianwood
    on_map(257)
    { 1 => [14, 15], 2 => [15, 16], 3 => [16, 15], 8 => [14, 20], 9 => [15, 19], 10 => [16, 20], 11 => [14, 18],
      12 => [14, 17], 14 => [16, 17], 16 => [17, 19], 17 => [16, 18], 18 => [13, 19] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(355, ["pbPushThisBoulder"])], :trigger => 1, :sprite => "Object boulder")
    end
    { 13 => [15, 18], 15 => [12, 20], 19 => [18, 19], 20 => [17, 20], 21 => [13, 17], 22 => [14, 19] }.each do |id, (x, y)|
      place(id, x, y, [TestCmd.new(355, ["pbRockSmash"])], :sprite => "Object rock")
    end
    { 5 => 14, 24 => 15, 28 => 16 }.each { |id, x| place(id, x, 14, [], :tile_id => 884) }
  end

  # A floor button that writes switch sw when stepped on, drawn with a tile.
  def button(id, x, y, sw)
    list = [TestCmd.new(101, ["\\PN pressed the button."]), TestCmd.new(121, [sw, sw, 0]), TestCmd.new(123, ["A", 0])]
    place(id, x, y, list, :trigger => 1, :tile_id => 398)
  end

  # An event at (x, y) whose live page runs list, placed on the map.
  def place(id, x, y, list, opts = {})
    page = TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""), :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page,
                           :tile_id => opts.fetch(:tile_id, 0))
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # Leaves for another map and comes back to map: what was said on arriving again.
  def leave_and_return(map)
    $game_map.map_id = 1
    PokeAccess::Caches.reset_all
    tick
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    tick
  end

  # Moves event id to (x, y).
  def move(id, x, y)
    ev = $game_map.events[id]
    ev.x = x
    ev.y = y
    World.next_frame
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map { |x| x.respond_to?(:key) ? x.name : PokeAccess::Locator.target_name(x) }
  end

  # One frame of the puzzle: what it said.
  def tick
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.log.dup
  end

  # What the info key says on the map now.
  def info_key
    PokeAccess::Info.map_text
  end
end
