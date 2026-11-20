# Pokemon Revival's puzzles on the shipped profile: the obstacles each character clears, Castillo Avalon's torches and
# disguises, Base Ranger 01's type tests, Tunia's hacking levels, the Palacio del Gran Sol's fountains and the Black
# Rose Tower's dungeon lever, each as heard with the puzzle assist and without it.

revival_obstacles_path = File.join(Harness::ROOT, "games", "revival", "character_obstacles.rb")
eval(Harness.source(revival_obstacles_path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING,
     revival_obstacles_path)

class RevivalPuzzlesGdTest < PokeAccessTest
  # The game's character constants the obstacles read, as the profile's constants set them.
  CHARACTERS = { :CHARACTER_NAMES => %w[Cira Vezo Milenka Rufio Tunia Gawain],
                 :CHARACTER_SWITCHES => [104, 109, 106, 108, 105, 107] }

  def setup
    super
    @consts = {}
    CHARACTERS.each do |c, value|
      @consts[c] = Object.send(:remove_const, c) if Object.const_defined?(c)
      Object.const_set(c, value)
    end
    @self_switches = $game_self_switches
    $game_self_switches = {}
  end

  def teardown
    CHARACTERS.each_key do |c|
      Object.send(:remove_const, c) if Object.const_defined?(c)
      Object.const_set(c, @consts[c]) if @consts.key?(c)
    end
    $game_self_switches = @self_switches
    super
  end

  test "names a character's obstacle by what it is and who clears it, until it is cleared" do
    $game_map.map_id = 54
    pages = obstacle_pages(106, "Object rock")
    rock = TestGameEvent.new(:id => 4, :x => 14, :y => 17, :pages => pages, :active_page => pages[0])
    assert_equal t(:rv_obstacle_rock, :who => "Milenka"), PokeAccess::RevivalObstacles.name_uncached(rock)
    cleared = TestGameEvent.new(:id => 4, :x => 14, :y => 17, :pages => pages, :active_page => pages[2])
    assert_nil PokeAccess::RevivalObstacles.name_uncached(cleared)
    person = TestGameEvent.new(:id => 5, :pages => [TestPage.new(:sprite => "npc")])
    assert_nil PokeAccess::RevivalObstacles.name_uncached(person)
  end

  test "lists Avalon's lit torches and counts those put out as each goes out" do
    on_map(203)
    { 24 => [68, 14], 55 => [30, 16], 23 => [10, 47] }.each { |id, (x, y)| place(id, x, y, "antorcha") }
    tick
    assert_equal [t(:rv_avalon_torch_lit)] * 3, names
    $game_switches[277] = true
    assert_equal [[t(:puzzle_progress, :label => t(:rv_avalon_torches_out), :n => 1, :of => 3), false]], tick
    assert_equal [t(:rv_avalon_torch_lit)] * 2, names
  end

  test "says the disguise Avalon's pedestals put on and when a strip takes it off" do
    on_map(203)
    tick
    $game_switches[247] = true
    assert_equal [[t(:rv_disguise, :pokemon => species(:ZUBAT)), false]], tick
    $game_switches[247] = false
    $game_switches[249] = true
    assert_equal [[t(:rv_disguise, :pokemon => species(:GASTLY)), false]], tick
    $game_switches[249] = false
    assert_equal [[t(:rv_disguise_none), false]], tick
  end

  test "names Base Ranger's icon and tiles by type, and with the assist lists only the right tile and its answer" do
    on_map(47)
    place(2, 14, 14, "botontipo1")
    place(11, 11, 15, "")
    place(10, 11, 19, "")
    tick
    icon = t(:rv_ranger_icon, :type => type(:NORMAL))
    right = t(:rv_ranger_tile, :type => type(:FIGHTING))
    assert_equal [icon, right, t(:rv_ranger_tile, :type => type(:DRAGON))], names
    PokeAccess::Config.puzzle_assist = true
    assert_equal [icon, right], names
    assert_includes info_key, t(:rv_ranger_answer, :type => type(:NORMAL), :right => type(:FIGHTING))
    $game_switches[155] = true
    assert_equal [], names
  end

  test "lists the breach of a hacking level and tells its rule on the first arrival only" do
    on_map(158)
    place(1, 14, 8, "")
    assert_equal [t(:rv_hack_breach)], names
    spec = PokeAccess::World::Mechanics.instance.spec
    assert_equal :rv_hack_rule, spec[:arrival_hint]
    assert spec[:arrival_once]
  end

  test "counts the hacked terminals of the Viejo Roble with the assist alone" do
    on_map(140)
    $game_variables[114] = 2
    refute_includes info_key.to_s, t(:rv_hack_terminals)
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, t(:puzzle_progress, :label => t(:rv_hack_terminals), :n => 2, :of => 5)
  end

  test "lists the palace's fountains until the player has looked into each" do
    on_map(134)
    { 35 => [29, 34], 36 => [17, 14], 37 => [41, 14] }.each { |id, (x, y)| place(id, x, y, "") }
    assert_equal [t(:rv_palace_fountain)] * 3, names
    $game_self_switches[[134, 36, "A"]] = true
    assert_equal [t(:rv_palace_fountain)] * 2, names
  end

  test "names the dungeon's lever and lists its poster until it is off the wall" do
    on_map(242)
    { 17 => [21, 6], 18 => [22, 6], 19 => [22, 5], 20 => [21, 5], 21 => [22, 7], 22 => [21, 7] }.each do |id, (x, y)|
      place(id, x, y, "")
    end
    assert_equal [t(:rv_dungeon_lever), t(:rv_dungeon_poster)].sort, names.sort
    $game_switches[295] = true
    assert_equal [t(:rv_dungeon_lever)], names
  end

  private

  # The spoken text of an i18n key.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A species' and a type's name as the data provider gives them.
  def species(id); PokeAccess::Data.species_name(id); end
  def type(id); PokeAccess::Data.type_name(id); end

  # An obstacle's three pages: what it says to anyone, the choice for the character of switch sw, cleared.
  def obstacle_pages(sw, sprite)
    [TestPage.new(:sprite => sprite, :list => [TestCmd.new(101, ["..."])]),
     TestPage.new(:sprite => sprite, :condition => { :switch1_valid => true, :switch1_id => sw },
                  :list => [TestCmd.new(102, [["Sí", "No"], 2])]),
     TestPage.new(:sprite => sprite, :through => true, :condition => { :self_switch_valid => true, :self_switch_ch => "A" })]
  end

  # Declares the shipped puzzles and puts the player on map with every flag off.
  def on_map(map)
    Harness.load_puzzles("revival")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    [114, 117, 123, 124].each { |v| $game_variables[v] = 0 }
    (154..158).to_a.concat((247..249).to_a).concat((277..282).to_a).push(295).each { |s| $game_switches[s] = false }
    World.next_frame
  end

  # An action event at (x, y) drawn with sprite, placed on the map.
  def place(id, x, y, sprite)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(122, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    World.next_frame
  end

  # The names the puzzles category lists now.
  def names
    PokeAccess::Puzzles.category_targets.map(&:name)
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
