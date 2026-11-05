# Royal's three gym trials that stand in the story's way (games/royal/puzzles/): Hoyuelo's Wooloo, Amura's water jets and Piston's
# conveyor belts, on the shipped profile over events shaped like the game's. What is heard without the puzzle assist is the room
# and its state; the answers come with it. Gamedata pass.
class RoyalPuzzlesGdTest < PokeAccessTest
  MAPS = [125, 155, 165]
  YELLOW_JET_ON = 23
  YELLOW_JET_OFF = 24

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    [77, 78, 79, 80, 81, 82, 94, 111].each { |i| $game_variables[i] = 0 }
    [116, 117, 118, 151, 152, 153, 154].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "Hoyuelo's Wooloo are named by what they do, and the blue patch of the pen is listed" do
    on_map(125)
    wooloo(1, 13, 80, "wooloo1")
    wooloo(2, 14, 82, "wooloo1run")
    wooloo(3, 14, 65, "wooloo2stop")
    $game_variables[77] = 2
    frame
    assert_equal [[14, 65, t(:royal_g1_wooloo_in)], [11, 73, t(:royal_g1_goal)], [13, 80, t(:royal_g1_wooloo)],
                  [14, 82, t(:royal_g1_wooloo_run)]], listed.sort_by { |_x, y, _n| y }
    $game_variables[77] = 5
    frame
    assert_includes listed, [11, 54, t(:royal_g1_goal)]
    refute_includes listed, [11, 73, t(:royal_g1_goal)]
    $game_variables[77] = 8
    frame
    assert_includes listed, [11, 26, t(:royal_g1_goal)]
  end

  test "Hoyuelo says each pen's goal, counts the Wooloo that stop in each column, and says when the fences go down" do
    on_map(125)
    frame
    assert_equal [], frame { $game_variables[77] = 1 }
    assert_equal [t(:royal_g1_pen1)], frame { $game_variables[77] = 2 }
    assert_equal [column(2, 1)], frame { $game_variables[79] = 1 }
    assert_equal [column(1, 1)], frame { $game_variables[78] = 1 }
    assert_equal PokeAccess.sentences([t(:royal_g1_pen1), "#{column(1, 1)}, #{column(2, 1)}, #{column(3, 0)}",
                                       t(:puzzle_sum, :n => 2), t(:royal_g1_rule)]), info_key
    assert_equal [t(:royal_g1_fences)], frame { set_vars(77 => 3, 78 => 0, 79 => 0, 80 => 0) }
    assert_equal [t(:royal_g1_pen2)], frame { $game_variables[77] = 5 }
    assert_equal [t(:royal_g1_fences)], frame { $game_variables[77] = 6 }
    assert_equal [t(:royal_g1_pen3)], frame { $game_variables[77] = 8 }
    assert_equal [column(5, 2)], frame { $game_variables[82] = 2 }
    assert_equal [t(:royal_g1_fences)], frame { $game_variables[77] = 9 }
    assert_equal [t(:royal_g1_last)], frame { $game_variables[77] = 11 }
    frame { $game_variables[77] = 12 }
    refute PokeAccess::Puzzles.active?
  end

  test "Hoyuelo gives the way to herd the Wooloo with the assist alone, by the pen" do
    on_map(125)
    frame
    refute_includes frame { $game_variables[77] = 2 }, t(:royal_g1_hint1)
    refute_includes info_key, t(:royal_g1_hint1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:royal_g1_hint1)
    assert_equal [PokeAccess.sentences([t(:royal_g1_pen2), t(:royal_g1_hint2)])], frame { $game_variables[77] = 5 }
    assert_equal [PokeAccess.sentences([t(:royal_g1_pen3), t(:royal_g1_hint3)])], frame { $game_variables[77] = 8 }
  end

  test "Amura's buttons are named by colour and numbered from north to south, the jets by their colour" do
    on_map(155)
    { 85 => [28, 51, 118], 86 => [16, 50, 118], 87 => [24, 37, 118], 88 => [30, 55, 117], 89 => [32, 43, 117],
      90 => [8, 38, 117], 91 => [16, 38, 116] }.each { |id, (x, y, s)| button(id, x, y, s) }
    jet(1, 19, 52, 116, true)
    jet(YELLOW_JET_ON, 34, 49, 118, true)
    frame
    assert_equal [[8, 38, t(:royal_g2_button_red, :n => 1)], [16, 38, t(:royal_g2_button_blue)],
                  [16, 50, t(:royal_g2_button_yellow, :n => 2)], [19, 52, t(:royal_g2_jets_blue)],
                  [24, 37, t(:royal_g2_button_yellow, :n => 1)], [28, 51, t(:royal_g2_button_yellow, :n => 3)],
                  [30, 55, t(:royal_g2_button_red, :n => 3)], [32, 43, t(:royal_g2_button_red, :n => 2)],
                  [34, 49, t(:royal_g2_jets_yellow)]], listed.sort_by { |x, _y, _n| x }
    assert_equal t(:royal_g2_jets_blue), PokeAccess::Puzzles.piece_name($game_map.events[1])
  end

  test "Amura says which colour a button changed and what that did to the jets, and gives the order with the assist alone" do
    on_map(155)
    jet(YELLOW_JET_ON, 34, 49, 118, true)
    jet(YELLOW_JET_OFF, 26, 43, 118, false)
    button(85, 28, 51, 118)
    frame
    assert_includes info_key, pipes(:yellow, :off)
    refute_includes info_key, t(:royal_g2_hint)
    changes = "#{t(:ctrl_quit, :n => 1)}, #{t(:ctrl_rise, :n => 1)}"
    said = frame { $game_switches[118] = true }
    assert_equal [PokeAccess.sentences([pipes(:yellow, :on), t(:ctrl_group, :what => t(:royal_g2_jets_yellow), :changes => changes)])], said
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:royal_g2_hint)
    frame { $game_variables[94] = 2 }
    refute PokeAccess::Puzzles.active?
  end

  test "Amura says its rule on arriving, in full only" do
    on_map(155)
    PokeAccess::Config.verbosity = :full
    assert_equal [t(:royal_g2_rule)], frame
    on_map(155)
    PokeAccess::Config.verbosity = :medium
    assert_equal [], frame
    PokeAccess::Config.verbosity = :full
  end

  test "Piston's buttons are named by colour and numbered from north to south, and its belts by the colours that turn them" do
    on_map(165)
    { 35 => [22, 31, 151], 21 => [34, 43, 151], 2 => [29, 64, 151], 8 => [29, 66, 151], 34 => [36, 37, 152],
      4 => [29, 53, 152], 27 => [24, 64, 152], 25 => [36, 64, 152], 15 => [36, 53, 153], 26 => [24, 59, 153],
      16 => [39, 49, 154] }.each { |id, (x, y, s)| button(id, x, y, s) }
    { 1 => [32, 66], 7 => [31, 60], 33 => [35, 44], 37 => [30, 23] }.each { |id, (x, y)| belt(id, x, y) }
    frame
    assert_equal [[22, 31, t(:royal_g3_button_purple, :n => 1)], [24, 59, t(:royal_g3_button_blue, :n => 2)],
                  [24, 64, t(:royal_g3_button_red, :n => 3)], [29, 53, t(:royal_g3_button_red, :n => 2)],
                  [29, 64, t(:royal_g3_button_purple, :n => 3)], [29, 66, t(:royal_g3_button_purple, :n => 4)],
                  [30, 23, t(:royal_g3_belt_plain)], [31, 60, belt_name(:red, :blue)], [32, 66, belt_name(:purple)],
                  [34, 43, t(:royal_g3_button_purple, :n => 2)], [35, 44, belt_name(:purple, :red, :green)],
                  [36, 37, t(:royal_g3_button_red, :n => 1)], [36, 53, t(:royal_g3_button_blue, :n => 1)],
                  [36, 64, t(:royal_g3_button_red, :n => 4)], [39, 49, t(:royal_g3_button_green)]], listed.sort_by { |x, _y, _n| x }
  end

  test "Piston says which colour of belts a button reversed, and gives the order of the buttons with the assist alone" do
    on_map(165)
    button(8, 29, 66, 151)
    button(16, 39, 49, 154)
    frame
    assert_includes info_key, belts(:purple, :off)
    refute_includes info_key, t(:royal_g3_hint)
    assert_equal [belts(:purple, :on)], frame { $game_switches[151] = true }
    assert_equal [belts(:green, :on)], frame { $game_switches[154] = true }
    assert_equal [belts(:purple, :off)], frame { $game_switches[151] = false }
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:royal_g3_hint)
    frame { $game_variables[111] = 3 }
    refute PokeAccess::Puzzles.active?
  end

  test "Piston says its rule on arriving, in full only" do
    on_map(165)
    PokeAccess::Config.verbosity = :full
    assert_equal [t(:royal_g3_rule)], frame
    on_map(165)
    PokeAccess::Config.verbosity = :medium
    assert_equal [], frame
    PokeAccess::Config.verbosity = :full
  end

  test "the belts' table names the twenty belts of the map, each by colours the profile knows" do
    declare_puzzles
    belts = PokeAccess::RoyalBelts::BELTS
    assert_equal [1, 3, 5, 6, 7, 14, 17, 18, 19, 20, 22, 23, 24, 28, 29, 30, 31, 32, 33, 37], belts.keys.sort
    assert_equal [], belts.values.flatten.uniq - PokeAccess::RoyalBelts::COLORS.keys
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("royal")
      all = mechanics.instance_variable_get(:@defs)
      MAPS.map { |map| [map, all[map]] }
    end
    defs = mechanics.instance_variable_get(:@defs)
    self.class.declared.each { |map, list| defs[map] = list }
  end

  # Puts the player on map with nothing placed, the assist off and the mechanics forgotten.
  def on_map(map)
    declare_puzzles
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event on the map: the pages given, else one with the trigger, sprite and commands of opts.
  def put(id, x, y, opts = {})
    pages = opts.fetch(:pages) do
      [TestPage.new(:trigger => opts.fetch(:trigger, 0), :sprite => opts.fetch(:sprite, ""),
                    :list => opts.fetch(:list, [TestCmd.new(101, ["..."]), TestCmd.new(0, [])]))]
    end
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => opts.fetch(:name, "EV#{id}"), :pages => pages)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # A Wooloo of the pen, named as the game's script renames it.
  def wooloo(id, x, y, name); put(id, x, y, :name => name, :sprite => "POKE_WOOLOO"); end

  # A wall button, acted on from beside it, that turns a colour's switch on.
  def button(id, x, y, switch)
    put(id, x, y, :trigger => 0, :list => [TestCmd.new(121, [switch, switch, 0]), TestCmd.new(0, [])])
  end

  # A water jet: drawn while its colour's switch is off, or while it is on.
  def jet(id, x, y, switch, drawn_off)
    cond = { :switch1_valid => true, :switch1_id => switch }
    always = lambda { |sprite| TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(0, [])]) }
    behind = lambda { |sprite| TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(0, [])], :condition => cond) }
    pages = drawn_off ? [always.call("OBJ_chorrillo"), behind.call("")] : [always.call(""), behind.call("OBJ_chorrillo")]
    put(id, x, y, :name => "Chorrillo.shadowless", :pages => pages)
  end

  # A belt's entrance: a touch event with no sprite.
  def belt(id, x, y)
    put(id, x, y, :trigger => 1, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
  end

  # The name Piston gives a belt turned by those colours.
  def belt_name(*colors)
    names = colors.map { |c| t("royal_g3_color_#{c}".to_sym) }
    t(:royal_g3_belt, :colors => PokeAccess::Routes::Text.and_list(names))
  end

  # A Wooloo column's count, as said.
  def column(n, count); t(:puzzle_value, :label => t(:royal_g1_column, :n => n), :v => count); end

  # Amura's pipes of a colour, as said in the info key and as they change.
  def pipes(color, state); "#{t("royal_g2_pipes_#{color}".to_sym)}: #{t(state == :on ? :royal_g2_on : :royal_g2_off)}"; end

  # Piston's belts of a colour, as said in the info key and as they change.
  def belts(color, state); "#{t("royal_g3_belts_#{color}".to_sym)}: #{t(state == :on ? :royal_g3_on : :royal_g3_off)}"; end

  # Sets several game variables at once, by id.
  def set_vars(map); map.each { |id, v| $game_variables[id] = v }; end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # What the info key says on the map now.
  def info_key; PokeAccess::Info.map_text; end

  # The puzzles category as [x, y, name as the locator says it], sorted.
  def listed
    PokeAccess::Puzzles.category_targets.map do |tg|
      name = tg.is_a?(PokeAccess::Locator::SurfaceTarget) ? tg.name : PokeAccess::Locator.target_name(tg)
      [tg.x, tg.y, name]
    end.sort_by { |x, y, _n| [x, y] }
  end
end
