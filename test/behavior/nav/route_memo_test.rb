# The probe's memo beside the player: a step into the tile they stand on, which every engine refuses, is asked again
# from its origin and kept as the map has it, the player put back; a refusal that is the map's own is kept as such.
class RouteMemoTest < PokeAccessTest
  Probe = PokeAccess::World::Probe

  test "a step into the player's own tile is asked again from its origin and kept open" do
    corridor
    with_own_tile_refused do |asked|
      assert_equal true, Probe.step?(2, 1, 4), "the step is open"
      assert_equal [[2, 1, 4, 1, 1], [2, 1, 4, 2, 1]], asked, "[x, y, d, player x, player y] of each time it is asked"
      assert_equal Probe::OPEN, kept(2, 1, 4), "and it is kept open"
    end
  end

  test "a step the map itself refuses beside the player is kept as refused" do
    corridor
    with_own_tile_refused do |asked|
      assert_equal false, Probe.step?(2, 1, 6), "the wall at (3, 1) stops it"
      assert_equal [[2, 1, 6, 1, 1]], asked, "asked once, from where the player stands"
      assert_equal Probe::CLOSED, kept(2, 1, 6), "and it is kept so"
    end
  end

  test "a step into the player's own tile that the map shuts as well is kept as refused" do
    corridor
    $game_map.block_step(2, 1, 4)
    with_own_tile_refused do
      assert_equal false, Probe.step?(2, 1, 4), "asked from its origin it is still shut"
      assert_equal Probe::CLOSED, kept(2, 1, 4), "and it is kept so"
    end
  end

  test "the regions' walk keeps the steps beside the player as a single question would, and asks nothing again" do
    corridor
    with_own_tile_refused do |asked|
      PokeAccess::Routes::Regions.foot.tiles
      asked.clear
      assert_equal [true, false], [Probe.step?(2, 1, 4), Probe.step?(2, 1, 6)], "into the player's tile, into the wall"
      assert_equal [], asked, "both answered from what the walk kept"
    end
  end

  test "the tile the player stood on is open again once they step off it" do
    corridor
    with_own_tile_refused do
      PokeAccess::Routes::Regions.foot.tiles
      $game_player.x = 2
      assert_equal true, reached?(1, 1), "from the next tile the regions reach the one just left"
      assert_equal [4], walk_route(1, 1, true), "and the route back onto it is one step"
    end
  end

  test "a step asked again from its origin puts the player back where they stood, facing as before" do
    facing = $game_player.direction
    $game_map.load_grid(["######",
                         "#.@..#",
                         "######"])
    $game_player.direction = 8
    with_own_tile_refused do
      Probe.step?(3, 1, 4)
      assert_equal [2, 1, 8], [$game_player.x, $game_player.y, $game_player.direction]
    end
  ensure
    $game_player.direction = facing
  end

  test "a slide crosses the tile the player stands on" do
    $game_map.load_grid(["#######",
                         "#..@..#",
                         "#######"])
    (1..5).each { |x| $game_map.set_terrain(x, 1, 12) }
    mv = PokeAccess::Routes::Moves
    with_own_tile_refused do
      s = PokeAccess::Pathfinder.searching { mv.step(5, 1, 0, PokeAccess::Routes::DIR_OF[4], mv::LEDGE) }
      assert_equal [1, 1, 0, 1, nil, false, false, :slide], s.to_a, "the slide from the far side runs on to the wall"
    end
  end

  private

  # A corridor with a wall at (3, 1) between two floor tiles, the player at (1, 1).
  def corridor
    $game_map.load_grid(["######",
                         "#@.#.#",
                         "######"])
  end

  # The answer the memo keeps for the step from (x, y) toward d, off every bridge.
  def kept(x, y, d)
    Probe.instance_variable_get(:@memo)[Probe.memo_key(x, y, d, 0)]
  end

  # Runs the block with the player's passable? as the engines have it: a step into the player's own tile is refused.
  # The block gets the steps asked of it, as [x, y, d, player x, player y] each time.
  def with_own_tile_refused
    asked = []
    own = $game_player.method(:passable?)
    $game_player.define_singleton_method(:passable?) do |x, y, d|
      asked.push([x, y, d, self.x, self.y])
      dd = PokeAccess::DIR_DELTA[d]
      dd && x + dd[0] == self.x && y + dd[1] == self.y ? false : own.call(x, y, d)
    end
    yield asked
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end
end
