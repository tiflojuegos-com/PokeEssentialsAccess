# One find_path is up to three searches -- the reachability probe, the walking route, then the route that
# allows ledge hops -- so a clock per search spends route_budget_ms, the option that promises "never spend
# more than this on a route", three times over. The interesting part is not the arithmetic: running out of
# time makes a search return nil, and returning nil is precisely what fires the NEXT search, so the cut-off
# feeds the work it exists to cut.
#
# The clock is faked here so the assertions are exact rather than "these two floats differ by a hair".
Suite.define("pathfinder: one route, one deadline") do
  pf = PokeAccess::Pathfinder
  prev = [PokeAccess::Config.route_auto, PokeAccess::Config.route_budget_ms]
  PokeAccess::Config.route_auto = true
  PokeAccess::Config.route_budget_ms = 8

  class << PokeAccess
    alias_method :clock__budget_spec, :clock
    def clock; @budget_spec_t = (@budget_spec_t || 0.0) + 1.0; end
  end

  falsy "no deadline is in scope to begin with", pf.instance_variable_get(:@budget_until)

  outer = pf.with_budget do
    a = pf.search_deadline
    b = pf.search_deadline
    eq "every search inside one route sees the same deadline", a, b
    eq "and a nested search does not award itself a fresh budget",
       pf.with_budget { pf.search_deadline }, a
    a
  end
  falsy "the deadline is gone once the route is done", pf.instance_variable_get(:@budget_until)

  later = pf.with_budget { pf.search_deadline }
  truthy "the next route gets its own deadline, not the stale one", later > outer

  # A search that blows up must not leave its deadline behind: the next route would inherit an hour that
  # already passed and give up on its first node check.
  begin
    pf.with_budget { raise "boom" }
  rescue StandardError
  end
  falsy "a search that raises still clears its deadline", pf.instance_variable_get(:@budget_until)

  # With the time mode off there is no deadline at all: the searches bound themselves by node count instead,
  # which is the old behaviour and must stay reachable.
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
