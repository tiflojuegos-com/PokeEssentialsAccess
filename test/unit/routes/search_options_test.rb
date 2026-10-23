# The search options each algorithm takes: weighted A*'s heuristic weight (1.25 to 3 times the distance, 1.5 unless
# set) and HPA*'s block size, each row shown only with its algorithm; the HPA* graph is built again for another size.

class SearchOptionsTest < PokeAccessTest
  test "weighs weighted A*'s heuristic by the chosen weight, in quarters" do
    { :w125 => [4, 5], :w150 => [4, 6], :w200 => [4, 8], :w300 => [4, 12] }.each do |w, pair|
      PokeAccess::Config.astar_weight = w
      assert_equal pair, PokeAccess::Pathfinder.algo_weights(:weighted), "for #{w}"
    end
  end

  test "keeps 1.5 times the distance for an unknown weight" do
    PokeAccess::Config.astar_weight = :w999
    assert_equal [4, 6], PokeAccess::Pathfinder.algo_weights(:weighted)
  end

  test "shows each option's row only with its algorithm" do
    cfg = PokeAccess::Config
    rows = { :astar_weight => :weighted, :hpa_cluster => :hpa }
    rows.each do |key, algo|
      setting = cfg.settings.find { |s| s.key == key }
      cfg.path_algorithm = algo
      assert_equal true, cfg.visible?(setting), "#{key} with #{algo}"
      cfg.path_algorithm = :astar
      assert_equal false, cfg.visible?(setting), "#{key} with A*"
    end
  end

  test "builds the HPA* graph again for another block size" do
    pf = PokeAccess::Pathfinder
    $game_map.load_grid(["#" * 32] + Array.new(20) { "#" + "." * 30 + "#" } + ["#" * 32])
    pf.invalidate_cache(true)
    PokeAccess::Config.hpa_cluster = 10
    ten = pf.hpa_graph
    PokeAccess::Config.hpa_cluster = 6
    six = pf.hpa_graph
    refute_same ten, six
    assert_same six, pf.hpa_graph, "and keeps it while the size stays"
  ensure
    $game_map.clear_grid
  end
end
