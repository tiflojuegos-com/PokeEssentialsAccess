# Limits#wider, for a search whose states are worth less than the tiles of one on foot: by effort it takes more states inside
# its block, with a deadline however fast the game's Ruby runs; the other modes stay as they are.

class LimitsWiderTest < PokeAccessTest
  LIMITS = PokeAccess::Routes::Limits

  test "takes times the states by effort inside the block, and only there" do
    limits = LIMITS.new(:effort, 100, 0)
    assert limits.spent?(101)
    limits.wider(4, 60) do
      refute limits.spent?(400)
      assert limits.spent?(401)
    end
    assert limits.spent?(101)
    refute limits.spent?(100)
  end

  test "stops by effort at its deadline, asked every so many states, and has none outside the block" do
    limits = LIMITS.new(:effort, 100, 0)
    limits.wider(4, -1) do
      assert limits.spent?(LIMITS::CHECK)
      refute limits.spent?(LIMITS::CHECK + 1)
      assert limits.time_spent?
    end
    refute limits.spent?(LIMITS::CHECK)
    refute limits.time_spent?
  end

  test "leaves no limit and a limit of time as they are" do
    none = LIMITS.new(:none, 100, 0)
    none.wider(4, -1) { refute none.spent?(LIMITS::CHECK * 1000) }
    timed = LIMITS.new(:time, 100, 60_000)
    timed.wider(4, -1) do
      refute timed.spent?(LIMITS::CHECK)
      refute timed.time_spent?
    end
    refute timed.time_spent?, "its own deadline is kept"
  end

  test "puts everything back when the block raises" do
    limits = LIMITS.new(:effort, 100, 0)
    assert_raises(ArgumentError) { limits.wider(4, -1) { raise ArgumentError } }
    assert limits.spent?(101)
    refute limits.time_spent?
  end
end
