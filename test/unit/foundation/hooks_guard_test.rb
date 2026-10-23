# The reentrancy guard leaves evidence of what it silences: Hooks.suppressed holds each outer>inner pair once, the outer
# method's name and the inner hook's key, up to forty pairs.
class HooksGuardTest < PokeAccessTest
  # A reader driven from inside another hooked method, one class per test so each binds its own hooks.
  class Evidence
    def outer_drive; inner_read; end
    def inner_read; :read; end
  end

  # The same, called again and again.
  class Repeat
    def outer_drive; inner_read; end
    def inner_read; :read; end
  end

  # Two outer methods driving one reader, for the cap.
  class Capped
    def first_drive; inner_read; end
    def second_drive; inner_read; end
    def inner_read; :read; end
  end

  test "notes the pair it silences, the outer method and the inner hook's key, and the reader says nothing" do
    PokeAccess::Hooks.after_hook("HooksGuardTest::Evidence", :inner_read) do |_s, _r, _a|
      PokeAccess.speak("leido", true)
    end
    PokeAccess::Hooks.after_hook("HooksGuardTest::Evidence", :outer_drive) { |_s, _r, _a| nil }
    kept_suppressed do
      Evidence.new.outer_drive
      assert_equal ["outer_drive>HooksGuardTest::Evidence#inner_read"], PokeAccess::Hooks.suppressed
    end
    assert_nothing_spoken "the reader the guarded outer drives"
  end

  test "notes a pair once, however often it silences it" do
    PokeAccess::Hooks.after_hook("HooksGuardTest::Repeat", :inner_read) { |_s, _r, _a| nil }
    PokeAccess::Hooks.after_hook("HooksGuardTest::Repeat", :outer_drive) { |_s, _r, _a| nil }
    kept_suppressed do
      3.times { Repeat.new.outer_drive }
      assert_equal ["outer_drive>HooksGuardTest::Repeat#inner_read"], PokeAccess::Hooks.suppressed
    end
  end

  test "notes the fortieth pair and none after it" do
    PokeAccess::Hooks.after_hook("HooksGuardTest::Capped", :inner_read) { |_s, _r, _a| nil }
    PokeAccess::Hooks.after_hook("HooksGuardTest::Capped", :first_drive) { |_s, _r, _a| nil }
    PokeAccess::Hooks.after_hook("HooksGuardTest::Capped", :second_drive) { |_s, _r, _a| nil }
    kept_suppressed do
      earlier = (1..39).map { |i| "drive#{i}>Earlier#read" }
      PokeAccess::Hooks.suppressed.replace(earlier.dup)
      Capped.new.first_drive
      Capped.new.second_drive
      assert_equal earlier + ["first_drive>HooksGuardTest::Capped#inner_read"], PokeAccess::Hooks.suppressed
    end
  end

  private

  # Runs the block with the guard's evidence empty, the session's put back after.
  def kept_suppressed
    list = PokeAccess::Hooks.suppressed
    saved = list.dup
    list.clear
    yield
  ensure
    list.replace(saved)
  end
end
