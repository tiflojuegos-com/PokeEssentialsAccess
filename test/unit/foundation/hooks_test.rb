# Hooks chain bodies around game methods and functions keeping results and visibility, note typos, mute what an
# after-hooked original calls (not a container's, frame_hook's or before-hook's), and log a failing body once.
class HooksTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  # A method two after-hooks chain on.
  class Chain
    def greet(x); x * 2; end
  end

  # A parent and its child, whose method calls the parent's through super.
  class SuperBase
    def step(log); log << "base"; end
  end

  class SuperChild < SuperBase
    def step(log); log << "child"; super; end
  end

  # A method a module prepended to its class overrides, calling the class's own through super.
  class Prepended
    def show(log); log << "own"; :own; end
    prepend(Module.new { def show(log); log << "patch"; super; end })
  end

  # A method only a prepended module defines.
  class PrependedOnly
    prepend(Module.new { def solo; :module; end })
  end

  # A private method, and a private one a prepended module overrides.
  class Private
    private

    def secret; :hidden; end
  end

  class PrivatePrepended
    prepend(Module.new { def secret; super; end; private :secret })

    private

    def secret; :hidden; end
  end

  # A class that has one method and lacks the one a typo names.
  class Typo
    def real_method; :real; end
  end

  # A present method an optional hook binds.
  class Optional
    def present_method; :orig; end
  end

  # A driver whose original runs a nested loop of readers, as gen 6 runs a wild battle inside Game_Player#update.
  module NestedLoop
    def update(log); run_battle(log); :updated; end
    def run_battle(log); show_message(log); move_cursor(log); :fought; end
    def show_message(log); log << :message; end
    def move_cursor(log); log << :cursor; end
  end

  # One driver per kind of hook on update, as each binds its own hooks.
  class GuardedDriver; include NestedLoop; end
  class FrameDriver; include NestedLoop; end
  class ContainerDriver; include NestedLoop; end
  class OpenerDriver; include NestedLoop; end

  # An outer method whose original calls an inner one; one class for the dedup, one for the call after it.
  class Reentrant
    def outer; inner; :outer_done; end
    def inner; :inner_done; end
  end

  class Unwound
    def outer; inner; :outer_done; end
    def inner; :inner_done; end
    def boom; raise ArgumentError, "the original fails"; end
  end

  # Methods whose original raises, or whose hook bodies do.
  class AroundEnsure
    def boom; raise "kaboom"; end
  end

  class AroundFails
    def run; :ran; end
  end

  class Swallowed
    def open; :opened; end
    def read; :read; end
  end

  class FailsOnce
    def read; :read; end
  end

  class FailsTwice
    def read; :read; end
  end

  # The screen a hooked method runs on.
  class Screen
    def refresh; :refreshed; end
  end

  # Spellings of one class across games: a parent, its empty alias subclass and an unrelated class.
  class VarBase
    def paint; :painted; end
  end

  class VarAlias < VarBase; end

  class VarOther
    def paint; :other; end
  end

  test "runs every after-hook of a method, the last registered first, each with the original's result" do
    log = []
    Hooks.after_hook("HooksTest::Chain", :greet) { |_i, r, _a| log << "first:#{r}" }
    Hooks.after_hook("HooksTest::Chain", :greet) { |_i, r, _a| log << "second:#{r}" }
    assert_equal 10, Chain.new.greet(5), "the original's result"
    assert_equal ["second:10", "first:10"], log
  end

  test "hooks a parent and its overriding child apart, so a call through super fires both, the parent's first" do
    Hooks.after_hook("HooksTest::SuperBase", :step) { |_i, _r, a| a[0] << "base hook" }
    Hooks.after_hook("HooksTest::SuperChild", :step) { |_i, _r, a| a[0] << "child hook" }
    log = []
    SuperChild.new.step(log)
    assert_equal ["child", "base", "base hook", "child hook"], log
  end

  test "hooks a method a prepended module overrides beneath the module, so the call still ends" do
    Hooks.after_hook("HooksTest::Prepended", :show) { |_i, r, a| a[0] << "hook:#{r}" }
    log = []
    assert_equal :own, Prepended.new.show(log)
    assert_equal ["patch", "own", "hook:own"], log
  end

  test "leaves unhooked a method only a prepended module defines, which still answers, and says why in the marker" do
    assert_equal false, Hooks.after_hook("HooksTest::PrependedOnly", :solo) { |_i, _r, _a| }
    assert_equal :module, PrependedOnly.new.solo
    assert_equal 1, marker_lines(/wrap HooksTest::PrependedOnly#solo: solo exists only in a module prepended to/).length
  end

  test "keeps a hooked private method private, making nothing of it public" do
    fired = []
    [Private, PrivatePrepended].each do |klass|
      assert_equal true, Hooks.after_hook(klass.name, :secret) { |_i, r, _a| fired << r }, "#{klass} binds"
      assert_equal [true, []],
                   [klass.private_method_defined?(:secret), klass.public_instance_methods(false).grep(/secret/)],
                   "#{klass}: private, and nothing named after it public"
      assert_equal :hidden, klass.new.send(:secret), "#{klass} still answers"
    end
    assert_equal [:hidden, :hidden], fired
  end

  test "notes a bind on a method a present class lacks as a likely typo, once" do
    kept_records do
      2.times { assert_equal false, Hooks.after_hook("HooksTest::Typo", :typo_method) { |_i, _r, _a| } }
      assert_equal ["HooksTest::Typo#typo_method"], Hooks.missing
    end
  end

  test "notes nothing for a bind on a class this game lacks" do
    kept_records do
      assert_equal false, Hooks.after_hook("HooksTest::NoSuchClass", :whatever) { |_i, _r, _a| }
      assert_equal [], Hooks.missing
    end
  end

  test "keeps an optional bind on a missing method out of the typo list, for every kind of hook" do
    bodies = { :after_hook => lambda { |_i, _r, _a| }, :before_hook => lambda { |_i, _a| },
               :around_hook => lambda { |_i, nxt, _a| nxt.call } }
    kept_records do
      bodies.each do |kind, body|
        assert_equal false, Hooks.send(kind, "HooksTest::Typo", :"gone_#{kind}", :optional => true, &body), kind.to_s
      end
      assert_equal [], Hooks.missing
    end
  end

  test "binds an optional hook on a method that exists like any other" do
    fired = []
    bound = Hooks.after_hook("HooksTest::Optional", :present_method, :optional => true) { |_i, r, _a| fired << r }
    assert_equal true, bound
    assert_equal :orig, Optional.new.present_method
    assert_equal [:orig], fired
  end

  test "mutes the hooks of the other methods an after-hooked original calls, before- and after-hooks alike" do
    Hooks.before_hook("HooksTest::GuardedDriver", :show_message) { |_i, a| a[0] << :message_hook }
    Hooks.after_hook("HooksTest::GuardedDriver", :move_cursor) { |_i, _r, a| a[0] << :cursor_hook }
    Hooks.after_hook("HooksTest::GuardedDriver", :update) { |_i, _r, a| a[0] << :update_hook }
    log = []
    kept_records { assert_equal :updated, GuardedDriver.new.update(log) }
    assert_equal [:message, :cursor, :update_hook], log
  end

  test "runs a frame_hook's original unguarded, so the readers of a nested loop speak, and its body after" do
    Hooks.before_hook("HooksTest::FrameDriver", :show_message) { |_i, a| a[0] << :message_hook }
    Hooks.after_hook("HooksTest::FrameDriver", :move_cursor) { |_i, _r, a| a[0] << :cursor_hook }
    Hooks.frame_hook("HooksTest::FrameDriver", :update) { |_i, a| a[0] << :tick }
    log = []
    assert_equal :updated, FrameDriver.new.update(log)
    assert_equal [:message_hook, :message, :cursor, :cursor_hook, :tick], log
  end

  test "lets the methods a hook_container's original calls fire their hooks" do
    Hooks.after_hook("HooksTest::ContainerDriver", :move_cursor) { |_i, _r, a| a[0] << :cursor_hook }
    Hooks.after_hook("HooksTest::ContainerDriver", :update, :hook_container => true) do |_i, _r, a|
      a[0] << :update_hook
    end
    log = []
    assert_equal :updated, ContainerDriver.new.update(log)
    assert_equal [:message, :cursor, :cursor_hook, :update_hook], log
  end

  test "leaves hooked the methods a before-hooked original calls" do
    Hooks.before_hook("HooksTest::OpenerDriver", :update) { |_i, a| a[0] << :opening }
    Hooks.after_hook("HooksTest::OpenerDriver", :move_cursor) { |_i, _r, a| a[0] << :cursor_hook }
    log = []
    assert_equal :updated, OpenerDriver.new.update(log)
    assert_equal [:opening, :message, :cursor, :cursor_hook], log
  end

  test "leaves an after-hooked method its dedup slot, which the hook of a method it calls would have taken" do
    spoke = []
    [:inner, :outer].each do |meth|
      Hooks.after_hook("HooksTest::Reentrant", meth) do |i, _r, _a|
        spoke << meth if PokeAccess::Cursor.changed?(i, :reent_slot, :k1)
      end
    end
    kept_records { assert_equal :outer_done, Reentrant.new.outer }
    assert_equal [:outer], spoke
  end

  test "fires a method's hook again once the after-hooked call around it has returned, or raised" do
    fired = []
    Hooks.after_hook("HooksTest::Unwound", :inner) { |_i, r, _a| fired << r }
    Hooks.after_hook("HooksTest::Unwound", :outer) { |_i, _r, _a| }
    Hooks.after_hook("HooksTest::Unwound", :boom) { |_i, _r, _a| }
    holder = Unwound.new
    kept_records do
      holder.outer
      assert_raises(ArgumentError) { holder.boom }
      assert_equal :inner_done, holder.inner
    end
    assert_equal [:inner_done], fired, "only the call made on its own fired"
  end

  test "runs an around-hook's ensure and lets the original's exception through" do
    ensured = []
    Hooks.around_hook("HooksTest::AroundEnsure", :boom) do |_i, nxt, _a|
      begin
        nxt.call
      ensure
        ensured << :ran
      end
    end
    error = assert_raises(RuntimeError) { AroundEnsure.new.boom }
    assert_equal ["kaboom", [:ran]], [error.message, ensured]
  end

  test "passes an error of the original on through an around-hook, without logging it as the hook's" do
    Hooks.around_hook("HooksTest::AroundEnsure", :boom) { |_i, nxt, _a| nxt.call }
    error = assert_raises(RuntimeError) { AroundEnsure.new.boom }
    assert_equal "kaboom", error.message
    assert_equal [], marker_lines(/hook body HooksTest::AroundEnsure#boom@\d+: RuntimeError: kaboom/)
  end

  test "writes an around-hook's own failure to the marker and raises it on to the caller" do
    Hooks.around_hook("HooksTest::AroundFails", :run) { |_i, _nxt, _a| raise ArgumentError, "the around body fails" }
    error = assert_raises(ArgumentError) { AroundFails.new.run }
    assert_equal "the around body fails", error.message
    assert_equal 1, marker_lines(/hook body HooksTest::AroundFails#run@\d+: ArgumentError: the around body fails/).size
  end

  test "swallows a failing before- or after-hook body, the call answering as if unhooked" do
    Hooks.before_hook("HooksTest::Swallowed", :open) { |_i, _a| raise "the before body fails" }
    Hooks.after_hook("HooksTest::Swallowed", :read) { |_i, _r, _a| raise "the after body fails" }
    assert_equal [:opened, :read], [Swallowed.new.open, Swallowed.new.read]
  end

  test "writes a failing hook body to the marker once, however often it fails" do
    Hooks.after_hook("HooksTest::FailsOnce", :read) { |_i, _r, _a| raise "the body fails again" }
    3.times { FailsOnce.new.read }
    assert_equal 1, marker_lines(/hook body HooksTest::FailsOnce#read@\d+: RuntimeError: the body fails again/).length
  end

  test "writes the failures of two hooks on one method apart" do
    Hooks.after_hook("HooksTest::FailsTwice", :read) { |_i, _r, _a| raise "the first fails" }
    Hooks.after_hook("HooksTest::FailsTwice", :read) { |_i, _r, _a| raise "the second fails" }
    FailsTwice.new.read
    assert_equal 2, marker_lines(/hook body HooksTest::FailsTwice#read@\d+: RuntimeError: the \w+ fails/).size
  end

  test "remembers the class whose hooked method ran last, the screen the player is on" do
    was = Hooks.screen
    Hooks.after_hook("HooksTest::Screen", :refresh) { |_i, _r, _a| }
    Screen.new.refresh
    assert_equal "HooksTest::Screen", Hooks.screen
  ensure
    Hooks.note_screen(was)
  end

  test "tries a group's spellings ancestors first and the rest in the order given, skipping an alias of one it bound" do
    tried = []
    names = ["HooksTest::VarMissing", "HooksTest::VarAlias", "HooksTest::VarBase", "HooksTest::VarOther"]
    kept_records do
      hit = Hooks.variants(names, :paint, "hooks_test_paint") do |cname|
        tried.push(cname)
        Hooks.after_hook(cname, :paint, :optional => true) { |_i, _r, _a| }
      end
      assert_equal ["HooksTest::VarBase", "HooksTest::VarOther"], hit
      assert_equal [], Hooks.unbound, "a group that bound is not reported"
    end
    assert_equal ["HooksTest::VarMissing", "HooksTest::VarBase", "HooksTest::VarOther"], tried
  end

  test "reports a group that bound nowhere under its label, up to forty groups" do
    kept_records do
      earlier = (1..39).map { |i| "group#{i}#refresh" }
      Hooks.unbound.replace(earlier.dup)
      Hooks.variants(["HooksTest::NoSuchFirst"], :refresh, "first_group") { |_cname| false }
      Hooks.variants(["HooksTest::NoSuchSecond"], :refresh) { |_cname| false }
      assert_equal earlier + ["first_group#refresh"], Hooks.unbound
    end
  end

  test "runs a wrapped function's after-bodies in turn with its arguments and result, the function once" do
    calls = []
    with_global(:pa_wg_after, lambda { |x| calls.push([:function, x]); x * 2 }) do
      Hooks.wrap_global("pa_wg_after", "hooks_test_after", :after) { |args, r| calls.push([:first, args, r]) }
      Hooks.wrap_global("pa_wg_after", "hooks_test_after", :after) { |args, r| calls.push([:second, args, r]) }
      assert_equal 10, pa_wg_after(5)
    end
    assert_equal [[:function, 5], [:first, [5], 10], [:second, [5], 10]], calls
  end

  test "runs a wrapped function's before-body ahead of it, with no result yet" do
    calls = []
    with_global(:pa_wg_before, lambda { |x| calls.push([:function, x]); x }) do
      Hooks.wrap_global("pa_wg_before", "hooks_test_before", :before) { |args, r| calls.push([:before, args, r]) }
      pa_wg_before(7)
    end
    assert_equal [[:before, [7], nil], [:function, 7]], calls
  end

  test "nests a wrapped function's around-bodies, the first registered outermost, each calling on to the next" do
    calls = []
    with_global(:pa_wg_around, lambda { |x| calls.push(:function); x + 1 }) do
      Hooks.wrap_global("pa_wg_around", "hooks_test_around", :around) do |_args, nxt|
        calls.push(:outer_in)
        r = nxt.call
        calls.push(:outer_out)
        r * 10
      end
      Hooks.wrap_global("pa_wg_around", "hooks_test_around", :around) do |_args, nxt|
        calls.push(:inner_in)
        r = nxt.call
        calls.push(:inner_out)
        r
      end
      assert_equal 30, pa_wg_around(2)
    end
    assert_equal [:outer_in, :inner_in, :function, :inner_out, :outer_out], calls
  end

  test "goes on to a wrapped function's next body when one raises, logging the failure under the function" do
    seen = []
    with_global(:pa_wg_chain, lambda { |x| x }) do
      fresh_log do
        Hooks.wrap_global("pa_wg_chain", "hooks_test_chain", :after) { |_a, _r| raise "boom" }
        Hooks.wrap_global("pa_wg_chain", "hooks_test_chain", :after) { |_a, r| seen.push(r) }
        assert_equal [3, 4], [pa_wg_chain(3), pa_wg_chain(4)], "the calls answer as unwrapped"
        assert_match(/\ARuntimeError: boom @ /, PokeAccess.logged["global_pa_wg_chain"])
      end
    end
    assert_equal [3, 4], seen, "the next body ran each time"
  end

  test "lets a wrapped function's error through, skipping its after-bodies" do
    ran = []
    with_global(:pa_wg_raises, lambda { |_x| raise IOError, "the function fails" }) do
      Hooks.wrap_global("pa_wg_raises", "hooks_test_raises", :after) { |_a, _r| ran.push(:after) }
      assert_raises(IOError) { pa_wg_raises(1) }
    end
    assert_equal [], ran
  end

  test "defines nothing for a function the game lacks, and lists it as absent once" do
    kept_records do
      2.times { Hooks.wrap_global("pa_wg_missing_xyz", "hooks_test_missing") { |_a, _r| } }
      assert_equal [false, false], [on_object?(:pa_wg_missing_xyz), on_object?(:pa_wg_missing_xyz__pa)]
      assert_equal ["pa_wg_missing_xyz"], Hooks.fn_absent
    end
  end

  test "keeps a wrapped public function public, so a game can call it on Kernel, and its original private" do
    with_global(:pa_wg_public, lambda { |x| x }, :public) do
      Hooks.wrap_global("pa_wg_public", "hooks_test_public", :before) { |_a, _r| }
      assert_equal 3, Kernel.pa_wg_public(3)
      assert_equal [:pa_wg_public], Object.public_instance_methods(false).grep(/pa_wg_public/)
    end
  end

  test "keeps a wrapped private function private, and its original too" do
    with_global(:pa_wg_private, lambda { |x| x }) do
      Hooks.wrap_global("pa_wg_private", "hooks_test_private", :before) { |_a, _r| }
      assert_equal true, Object.private_method_defined?(:pa_wg_private), "the function"
      assert_equal [], Object.public_instance_methods(false).grep(/pa_wg_private/), "nothing of it public"
    end
  end

  test "wraps a top-level function on Object, public or private, where its bare calls go" do
    seen = []
    with_global(:pa_wk_public, lambda { |x| x }, :public) do
      with_global(:pa_wk_private, lambda { |x| x }) do
        Hooks.wrap_kernel("pa_wk_public", "hooks_test_object", :before) { |args, _r| seen.push([:public, args[0]]) }
        Hooks.wrap_kernel("pa_wk_private", "hooks_test_object", :before) { |args, _r| seen.push([:private, args[0]]) }
        assert_equal [11, 12], [pa_wk_public(11), pa_wk_private(12)]
      end
    end
    assert_equal [[:public, 11], [:private, 12]], seen
  end

  test "wraps a function Kernel's own singleton defines where it lives, public or private" do
    seen = []
    with_kernel_function(:pa_wk_kernel, lambda { |x| x }) do
      with_kernel_function(:pa_wk_hidden, lambda { |x| x }, :private) do
        Hooks.wrap_kernel("pa_wk_kernel", "hooks_test_kernel", :before) { |args, _r| seen.push([:public, args[0]]) }
        Hooks.wrap_kernel("pa_wk_hidden", "hooks_test_kernel", :before) { |args, _r| seen.push([:private, args[0]]) }
        assert_equal [12, 13], [Kernel.pa_wk_kernel(12), Kernel.send(:pa_wk_hidden, 13)]
      end
    end
    assert_equal [[:public, 12], [:private, 13]], seen
  end

  test "adds a second wrap's body to a Kernel function's first, the function running once" do
    calls = []
    with_kernel_function(:pa_wk_twice, lambda { |x| calls.push([:function, x]); x }) do
      Hooks.wrap_kernel("pa_wk_twice", "hooks_test_twice", :before) { |args, _r| calls.push([:first, args[0]]) }
      Hooks.wrap_kernel("pa_wk_twice", "hooks_test_twice", :before) { |args, _r| calls.push([:second, args[0]]) }
      assert_equal 14, Kernel.pa_wk_twice(14)
    end
    assert_equal [[:first, 14], [:second, 14], [:function, 14]], calls
  end

  private

  # Runs the block with the typo, unbound, absent-function and silenced-pair lists empty, the session's put back after.
  def kept_records
    lists = [Hooks.missing, Hooks.unbound, Hooks.fn_absent, Hooks.suppressed]
    saved = lists.map { |l| l.dup }
    lists.each { |l| l.clear }
    yield
  ensure
    lists.each_with_index { |l, i| l.replace(saved[i]) }
  end

  # Runs the block with log_once's record of this session empty, the record put back after.
  def fresh_log
    saved = PokeAccess.instance_variable_get(:@logged_once)
    PokeAccess.instance_variable_set(:@logged_once, {})
    yield
  ensure
    PokeAccess.instance_variable_set(:@logged_once, saved)
  end

  # The marker file's lines matching pattern.
  def marker_lines(pattern)
    (File.readlines(PokeAccess.marker_file) rescue []).grep(pattern)
  end

  # True when Object has a method of that name, public or private.
  def on_object?(name)
    Object.method_defined?(name) || Object.private_method_defined?(name)
  end

  # Runs the block with a top-level function defined on Object as body (private, as a game's bare def is, unless
  # public), then takes it, the original a wrap kept and the bodies wrapped onto it away.
  def with_global(name, body, visibility = :private)
    Object.send(:define_method, name, &body)
    Object.send(visibility, name)
    yield
  ensure
    [name, :"#{name}__pa"].each { |m| Object.send(:remove_method, m) if on_object?(m) }
    Hooks.fn_bodies.delete_if { |k, _v| k.start_with?("#{name}|") }
  end

  # Runs the block with a function defined on Kernel's own singleton as body (public, as gen 6 defines its own, unless
  # private), then takes it, the original a wrap kept and the bodies wrapped onto it away.
  def with_kernel_function(name, body, visibility = :public)
    meta = Kernel.singleton_class
    meta.send(:define_method, name, &body)
    meta.send(visibility, name)
    yield
  ensure
    [name, :"#{name}__pa"].each do |m|
      meta.send(:remove_method, m) if meta.method_defined?(m, false) || meta.private_method_defined?(m, false)
    end
    Hooks.fn_bodies.delete_if { |k, _v| k.start_with?("#{name}|") }
  end
end
