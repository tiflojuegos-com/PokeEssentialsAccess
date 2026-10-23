# The guide's track (Guide.track) across a ledge hop, which lands two tiles on: the landing is on the route, going back
# over the hop is a lookup, and the hop's press is checked against where it lands.
class GuideLedgeSpanTest < PokeAccessTest
  T = PokeAccess::I18n
  # A shaft down from the player at (1,2) to (1,7), with a ledge at (1,4) hopped downward onto (1,5).
  SHAFT = ['###',
           '#.#',
           '#@#',
           '#.#',
           '#.#',
           '#.#',
           '#.#',
           '#.#',
           '###']

  test "replayed, a plain press walks one tile and a press onto the ledge lands two tiles on" do
    shaft
    assert_equal [[[1, 3, 0]], [[1, 5, 0]]], [spots(traced(1, 2, 0, [2])), spots(traced(1, 3, 0, [2]))]
  end

  test "walking the way down, over the hop to its end, searches only once" do
    shaft
    guided do |loc, _pass|
      steps_aim(loc, bottom(loc))
      count_plans do |n|
        [[1, 2], [1, 3], [1, 5], [1, 6]].each { |x, y| walk_to(loc, x, y) }
        assert_equal [[T.t(:loc_arrived)], 1], [walk_to(loc, 1, 7), n[0]], "it arrives at the end it planned"
      end
    end
  end

  test "going back from the landing to before the hop searches nothing and says the leg from there again" do
    shaft
    guided do |loc, _pass|
      steps_aim(loc, bottom(loc))
      count_plans do |n|
        [[1, 2], [1, 3], [1, 5]].each { |x, y| walk_to(loc, x, y) }
        said = walk_to(loc, 1, 3)
        assert_equal [[T.t(:loc_jump, :dir => T.t(:dir_down))], 1], [said, n[0]]
      end
    end
  end

  test "half a second on at the takeoff, with the ledge still there, its checks plan nothing" do
    shaft
    guided do |loc, pass|
      steps_aim(loc, bottom(loc))
      count_plans do |n|
        [[1, 2], [1, 3]].each { |x, y| walk_to(loc, x, y) }
        pass.call(0.5)
        walk_to(loc, 1, 3)
        assert_equal 1, n[0]
      end
    end
  end

  test "a ledge gone from the way leaves the hop's press landing short, and half a second on it plans again" do
    shaft
    guided do |loc, pass|
      steps_aim(loc, bottom(loc))
      count_plans do |n|
        [[1, 2], [1, 3]].each { |x, y| walk_to(loc, x, y) }
        $game_map.clear_ledges
        pass.call(0.5)
        walk_to(loc, 1, 3)
        assert_equal 2, n[0]
      end
    end
  end

  private

  # Loads SHAFT with its ledge.
  def shaft
    hpa_fresh_grid(SHAFT)
    $game_map.place_ledge(1, 4, 2)
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # A spot in the wall under the shaft, acted on from its last tile (1,7): the way there is four presses down.
  def bottom(loc)
    loc::SurfaceTarget.new(1, 8, "cofre", :spot)
  end

  # The step guide's leg of n presses down.
  def leg(n)
    T.t(:loc_leg, :n => n, :dir => T.t(:dir_down))
  end

  # Runs the block in with_guide_state with the clock stopped (with_clock), yielding the locator and the clock's lambda.
  def guided
    with_guide_state { |loc| with_clock { |pass| yield loc, pass } }
  end

  # Runs the block with PokeAccess.clock standing still, yielding a lambda that moves it on by the seconds given.
  def with_clock
    now = [1000.0]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    yield lambda { |secs| now[0] += secs }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # Counts the plans made (Routes::Planner.plan) while the block runs, yielded as a one-element array.
  def count_plans
    pl = PokeAccess::Routes::Planner
    real = pl.method(:plan)
    n = [0]
    pl.define_singleton_method(:plan) { |*a| n[0] += 1; real.call(*a) }
    yield n
  ensure
    pl.define_singleton_method(:plan, real)
  end
end
