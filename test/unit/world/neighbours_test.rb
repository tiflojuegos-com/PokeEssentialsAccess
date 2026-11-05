# World::Neighbours: a question about a step off the map answered with one kept copy of the map across, lent to the
# factory, its pages taken afresh once a frame; a neighbour the game has loaded answers for itself, and nothing is kept
# with the option off or left behind in the factory; the maps built ahead go one at a time, with the player still.
class NeighboursTest < PokeAccessTest
  Neighbours = PokeAccess::World::Neighbours
  Probe = PokeAccess::World::Probe
  Epoch = PokeAccess::World::Epoch
  # The neighbour across this map's south edge.
  SOUTH = 3
  # The neighbour across its north edge.
  NORTH = 4

  # An event of a copy, counting its refreshes.
  class CopyEvent
    attr_reader :refreshed

    def initialize; @refreshed = 0; end
    def refresh; @refreshed += 1; end
  end

  # A map as the factory builds it: open except where a test closes it, one event to refresh.
  class FarMap
    attr_reader :map_id, :events
    attr_accessor :closed

    def initialize(id)
      @map_id = id
      @events = { 1 => CopyEvent.new }
      @closed = false
    end
  end

  # The engine's switches or variables, kept in an array.
  class FlagStore
    def initialize; @data = []; end
    def [](id); @data[id]; end
    def []=(id, value); @data[id] = value; end
  end

  # The engine's factory: each lookup of a step off the map builds a fresh map when the one asked for is not among its
  # maps, as in the newer engines.
  class Factory
    attr_reader :built, :during

    def initialize(live = [])
      @maps = live
      @built = []
    end

    def getMapNoAdd(id)
      @maps.each { |m| return m if m.map_id == id }
      @built.push([id, $scene])
      yield_failure(id)
      FarMap.new(id)
    end

    def fail_with(error); @error = error; end

    def yield_failure(_id)
      raise @error if @error
    end

    # The engine's answer for a step onto (x, y) of the map across, noting the maps it held meanwhile.
    def step_off(id)
      @during = @maps.map { |m| m.map_id }
      2.times { getMapNoAdd(id) }
      !getMapNoAdd(id).closed
    end
  end

  test "builds one copy per neighbour however many steps off the map are asked" do
    with_factory do |factory|
      3.times do |x|
        Probe.step?(x + 1, 3, 2)
        Probe.step?(x + 1, 0, 8)
      end
      assert_equal [SOUTH, NORTH], factory.built.map { |id, _s| id }
      assert_equal [SOUTH, NORTH], Neighbours.maps
    end
  end

  test "the copy answers from the factory's maps and leaves none behind" do
    with_factory do |factory|
      assert Probe.step?(1, 3, 2)
      assert_includes factory.during, SOUTH
      assert_equal [], factory_maps(factory).map { |m| m.map_id }
    end
  end

  test "a neighbour the game has loaded answers for itself, with no copy" do
    live = FarMap.new(SOUTH)
    live.closed = true
    with_factory([live]) do |factory|
      refute Probe.step?(1, 3, 2)
      assert_equal [], factory.built
      assert_equal [], Neighbours.maps
    end
  end

  test "an older engine finds the copy too, and adds nothing to its maps" do
    with_factory do |factory|
      factory.define_singleton_method(:getMap) do |id|
        @maps.each { |m| return m if m.map_id == id }
        @maps.push(getMapNoAdd(id))
        @maps.last
      end
      seen = Neighbours.lending(1, 4) { factory.getMap(SOUTH).map_id }
      assert_equal SOUTH, seen
      assert_equal [SOUTH], factory.built.map { |id, _s| id }
      assert_equal [], factory_maps(factory)
    end
  end

  test "an error in the question takes the copy back all the same" do
    with_factory do |factory|
      assert_raises(ArgumentError) { Neighbours.lending(1, 4) { raise ArgumentError } }
      assert_equal [], factory_maps(factory)
    end
  end

  test "a step off an edge with no connection builds nothing" do
    with_factory do |factory|
      Probe.step?(0, 1, 4)
      assert_equal [], factory.built
    end
  end

  test "a copy takes its pages afresh once a frame, not on the frame it is built" do
    with_factory do |_factory|
      Probe.step?(1, 3, 2)
      event = copy(SOUTH).events[1]
      Probe.step?(2, 3, 2)
      assert_equal 0, event.refreshed
      Epoch.dirty!
      Probe.step?(1, 3, 2)
      Probe.step?(2, 3, 2)
      assert_equal 1, event.refreshed
    end
  end

  test "a copy answers as its map stands, each question asked of the engine" do
    with_factory do |_factory|
      assert Probe.step?(1, 3, 2)
      copy(SOUTH).closed = true
      refute Probe.step?(1, 3, 2)
    end
  end

  test "builds and refreshes with no scene, and puts the scene back" do
    was = $scene
    $scene = :the_map
    with_factory do |factory|
      Probe.step?(1, 3, 2)
      Epoch.dirty!
      scene_at_refresh = nil
      copy(SOUTH).events[1].define_singleton_method(:refresh) { scene_at_refresh = $scene }
      Probe.step?(1, 3, 2)
      assert_equal [[SOUTH, nil]], factory.built
      assert_nil scene_at_refresh
      assert_equal :the_map, $scene
    end
  ensure
    $scene = was
  end

  test "what a map's setup or a page's refresh sets in the game's flags is put back" do
    switches = FlagStore.new
    variables = FlagStore.new
    had = [$game_switches, $game_variables]
    $game_switches = switches
    $game_variables = variables
    switches[5] = true
    variables[6] = 40
    with_factory do |factory|
      real = factory.method(:getMapNoAdd)
      factory.define_singleton_method(:getMapNoAdd) do |id|
        unless @maps.any? { |m| m.map_id == id }
          switches[5] = false
          variables[6] = 1
        end
        real.call(id)
      end
      Probe.step?(1, 3, 2)
      assert_equal [true, 40], [switches[5], variables[6]]
      Epoch.dirty!
      copy(SOUTH).events[1].define_singleton_method(:refresh) { switches[5] = false }
      Probe.step?(1, 3, 2)
      assert_equal true, switches[5]
    end
  ensure
    $game_switches, $game_variables = had
  end

  test "with the option off the engine builds as ever and nothing is kept" do
    PokeAccess::Config.neighbour_cache = false
    with_factory do |factory|
      2.times { Probe.step?(1, 3, 2) }
      assert_equal [SOUTH] * 6, factory.built.map { |id, _s| id }
      assert_equal [], Neighbours.maps
    end
  end

  test "a copy that cannot be built leaves the question to the engine" do
    with_factory do |factory|
      factory.fail_with(RuntimeError.new("no such map"))
      assert_equal PokeAccess::World::Probe::ERROR, Probe.answer(1, 3, 2)
      assert_equal [], Neighbours.maps
    end
  end

  test "a refresh that fails drops the copy" do
    with_factory do |_factory|
      Probe.step?(1, 3, 2)
      Epoch.dirty!
      copy(SOUTH).events[1].define_singleton_method(:refresh) { raise "broken page" }
      Probe.step?(1, 3, 2)
      assert_equal [], Neighbours.maps
    end
  end

  test "keeps as many maps as the setting says, the one used last among the newest" do
    with_factory do |_factory|
      ids = (10...(10 + PokeAccess::Config.neighbour_cache_size)).to_a
      ids.each { |id| Neighbours.copy_of(id) }
      Neighbours.copy_of(10)
      Neighbours.copy_of(99)
      assert_equal ids[2..-1] + [10, 99], Neighbours.maps
    end
  end

  test "keeps fewer or more maps with the setting changed, 16 unless it is" do
    assert_equal 16, PokeAccess::Config.setting(:neighbour_cache_size).default
    assert_equal [8, 64, 8], PokeAccess::Config::KIND_BOUNDS[PokeAccess::Config.setting(:neighbour_cache_size).kind][0, 3]
    with_factory do |_factory|
      PokeAccess::Config.neighbour_cache_size = 8
      ids = (10..18).to_a
      ids.each { |id| Neighbours.copy_of(id) }
      assert_equal ids[1..-1], Neighbours.maps
      PokeAccess::Config.neighbour_cache_size = 16
      more = (20..27).to_a
      more.each { |id| Neighbours.copy_of(id) }
      assert_equal ids[1..-1] + more, Neighbours.maps
    end
  end

  test "the size option shows only with the cache on" do
    row = PokeAccess::Config.setting(:neighbour_cache_size)
    assert PokeAccess::Config.visible?(row)
    PokeAccess::Config.neighbour_cache = false
    refute PokeAccess::Config.visible?(row)
  end

  test "survives the map being left: the copies go only by age" do
    with_factory do |_factory|
      Probe.step?(1, 3, 2)
      PokeAccess::World.reset!
      assert_equal [SOUTH], Neighbours.maps
    end
  end

  test "builds ahead only with the option on and the player still, one every gap" do
    with_factory do |factory|
      Neighbours.warm
      assert_equal [], factory.built
      PokeAccess::Config.neighbours_background = true
      moving(true) { Neighbours.warm }
      assert_equal [], factory.built
      moving(false) do
        Neighbours.warm
        assert_equal [SOUTH], factory.built.map { |id, _s| id }
        map_frames(Neighbours::WARM_GAP - 1)
        Neighbours.warm
        assert_equal [SOUTH], factory.built.map { |id, _s| id }
        map_frames(1)
        Neighbours.warm
        assert_equal [SOUTH, NORTH], factory.built.map { |id, _s| id }
        map_frames(Neighbours::WARM_GAP * 2)
        Neighbours.warm
        assert_equal 2, factory.built.length
      end
    end
  end

  test "a neighbour that cannot be built is tried once on this map, and again on coming back" do
    PokeAccess::Config.neighbours_background = true
    with_factory do |factory|
      factory.fail_with(RuntimeError.new("no such map"))
      moving(false) do
        Neighbours.warm
        3.times do
          map_frames(Neighbours::WARM_GAP)
          Neighbours.warm
        end
        assert_equal [SOUTH, NORTH], factory.built.map { |id, _s| id }
        Neighbours.instance_variable_set(:@tried, [$game_map.map_id + 1, SOUTH, NORTH])
        map_frames(Neighbours::WARM_GAP)
        Neighbours.warm
        assert_equal [SOUTH, NORTH, SOUTH], factory.built.map { |id, _s| id }
      end
    end
  end

  test "the map asked for is the one the game has loaded, else a copy" do
    live = FarMap.new(SOUTH)
    with_factory([live]) do |factory|
      assert_same live, Neighbours.map(SOUTH)
      assert_equal NORTH, Neighbours.map(NORTH).map_id
      assert_same Neighbours.map(NORTH), Neighbours.map(NORTH)
      assert_equal [NORTH], factory.built.map { |id, _s| id }
    end
  end

  test "with no factory there is no map" do
    with_factory do |_factory|
      $map_factory = nil
      assert_nil Neighbours.map(SOUTH)
    end
  end

  test "builds nothing ahead that the game has loaded" do
    PokeAccess::Config.neighbours_background = true
    with_factory([FarMap.new(SOUTH)]) do |factory|
      moving(false) { Neighbours.warm }
      assert_equal [NORTH], factory.built.map { |id, _s| id }
    end
  end

  test "a factory that cannot build a map apart keeps the question" do
    with_factory do |_factory|
      $map_factory = Object.new
      assert_equal :asked, Neighbours.lending(1, 4) { :asked }
      assert_equal [], Neighbours.maps
    end
  end

  test "a map the factory cannot build keeps nothing and leaves the question to the engine" do
    with_factory do |factory|
      factory.define_singleton_method(:getMapNoAdd) { |_id| nil }
      assert_equal :asked, Neighbours.lending(1, 4) { :asked }
      assert_equal [], Neighbours.maps
    end
  end

  test "builds nothing ahead with the cache off" do
    PokeAccess::Config.neighbours_background = true
    PokeAccess::Config.neighbour_cache = false
    with_factory do |factory|
      moving(false) { Neighbours.warm }
      assert_equal [], factory.built
    end
  end

  test "a map built ahead is the copy the first question takes" do
    PokeAccess::Config.neighbours_background = true
    with_factory do |factory|
      moving(false) { Neighbours.warm }
      Probe.step?(1, 3, 2)
      assert_equal [SOUTH], factory.built.map { |id, _s| id }
    end
  end

  test "finds the factory under the name each era gives it" do
    had = [$map_factory, $MapFactory]
    $map_factory = nil
    $MapFactory = :older
    assert_equal :older, PokeAccess::World::Engine.map_factory
    $map_factory = :newer
    assert_equal :newer, PokeAccess::World::Engine.map_factory
    $map_factory = $MapFactory = nil
    assert_nil PokeAccess::World::Engine.map_factory
  ensure
    $map_factory, $MapFactory = had
  end

  test "the connections the data provider keeps answer over the engine's helper" do
    with_factory do
      h = $game_map.height
      keeper = Object.new
      keeper.define_singleton_method(:map_connections) { [[$game_map.map_id, 0, 0, SOUTH, 0, 0]] }
      assert_equal [SOUTH, 2, 0], PokeAccess::World::Engine.across(2, h)
      Harness.with_provider(keeper) { assert_equal [SOUTH, 2, h], PokeAccess::World::Engine.across(2, h) }
    end
  end

  test "a step the engine runs out of stack on is closed, and the map's other neighbour still answers" do
    with_factory do |factory|
      factory.fail_with(SystemStackError.new("stack level too deep"))
      assert_equal Probe::CLOSED, Probe.answer(1, 3, 2)
      factory.fail_with(nil)
      assert Probe.step?(1, 0, 8)
      assert Probe.step?(1, 3, 2), "tried again"
    end
  end

  test "with the cache off, a step the engine runs out of stack on is closed" do
    PokeAccess::Config.neighbour_cache = false
    with_factory do |factory|
      factory.fail_with(SystemStackError.new("stack level too deep"))
      assert_equal Probe::CLOSED, Probe.answer(1, 3, 2)
    end
  end

  test "a map that runs the engine out of stack is no map to read, and building it ahead keeps nothing" do
    with_factory do |factory|
      factory.fail_with(SystemStackError.new("stack level too deep"))
      assert_nil Neighbours.map(SOUTH)
      assert_equal 1, factory.built.length
      PokeAccess::Config.neighbours_background = true
      moving(false) { assert_nil Neighbours.warm }
      assert_equal 2, factory.built.length
      assert_equal [], Neighbours.maps
    end
  end

  test "with the cache off a map to read is built and not kept" do
    PokeAccess::Config.neighbour_cache = false
    with_factory do |factory|
      assert_equal SOUTH, Neighbours.map(SOUTH).map_id
      assert_equal [], Neighbours.maps
      assert_equal [SOUTH], factory.built.map { |id, _s| id }
    end
  end

  test "with no factory to lend to, a question that runs the engine out of stack still answers closed" do
    with_factory do
      $map_factory = nil
      assert_equal Probe::CLOSED, Neighbours.lending(1, 4) { raise SystemStackError, "stack level too deep" }
    end
  end

  test "a landing off the map is asked with the copy lent, and closed when the engine cannot build it" do
    with_factory do |factory|
      3.times { assert Probe.lands?(1, 3, 2, 1, 4) }
      assert_equal [SOUTH], factory.built.map { |id, _s| id }
      assert_equal [], factory_maps(factory)
      factory.fail_with(SystemStackError.new("stack level too deep"))
      assert_equal false, Probe.lands?(1, 0, 8, 1, -1)
      assert_equal 2, factory.built.length
    end
  end

  test "a step off the map partway up a side stair, whose answers are not kept, is asked with the copy lent as well" do
    with_factory do |factory|
      $game_player.define_singleton_method(:on_middle_of_stair?) { true }
      Probe.instance_variable_set(:@memo, nil)
      3.times { assert Probe.step?(1, 3, 2) }
      assert_equal [SOUTH], factory.built.map { |id, _s| id }
    end
  ensure
    $game_player.singleton_class.send(:remove_method, :on_middle_of_stair?) rescue nil
  end

  test "the background option shows only with the cache on" do
    row = PokeAccess::Config.setting(:neighbours_background)
    assert PokeAccess::Config.visible?(row)
    PokeAccess::Config.neighbour_cache = false
    refute PokeAccess::Config.visible?(row)
  end

  test "the cache comes on and building ahead off" do
    assert_equal [true, false], [PokeAccess::Config.setting(:neighbour_cache).default,
                                 PokeAccess::Config.setting(:neighbours_background).default]
  end

  private

  # A map connected south and north, the engine's factory on the global its era names, and the player's passable? going
  # to it for a step off the map. The block gets the factory.
  def with_factory(live = [])
    hpa_fresh_grid(["#####", "#...#", "#.@.#", "#...#"])
    here = $game_map.map_id
    h = $game_map.height
    w = $game_map.width
    helper = Module.new
    helper.define_singleton_method(:getMapConnections) do
      [[77, 0, 0, 78, 0, 0], [here, 0, h, SOUTH, 0, 0], [NORTH, 0, 10, here, 0, 0]]
    end
    helper.define_singleton_method(:getMapDims) { |id| [SOUTH, NORTH].include?(id) ? [w, 10] : [0, 0] }
    Object.const_set(:MapFactoryHelper, helper)
    had = $map_factory
    $map_factory = factory = Factory.new(live)
    plain = Game_Player.instance_method(:passable?)
    $game_player.define_singleton_method(:passable?) do |x, y, d|
      dy = d == 2 ? 1 : (d == 8 ? -1 : 0)
      dx = d == 6 ? 1 : (d == 4 ? -1 : 0)
      ny = y + dy
      next plain.bind(self).call(x, y, d) if ny >= 0 && ny < h && x + dx >= 0 && x + dx < w
      id = ny >= h ? SOUTH : (ny < 0 ? NORTH : nil)
      id ? factory.step_off(id) : false
    end
    yield factory
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?) rescue nil
    Object.send(:remove_const, :MapFactoryHelper) if Object.const_defined?(:MapFactoryHelper)
    $map_factory = had
    $game_map.clear_grid
  end

  # The copy kept of a map.
  def copy(id); Neighbours.instance_variable_get(:@kept).find { |c| c.id == id }.map; end

  # The maps a factory holds.
  def factory_maps(factory); factory.instance_variable_get(:@maps); end

  # Lets n map frames go by.
  def map_frames(n)
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + n)
  end

  # Runs the block with the player moving or still.
  def moving(state)
    $game_player.define_singleton_method(:moving?) { state }
    Neighbours.instance_variable_set(:@warm_at, 0)
    Neighbours.instance_variable_set(:@tried, [])
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :moving?) rescue nil
  end
end
