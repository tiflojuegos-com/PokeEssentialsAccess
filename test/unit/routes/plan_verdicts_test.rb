# What a plan tells when its searches stop short: that there is no route, once the regions walked on meanwhile tell
# the target cannot be got to on foot; no assisted route through an obstacle after a search on foot cut short, which
# may have missed a way on foot; and a plan whose search on foot was left unsettled is never kept, so asking again
# goes on where the regions and the flood stopped.

class PlanVerdictsTest < PokeAccessTest
  POCKET = ["############",
            "#@.......#.#",
            "#........#.#",
            "#........###",
            "############"]
  DETOUR = ["###########",
            "#@.......G#",
            "#.#######.#",
            "#.#######.#",
            "#.#######.#",
            "#.#######.#",
            "#.........#",
            "###########"]
  OPEN = ["############",
          "#@.........#",
          "#..........#",
          "#..........#",
          "############"]

  test "says there is no route once the regions tell a walled-off target cannot be got to" do
    on_grid(POCKET, :regions) do
      assert_equal :none, planner.plan(10, 1).kind
    end
  end

  test "makes a plan its search on foot left unsettled again when asked again" do
    on_grid(OPEN, :astar) do
      makes = without_flood { counting_makes { 2.times { assert_equal :cut, planner.plan(10, 3).kind } } }
      assert_equal 2, makes
    end
  end

  test "offers no assisted route through an obstacle when the search on foot was cut short" do
    on_grid(DETOUR, :astar, 20) do
      World.event(:kind => :npc, :id => 80, :x => 5, :y => 1, :name => "Tree").blocking = true
      PokeAccess::Pathfinder.invalidate_cache(true)
      assert_equal :cut, without_flood { planner.plan(9, 1).kind }
    end
  end

  test "gets the route on a later question once the flood can tell" do
    on_grid(OPEN, :astar) do
      without_flood { planner.plan(10, 3) }
      assert_equal :walk, planner.plan(10, 3).kind
    end
  end

  private

  def planner; PokeAccess::Routes::Planner; end

  def on_grid(rows, algo, nodes = 3)
    cfg = PokeAccess::Config
    was = [cfg.astar_max, cfg.path_algorithm]
    cfg.astar_max = nodes
    cfg.path_algorithm = algo
    $game_map.load_grid(rows)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield
  ensure
    cfg.astar_max, cfg.path_algorithm = was
    $game_map.clear_grid
  end

  def without_flood
    flood = PokeAccess::Routes::Flood
    flood.singleton_class.send(:alias_method, :for_spec, :for)
    flood.define_singleton_method(:for) { |*_a| nil }
    yield
  ensure
    flood.singleton_class.send(:alias_method, :for, :for_spec)
    flood.singleton_class.send(:remove_method, :for_spec)
  end

  def counting_makes
    n = 0
    planner.singleton_class.send(:alias_method, :make_spec, :make)
    planner.define_singleton_method(:make) { |*a| n += 1; make_spec(*a) }
    yield
    n
  ensure
    planner.singleton_class.send(:alias_method, :make, :make_spec)
    planner.singleton_class.send(:remove_method, :make_spec)
  end
end
