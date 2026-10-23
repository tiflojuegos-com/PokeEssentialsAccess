# Hooks.rebind, run after an F12 reset has evaluated the game's scripts anew: each wrapper of the mod whose method the
# scripts replaced is put back around the method they define now, and a wrapper still in place is left alone.
class RebindTest < PokeAccessTest
  # A game class whose one method the scripts define.
  class PlantedScene
    def run; :first; end
  end

  # A game class nothing replaces.
  class PlantedStill
    def run; :still; end
  end

  # A game module with a singleton function.
  module PlantedOwner
    def self.say(x); x; end
  end

  test "puts back an instance hook the scripts replaced, around the method they define now" do
    seen = []
    put_back = with_own_bindings do
      PokeAccess::Hooks.after_hook("RebindTest::PlantedScene", :run) { |_s, r, _a| seen.push(r) }
      PlantedScene.new.run
      PlantedScene.class_eval { def run; :second; end }
      PlantedScene.new.run
      n = PokeAccess::Hooks.rebind
      [n, PlantedScene.new.run]
    end
    assert_equal [[1, :second], [:first, :second]], [put_back, seen]
  end

  test "leaves a wrapper still in place alone, so its hook runs once a call" do
    seen = []
    put_back = with_own_bindings do
      PokeAccess::Hooks.after_hook("RebindTest::PlantedStill", :run) { |_s, r, _a| seen.push(r) }
      n = PokeAccess::Hooks.rebind
      PlantedStill.new.run
      n
    end
    assert_equal [0, [:still]], [put_back, seen]
  end

  test "puts back the wrappers of a top-level function and of a module's singleton function" do
    seen = []
    put_back = with_own_bindings do
      Object.class_eval { def rebind_planted_fn; :one; end; private :rebind_planted_fn }
      PokeAccess::Hooks.wrap_global("rebind_planted_fn", "rebind_test") { |_a, r| seen.push(r) }
      PokeAccess::Hooks.wrap_singleton("RebindTest::PlantedOwner", "say", "rebind_test", :after) do |_a, r|
        seen.push(r)
      end
      Object.class_eval { def rebind_planted_fn; :two; end; private :rebind_planted_fn }
      PlantedOwner.module_eval { def self.say(x); x * 2; end }
      n = PokeAccess::Hooks.rebind
      send(:rebind_planted_fn)
      PlantedOwner.say(3)
      n
    end
    assert_equal [2, [:two, 6]], [put_back, seen]
  end

  test "keeps the frame's pulse on Input.update and the remapped buttons among the wrappers a reset puts back" do
    rows = PokeAccess::Hooks.instance_variable_get(:@bound)
    input = (class << Input; self; end)
    kept = [:update, :trigger?, :press?, :repeat?].select { |m| rows.any? { |r| r[0] == input && r[1] == m } }
    assert_equal [:update, :trigger?, :press?, :repeat?], kept
  end

  private

  # The block's value with Hooks keeping only the wrappers the block installs, the mod's own put back after.
  def with_own_bindings
    was = PokeAccess::Hooks.instance_variable_get(:@bound)
    PokeAccess::Hooks.instance_variable_set(:@bound, [])
    yield
  ensure
    PokeAccess::Hooks.instance_variable_set(:@bound, was)
  end
end
