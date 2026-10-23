# How a route that pushes boulders moves the player between pushes, as a route on foot does: it keeps the transfers
# on the way, hops ledges, keeps a bridge's two levels apart, and its slides stop in front of the boulders where the
# search has them, though they are lent through to the engine.

class PushMovesTest < PokeAccessTest
  ICE = 12
  RIGHT = 6

  test "keeps a transfer on the way to the first push" do
    on_row("#@..#.....#") do
      World.touch(:id => 60, :x => 3, :y => 1, :list => [TestCmd.new(201, [0, $game_map.map_id, 5, 1])])
      boulder(61, 7, 1)
      assert_equal [[6, 6, 6], [1], [7, 1]], pushed_route(Goal.near(9, 1)) { |r, g| [r.to_a, r.warps, [g[:x], g[:y]]] }
    end
  end

  test "hops a ledge on the way to the first push" do
    on_row("#@.......#", "#######.##") do
      $game_map.place_ledge(3, 1, RIGHT)
      boulder(61, 6, 1)
      assert_equal [[6, 6, 6], [6, 1]], pushed_route(Goal.onto(7, 2)) { |r, g| [r.to_a, [g[:x], g[:y]]] }
    end
  end

  test "stops a slide in front of a boulder standing on the ice" do
    on_row("#@.......#", "#####.####") do
      (2..7).each { |x| $game_map.set_terrain(x, 1, ICE) }
      boulder(61, 5, 1)
      assert_equal [[6], [5, 1]], pushed_route(Goal.onto(5, 2)) { |r, g| [r.to_a, [g[:x], g[:y]]] }
    end
  end

  test "stops a slide on the last tile of ice in front of a boulder just past it" do
    on_row("#@.......#", "#####.####") do
      (2..4).each { |x| $game_map.set_terrain(x, 1, ICE) }
      boulder(61, 5, 1)
      assert_equal [[6], [5, 1]], pushed_route(Goal.onto(5, 2)) { |r, g| [r.to_a, [g[:x], g[:y]]] }
    end
  end

  test "in a game whose pushed boulders slide, a boulder pushed onto ice comes to rest past it" do
    on_row("#@.......#") do
      (4..6).each { |x| $game_map.set_terrain(x, 1, ICE) }
      boulder(61, 3, 1)
      first = lambda { |r, g| [r.to_a, [g[:x], g[:y]]] }
      assert_equal [[6], [3, 1]], pushed_route(rock_goal(3, 1, [5, 1, 5, 1]), &first), "elsewhere one tile a push"
      sliding do
        assert_nil pushed_route(rock_goal(3, 1, [5, 1, 5, 1])) { |r, _g| r }, "it slides past (5,1)"
        assert_equal [[6], [3, 1]], pushed_route(rock_goal(3, 1, [7, 1, 7, 1]), &first), "to (7,1) in one push"
      end
    end
  end

  test "keeps the same tile on the two levels of a bridge apart" do
    pushes = PokeAccess::Routes::Pushes
    refute_equal pushes.pack([3, 1, [], 0]), pushes.pack([3, 1, [], 1])
  end

  private

  Goal = PokeAccess::Routes::Goal

  def on_row(row, below = nil)
    wall = "#" * row.length
    $game_map.load_grid([wall, row, below || wall, wall])
    yield
  ensure
    World.clear_events
    $game_map.clear_ledges
    $game_map.clear_grid
  end

  def boulder(id, x, y)
    ev = World.touch(:id => id, :name => "Boulder", :x => x, :y => y, :trigger => 0, :sprite => "boulder",
                     :list => [TestCmd.new(355, ["pbPushThisBoulder"])])
    ev.blocking = true
    def ev.passableStrict?(x, y, d)
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0)); ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      return true if through
      !$game_map.blocked?(nx, ny)
    end
    PokeAccess::Pathfinder.invalidate_cache(true)
    ev
  end

  def pushed_route(goal)
    r = PokeAccess::Routes::Pushes.route(goal)
    r && yield(r[0], r[1])
  end

  # A goal that takes the boulder starting on (x, y) into the box [x0, y0, x1, y1].
  def rock_goal(x, y, box)
    k = PokeAccess::Routes.pkey(x, y)
    PokeAccess::Routes::Pushes::RockGoal.new(k, x, y, box, PokeAccess::Routes::Effects.boulder_index[k])
  end

  # Runs the block in a game whose pushed boulders slide on ice (Pushes.sliding_rocks!), put back after.
  def sliding
    pushes = PokeAccess::Routes::Pushes
    was = pushes.instance_variable_get(:@sliding)
    pushes.sliding_rocks!
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    pushes.instance_variable_set(:@sliding, was)
  end
end
