# The conveyor belts of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/conveyors_rv.rb): a step
# onto a belt ends where the belts carry the player, each tile its own way, until off them or blocked; a closed loop
# of belts is no step, since the game would never let go.
Harness.load_common("rv_common")

class RvConveyorsTest < PokeAccessTest
  DOWN = 20
  LEFT = 21
  RIGHT = 22
  UP = 23

  test "carries the player along the belts, each tile its own way, until off them" do
    on_belts(["#######", "#@....#", "#.....#", "#.....#", "#######"], [2, 1, RIGHT], [3, 1, DOWN], [3, 2, DOWN]) do
      assert_equal [3, 3, :slide], step_right_from(1, 1)
    end
  end

  test "stops on the belt tile whose way is blocked" do
    on_belts(["######", "#@..##", "######"], [2, 1, RIGHT], [3, 1, RIGHT]) do
      assert_equal [3, 1, :slide], step_right_from(1, 1)
    end
  end

  test "stops short of a boulder a push search has on the belts' way, though the boulders are lent through" do
    on_belts(["#######", "#@....#", "#######"], [2, 1, RIGHT], [3, 1, RIGHT]) do
      rock = lambda { |x, y| x == 4 && y == 1 }
      assert_equal [3, 1, :slide], PokeAccess::Routes::Moves.with_rocks(rock) { step_right_from(1, 1) }
    end
  end

  test "is no step onto a loop of belts the player never leaves" do
    on_belts(["######", "#@...#", "#....#", "######"], [2, 1, RIGHT], [3, 1, DOWN], [3, 2, LEFT], [2, 2, UP]) do
      assert_nil step_right_from(1, 1)
    end
  end

  private

  def on_belts(rows, *belts)
    rules = PokeAccess::Routes::Moves.instance_variable_get(:@arrival_rules)
    saved = rules.dup
    names = { :DownConveyor => DOWN, :LeftConveyor => LEFT, :RightConveyor => RIGHT, :UpConveyor => UP }
    added = names.keys.reject { |n| PBTerrain.const_defined?(n) }
    added.each { |n| PBTerrain.const_set(n, names[n]) }
    PokeAccess::World::Terrain.reset!
    PokeAccess::ConveyorsRV.bind
    $game_map.load_grid(rows)
    belts.each { |x, y, tag| $game_map.set_terrain(x, y, tag) }
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    rules.replace(saved)
    added.each { |n| PBTerrain.send(:remove_const, n) } if added
    PokeAccess::ConveyorsRV.instance_variable_set(:@ways, {})
    $game_map.clear_grid
    PokeAccess::World::Terrain.reset!
  end

  def step_right_from(x, y)
    moves = PokeAccess::Routes::Moves
    s = PokeAccess::Pathfinder.searching { moves.step(x, y, 0, PokeAccess::Routes::DIR_OF[6], 0) }
    s && [s.x, s.y, s.kind]
  end
end
