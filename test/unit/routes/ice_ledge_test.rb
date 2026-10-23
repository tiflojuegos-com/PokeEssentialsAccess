# Ice and ledges chain as the engine plays them: a hop that lands on ice slides on, and a slide that reaches a ledge
# hops it, landing two tiles on (and sliding again on ice), or stops before it when the hop cannot land.

class IceLedgeTest < PokeAccessTest
  ICE = 12
  RIGHT = 6

  test "slides on from a hop that lands on ice" do
    on_row("#@....#", :ice => [3, 4], :ledge => 2) do
      assert_equal [5, 1, :jump], step_right(1)
    end
  end

  test "hops a ledge the slide reaches and stops on the floor it lands on" do
    on_row("#@.....#", :ice => [2, 3], :ledge => 4) do
      assert_equal [5, 1, :slide], step_right(1)
    end
  end

  test "slides on again when the ledge a slide hops lands on ice" do
    on_row("#@......#", :ice => [2, 3, 5, 6], :ledge => 4) do
      assert_equal [7, 1, :slide], step_right(1)
    end
  end

  test "stops the slide before a ledge whose hop cannot land" do
    on_row("#@...#", :ice => [2, 3], :ledge => 4) do
      assert_equal [3, 1, :slide], step_right(1)
    end
  end

  private

  def on_row(row, opts)
    wall = "#" * row.length
    $game_map.load_grid([wall, row, wall])
    opts[:ice].each { |x| $game_map.set_terrain(x, 1, ICE) }
    $game_map.place_ledge(opts[:ledge], 1, RIGHT)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    $game_map.clear_ledges
    $game_map.clear_grid
  end

  def step_right(x)
    moves = PokeAccess::Routes::Moves
    s = PokeAccess::Pathfinder.searching { moves.step(x, 1, 0, PokeAccess::Routes::DIR_OF[RIGHT], moves::LEDGE) }
    s && [s.x, s.y, s.kind]
  end
end
