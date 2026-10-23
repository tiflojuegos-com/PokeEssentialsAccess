# No jump lands on a field-move obstacle and no slide crosses one, even in the assisted search that sets them aside:
# the engine refuses the jump and stops the slide in front of it. Only the step up to the obstacle carries its gate,
# so an assisted route holds where the player faces it.

class ObstacleLandingTest < PokeAccessTest
  ICE = 12
  RIGHT = 6

  test "goes nowhere hopping a ledge onto an obstacle in the assisted search" do
    with_row(:ledge => 2, :tree => 3) do
      assert_nil assisted_step(1)
    end
  end

  test "offers no assisted route that asks for the field move from above the ledge" do
    with_row(:ledge => 2, :tree => 3) do
      assert_nil PokeAccess::Routes::Planner.assisted(5, 1)
    end
  end

  test "stops a slide in front of an obstacle, where the step up to it carries its gate" do
    with_row(:ice => [2, 3], :tree => 4) do
      assert_equal [3, 1, false], assisted_step(1)
      assert_equal [4, 1, true], assisted_step(3)
    end
  end

  test "holds an assisted route over ice in front of the obstacle" do
    with_row(:ice => [2, 3], :tree => 4) do
      route, gate = PokeAccess::Routes::Planner.assisted(5, 1)
      assert_equal [[6], 4], [route.to_a, gate[:x]]
    end
  end

  private

  def with_row(opts)
    $game_map.load_grid(["#######",
                         "#@....#",
                         "#######"])
    (opts[:ice] || []).each { |x| $game_map.set_terrain(x, 1, ICE) }
    $game_map.place_ledge(opts[:ledge], 1, RIGHT) if opts[:ledge]
    World.event(:kind => :npc, :id => 80, :x => opts[:tree], :y => 1, :name => "Tree").blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    World.clear_events
    $game_map.clear_ledges
    $game_map.clear_grid
  end

  def assisted_step(x)
    pf = PokeAccess::Pathfinder
    moves = PokeAccess::Routes::Moves
    s = pf.with_gates_open do
      pf.searching { moves.step(x, 1, 0, PokeAccess::Routes::DIR_OF[RIGHT], moves::LEDGE | moves::ASSIST) }
    end
    s && [s.x, s.y, !s.gate.nil?]
  end
end
