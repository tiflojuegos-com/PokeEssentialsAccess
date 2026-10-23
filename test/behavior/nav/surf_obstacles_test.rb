# A planned surf crosses only the water a surfer can move on: a rock or a wall laid over the water (its tile still
# tagged as water underneath) stops it, as the engine refuses that move afloat.

class SurfObstaclesTest < PokeAccessTest
  OPEN = ["#########", "#@..~~~.#", "#########"]
  ROCKY = ["#########", "#@..~%~.#", "#########"]

  test "plans a surf across open water, pushing off from its shore" do
    with_tile_world(OPEN) do
      assert_equal [3, 1, 6], PokeAccess::Pathfinder.surf_plan(7, 1)
    end
  end

  test "plans no surf across a rock laid over the water" do
    with_tile_world(ROCKY) do
      assert_nil PokeAccess::Pathfinder.surf_plan(7, 1)
    end
  end

  test "makes no planned surf move into the rock, and keeps the one beside it" do
    moves = PokeAccess::Routes::Moves
    right = PokeAccess::Routes::DIR_OF[6]
    with_tile_world(ROCKY) do
      assert_nil moves.step(4, 1, 0, right, moves::SURF_PLAN)
      s = moves.step(3, 1, 0, right, moves::SURF_PLAN)
      assert_equal [4, 1, :surf], s && [s.x, s.y, s.kind]
    end
  end
end
