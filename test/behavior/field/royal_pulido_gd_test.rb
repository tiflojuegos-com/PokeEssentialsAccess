# Royal's optional and side puzzles (games/royal/puzzles/): Hoyuelo's megaliths and the Chromatic Mine's carts, on the
# shipped profile over events shaped like the game's. What a sighted player sees is said without the puzzle assist; the
# order and the next step towards the exit come with it. Gamedata pass.
class RoyalPulidoGdTest < PokeAccessTest
  MAPS = [116, 104]

  class << self
    attr_accessor :declared
  end

  def setup
    super
    @defs = mechanics.instance_variable_get(:@defs).dup
    @map = $game_map.map_id
    @selfs = $game_self_switches
    @player = [$game_player.x, $game_player.y]
  end

  def teardown
    World.clear_events
    $game_variables[76] = 0
    PokeAccess::Puzzles::Auto.instance_variable_set(:@last_used, nil)
    [92, 93, 94].each { |i| $game_switches[i] = false }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @player
    mechanics.instance_variable_set(:@defs, @defs)
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    mechanics.forget
    PokeAccess::Caches.reset_all
    super
  end

  test "the megaliths are named as such, and with the assist the three of the order say their place" do
    on_map(116)
    { 72 => [6, 27], 73 => [15, 10], 74 => [24, 44], 75 => [55, 12], 76 => [69, 29] }.each { |id, (x, y)| put(id, x, y) }
    frame
    assert_equal [[6, 27, stone], [15, 10, stone], [24, 44, stone], [55, 12, stone], [69, 29, stone]], listed
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[6, 27, stone], [15, 10, stone(1)], [24, 44, stone(2)], [55, 12, stone], [69, 29, stone(3)]], listed
    $game_self_switches[[116, 76, "A"]] = true
    refute PokeAccess::Puzzles.active?
  end

  test "the mine says each rail switch as it turns, and with the assist marks the next cart or lever towards the exit" do
    on_map(104)
    put(7, 33, 53)
    put(9, 24, 42)
    place_lever(5, 17, 33, 92)
    place_lever(4, 53, 43, 93)
    turntable(2, 43, 36, 93)
    stand(39, 58)
    frame
    assert_equal [[17, 33, lever(1)], [24, 42, cart], [33, 53, cart], [53, 43, lever(2)]], listed
    assert_equal ["#{t(:royal_mine_switch2)}: #{t(:royal_mine_turned)}"], frames(8) { fire(@events[4]); $game_switches[93] = true }
    $game_switches[93] = false
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[17, 33, lever(1)], [24, 42, cart], [33, 53, t(:royal_mine_cart_next)], [53, 43, lever(2)]], listed
    stand(44, 43)
    assert_equal [[17, 33, lever(1)], [24, 42, cart], [33, 53, cart], [53, 43, lever(2, :next)]], listed
    stand(20, 42)
    assert_equal [[17, 33, lever(1)], [24, 42, t(:royal_mine_cart_next)], [33, 53, cart], [53, 43, lever(2)]], listed
  end

  private

  # The spoken text of an i18n key.
  def t(*args); PokeAccess::I18n.t(*args); end

  # The mechanics registry.
  def mechanics; PokeAccess::World::Mechanics; end

  # A megalith's name, with its place in the order when given.
  def stone(n = nil); n ? t(:royal_megalith_order, :n => n) : t(:royal_megalith); end

  # A mine cart's name.
  def cart; t(:royal_mine_cart); end

  # A lever's name by its rail switch, marked as the next step when asked.
  def lever(n, mark = nil); t(mark ? :royal_mine_lever_next : :royal_mine_lever, :n => n); end

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
    @events = {}
    PokeAccess::Caches.reset_all
    mechanics.forget
  end

  # Moves the player onto a tile.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # A lever as the mine's: no text, it turns a rail switch on.
  def place_lever(id, x, y, switch)
    page = TestPage.new(:trigger => 0, :sprite => "OBJ_Pokeball", :list => [TestCmd.new(121, [switch, switch, 0]), TestCmd.new(0, [])])
    add(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page]))
  end

  # A rail switch drawn on the floor, walked over, with a second page while its switch is on.
  def turntable(id, x, y, switch)
    pages = [TestPage.new(:sprite => "OBJ_AscensorPiston", :through => true),
             TestPage.new(:sprite => "OBJ_AscensorPiston", :through => true, :condition => { :switch1_valid => true, :switch1_id => switch })]
    add(TestGameEvent.new(:id => id, :x => x, :y => y, :pages => pages))
  end

  # Places an event on the map.
  def add(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    @events[ev.id] = ev
  end

  # What the player's use of an event does, as the interpreter's setup tells it.
  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
  end

  # What the next n map frames say, after the block, the events synced on each.
  def frames(n)
    SpeakCapture.clear
    yield if block_given?
    n.times do
      PokeAccess::World::Epoch.tick if PokeAccess::World::Epoch.respond_to?(:tick)
      PokeAccess::World::Events.sync(true)
      PokeAccess::Puzzles.tick
    end
    SpeakCapture.lines
  end

  # An event on the map with one action page of the sprite of opts and a text.
  def put(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => opts.fetch(:sprite, ""), :list => [TestCmd.new(101, ["..."]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    @events[id] = ev
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  # The puzzles category as [x, y, name], in reading order of the tiles.
  def listed
    PokeAccess::Puzzles.category_targets.map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |x, y, _n| [x, y] }
  end
end
