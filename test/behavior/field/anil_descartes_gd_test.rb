# Anil's second pass over its discards (games/anil/puzzles/): the ice floors of the Seafoam Islands and the Glacial
# Cave, the carrying floors of the Rocket Hideout and Warehouse, and Koga's Ninja Creed quiz in Fuchsia's gym. The
# floors' rules are said on the first arrival alone; the quiz's right answer comes with the assist. Gamedata pass.
class AnilDescartesGdTest < PokeAccessTest
  MAPS = [125, 133, 134, 135, 198, 83, 84, 214]
  ICE = [133, 134, 135, 198]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
  end

  def teardown
    World.clear_events
    $game_switches[192] = false
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Puzzles.instance_variable_set(:@told, {})
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the ice floors say their rule on the first arrival alone, beside the Glacial Cave's altar" do
    ICE.each do |map|
      on_map(map)
      assert_equal [t(:anil_ice_rule)], frame, "map #{map}"
      on_map(map)
      assert_empty frame, "map #{map} again"
    end
    assert_equal [nil, :ice], mechanics.instance_variable_get(:@defs)[198].map { |part, _spec| part }
    [130, 136].each { |map| assert_nil mechanics.instance_variable_get(:@defs)[map], "map #{map} has no ice" }
  end

  test "the Rocket floors that carry the player say so on the first arrival" do
    [83, 84, 214].each do |map|
      on_map(map)
      assert_equal [t(:anil_carry_rule)], frame, "map #{map}"
      on_map(map)
      assert_empty frame, "map #{map} again"
    end
  end

  test "the Ninja Creed's books are named until Koga is beaten, and the quiz's right answers are those that count" do
    on_map(125)
    [[1, 2, 7], [2, 2, 23], [3, 31, 7]].each { |id, x, y| put(id, x, y, "libro") }
    assert_equal [[2, 7, t(:anil_creed_book)], [2, 23, t(:anil_creed_book)], [31, 7, t(:anil_creed_book)]], listed
    right = [TestCmd.new(122, [181, 181, 1, 0, 1], 1)]
    assert_equal "Su discreción", option(39, ["Su elegancia", "Su discreción", "Su sabiduría"], [[], right, []])
    assert_equal "Otro ninja", option(39, ["Otro ninja", "El orgullo propio", "Su señor"], [right, [], []])
    $game_switches[192] = true
    PokeAccess::Caches.reset_all
    assert_empty listed
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # Declares the profile's puzzles on their maps, loading its files once per process.
  def declare_puzzles
    self.class.declared ||= begin
      Harness.load_puzzles("anil")
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
    $game_map.map_id = map
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # An event with one action page of the sprite, saying a line.
  def put(id, x, y, sprite)
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    World.next_frame
  end

  # The option right_choice picks of a menu on an event, its page made of the options and each one's commands.
  def option(id, options, branches)
    list = [TestCmd.new(102, [options, 1], 0)]
    branches.each_with_index do |cmds, i|
      list.push(TestCmd.new(402, [i, options[i]], 0))
      list.concat(cmds)
      list.push(TestCmd.new(0, [], 1))
    end
    list.push(TestCmd.new(404, [], 0))
    page = TestPage.new(:trigger => 1, :sprite => "", :list => list)
    $game_map.events[id] = TestGameEvent.new(:id => id, :x => 16, :y => 17, :pages => [page], :active_page => page)
    World.next_frame
    int = $game_system.map_interpreter
    int.instance_variable_set(:@event_id, id)
    PokeAccess::Puzzles::Answers.right_option(int, list, 0)
  end

  # What the puzzles say on the next map frame.
  def frame
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name], in reading order of the tiles.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
