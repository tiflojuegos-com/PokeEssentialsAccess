# hpa_search never mutates the cached HPA* graph: no keys gained, no writing default-proc left on it (hpa_arena and
# hpa_fresh_grid come from test/support/hpa_helpers.rb).
Suite.define("pathfinder: hpa_search never mutates the cached graph") do
  pf = PokeAccess::Pathfinder
  prev = [PokeAccess::Config.route_cache, PokeAccess::Config.route_reach,
          PokeAccess::Config.astar_max, PokeAccess::Config.path_algorithm]
  PokeAccess::Config.route_cache = false
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  PokeAccess::Config.path_algorithm = :hpa

  hpa_fresh_grid(hpa_arena("."))
  gr = pf.hpa_graph
  truthy "the graph builds", gr.is_a?(Hash)
  adj_before = gr[:adj].length
  byc_before = gr[:byc].length
  truthy "the graph has portals", adj_before > 0

  3.times do
    r = pf.hpa_search(22, 12)
    truthy "the search still routes", r.is_a?(Array) && !r.empty?
  end
  pf.hpa_search(2, 1)

  eq "adj gained no keys after repeated searches", gr[:adj].length, adj_before
  eq "byc gained no keys after repeated searches", gr[:byc].length, byc_before
  falsy "no default-proc remains on the cached adjacency", gr[:adj].default_proc
  falsy "no default-proc remains on the cached cluster index", gr[:byc].default_proc
ensure
  PokeAccess::Config.route_cache = prev[0]
  PokeAccess::Config.route_reach = prev[1]
  PokeAccess::Config.astar_max = prev[2]
  PokeAccess::Config.path_algorithm = prev[3]
end
