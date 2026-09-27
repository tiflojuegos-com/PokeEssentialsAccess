# One search operation, one SearchContext: whatever wrapper opens it, the searches nested inside share it, and it is
# gone when the outermost ends, even on a raise.
Suite.define("pathfinder: a search operation shares one context and drops it when it ends") do
  pf = PokeAccess::Pathfinder
  PokeAccess::Config.route_reach = 128
  PokeAccess::Config.astar_max = 5000
  $game_map.load_grid(["#######", "#@....#", "#.....#", "#######"])
  pf.invalidate_cache(true)

  falsy "no operation is open between searches", pf.context
  falsy "and nothing is searching", pf.searching?

  seen = pf.searching do
    outer = pf.context
    inner = pf.searching { [pf.context, pf.context.depth, pf.searching?] }
    [outer, outer.depth, outer.vehicle, inner]
  end
  truthy "a nested search runs in the outer one's context", seen[3][0].equal?(seen[0])
  eq "and counts one level deeper", [seen[1], seen[3][1]], [1, 2]
  eq "the vehicle the search started with is at hand", seen[2], pf.vehicle_state
  truthy "and searching? says so inside", seen[3][2]
  falsy "the context is gone once the search ends", pf.context

  again = pf.searching { pf.context }
  falsy "the next search opens a context of its own", again.equal?(seen[0])

  gated = pf.with_gates_open { pf.searching { [pf.context.assisting, pf.context.depth] } }
  eq "a search inside an assisted operation runs in it, assisted", gated, [true, 1]
  falsy "and the assisted operation closes with its wrapper", pf.context

  begin
    pf.with_budget { pf.searching { raise "boom" } }
  rescue StandardError
  end
  falsy "a search that raises still closes its operation", pf.context
  falsy "and leaves nothing searching", pf.searching?

  eq "a route is still found through it all", pf.find_path(5, 2).is_a?(Array), true
end
