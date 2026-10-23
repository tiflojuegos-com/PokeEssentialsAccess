# World::Events: a record per engine event, read at most once a frame unless forced; each change told with its tiles,
# record and how it changed; tiles indexed in engine order; facets and summaries kept while what they hang on stands.
class EventsTest < PokeAccessTest
  Events = PokeAccess::World::Events
  Flags = PokeAccess::World::Flags
  Probe = PokeAccess::World::Probe
  # A change of each field the records compare, made on an event.
  FIELDS = {
    "through" => lambda { |e| e.through = true },
    "sprite" => lambda { |e| e.character_name = "rock" },
    "tile" => lambda { |e| e.tile_id = 400 },
    "name" => lambda { |e| e.name = "Otro" },
    "page" => lambda { |e| e.instance_variable_set(:@active, TestPage.new) },
    "trigger" => lambda { |e| e.instance_variable_set(:@trigger, 3) },
    "width" => lambda { |e| e.instance_variable_set(:@width, 1) },
    "height" => lambda { |e| e.instance_variable_set(:@height, 1) }
  }.freeze

  test "an event that comes is indexed on its tile and told as come" do
    changes = told do
      World.event(:id => 9, :x => 3, :y => 2)
      Events.sync
    end
    assert_equal [[[[3, 2]], 9, :come]], changes
    assert_equal [9], ids(Events.at(3, 2))
  end

  test "an event that goes leaves its tile to the others and is told as go" do
    World.event(:id => 1, :x => 2, :y => 2)
    World.event(:id => 2, :x => 2, :y => 2)
    Events.sync(true)
    changes = told do
      $game_map.events.delete(1)
      Events.sync(true)
    end
    assert_equal [[[[2, 2]], 1, :go]], changes
    assert_equal [2], ids(Events.at(2, 2))
  end

  test "a move is told as a move with the tiles it left and reached, and the index follows it" do
    e = World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    changes = told do
      e.x = 5
      Events.sync(true)
    end
    assert_equal [[[[4, 4], [5, 4]], 3, :move]], changes
    assert_equal [[], [3]], [ids(Events.at(4, 4)), ids(Events.at(5, 4))]
  end

  test "each compared field that changes is told as a change and bumps the record's generation" do
    FIELDS.each do |field, change|
      World.clear_events
      e = World.event(:id => 3, :x => 4, :y => 4)
      Events.sync(true)
      r = Events.record_of(e)
      gen = r.gen
      changes = told do
        change.call(e)
        Events.sync(true)
      end
      assert_equal [[[[[4, 4]], 3, :change]], gen + 1], [changes, r.gen], field
    end
  end

  test "a sync with nothing changed tells nothing and bumps nothing" do
    e = World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    r = Events.record_of(e)
    counts = [r.gen, Events.gen, Events.turns]
    changes = told { Events.sync(true) }
    assert_equal [[], counts], [changes, [r.gen, Events.gen, Events.turns]]
  end

  test "each change bumps the generation of the events as a whole, once more when the lists are rebuilt after it" do
    { "an event coming" => [2, lambda { World.event(:id => 9, :x => 3, :y => 2) }],
      "an event moving" => [1, lambda { $game_map.events[3].x = 5 }],
      "an event changing" => [1, lambda { $game_map.events[3].name = "Otro" }],
      "an event going" => [2, lambda { $game_map.events.delete(3) }] }.each do |what, (bumps, change)|
      World.clear_events
      World.event(:id => 3, :x => 4, :y => 4)
      Events.sync(true)
      gen = Events.gen
      change.call
      Events.sync(true)
      assert_equal gen + bumps, Events.gen, what
    end
  end

  test "reads the engine at most once a frame, unless forced" do
    e = World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    e.x = 5
    assert_equal [3], ids(Events.at(4, 4)), "within the frame it was read in, the record stands"
    World.next_frame
    assert_equal [3], ids(Events.at(5, 4)), "a frame later it is read again"
    e.x = 6
    Events.sync(true)
    assert_equal [3], ids(Events.at(6, 4)), "forced, at once"
  end

  test "never reads the engine while events are lent through" do
    rock = World.event(:id => 3, :x => 2, :y => 2)
    Events.sync(true)
    changes = told { Probe.lend_through([rock]) { Events.sync(true) } }
    assert_equal [[], false], [changes, Events.record_of(rock).through]
  end

  test "an event comes and goes as a turn when its page is one a route reads" do
    { 0 => 1, 1 => 1, 2 => 1, 3 => 0, 4 => 0 }.each do |trigger, want|
      Events.sync(true)
      before = Events.turns
      place(TestGameEvent.new(:id => 7, :x => 2, :y => 2, :pages => [TestPage.new(:trigger => trigger)]))
      Events.sync(true)
      came = Events.turns - before
      $game_map.events.delete(7)
      Events.sync(true)
      assert_equal [want, want], [came, Events.turns - before - came], "trigger #{trigger}"
    end
  end

  test "a change is a turn only when the page turns from or to one a route reads" do
    { "from autorun to the action button" => [3, lambda { |e| turn_page(e, 0) }, 1],
      "from the action button to autorun" => [0, lambda { |e| turn_page(e, 3) }, 1],
      "from player touch to parallel" => [1, lambda { |e| turn_page(e, 4) }, 1],
      "from parallel to event touch" => [4, lambda { |e| turn_page(e, 2) }, 1],
      "from autorun to parallel" => [3, lambda { |e| turn_page(e, 4) }, 0],
      "an action event moving" => [0, lambda { |e| e.x = 3 }, 0] }.each do |what, (trigger, change, want)|
      World.clear_events
      e = place(TestGameEvent.new(:id => 7, :x => 2, :y => 2, :pages => [TestPage.new(:trigger => trigger)]))
      Events.sync(true)
      before = Events.turns
      change.call(e)
      Events.sync(true)
      assert_equal want, Events.turns - before, what
    end
  end

  test "events on one tile are listed in the engine's order, whichever came onto it last" do
    first = World.event(:id => 1, :x => 1, :y => 1)
    World.event(:id => 2, :x => 2, :y => 2)
    last = World.event(:id => 3, :x => 3, :y => 3)
    Events.sync(true)
    last.x = 2
    last.y = 2
    Events.sync(true)
    first.x = 2
    first.y = 2
    Events.sync(true)
    assert_equal [1, 2, 3], ids(Events.at(2, 2))
  end

  test "follows the engine's order when it changes" do
    World.event(:id => 1, :x => 2, :y => 2)
    World.event(:id => 2, :x => 2, :y => 2)
    Events.sync(true)
    $game_map.events[1] = $game_map.events.delete(1)
    Events.sync(true)
    assert_equal [[2, 1], [2, 1]], [ids(Events.at(2, 2)), ids(Events.records)]
  end

  test "an event replaced by another object under its id goes, and the new one comes" do
    World.event(:id => 5, :x => 1, :y => 1)
    Events.sync(true)
    fresh = TestGameEvent.new(:id => 5, :x => 2, :y => 1)
    changes = told do
      $game_map.events[5] = fresh
      Events.sync(true)
    end
    assert_equal [[[[1, 1]], 5, :go], [[[2, 1]], 5, :come]], changes
    assert_same fresh, Events.at(2, 1).first.ev
  end

  test "keeps its records while the map's events cannot be read" do
    World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    $game_map.define_singleton_method(:events) { raise "unreadable" }
    World.next_frame
    assert_equal [3], ids(Events.records)
  ensure
    $game_map.singleton_class.send(:remove_method, :events) if $game_map.singleton_methods.include?(:events)
  end

  test "an engine event with no id is not recorded" do
    World.event(:id => 3, :x => 4, :y => 4)
    $game_map.events[99] = TestGameEvent.new(:id => nil, :x => 1, :y => 1)
    World.next_frame
    assert_equal [[3], []], [ids(Events.records), ids(Events.at(1, 1))]
  end

  test "an event whose through cannot be read counts as not through, and as unchanged at each sync" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    def e.through; raise "unreadable"; end
    Events.sync(true)
    changes = told { Events.sync(true) }
    assert_equal [false, []], [Events.record_of(e).through, changes]
  end

  test "a new map forgets the records of the map left, telling none of them gone" do
    World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    changes = told do
      $game_map.events.clear
      $game_map.map_id = 2
      World.next_frame
      Events.records
    end
    assert_equal [[], [], []], [Events.records, Events.covered, changes]
  end

  test "forgetting the records counts as a change and a turn, and the next question reads them afresh" do
    World.event(:id => 3, :x => 4, :y => 4)
    Events.sync(true)
    counts = [Events.gen + 1, Events.turns + 1]
    Events.forget
    bumped = [Events.gen, Events.turns]
    assert_equal [counts, [3]], [bumped, ids(Events.at(4, 4))], "bumped once each; within the frame, read again"
  end

  test "an event's size spreads its tiles right and up, each indexed" do
    six = [[5, 3], [5, 4], [6, 3], [6, 4], [7, 3], [7, 4]]
    { "a size the engine keeps" => [{ :@width => 3, :@height => 2 }, "Truck", six],
      "a size in its name" => [{}, "Truck size(3,2)", six],
      "a size in its name, spaced and in capitals" => [{}, "Truck SIZE( 3 , 2 )", six],
      "a size of nothing in its name, its own tile still" => [{}, "Truck size(0,0)", [[5, 4]]]
    }.each do |how, (ivars, name, tiles)|
      World.clear_events
      e = World.event(:id => 4, :x => 5, :y => 4, :name => name)
      ivars.each { |k, v| e.instance_variable_set(k, v) }
      Events.sync(true)
      assert_equal tiles, Events.record_of(e).tiles.sort, how
      assert_equal [[4]] * tiles.length, tiles.map { |x, y| ids(Events.at(x, y)) }, how
    end
  end

  test "anchored gives the records standing on the tile itself, not those only covering it" do
    World.event(:id => 4, :x => 5, :y => 4, :name => "Truck size(3,2)")
    got = [[5, 4], [5, 3], [6, 4], [6, 3]].map { |x, y| ids(Events.anchored(x, y)) }
    assert_equal [[4], [], [], []], got, "its own tile; then tiles it covers in its column, in its row, in neither"
  end

  test "a tile's index key is the routes' own packing of it" do
    [[0, 0], [7, 3], [250, 99]].each { |x, y| assert_equal PokeAccess::Routes.pkey(x, y), Events.key(x, y), "(#{x}, #{y})" }
  end

  test "covered lists the tiles last read, without reading the events again" do
    e = World.event(:id => 4, :x => 5, :y => 4, :name => "Cart size(2,1)")
    Events.sync(true)
    e.x = 9
    World.next_frame
    assert_equal [[5, 4], [6, 4]], Events.covered.sort
  end

  test "record_of gives the record of the engine's own object, and nil for any other" do
    e = World.event(:id => 4, :x => 5, :y => 4)
    assert_same e, Events.record_of(e).ev
    assert_nil Events.record_of(TestGameEvent.new(:id => 4, :x => 5, :y => 4)), "another object under its id"
    assert_nil Events.record_of(Object.new), "an object with no id"
  end

  test "tiles_of gives the record's tiles, and reads now an event moved since or that is not the record's" do
    e = World.event(:id => 4, :x => 5, :y => 4)
    Events.sync(true)
    e.name = "Cart size(2,1)"
    assert_equal [[5, 4]], Events.tiles_of(e), "where it was read, the record's tiles"
    e.x = 7
    assert_equal [[7, 4], [8, 4]], Events.tiles_of(e), "moved since it was read"
    cart = TestGameEvent.new(:id => 4, :x => 5, :y => 4, :name => "Cart size(2,1)")
    assert_equal [[5, 4], [6, 4]], Events.tiles_of(cart), "another object under its id"
    assert_equal [[1, 1]], Events.tiles_of(TestGameEvent.new(:id => 8, :x => 1, :y => 1)), "one never read"
  end

  test "tells the events that walk about by themselves" do
    steps = TestMoveRoute.new([TestMoveCmd.new(15), TestMoveCmd.new(1), TestMoveCmd.new(0)])
    turns = TestMoveRoute.new([TestMoveCmd.new(15), TestMoveCmd.new(16), TestMoveCmd.new(0)])
    { "fixed" => [TestPage.new(:move_type => 0), false],
      "at random" => [TestPage.new(:move_type => 1), true],
      "toward the player" => [TestPage.new(:move_type => 2), true],
      "along a route that takes a step" => [TestPage.new(:move_type => 3, :move_route => steps), true],
      "along a route of turns" => [TestPage.new(:move_type => 3, :move_route => turns), false],
      "along no route" => [TestPage.new(:move_type => 3), false],
      "along a route whose commands cannot tell their code" =>
        [TestPage.new(:move_type => 3, :move_route => TestMoveRoute.new([Object.new])), false],
      "fixed, with a route that steps" => [TestPage.new(:move_type => 0, :move_route => steps), false],
      "a page with no move type" => [Object.new, false],
      "no page" => [nil, false] }.each do |what, (page, want)|
      World.clear_events
      e = World.event(:id => 6, :x => 2, :y => 2)
      e.instance_variable_set(:@active, page)
      Events.sync(true)
      assert_equal want, Events.mover?(Events.record_of(e)), what
    end
  end

  test "walkers are the events that walk about by themselves and are not through, one whose through fails among them" do
    walker = place(TestGameEvent.new(:id => 1, :x => 1, :y => 1, :pages => [TestPage.new(:move_type => 1)]))
    ghost = place(TestGameEvent.new(:id => 2, :x => 2, :y => 1, :pages => [TestPage.new(:move_type => 1)]))
    ghost.through = true
    place(TestGameEvent.new(:id => 3, :x => 3, :y => 1))
    odd = place(TestGameEvent.new(:id => 4, :x => 4, :y => 1, :pages => [TestPage.new(:move_type => 2)]))
    def odd.through; raise "unreadable"; end
    assert_equal [walker, odd], Events.walkers
  end

  test "a facet is computed on first use and kept while nothing it hangs on changes" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    calls = 0
    with_facet(:spec_switch, lambda { |_r| calls += 1; Flags.switch(77) }) do
      r = Events.record_of(e)
      first = Events.facet(r, :spec_switch)
      World.next_frame
      Events.sync
      assert_equal [false, false, 1], [first, Events.facet(r, :spec_switch), calls]
    end
  end

  test "a flag a facet read changing drops it, told as a change of its tiles and counted as a turn" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    calls = 0
    with_facet(:spec_switch, lambda { |_r| calls += 1; Flags.switch(77) }) do
      r = Events.record_of(e)
      first = Events.facet(r, :spec_switch)
      $game_switches[77] = true
      before = Events.turns
      changes = told { Events.sync(true) }
      assert_equal [[[[1, 1]], 4, :change]], changes
      assert_equal before + 1, Events.turns
      assert_equal [false, true, 2], [first, Events.facet(r, :spec_switch), calls]
    end
  end

  test "a record keeps watching the flags of its facets that still stand" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    calls = Hash.new(0)
    with_facet(:spec_a, lambda { |_r| calls[:a] += 1; Flags.switch(71) }) do
      with_facet(:spec_b, lambda { |_r| calls[:b] += 1; Flags.switch(72) }) do
        r = Events.record_of(e)
        Events.facet(r, :spec_a)
        Events.facet(r, :spec_b)
        $game_switches[71] = true
        Events.sync(true)
        $game_switches[72] = true
        Events.sync(true)
        assert_equal [true, true, { :a => 2, :b => 2 }], [Events.facet(r, :spec_a), Events.facet(r, :spec_b), calls]
      end
    end
  end

  test "a facet goes once its record changes" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    calls = 0
    with_facet(:spec_place, lambda { |r| calls += 1; [r.x, r.y] }) do
      r = Events.record_of(e)
      first = Events.facet(r, :spec_place)
      e.x = 2
      Events.sync(true)
      assert_equal [[1, 1], [2, 1], 2], [first, Events.facet(r, :spec_place), calls]
    end
  end

  test "an event gone no longer watches the flags its facets read" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    with_facet(:spec_switch, lambda { |_r| Flags.switch(77) }) do
      Events.facet(Events.record_of(e), :spec_switch)
      $game_map.events.delete(4)
      Events.sync(true)
      turns = Events.turns
      $game_switches[77] = true
      changes = told { Events.sync(true) }
      assert_equal [[], turns], [changes, Events.turns], "its flag changing tells nothing and turns nothing"
    end
  end

  test "a facet that read what nothing can watch lasts until an event's end" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    calls = 0
    with_facet(:spec_volatile, lambda { |_r| calls += 1; Flags.volatile!; :read }) do
      r = Events.record_of(e)
      Events.facet(r, :spec_volatile)
      Events.sync(true)
      Events.facet(r, :spec_volatile)
      kept = calls
      Flags.event_ended!
      Events.sync(true)
      Events.facet(r, :spec_volatile)
      assert_equal [1, 2], [kept, calls]
    end
  end

  test "a facet whose provider fails, or that no provider gives, is nil" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    with_facet(:spec_broken, lambda { |_r| raise "broken" }) do
      r = Events.record_of(e)
      assert_nil Events.facet(r, :spec_broken), "a provider that fails"
      assert_nil Events.facet(r, :spec_unregistered), "no provider"
    end
  end

  test "a provider registered anew drops the facet kept under its name" do
    e = World.event(:id => 4, :x => 1, :y => 1)
    with_facet(:spec_kind, lambda { |_r| :old }) do
      r = Events.record_of(e)
      first = Events.facet(r, :spec_kind)
      Events.facet_provider(:spec_kind) { |_r| :new }
      assert_equal [:old, :new], [first, Events.facet(r, :spec_kind)]
    end
  end

  test "a summary is kept until any event changes" do
    e = World.event(:id => 5, :x => 1, :y => 1)
    built = 0
    count = lambda { built += 1; Events.records.length }
    first = [Events.summary(:spec_count, &count), Events.summary(:spec_count, &count), built]
    e.x = 2
    World.next_frame
    assert_equal [[1, 1, 1], 1, 2], [first, Events.summary(:spec_count, &count), built]
  end

  test "a facet or summary asked while events are lent is answered, not kept" do
    rock = World.event(:id => 3, :x => 2, :y => 2)
    with_facet(:spec_lent, lambda { |r| (r.ev.through rescue false) ? true : false }) do
      rec = Events.record_of(rock)
      inside = Probe.lend_through([rock]) { [Events.facet(rec, :spec_lent), Events.summary(:spec_lent) { :lent }] }
      assert_equal [true, :lent], inside, "inside, the lent state is what is read"
      assert_equal [false, :standing], [Events.facet(rec, :spec_lent), Events.summary(:spec_lent) { :standing }],
                   "outside, neither was kept"
    end
  end

  test "the boulder index follows a boulder pushed twice in a row" do
    b = boulder(6, 3, 3)
    seen = [3, 4, 5].map do |x|
      b.x = x
      World.next_frame
      PokeAccess::Routes::Effects.boulder_index.keys
    end
    assert_equal [3, 4, 5].map { |x| [PokeAccess::Routes.pkey(x, 3)] }, seen
  end

  private

  # The changes Events tells while the block runs, each as [its tiles sorted, the record's id, how it changed].
  def told
    seen = []
    listener = lambda { |tiles, r, how| seen.push([tiles.sort, r.id, how]) }
    Events.on_change(&listener)
    yield
    seen
  ensure
    Events.instance_variable_get(:@changes).delete(listener)
  end

  # Runs the block with a facet provider registered under name, taken out after.
  def with_facet(name, provider)
    Events.facet_provider(name, &provider)
    yield
  ensure
    Events.instance_variable_get(:@providers).delete(name)
  end

  # The ids of these records, in their order.
  def ids(records)
    records.map { |r| r.id }
  end

  # Puts an engine event on the test map, seen from the next frame on.
  def place(ev)
    $game_map.events[ev.id] = ev
    World.next_frame
    ev
  end

  # Turns an event to a new page with this trigger, as the engine's refresh does.
  def turn_page(ev, trigger)
    ev.instance_variable_set(:@active, TestPage.new(:trigger => trigger))
    ev.instance_variable_set(:@trigger, trigger)
  end

  # A pushable boulder (pbPushThisBoulder) standing on (x, y).
  def boulder(id, x, y)
    page = TestPage.new(:trigger => 0, :sprite => "boulder", :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    place(TestGameEvent.new(:id => id, :x => x, :y => y, :name => "Boulder", :pages => [page]))
  end
end
