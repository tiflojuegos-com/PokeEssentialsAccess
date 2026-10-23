# World::Flags: a reading notes each live value read inside it and tells later whether each still gives what it gave;
# a read nothing can watch holds until the next event's end, and a value the engine cannot give raises.
class FlagsTest < PokeAccessTest
  Flags = PokeAccess::World::Flags
  # A conditional branch on the event's self switch A being off, transferring the player when it is, and its end.
  SELF_SWITCH_BRANCH = [TestCmd.new(111, [2, "A", 1]), TestCmd.new(201, [0, 9, 1, 1], 1), TestCmd.new(412, [])].freeze

  test "a reading answers the block's value and notes each read with the value it gave" do
    $game_switches[61] = true
    $game_variables[62] = 3
    v, deps = Flags.reading { [Flags.switch(61), Flags.variable(62)] }
    assert_equal [[true, 3], [[[:switch, 61], true], [[:variable, 62], 3]]], [v, deps]
  end

  test "a read of each kind holds while its value stands and stops holding once it changes" do
    ev = World.event(:id => 4, :x => 2, :y => 2)
    switches = { [1, 2, "A"] => true }
    maps = { 12 => true }
    counts = { :POTION => 2 }
    $game_variables[62] = 3
    with_live_state(switches, maps, counts) do
      { "a switch" => [lambda { Flags.switch(61) }, [:switch, 61], false, lambda { $game_switches[61] = true }],
        "a variable" => [lambda { Flags.variable(62) }, [:variable, 62], 3, lambda { $game_variables[62] = 4 }],
        "a self switch" => [lambda { Flags.self_switch([1, 2, "A"]) }, [:self_switch, [1, 2, "A"]], true,
                            lambda { switches.delete([1, 2, "A"]) }],
        "a vehicle" => [lambda { Flags.vehicle(:surfing) }, [:vehicle, :surfing], false,
                        lambda { $PokemonGlobal.surfing = true }],
        "the bag" => [lambda { Flags.bag(:POTION) }, [:bag, :POTION], 2, lambda { counts[:POTION] = 3 }],
        "a visited map" => [lambda { Flags.visited(12) }, [:visited, 12], true, lambda { maps.delete(12) }],
        "an event's facing" => [lambda { Flags.direction(4) }, [:direction, 4], 2, lambda { ev.direction = 8 }],
        "the facing of an event the map lacks" => [lambda { Flags.direction(9) }, [:direction, 9], nil,
                                                   lambda { World.event(:id => 9, :x => 3, :y => 3) }]
      }.each do |what, (read, key, value, change)|
        got, deps = Flags.reading { read.call }
        held = Flags.current?(deps)
        change.call
        assert_equal [value, [[key, value]], true, false], [got, deps, held, Flags.current?(deps)], what
      end
    end
  end

  test "a facing is the map event's, or the given event's own" do
    ev = World.event(:id => 4, :x => 2, :y => 2)
    ev.direction = 8
    other = TestGameEvent.new(:id => 4)
    other.direction = 6
    assert_equal [8, 6], [Flags.direction(4), Flags.direction(4, other)]
  end

  test "a String or an Array changed in place stops holding" do
    { "an Array" => [[1, 2], lambda { |v| v.push(3) }],
      "a String" => [String.new("ab"), lambda { |v| v << "c" }] }.each do |what, (value, change)|
      $game_variables[63] = value
      _v, deps = Flags.reading { Flags.variable(63) }
      held = Flags.current?(deps)
      change.call($game_variables[63])
      assert_equal [true, false], [held, Flags.current?(deps)], what
    end
  end

  test "a nested reading keeps its own reads apart from the reading around it" do
    inner = nil
    _v, outer = Flags.reading do
      inner = Flags.reading { Flags.switch(61) }[1]
      Flags.variable(62)
    end
    assert_equal [[[[:switch, 61], false]], [[[:variable, 62], 0]]], [inner, outer]
  end

  test "a read nothing can watch holds until the next event's end" do
    _v, deps = Flags.reading { Flags.volatile! }
    held = Flags.current?(deps)
    Flags.event_ended!
    assert_equal [true, false], [held, Flags.current?(deps)]
  end

  test "a self switch the engine cannot give raises, and a read noted of it no longer holds" do
    with_live_state(nil, {}, {}) do
      assert_raises(StandardError) { Flags.self_switch([1, 2, "A"]) }
      assert_equal false, Flags.current?([[[:self_switch, [1, 2, "A"]], false]])
    end
  end

  test "a page reading a self switch the engine cannot give is unknown, not read as off" do
    page = World.touch(:id => 4, :list => SELF_SWITCH_BRANCH)
    got = [nil, {}].map do |switches|
      with_live_state(switches, {}, {}) do
        o = PokeAccess::EventPages.outcome(page, 2, [5, 5])
        [o.unknown, o.transfer]
      end
    end
    assert_equal [[true, nil], [false, [9, 1, 1]]], got, "unreadable: unknown; readable and off: the branch transfers"
  end

  private

  # Runs the block with the engine's self switches, visited maps and bag (a gen-6 one counting items) given by these
  # hashes, each put back after.
  def with_live_state(self_switches, visited, counts)
    had = [$game_self_switches, $bag, $PokemonBag]
    bag = Object.new
    bag.define_singleton_method(:pbQuantity) { |item| counts[item] || 0 }
    $game_self_switches = self_switches
    $bag = nil
    $PokemonBag = bag
    $PokemonGlobal.define_singleton_method(:visitedMaps) { visited }
    yield
  ensure
    $game_self_switches, $bag, $PokemonBag = had
    $PokemonGlobal.singleton_class.send(:remove_method, :visitedMaps)
  end
end
