# Hooks bind to a class's private methods, initialize among them: the original runs between the hooks, a wrapped
# private method stays private and a public one public.

# A game class whose constructor the hooks watch; built is what the constructor was handed.
class HookInitProbe
  attr_reader :built

  def initialize(*args)
    @built = args
  end
end

# A game class with a private helper its public method calls, and a public method beside it.
class HookPrivateProbe
  def reveal
    secret
  end

  def shown
    :shown
  end

  private

  def secret
    :kept
  end
end

class HookInitializeTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  test "hooks bind before and after a private initialize, the constructor running between them" do
    seen = []
    bound = [Hooks.before_hook("HookInitProbe", :initialize) { |inst, args| seen.push([:before, inst.built, args]) },
             Hooks.after_hook("HookInitProbe", :initialize) { |inst, _r, args| seen.push([:after, inst.built, args]) }]
    obj = HookInitProbe.new(:a, 2)
    assert_equal [true, true], bound, "both bind to the private constructor"
    assert_equal [:a, 2], obj.built, "the constructor got its arguments"
    assert_equal [[:before, nil, [:a, 2]], [:after, [:a, 2], [:a, 2]]], seen,
                 "the before body saw the object unbuilt, the after body built, each with the arguments"
  end

  test "a hook on a private method fires on the object's own calls, and the method stays private" do
    seen = []
    bound = Hooks.after_hook("HookPrivateProbe", :secret) { |_i, result, _a| seen.push(result) }
    obj = HookPrivateProbe.new
    assert_equal true, bound, "it binds to the private method"
    assert_equal :kept, obj.reveal, "the object's own call reaches the original"
    assert_equal [:kept], seen, "through the hook"
    assert_raises(NoMethodError, "no caller outside the object may call it") { obj.secret }
  end

  test "a hook on a public method leaves it public" do
    assert_equal true, Hooks.before_hook("HookPrivateProbe", :shown) { |_i, _a| nil }, "it binds"
    assert_equal :shown, HookPrivateProbe.new.shown, "a caller outside the object still reaches it"
  end
end
