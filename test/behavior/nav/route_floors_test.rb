# The map's floor switch as part of a route's state (World::Floors, Pathfinder::FLOOR, Reborn's Lower Level): the stairs
# that set it change the floor a search is on, each floor's pages decide its steps, the guide's replay and the presses
# that cannot be undone follow the floor, and the game's state is left as it was.
class RouteFloorsTest < PokeAccessTest
  Effects = PokeAccess::Routes::Effects
  Floors = PokeAccess::World::Floors
  Moves = PokeAccess::Routes::Moves
  # A stair down on (1, 1) and one up on (5, 1); a gate on (3, 2) that stands on the upper floor and is a blank page on
  # the lower one; the way on below it.
  # A long corridor over a lower one: stairs at its two ends (1, 1) and (9, 1), the gate on (7, 2).
  LONG = ["###########",
          "#.........#",
          "#######.###",
          "#.........#",
          "###########"]
  GRID = ["#######",
          "#.....#",
          "###.###",
          "#.....#",
          "#######"]

  # An event whose pages a stand-in copy sets up (World::Floors.copy): its page and whether it blocks are its own ivars.
  class FloorEvent < TestGameEvent
    def instance_variable_get(sym)
      sym == :@page && instance_variable_defined?(:@page) ? @page : super
    end

    def blocking; !@through && !@character_name.to_s.empty?; end
  end

  test "a stair that sets the floor switch changes the floor a route is on, and the other floor's pages open its way" do
    floors do
      assert_equal 410, Effects.level_switch
      route = walk_route(3, 3, true)
      refute_nil route, "down the stair, back and through the gate below"
      assert_equal [4, 4, 6, 6, 2, 2], route.to_a
      lvl = PokeAccess::Pathfinder.bridge_level
      steps = Moves.trace(3, 1, lvl, route, PokeAccess::Pathfinder.replay_mode)
      assert_equal [0, 1024, 1024, 1024, 1024, 1024], steps.map { |s| s.level }
      assert_equal [nil, :floor, nil, nil, nil, nil], Moves.one_way(3, 1, lvl, route)
      assert_nil Floors.key, "the search looks at the standing floor again"
      refute $game_switches[410], "the game's switch is left off"
      assert_equal "rock", $game_map.events[30].character_name, "and the gate on its page"
    end
  end

  test "on the floor that stands the gate's own page decides" do
    floors do
      $game_switches[410] = true
      gate = $game_map.events[30]
      gate.instance_variable_set(:@page, gate.instance_variable_get(:@event).pages[1])
      gate.character_name = ""
      gate.through = true
      World.next_frame
      assert_equal [2, 2], walk_route(3, 3, true).to_a
    end
  end

  test "a switch the stairs set that no other event reads is a level but no floor" do
    floors(false) do
      assert_equal [410], Effects.level_switches.keys
      assert_nil Effects.level_switch
    end
  end

  test "a target acted on from one floor alone is got to on that floor" do
    floors do
      item = TestPage.new(:trigger => 0, :sprite => "ball", :list => [TestCmd.new(355, ["pbItemBall(:SUNSTONE)"])],
                          :condition => { :switch1_valid => true, :switch1_id => 410 })
      blank = TestPage.new(:trigger => 0)
      $game_map.events[31] = FloorEvent.new(:id => 31, :x => 1, :y => 3, :pages => [blank, item], :active_page => blank)
      World.next_frame
      assert_equal true, Effects.target_floor(1, 3)
      route = walk_route(1, 3)
      steps = Moves.trace(3, 1, 0, route, PokeAccess::Pathfinder.replay_mode)
      assert_equal 1024, steps.last.level, "it ends below, where the item is picked up"
    end
  end

  test "a computer whose page stands above alone has no way where only the floor below reaches it (Lapis's shutter)" do
    floors do
      panel = TestPage.new(:trigger => 0, :sprite => "panel",
                           :list => [World.if_facing(4), TestCmd.new(121, [556, 556, 0], 1), TestCmd.new(101, ["UNLOCKED"], 1),
                                     TestCmd.new(0, [], 1), World.end_])
      below = TestPage.new(:trigger => 0, :through => true, :condition => { :switch1_valid => true, :switch1_id => 410 })
      $game_map.events[32] = FloorEvent.new(:id => 32, :x => 1, :y => 3, :pages => [panel, below], :active_page => panel)
      World.next_frame
      assert_equal false, Effects.target_floor(1, 3)
      assert_nil walk_route(1, 3), "its front is walked below, where its page does nothing"
    end
  end

  test "a heap that only moves away with the floor switch on is got to on the floor below (Water Treatment)" do
    floors do
      away = TestMoveRoute.new([TestMoveCmd.new(11), TestMoveCmd.new(0)])
      heap = TestPage.new(:trigger => 0, :sprite => "block",
                          :list => [TestCmd.new(111, [0, 410, 0], 0), TestCmd.new(209, [0, away], 1), TestCmd.new(0, [], 1),
                                    World.end_(0)])
      $game_map.events[33] = FloorEvent.new(:id => 33, :x => 5, :y => 3, :pages => [heap], :active_page => heap)
      World.next_frame
      assert_equal true, Effects.target_floor(5, 3)
      route = walk_route(5, 3)
      assert_equal 1024, Moves.trace(3, 1, 0, route, PokeAccess::Pathfinder.replay_mode).last.level
    end
  end

  test "a flag only the other floor's page reads, turned on, shuts the way that floor gave" do
    floors do
      gate = $game_map.events[30]
      shut = TestPage.new(:trigger => 0, :sprite => "rock",
                          :condition => { :switch1_valid => true, :switch1_id => 410, :switch2_valid => true,
                                          :switch2_id => 500 })
      gate.instance_variable_get(:@event).pages.push(shut)
      World.next_frame
      assert_equal [4, 4, 6, 6, 2, 2], walk_route(3, 3, true).to_a
      $game_switches[500] = true
      World.next_frame
      assert_nil walk_route(3, 3, true), "the gate below now stands too"
    end
  ensure
    $game_switches[500] = false
  end

  test "whether the player stands over an event is asked of the engine shown the floor looked at" do
    floors do
      ev = TestGameEvent.new(:id => 31, :x => 1, :y => 3, :pages => [TestPage.new(:trigger => 1)])
      def ev.over_trigger?; !$game_map.events[30].blocking; end
      $game_map.events[31] = ev
      assert_equal 410, Effects.level_switch
      refute Effects.fires_on_arrival?(ev), "on the floor that stands, the gate is drawn"
      below = PokeAccess::Pathfinder.searching { Floors.looking(410, true) { Effects.fires_on_arrival?(ev) } }
      assert below, "below, the gate's page is blank"
    end
  end

  test "on the other floor a step away from every stand-in takes the standing floor's answer, the route the same" do
    long_corridor
    route = walk_route(7, 3, true)
    refute_nil route, "down the stair at the west end and back through the gate below"
    froms = floor_froms
    refute_empty froms, "the steps by the gate are asked on its own floor"
    assert froms.all? { |x| (x - 7).abs <= 2 }, "steps away from the gate share the standing floor's answers: #{froms.sort.inspect}"
  ensure
    $game_switches[410] = false
  end

  test "with the map's events in no plain Hash every step of the other floor is asked on that floor" do
    long_corridor
    events = Class.new(Hash).new
    $game_map.events.each { |k, v| events[k] = v }
    $game_map.instance_variable_set(:@events, events)
    World.next_frame
    refute_nil walk_route(7, 3, true)
    assert floor_froms.any? { |x| (x - 7).abs > 2 }, "the engine is shown every event on the floor that stands"
  ensure
    $game_switches[410] = false
  end

  test "a question afloat on the other floor keeps its answer apart from the standing floor's" do
    floors do
      probe = PokeAccess::World::Probe
      kept = nil
      Floors.looking(410, true) do
        probe.session do
          probe.with_surf(true) do
            sig = probe.instance_variable_get(:@sig)
            kept = [probe.instance_variable_get(:@memo), probe.saved[2][sig] && probe.saved[2][sig][[410, true]]]
          end
        end
      end
      refute_nil kept[1], "the floor's own answers afloat"
      assert_same kept[1], kept[0]
    end
  end

  private

  # The long corridor with the player on (5, 1), its stairs at the two ends and the gate on (7, 2).
  def long_corridor
    $game_map.load_grid(LONG)
    $game_player.x = 5
    $game_player.y = 1
    stair(40, 1, 1, 0)
    stair(41, 9, 1, 1)
    up = TestPage.new(:trigger => 0, :sprite => "rock")
    down = TestPage.new(:trigger => 0, :through => true, :condition => { :switch1_valid => true, :switch1_id => 410 })
    ev = FloorEvent.new(:id => 30, :x => 7, :y => 2, :pages => [up, down], :active_page => up)
    ev.instance_variable_set(:@page, up)
    ev.through = false
    $game_map.events[30] = ev
    World.next_frame
  end

  # The columns of the steps the probe kept for the floor that does not stand.
  def floor_froms
    stride = PokeAccess::World::Probe::STRIDE
    froms = PokeAccess::World::Probe.saved[2].values.map { |by_floor| by_floor.values }.flatten.map(&:keys).flatten
    froms.map { |k| (k / 32) / stride }.uniq
  end

  # The grid with the player on (3, 1), the stairs and, with gate, the gate reading switch 410.
  def floors(gate = true)
    $game_map.load_grid(GRID)
    $game_player.x = 3
    $game_player.y = 1
    stair(40, 1, 1, 0)
    stair(41, 5, 1, 1)
    if gate
      up = TestPage.new(:trigger => 0, :sprite => "rock")
      down = TestPage.new(:trigger => 0, :through => true, :condition => { :switch1_valid => true, :switch1_id => 410 })
      ev = FloorEvent.new(:id => 30, :x => 3, :y => 2, :pages => [up, down], :active_page => up)
      ev.instance_variable_set(:@page, up)
      ev.through = false
      $game_map.events[30] = ev
    end
    World.next_frame
    yield
  ensure
    $game_switches[410] = false
  end

  # A stair on (x, y) that sets switch 410 to value (0 on, 1 off) as the player steps on it.
  def stair(id, x, y, value)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(121, [410, 410, value])])
  end
end
