# The routes through a puzzle's controls keep to the route limit's deadline: none reads the room's floor once it has
# passed, the stop counted, and the floor's reading stops when it passes meanwhile.

class ControlsDeadlineTest < PokeAccessTest
  test "reads no floor once the deadline has passed, and counts the stop" do
    with_room do
      reads = 0
      ctl = PokeAccess::Routes::Controls
      ctl.singleton_class.send(:alias_method, :floor_spec, :floor_from)
      ctl.define_singleton_method(:floor_from) { |*a| reads += 1; floor_spec(*a) }
      begin
        cuts = past_deadline { |lim| [ctl.route(PokeAccess::Routes::Goal.near(6, 1)), lim] }
        assert_equal [nil, 0, 1], [cuts[0], reads, cuts[1].cuts]
      ensure
        ctl.singleton_class.send(:alias_method, :floor_from, :floor_spec)
        ctl.singleton_class.send(:remove_method, :floor_spec)
      end
    end
  end

  test "stops reading the floor when the deadline passes" do
    $game_map.load_grid(["############"] + Array.new(8) { "#..........#" } + ["############"])
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_nil past_deadline { PokeAccess::Routes::Controls.floor_from(1, 1) }
  ensure
    $game_map.clear_grid
  end

  private

  def past_deadline
    PokeAccess::Config.route_limit = :time
    PokeAccess::Pathfinder.with_limits do |lim|
      lim.instance_variable_set(:@deadline, PokeAccess.clock - 1)
      yield lim
    end
  end

  def with_room
    mech = PokeAccess::World::Mechanics
    $game_map.load_grid(["#########",
                         "#@......#",
                         "#.#######",
                         "#########"])
    plate = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(121, [142, 142, 0])])
    $game_map.events[43] = TestGameEvent.new(:id => 43, :x => 1, :y => 2, :pages => [plate])
    rays = [TestPage.new(:trigger => 0, :sprite => "rayosR"),
            TestPage.new(:trigger => 0, :sprite => "", :condition => { :switch1_valid => true, :switch1_id => 142 })]
    wall = TestGameEvent.new(:id => 20, :x => 4, :y => 1, :pages => rays)
    wall.blocking = true
    $game_map.events[20] = wall
    mech.declare($game_map.map_id, :kind => :state, :controls => true,
                 :watch => [{ :switch => 142, :label => :gym3_red, :on => :gym3_on, :off => :gym3_off }],
                 :obstacles => [{ :match => /rayos/i, :kind => :wall }])
    mech.forget
    PokeAccess::Config.puzzle_assist = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    PokeAccess::Config.puzzle_assist = false
    $game_switches[142] = false
    mech.instance_variable_set(:@defs, {})
    mech.forget
    mech::Links.forget
    World.clear_events
    $game_map.clear_grid
  end
end
