# A search cut short that the flood cannot answer either (a flood cut on a map too large) is tried again with the
# reach estimate only by an algorithm whose frontier the estimate orders: Dijkstra, breadth- and depth-first would
# repeat the very same search.

class CutRetryTest < PokeAccessTest
  test "does not search again with the reach estimate for an algorithm it would not steer" do
    [:dijkstra, :bfs, :dfs].each do |algo|
      assert_equal [:cut, 1], cut_search(algo), "for #{algo}"
    end
  end

  test "searches again with the reach estimate for an algorithm it steers" do
    assert_equal [:cut, 2], cut_search(:astar)
  end

  private

  def cut_search(algo)
    rs = PokeAccess::Routes
    cfg = PokeAccess::Config
    was = [cfg.route_limit, cfg.astar_max]
    runs = 0
    search = rs::Search
    search.singleton_class.send(:alias_method, :run_spec, :run)
    search.define_singleton_method(:run) { |*a| runs += 1; run_spec(*a) }
    flood = rs::Flood
    flood.singleton_class.send(:alias_method, :for_spec, :for)
    flood.define_singleton_method(:for) { |*_a| nil }
    $game_map.load_grid(["############", "#@.........#", "#..........#", "#.........##", "#.........#.", "############"])
    cfg.route_limit = :effort
    cfg.astar_max = 3
    PokeAccess::Pathfinder.invalidate_cache(true)
    r = PokeAccess::Pathfinder.searching do
      search.best(rs::Goal.onto(11, 4), rs::CostModel.new(:shortest), 0, algo, nil)
    end
    [r.status, runs]
  ensure
    search.singleton_class.send(:alias_method, :run, :run_spec)
    search.singleton_class.send(:remove_method, :run_spec)
    flood.singleton_class.send(:alias_method, :for, :for_spec)
    flood.singleton_class.send(:remove_method, :for_spec)
    cfg.route_limit, cfg.astar_max = was
    $game_map.clear_grid
  end
end
