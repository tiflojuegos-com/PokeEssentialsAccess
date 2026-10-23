# Hooks.wrap_singleton wraps a game module's own function (Module.x) as wrap_kernel wraps Kernel's: around bodies nest
# around the call, before and after bodies see its arguments (the after one its result too), beneath a module
# prepended to the singleton, and an absent module or function is recorded, not raised on.

# A game module's own functions, each wrapped by one test only.
module PaSingletonRig
  def self.run(a, b = 1); a * b; end
  def self.crash(x); raise ArgumentError, "bad #{x}"; end
  def self.timed(x); x * 2; end
  def self.fails(x); raise ArgumentError, "bad #{x}"; end
  def self.nested(x); x + 1; end
  def self.hidden(x); x; end
  private_class_method :hidden
  def self.calls_hidden(x); hidden(x); end
end

# A module function a module prepended to its singleton overrides (Module#prepend, Ruby 2+).
module PaPrependedRig
  def self.fetch(x); "own:#{x}"; end
end
PaPrependedRig.singleton_class.send(:prepend, Module.new { define_method(:fetch) { |x| "patch>" + super(x) } })

class WrapSingletonTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  test "wraps beneath a module prepended to the singleton, without looping" do
    Hooks.wrap_singleton("PaPrependedRig", :fetch, "spec_prepend", :around) do |_args, call_next|
      "wrap>" + call_next.call
    end
    assert_equal "patch>wrap>own:1", unless_looping { PaPrependedRig.fetch(1) },
                 "the module, then the wrapper, then the function's own body"
  end

  test "an around body runs around the call with its arguments and keeps its result" do
    trace = []
    Hooks.wrap_singleton("PaSingletonRig", :run, "spec_run", :around) do |args, call_next|
      trace.push([:enter, args.dup])
      r = call_next.call
      trace.push([:leave, r])
      r
    end
    assert_equal [12, [[:enter, [3, 4]], [:leave, 12]]], [PaSingletonRig.run(3, 4), trace]
  end

  test "an around body's ensure runs when the function raises, and the raise goes on" do
    trace = []
    Hooks.wrap_singleton("PaSingletonRig", :crash, "spec_crash", :around) do |_args, call_next|
      begin
        call_next.call
      ensure
        trace.push(:leave)
      end
    end
    assert_raises(ArgumentError) { PaSingletonRig.crash(1) }
    assert_equal [:leave], trace
  end

  test "before and after bodies see the arguments, the after body the result too" do
    seen = []
    [:before, :after].each do |timing|
      Hooks.wrap_singleton("PaSingletonRig", :timed, "spec_timed", timing) { |args, r| seen.push([timing, args, r]) }
    end
    assert_equal [6, [[:before, [3], nil], [:after, [3], 6]]], [PaSingletonRig.timed(3), seen]
  end

  test "an after body is skipped when the function raises" do
    seen = []
    Hooks.wrap_singleton("PaSingletonRig", :fails, "spec_fails", :after) { |_args, r| seen.push(r) }
    assert_raises(ArgumentError) { PaSingletonRig.fails(1) }
    assert_equal [], seen
  end

  test "a function wrapped twice nests its around bodies, the first registered outermost" do
    trace = []
    [:outer, :inner].each do |tag|
      Hooks.wrap_singleton("PaSingletonRig", :nested, "spec_nested", :around) do |_args, call_next|
        trace.push([tag, :in])
        r = call_next.call
        trace.push([tag, :out])
        r
      end
    end
    got = unless_looping { PaSingletonRig.nested(1) }
    assert_equal [2, [[:outer, :in], [:inner, :in], [:inner, :out], [:outer, :out]]], [got, trace]
  end

  test "a private function is wrapped too" do
    seen = []
    Hooks.wrap_singleton("PaSingletonRig", :hidden, "spec_hidden", :before) { |args, _r| seen.push(args.dup) }
    assert_equal [5, [[5]]], [PaSingletonRig.calls_hidden(5), seen]
  end

  test "an absent function or module is recorded as absent, not raised on" do
    got = keeping_fn_absent do
      Hooks.wrap_singleton("PaSingletonRig", :missing_function, "spec_absent", :around) { |_a, n| n.call }
      Hooks.wrap_singleton("PaNoSuchModule", :run, "spec_absent", :around) { |_a, n| n.call }
      Hooks.fn_absent.dup
    end
    assert_equal ["PaSingletonRig.missing_function", "PaNoSuchModule.run"], got
  end

  private

  # The block's value, or :looped when the wrapper calls itself without end.
  def unless_looping
    yield
  rescue SystemStackError
    :looped
  end

  # The block's value with the absent functions' record emptied for it, the record put back after.
  def keeping_fn_absent
    was = Hooks.fn_absent.dup
    Hooks.fn_absent.clear
    yield
  ensure
    Hooks.fn_absent.replace(was)
  end
end
