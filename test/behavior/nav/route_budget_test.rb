# One route, one budget: every search inside an operation shares its Routes::Limits, closed with it even on a raise;
# the budget stops a search by the route limit setting (a deadline read every CHECK states, astar_max, or never).
class RouteBudgetTest < PokeAccessTest
  Pathfinder = PokeAccess::Pathfinder
  Limits = PokeAccess::Routes::Limits

  test "shares one budget with every search inside an operation, nested ones included" do
    Pathfinder.with_limits do |budget|
      assert_same budget, Pathfinder.context.limits, "the operation carries it"
      assert_same budget, Pathfinder.limits, "a search inside it is handed it"
      assert_same budget, Pathfinder.with_limits { |inner| inner }, "a nested operation awards itself no fresh one"
      assert_same budget, Pathfinder.searching { |inner| inner }, "nor does a nested search"
    end
  end

  test "closes the operation and its budget with the outermost search" do
    Pathfinder.with_limits { Pathfinder.with_limits { nil } }
    assert_nil Pathfinder.context
  end

  test "gives the next operation a budget of its own" do
    first = Pathfinder.with_limits { |l| l }
    refute_same first, Pathfinder.with_limits { |l| l }
  end

  test "closes an operation whose search raises, passing the error on" do
    assert_raises(RuntimeError) { Pathfinder.with_limits { raise "boom" } }
    assert_nil Pathfinder.context
  end

  test "closes a budget with the outermost search that opened it, even inside an open frame" do
    Pathfinder.with_gates_open do
      first = Pathfinder.with_limits { |l| l }
      refute_same first, Pathfinder.with_limits { |l| l }, "each search in the frame opens its own"
      assert_nil Pathfinder.context.limits, "and none is left open between them"
    end
  end

  test "outside any operation, hands each ask a fresh budget from the settings" do
    PokeAccess::Config.astar_max = 321
    first = Pathfinder.limits
    refute_same first, Pathfinder.limits
    assert_equal [:effort, 321], first.key
  end

  test "takes the budget the settings ask for, keyed by its mode and its size" do
    { [:time, 300, 20] => [:time, 20], [:effort, 300, 20] => [:effort, 300],
      [:none, 300, 20] => [:none, nil] }.each do |(limit, nodes, ms), key|
      PokeAccess::Config.route_limit = limit
      PokeAccess::Config.astar_max = nodes
      PokeAccess::Config.route_budget_ms = ms
      assert_equal key, Limits.from_config.key, "under #{limit}"
    end
  end

  test "takes a setting it cannot read at that setting's default" do
    default = lambda { |key| PokeAccess::Config.setting(key).default }
    PokeAccess::Config.astar_max = 300
    PokeAccess::Config.route_limit = :time
    time = with_unreadable(:route_budget_ms) { Limits.from_config.key }
    PokeAccess::Config.route_limit = :effort
    effort = with_unreadable(:astar_max) { Limits.from_config.key }
    mode = with_unreadable(:route_limit) { Limits.from_config.key }
    assert_equal [[:time, default.call(:route_budget_ms)], [:effort, default.call(:astar_max)],
                  [default.call(:route_limit), 300]], [time, effort, mode]
  end

  test "takes an unknown limit for the effort limit" do
    budget = Limits.new(:soon, 10, 8)
    assert_equal [:effort, [:effort, 10], false, true], [budget.mode, budget.key, budget.spent?(10), budget.spent?(11)]
  end

  test "under the time limit, reads the deadline only every CHECK states" do
    with_clock(100.0) do |now|
      budget = Limits.new(:time, 300, 8)
      now[0] = 200.0
      check = Limits::CHECK
      stops = [1, check - 1, check, check + 1, 2 * check].map { |i| budget.spent?(i) }
      assert_equal [false, false, true, false, true], stops
    end
  end

  test "under the time limit, stops a search once the clock is past the deadline, not at it" do
    with_clock(100.0) do |now|
      budget = Limits.new(:time, 300, 8)
      now[0] = 100.0 + 8 / 1000.0
      at = [budget.spent?(Limits::CHECK), budget.time_spent?]
      now[0] = 100.009
      assert_equal [[false, false], [true, true]], [at, [budget.spent?(Limits::CHECK), budget.time_spent?]]
    end
  end

  test "counts each stop it makes, and only those" do
    budget = Limits.new(:effort, 10, 8)
    counts = [10, 11, 12].map { |i| [budget.spent?(i), budget.cuts] }
    assert_equal [[false, 0], [true, 1], [true, 2]], counts
  end

  test "counts a search stopped by a cap of its own, answering nil for it" do
    budget = Limits.new(:effort, 10, 8)
    assert_equal [nil, 1], [budget.cut!, budget.cuts]
  end

  test "with the effort limit, keeps no clock and stops a search once past astar_max states" do
    with_clock(100.0) do |now|
      budget = Limits.new(:effort, 10, 8)
      now[0] = 1000.0
      assert_equal [false, false, true], [budget.time_spent?, budget.spent?(10), budget.spent?(11)]
    end
  end

  test "with no limit, never stops a search" do
    with_clock(100.0) do |now|
      budget = Limits.new(:none, 10, 8)
      now[0] = 1000.0
      assert_equal [true, false, false, 0],
                   [budget.none?, budget.spent?(Limits::CHECK * 1000), budget.time_spent?, budget.cuts]
    end
  end

  private

  # Runs the block with PokeAccess.clock reading now[0], the seconds the block sets through now; the clock put back
  # after.
  def with_clock(start)
    now = [start]
    clock = PokeAccess.singleton_class
    clock.send(:alias_method, :clock__route_budget, :clock)
    clock.send(:define_method, :clock) { now[0] }
    yield now
  ensure
    clock.send(:alias_method, :clock, :clock__route_budget)
    clock.send(:remove_method, :clock__route_budget)
  end

  # The block's value with the setting key raising when read, its reader put back after.
  def with_unreadable(key)
    meta = PokeAccess::Config.singleton_class
    kept = :"#{key}__route_budget"
    meta.send(:alias_method, kept, key)
    meta.send(:define_method, key) { raise "unreadable" }
    yield
  ensure
    meta.send(:alias_method, key, kept)
    meta.send(:remove_method, kept)
  end
end
