# Hooks.override swaps a mod module's or a game class's method for a body handed the original: overrides stack, are
# listed for the diag, re-raise a failing body; an absent target is missing unless optional, a refused one is marked.
class OverrideTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  # The stand-ins the tests override, one per test, since an override stays for the whole run.
  module Reader
    def self.detail(x); "core:#{x}"; end
  end

  module Listed
    def self.detail; "core"; end
    def self.other; "core"; end
  end

  module Stacked
    def self.detail(x); "core:#{x}"; end
  end

  module Keyworded
    def self.pick(a, b: 0); [a, b]; end
  end

  module Failing
    def self.detail; "core"; end
  end

  module FailingTwice
    def self.detail; "core"; end
  end

  module Bare; end

  class Scene
    def read(*_args); :engine; end
  end

  class FailingScene
    def read; :engine; end
  end

  class Hidden
    def peek; :hidden; end
    private :peek
  end

  class Named
    def name; "inner"; end
  end

  class SelfLabelled
    def self.to_s; "class-level"; end
  end

  module PrependedPeek
    def peek; :prepended; end
  end

  class OnlyPrepended
    prepend PrependedPeek
  end

  module PrependedDetail
    def detail; :prepended; end
  end

  module SingletonPrepended
    singleton_class.prepend(PrependedDetail)
  end

  def setup
    super
    @listed = [Hooks.overrides.length, Hooks.missing.length]
  end

  def teardown
    Hooks.overrides.slice!(@listed[0]..-1)
    Hooks.missing.slice!(@listed[1]..-1)
    super
  end

  test "replaces a module's singleton method, handing the body the module, the original and the arguments" do
    seen = nil
    Hooks.override(Reader, :detail) do |mod, original, args|
      seen = [mod, args]
      "game:#{args[0]}+#{original.call}"
    end
    assert_equal "game:5+core:5", Reader.detail(5), "the body answers, wrapping the original"
    assert_equal [Reader, [5]], seen, "with the module and the call's arguments"
  end

  test "lists each installation for the diag as target and method, with its tag when given" do
    count = Hooks.overrides.length
    Hooks.override(Listed, :detail, :tag => "spec") { |_m, original, _a| original.call }
    assert_equal ["OverrideTest::Listed.detail (spec)"], Hooks.overrides[count..-1], "tagged"
    Hooks.override(Listed, :other) { |_m, original, _a| original.call }
    assert_equal ["OverrideTest::Listed.detail (spec)", "OverrideTest::Listed.other"], Hooks.overrides[count..-1],
                 "untagged"
  end

  test "hands a second override the first as its original" do
    Hooks.override(Stacked, :detail) { |_m, original, args| "game:#{args[0]}+#{original.call}" }
    Hooks.override(Stacked, :detail) { |_m, original, _a| "outer[#{original.call}]" }
    assert_equal "outer[game:5+core:5]", Stacked.detail(5)
  end

  test "replaces a game class's instance method named by its class, handing the body the instance" do
    Hooks.override("OverrideTest::Scene", :read) { |scene, original, args| [scene, original.call, args] }
    scene = Scene.new
    got = scene.read(1)
    assert_same scene, got[0], "the body gets the instance"
    assert_equal [:engine, [1]], got[1, 2], "and the original and the arguments"
    assert_equal "OverrideTest::Scene.read", Hooks.overrides.last, "listed by the class's name"
  end

  test "replaces a private instance method, which stays private" do
    Hooks.override("OverrideTest::Hidden", :peek) { |_scene, original, _a| "seen:#{original.call}" }
    assert_equal "seen:hidden", Hidden.new.send(:peek)
    assert_equal true, Hidden.private_method_defined?(:peek)
  end

  test "overrides an instance method that Module also answers on the class (:name) as the instance method" do
    Hooks.override("OverrideTest::Named", :name) { |_scene, original, _a| "seen:#{original.call}" }
    assert_equal "seen:inner", Named.new.name, "the instance method is replaced"
    assert_equal "OverrideTest::Named", Named.name, "the class-level name Module provides stays untouched"
  end

  test "overrides a name every class answers as the class's own when the class defines it itself" do
    Hooks.override("OverrideTest::SelfLabelled", :to_s) { |_mod, original, _a| "game+#{original.call}" }
    assert_equal "game+class-level", SelfLabelled.to_s, "the class's own is replaced"
    assert_match(/\A#<OverrideTest::SelfLabelled/, SelfLabelled.new.to_s, "while its instances keep Kernel's")
  end

  test "passes keyword arguments on to the original as keywords" do
    Hooks.override(Keyworded, :pick) { |_m, original, _a| original.call }
    assert_equal [1, 2], Keyworded.pick(1, b: 2)
  end

  test "re-raises a failing body's error to the caller, for a module's method and a class's" do
    Hooks.override(Failing, :detail) { |_m, _o, _a| raise "module boom" }
    Hooks.override("OverrideTest::FailingScene", :read) { |_s, _o, _a| raise "scene boom" }
    { "module boom" => lambda { Failing.detail }, "scene boom" => lambda { FailingScene.new.read } }.each do |text, call|
      assert_equal text, assert_raises(RuntimeError) { call.call }.message
    end
  end

  test "writes a failing body to the marker once, however often it fails" do
    Hooks.override(FailingTwice, :detail) { |_m, _o, _a| raise "boom" }
    2.times { assert_raises(RuntimeError) { FailingTwice.detail } }
    line = "hook body override OverrideTest::FailingTwice.detail: RuntimeError: boom"
    logged = marker_lines.select { |l| l.include?(line) }
    assert_equal 1, logged.length, marker_lines.last(3).inspect
  end

  test "notes in the marker a module method it cannot replace, and lists nothing" do
    count = Hooks.overrides.length
    Hooks.override(SingletonPrepended, :detail) { |_m, _o, _a| :replaced }
    assert_equal :prepended, SingletonPrepended.detail, "the method stays the prepended module's"
    assert_equal [], Hooks.overrides[count..-1], "nothing listed"
    assert_match(/: override OverrideTest::SingletonPrepended#detail: detail exists only in a module prepended to /,
                 marker_lines.last)
  end

  test "lists no override it could not install on a class" do
    count = Hooks.overrides.length
    Hooks.override("OverrideTest::OnlyPrepended", :peek) { |_s, _o, _a| :replaced }
    assert_equal :prepended, OnlyPrepended.new.peek, "the method stays the prepended module's"
    assert_equal [], Hooks.overrides[count..-1], "nothing listed"
  end

  test "installs and records nothing for an optional target or method that is absent" do
    count = Hooks.overrides.length
    Hooks.override("OverrideTest::NoSuchOptional", :y, :optional => true) { |_i, _o, _a| }
    Hooks.override(Bare, :no_such_optional, :optional => true) { |_i, _o, _a| }
    assert_equal count, Hooks.overrides.length, "nothing installed"
    assert_equal [], Hooks.missing & ["OverrideTest::NoSuchOptional#y", "OverrideTest::Bare#no_such_optional"],
                 "nothing missing"
  end

  test "records an absent target or method that was not optional as missing, once" do
    count = Hooks.overrides.length
    before = Hooks.missing.dup
    2.times do
      Hooks.override("OverrideTest::NoSuchClass", :x) { |_i, _o, _a| }
      Hooks.override(Bare, :no_such_meth) { |_i, _o, _a| }
    end
    assert_equal count, Hooks.overrides.length, "nothing installed"
    assert_equal before + ["OverrideTest::NoSuchClass#x", "OverrideTest::Bare#no_such_meth"], Hooks.missing
  end

  private

  # The lines of the mod's marker file, or none before it exists.
  def marker_lines
    File.exist?(PokeAccess.marker_file) ? File.readlines(PokeAccess.marker_file).map(&:chomp) : []
  end
end
