# The game asked about a step with only the events around it on show (Probe.ask_near, Events.near_step): the two ways every
# game goes over its events see those within a tile of the step, any other read sees them all, the answer is the same, and
# the map has its own list back whatever happens.
class NearEventsTest < PokeAccessTest
  include TileWorldHelpers

  Probe = PokeAccess::World::Probe
  Events = PokeAccess::World::Events
  RIGHT = 6
  ROOM = ["##########", "#@.......#", "#........#", "#........#", "##########"].freeze

  # A player whose passable? notes what the game sees of its events while asked, and fails when told to.
  class WatchingPlayer < TileWorldPlayer
    attr_reader :seen
    attr_writer :failing

    def passable?(x, y, d)
      list = $game_map.events
      each = []
      list.each_value { |e| each.push(e.id) }
      @seen = { :values => list.values.map { |e| e.id }.sort, :each_value => each.sort, :keys => list.keys.sort,
                :order => list.values.map { |e| e.id }, :each_gives => list.each_value { |_e| nil }.equal?(list),
                :by_id => list[44] && list[44].id, :length => list.length, :plain => list.instance_of?(Hash) }
      raise "the game failed" if @failing
      super
    end
  end

  test "shows the game the events within a tile of the step, by both ways it goes over them" do
    on_room do |pl|
      put(30, 4, 1)
      put(31, 5, 2)
      put(32, 2, 2)
      put(33, 3, 0)
      put(44, 8, 3)
      put(45, 6, 1)
      put(46, 4, 3)
      ask(3, 1, RIGHT)
      assert_equal [30, 31, 32, 33], pl.seen[:values], "on the step or within a tile of it; not two tiles off"
      assert_equal pl.seen[:values], pl.seen[:each_value]
      assert pl.seen[:each_gives], "each_value gives the Hash back, as a Hash's does"
    end
  end

  test "keeps them in the map's own order, a wide event only once" do
    on_room do |pl|
      put(31, 5, 1)
      put(30, 4, 1)
      put(33, 4, 2, "size(2,1)")
      put(32, 2, 1)
      ask(3, 1, RIGHT)
      assert_equal [31, 30, 33, 32], pl.seen[:order]
    end
  end

  test "leaves any other read all the events" do
    on_room do |pl|
      put(30, 4, 1)
      put(44, 8, 3)
      ask(3, 1, RIGHT)
      assert_equal [[30, 44], 44, 2], [pl.seen[:keys], pl.seen[:by_id], pl.seen[:length]]
    end
  end

  test "answers as with them all" do
    on_room do |_pl|
      put(30, 4, 1).blocking = true
      put(44, 8, 3).blocking = true
      near = [ask(3, 1, RIGHT), ask(2, 1, RIGHT), ask(7, 3, RIGHT)]
      PokeAccess::Config.near_events = false
      assert_equal [ask(3, 1, RIGHT), ask(2, 1, RIGHT), ask(7, 3, RIGHT)], near
      assert_equal [Probe::CLOSED, Probe::OPEN, Probe::CLOSED], near
    end
  end

  test "sees a wide event from any tile it covers, and from a tile beside it, as a sizeC event stops" do
    on_room do |pl|
      put(30, 5, 2, "sizeC(3,1)")
      ask(6, 2, RIGHT)
      assert_equal [30], pl.seen[:values], "on it"
      ask(3, 2, RIGHT)
      assert_equal [30], pl.seen[:values], "stepping onto the tile a sizeC event blocks, left of the ones it covers"
      ask(2, 2, RIGHT)
      assert_equal [], pl.seen[:values], "further off"
    end
  end

  test "puts the map's own list back, also when the game fails" do
    on_room do |pl|
      list = $game_map.events
      put(30, 4, 1)
      ask(3, 1, RIGHT)
      assert_same list, $game_map.events
      pl.failing = true
      assert_equal Probe::ERROR, ask(3, 1, RIGHT)
      assert_same list, $game_map.events
    end
  end

  test "shows them all with near_events off, for a question with no direction and for a step off the map" do
    on_room do |pl|
      put(44, 8, 3)
      PokeAccess::Config.near_events = false
      ask(3, 1, RIGHT)
      assert_equal [[44], true], [pl.seen[:values], pl.seen[:plain]], "off"
      PokeAccess::Config.near_events = true
      ask(3, 1, 0)
      assert_equal [[44], true], [pl.seen[:values], pl.seen[:plain]], "no direction"
      Probe.all_events { ask(3, 1, RIGHT) }
      assert_equal [[44], true], [pl.seen[:values], pl.seen[:plain]], "off the map"
      ask(3, 1, RIGHT)
      assert_equal [[], false], [pl.seen[:values], pl.seen[:plain]], "and back to the near ones"
    end
  end

  test "shows them all for a step off the map, through the probe's own way of asking" do
    on_room do |pl|
      put(44, 8, 3)
      Probe.answer(0, 1, 4)
      assert_equal [[44], true], [pl.seen[:values], pl.seen[:plain]]
    end
  end

  test "shows them all partway up a stair, where the game answers from the stair and not from the step" do
    on_room do |pl|
      put(44, 8, 3)
      def pl.on_stair?; true; end
      Probe.refresh
      Probe.answer(3, 1, RIGHT)
      assert_equal [[44], true], [pl.seen[:values], pl.seen[:plain]]
      class << pl; remove_method :on_stair?; end
      Probe.refresh
      Probe.answer(4, 1, RIGHT)
      assert_equal [[], false], [pl.seen[:values], pl.seen[:plain]], "and the near ones once off it"
    end
  end

  test "shows them all on a map where the game has an event reaching past the tile of margin" do
    on_room do |pl|
      put(30, 4, 1)
      ask(1, 3, RIGHT)
      assert_equal false, pl.seen[:plain], "none does yet"
      hitbox = put(44, 8, 3)
      def hitbox.at_coordinate?(x, y); x.between?(@x - 2, @x + 2) && y.between?(@y - 2, @y + 2); end
      hitbox.x = 7
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal [[30, 44], true], [pl.seen[:values], pl.seen[:plain]]
    end
  end

  test "tells an event on a tile two away from those it covers, on any side, from one within a tile of them" do
    on_room do |_pl|
      ev = put(44, 5, 2, "size(2,2)")
      r = Events.records.find { |e| e.id == 44 }
      [[3, 2], [8, 2], [5, 4], [5, -1], [3, -1], [8, 4], [3, 4], [8, -1]].each do |spot|
        only_on(ev, spot)
        assert Events.reaches_past?(r), "on #{spot.inspect}"
      end
      [[4, 2], [7, 2], [5, 3], [5, 0], [4, 0], [7, 3], [9, 2]].each do |spot|
        only_on(ev, spot)
        refute Events.reaches_past?(r), "on #{spot.inspect}"
      end
    end
  end

  test "takes in an event's reach when its page turns, as a hitbox comes with its page" do
    on_room do |pl|
      ev = put(44, 8, 3)
      ask(1, 3, RIGHT)
      assert_equal false, pl.seen[:plain]
      def ev.at_coordinate?(x, y); x.between?(@x - 2, @x + 2) && y == @y; end
      ev.instance_variable_set(:@active, TestPage.new(:trigger => 0, :sprite => "npc"))
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal true, pl.seen[:plain]
    end
  end

  test "shows them all once an event stands on a stair, where the game looks for events by the stair" do
    on_room do |pl|
      ev = put(44, 8, 3)
      ask(1, 3, RIGHT)
      assert_equal false, pl.seen[:plain]
      def ev.is_event_at_target?(*_a); false; end
      def ev.on_stair?; true; end
      ev.x = 7
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal true, pl.seen[:plain]
    end
  end

  test "keeps to the near ones with an event on a stair, where the game looks for events by their tile" do
    on_room do |pl|
      ev = put(44, 8, 3)
      def ev.on_stair?; true; end
      ev.x = 7
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal false, pl.seen[:plain]
    end
  end

  test "keeps to the near ones with an event off the stair, where the game looks for events by the stair" do
    on_room do |pl|
      ev = put(44, 8, 3)
      def ev.is_event_at_target?(*_a); false; end
      def ev.on_stair?; false; end
      ev.x = 7
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal false, pl.seen[:plain]
    end
  end

  test "shows them all before the events are read" do
    on_room do |pl|
      put(44, 8, 3)
      Events.forget
      ask(3, 1, RIGHT)
      assert_equal true, pl.seen[:plain]
    end
  end

  test "keeps to the near ones with events as wide as the game's own check of them" do
    on_room do |pl|
      wide = put(44, 5, 3, "size(3,2)")
      def wide.at_coordinate?(x, y); x.between?(@x, @x + 2) && y.between?(@y - 1, @y); end
      wide.x = 4
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal [[], false], [pl.seen[:values], pl.seen[:plain]]
    end
  end

  test "takes an event whose own check fails as one that may reach past the margin" do
    on_room do |pl|
      odd = put(44, 8, 3)
      def odd.at_coordinate?(_x, _y); raise "failed"; end
      odd.x = 7
      Events.sync(true)
      ask(1, 3, RIGHT)
      assert_equal true, pl.seen[:plain]
    end
  end

  test "goes over the near ones with an each_value that has no block as well" do
    on_room do |_pl|
      list = $game_map.events
      put(30, 4, 1)
      put(44, 8, 3)
      shown = Events.near_step(list, 3, 1, 4, 1)
      assert_equal [30], shown.each_value.map { |e| e.id }
    end
  end

  test "asks everything afresh once near_events is changed, for the maps kept too" do
    on_room do |_pl|
      put(30, 4, 1)
      PokeAccess::World::Visits.instance_variable_set(:@kept, [[99, 1, [], []]])
      Probe.session { Probe.step?(2, 1, RIGHT) }
      PokeAccess::Routes::Regions.foot
      refute_empty PokeAccess::Routes::Regions.instance_variable_get(:@sets)
      PokeAccess::Config.set(:near_events, false)
      assert_empty PokeAccess::World::Visits.maps, "the maps kept"
      assert_empty PokeAccess::Routes::Regions.instance_variable_get(:@sets), "the regions"
      assert_nil Probe.instance_variable_get(:@memo), "the answers"
    end
  end

  test "keeps everything when any other setting is changed" do
    on_room do |_pl|
      put(30, 4, 1)
      PokeAccess::World::Visits.instance_variable_set(:@kept, [[99, 1, [], []]])
      Probe.session { Probe.step?(2, 1, RIGHT) }
      PokeAccess::Routes::Regions.foot
      begin
        PokeAccess::Config.set(:route_stats, PokeAccess::Config.route_stats)
        assert_equal [99], PokeAccess::World::Visits.maps
        refute_empty PokeAccess::Routes::Regions.instance_variable_get(:@sets), "the regions"
        refute_nil Probe.instance_variable_get(:@memo), "the answers"
      ensure
        PokeAccess::World::Visits.forget
      end
    end
  end

  test "keeps all_events to its block, also when it fails" do
    assert_raises(RuntimeError) { Probe.all_events { raise "failed" } }
    on_room do |pl|
      put(44, 8, 3)
      ask(3, 1, RIGHT)
      assert_equal [], pl.seen[:values]
    end
  end

  test "takes in the events that come and go for the reads that see them all" do
    on_room do |pl|
      put(30, 4, 1)
      ask(3, 1, RIGHT)
      assert_equal [30], pl.seen[:keys]
      put(44, 8, 3)
      Events.sync(true)
      ask(3, 1, RIGHT)
      assert_equal [30, 44], pl.seen[:keys], "one come"
      $game_map.events.delete(30)
      Events.sync(true)
      ask(3, 1, RIGHT)
      assert_equal [[44], []], [pl.seen[:keys], pl.seen[:values]], "one gone"
    end
  end

  test "leaves alone a list that is no plain Hash" do
    own = Class.new(Hash)
    list = own.new
    assert_nil Events.near_step(list, 1, 1, 2, 1)
  end

  test "goes up and down the map as well as along it" do
    on_room do |pl|
      put(30, 3, 1)
      put(31, 2, 3)
      put(32, 1, 0)
      put(33, 2, 4)
      put(44, 8, 3)
      ask(2, 2, 8)
      assert_equal [30, 31, 32], pl.seen[:values], "up: from a row above where it lands to a row below where it starts"
      ask(2, 2, 2)
      assert_equal [30, 31, 33], pl.seen[:values], "down: from a row above where it starts to a row below where it lands"
    end
  end

  test "goes left as well as right" do
    on_room do |pl|
      put(30, 1, 1)
      put(31, 3, 2)
      put(32, 4, 1)
      ask(3, 1, 4)
      assert_equal [30, 31, 32], pl.seen[:values]
      ask(2, 1, 4)
      assert_equal [30, 31], pl.seen[:values], "and not two tiles past where it starts"
    end
  end

  test "keeps one list for the questions of a map, a new one for another map's" do
    on_room do |_pl|
      list = $game_map.events
      put(30, 4, 1)
      shown = Events.near_step(list, 3, 1, 4, 1)
      assert_same shown, Events.near_step(list, 5, 1, 6, 1)
      other = {}
      refute_same shown, Events.near_step(other, 5, 1, 6, 1)
    end
  end

  private

  # The room with a watching player, near events on, the events read afresh.
  def on_room
    with_tile_world(ROOM) do |world|
      pl = WatchingPlayer.new(world.start[0], world.start[1])
      $game_player = pl
      Events.forget
      PokeAccess::Config.near_events = true
      yield pl
    end
  ensure
    PokeAccess::Config.near_events = true
    Events.forget
  end

  # Has the game say the event stands on spot and nowhere else.
  def only_on(ev, spot)
    ev.define_singleton_method(:at_coordinate?) { |x, y| [x, y] == spot }
  end

  # An event of id on (x, y), read into the world.
  def put(id, x, y, name = "EV#{id}")
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [TestPage.new(:trigger => 0, :sprite => "npc")])
    $game_map.events[id] = ev
    Events.sync(true)
    ev
  end

  def ask(x, y, d)
    Probe.engine(x, y, d)
  end
end
