# One route, one deadline: every search inside with_budget (probe, walking route, ledge route) shares it, nested ones
# included, and it closes with the route even on a raise; with route_auto off there is none. The clock is faked.
Suite.define("pathfinder: one route, one deadline") do
  pf = PokeAccess::Pathfinder
  prev = [PokeAccess::Config.route_auto, PokeAccess::Config.route_budget_ms]
  PokeAccess::Config.route_auto = true
  PokeAccess::Config.route_budget_ms = 8

  class << PokeAccess
    alias_method :clock__budget_spec, :clock
    def clock; @budget_spec_t = (@budget_spec_t || 0.0) + 1.0; end
  end

  falsy "no search operation, so no deadline, is open to begin with", pf.context

  outer = pf.with_budget do
    a = pf.search_deadline
    b = pf.search_deadline
    eq "every search inside one route sees the same deadline", a, b
    eq "and a nested search does not award itself a fresh budget",
       pf.with_budget { pf.search_deadline }, a
    a
  end
  falsy "the operation and its deadline are gone once the route is done", pf.context

  later = pf.with_budget { pf.search_deadline }
  truthy "the next route gets its own deadline, not the stale one", later > outer

  begin
    pf.with_budget { raise "boom" }
  rescue StandardError
  end
  falsy "a search that raises still closes its operation, deadline and all", pf.context

  PokeAccess::Config.route_auto = false
  eq "with the time mode off there is nothing to run out of",
     pf.with_budget { pf.search_deadline }, nil
ensure
  class << PokeAccess
    alias_method :clock, :clock__budget_spec
    remove_method :clock__budget_spec
  end
  PokeAccess::Config.route_auto = prev[0]
  PokeAccess::Config.route_budget_ms = prev[1]
end
