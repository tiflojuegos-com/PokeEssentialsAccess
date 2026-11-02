# Boon's Terrain Tag Side Stairs (plugins/boon_side_stairs.rb): a press left or right on a stair tile walks the slope a
# row up or down, and a step onto a slope from level ground drops a row on its way down, as Game_Player#move_left and
# #move_right play them; the route finder walks those presses, none of them taken for a hop.
class BoonSideStairsTest < PokeAccessTest
  Stairs = PokeAccess::BoonSideStairs
  PF = PokeAccess::Pathfinder
  LEFT = 24
  RIGHT = 25

  test "going down a left stair takes each press left a row down, onto the stair's next tile" do
    with_stairs do
      grid(["######",
            "#....#",
            "#....#",
            "#....#",
            "######"], [2, 2] => LEFT, [3, 1] => LEFT)
      assert_equal [2, 2, 1], Stairs.leave(3, 1, 4), "down the slope"
    end
  end

  test "going up a stair takes the press a row up, whatever the tile there" do
    with_stairs do
      grid(["######",
            "#....#",
            "#....#",
            "######"], [1, 2] => LEFT, [3, 2] => RIGHT)
      assert_equal [[2, 1, 1], [2, 1, 1]], [Stairs.leave(1, 2, 6), Stairs.leave(3, 2, 4)], "a left stair going right, a right one going left"
    end
  end

  test "going down a right stair takes each press right a row down" do
    with_stairs do
      grid(["######",
            "#....#",
            "#....#",
            "######"], [2, 1] => RIGHT, [3, 2] => RIGHT)
      assert_equal [3, 2, 1], Stairs.leave(2, 1, 6)
    end
  end

  test "on the way down a press stays on its row when the tile below ahead is no stair of its own" do
    with_stairs do
      grid(["######",
            "#....#",
            "#....#",
            "######"], [3, 1] => LEFT, [2, 2] => RIGHT)
      assert_equal [2, 1, 1], Stairs.leave(3, 1, 4), "the tile ahead, on the same row"
    end
  end

  test "a press off the slope with no way ahead is no step" do
    with_stairs do
      grid(["####",
            "#.##",
            "####"], [1, 1] => LEFT)
      assert_equal false, Stairs.leave(1, 1, 6)
    end
  end

  test "an up or down press and a tile off the stairs are left to the engine" do
    with_stairs do
      grid(["####",
            "#..#",
            "#..#",
            "####"], [1, 1] => LEFT)
      assert_equal [nil, nil, nil], [Stairs.leave(1, 1, 8), Stairs.leave(1, 1, 2), Stairs.leave(2, 2, 4)]
    end
  end

  test "a step from level ground drops a row only on the way down the slope" do
    with_stairs do
      grid(["#####",
            "#...#",
            "#...#",
            "#####"], [2, 1] => LEFT, [1, 1] => RIGHT)
      assert_equal [[2, 2, 1], nil, [1, 2, 1], nil, nil],
                   [Stairs.arrival(2, 1, 4), Stairs.arrival(2, 1, 6), Stairs.arrival(1, 1, 6), Stairs.arrival(1, 1, 4),
                    Stairs.arrival(1, 2, 4)]
    end
  end

  test "a press from one stair onto the other kind drops a row on its way down" do
    with_stairs do
      grid(["######",
            "#....#",
            "#....#",
            "#....#",
            "######"], [3, 1] => RIGHT, [2, 1] => LEFT)
      assert_equal [2, 2, 1], Stairs.leave(3, 1, 4), "a right stair's press left, onto a left stair"
    end
  end

  test "a step up or down onto a stair stays on it" do
    with_stairs do
      grid(["####",
            "#..#",
            "#..#",
            "####"], [1, 1] => RIGHT, [2, 1] => LEFT)
      assert_equal [nil, nil, nil, nil], [8, 2].flat_map { |d| [Stairs.arrival(1, 1, d), Stairs.arrival(2, 1, d)] }
    end
  end

  test "the tile along the slope is asked for by the stair's own direction, whichever the press, as the script does" do
    with_stairs do
      grid(["#####",
            "#...#",
            "#...#",
            "#...#",
            "#####"], [2, 2] => LEFT)
      assert_equal [[1, 3, 4], [2, 2, 4]], asked { Stairs.leave(2, 2, 4) }, "a left stair, going left"
      assert_equal [[3, 1, 4], [2, 2, 6]], asked { Stairs.leave(2, 2, 6) }, "a left stair, going right"
      $game_map.set_terrain(2, 2, RIGHT)
      assert_equal [[1, 1, 6], [2, 2, 4]], asked { Stairs.leave(2, 2, 4) }, "a right stair, going left"
      assert_equal [[3, 3, 6], [2, 2, 6]], asked { Stairs.leave(2, 2, 6) }, "a right stair, going right"
    end
  end

  test "from a stair the route finder walks down its slope press by press, and off it along the row" do
    with_stairs do
      grid(["#######",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######"], [4, 1] => LEFT, [3, 2] => LEFT, [2, 3] => LEFT)
      steps = traced(4, 1, 0, [4, 4, 4])
      assert_equal [[3, 2], [2, 3], [1, 3]], steps.map { |s| [s.x, s.y] }
      assert_equal [:walk, :walk, :walk], steps.map { |s| s.kind }
    end
  end

  test "the route finder walks the presses of a slope, no hop among them" do
    with_stairs do
      grid(["#######",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######"], [4, 1] => LEFT, [3, 2] => LEFT)
      steps = traced(5, 1, 0, [4, 4, 4])
      assert_equal [[4, 2], [3, 3], [2, 3]], steps.map { |s| [s.x, s.y] }, "onto the stair a row down, along it, off it"
      assert_equal [:walk, :walk, :walk], steps.map { |s| s.kind }
    end
  end

  test "with no stairs in the game the rules own no tile" do
    Stairs.instance_variable_set(:@tags, nil)
    grid(["####",
          "#..#",
          "####"])
    assert_equal [[], nil, nil], [Stairs.tags, Stairs.leave(1, 1, 6), Stairs.arrival(2, 1, 6)]
  end

  private

  # Runs the block with the script's stair terrains defined as the plugin reads them, taken away after.
  def with_stairs
    PBTerrain.const_set(:StairLeft, LEFT)
    PBTerrain.const_set(:StairRight, RIGHT)
    Stairs.instance_variable_set(:@tags, nil)
    yield
  ensure
    PBTerrain.send(:remove_const, :StairLeft)
    PBTerrain.send(:remove_const, :StairRight)
    Stairs.instance_variable_set(:@tags, nil)
  end

  # The tiles the block asks the world about, as [x, y, direction], the world answering that each is closed.
  def asked
    probe = PokeAccess::World::Probe
    keep = probe.method(:step?)
    tiles = []
    probe.define_singleton_method(:step?) do |x, y, d, *_rest|
      tiles.push([x, y, d])
      false
    end
    yield
    tiles
  ensure
    probe.define_singleton_method(:step?, keep)
  end

  # Loads rows as the test map, each tile of terrain given its tag, the player on its top left floor.
  def grid(rows, terrain = {})
    $game_map.clear_ledges
    $game_map.clear_grid
    $game_map.load_grid(rows)
    terrain.each { |(x, y), t| $game_map.set_terrain(x, y, t) }
    PF.invalidate_cache(true)
  end
end
