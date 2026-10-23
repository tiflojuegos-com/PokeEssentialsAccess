# Under a deadline (route_limit by time), JPS's scans read it: a scan over open ground runs long between two jump
# points, so a search whose time ran out is cut there, as A* is, instead of running on.

class JpsDeadlineTest < PokeAccessTest
  test "cuts a jump point search once its time ran out, partway along a long scan" do
    assert_equal :cut, open_ground_search(true)
  end

  test "finds the route while there is time" do
    assert_equal :found, open_ground_search(false)
  end

  private

  def open_ground_search(out_of_time)
    rs = PokeAccess::Routes
    cfg = PokeAccess::Config
    was = cfg.route_limit
    limits = rs::Limits
    limits.send(:alias_method, :time_spent_spec?, :time_spent?)
    limits.send(:define_method, :time_spent?) { out_of_time }
    $game_map.load_grid(["#" * 202, "#@" + "." * 199 + "#", "#" * 202])
    cfg.route_limit = :time
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::Pathfinder.searching do
      rs::Search.run(rs::Goal.onto(200, 1), rs::CostModel.new(:shortest), 0, :jps, 1).status
    end
  ensure
    limits.send(:alias_method, :time_spent?, :time_spent_spec?)
    limits.send(:remove_method, :time_spent_spec?)
    cfg.route_limit = was
    $game_map.clear_grid
  end
end
