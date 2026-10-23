# A way across water the launch search runs out of states for is a route that could not be told, not one there is none
# of: the stop of its own budget counts as the operation's.

class LaunchCutTest < PokeAccessTest
  ISLANDS = ["##########",
             "#@~~~~~~.#",
             "##########"]

  test "tells a target across water past the launch's budget as cut, not as none" do
    with_tile_world(ISLANDS) do
      with_launch_nodes(2) do
        assert_equal :cut, PokeAccess::Routes::Planner.plan(8, 1).kind
      end
    end
  end

  test "plans the surf to a target across water within the launch's budget" do
    with_tile_world(ISLANDS) do
      assert_equal :surf, PokeAccess::Routes::Planner.plan(8, 1).kind
    end
  end

  private

  def with_launch_nodes(n)
    launch = PokeAccess::Routes::Launch
    was = launch::NODES
    launch.send(:remove_const, :NODES)
    launch.const_set(:NODES, n)
    yield
  ensure
    launch.send(:remove_const, :NODES)
    launch.const_set(:NODES, was)
  end
end
