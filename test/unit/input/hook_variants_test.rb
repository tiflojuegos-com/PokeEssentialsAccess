# Hooks.variants binds one hook across the spellings a class takes in different games, the class that owns the method
# ahead of its empty alias subclasses, and reports a group none of whose spellings binds; the registrars answer whether
# they bound.

# Stand-ins for the classes the spellings name, each hooked by one test only.
class HookVariantsLiveScene; def update(*_a); :updated; end; end

class HookVariantsFirstScene; def update(*_a); :updated; end; end

class HookVariantsOwner; def refresh; :owner; end; end

class HookVariantsAlias < HookVariantsOwner; end

class HookVariantsBareParent; end

class HookVariantsChild < HookVariantsBareParent; def draw; :drawn; end; end

class HookVariantsBindTarget; def refresh; :done; end; end

class HookVariantsAnswerTarget; def refresh; :done; end; end

class HookVariantsTest < PokeAccessTest
  Hooks = PokeAccess::Hooks

  test "a group none of whose spellings binds is reported by its first spelling" do
    hit, reported = reporting do
      Hooks.variants(["NoSuchSceneA", "NoSuchSceneB"], :pbStartScene) { |c| bind_around(c, :pbStartScene) }
    end
    assert_equal [[], ["NoSuchSceneA#pbStartScene"]], [hit, reported]
  end

  test "a group is reported under its label when it has one" do
    _hit, reported = reporting do
      Hooks.variants(["NoSuchSceneA"], :update, "spec_label") { |c| bind_around(c, :update) }
    end
    assert_equal ["spec_label#update"], reported
  end

  test "a group registered again is reported once" do
    _hit, reported = reporting do
      2.times { Hooks.variants(["NoSuchSceneA", "NoSuchSceneB"], :pbStartScene) { |c| bind_around(c, :pbStartScene) } }
    end
    assert_equal ["NoSuchSceneA#pbStartScene"], reported
  end

  test "the report keeps at most forty groups" do
    earlier = (1..39).map { |i| "SpecGroup#{i}#update" }
    _hit, reported = reporting do
      Hooks.unbound.concat(earlier)
      Hooks.variants(["NoSuchSceneA"], :update) { |c| bind_around(c, :update) }
      Hooks.variants(["NoSuchSceneB"], :update) { |c| bind_around(c, :update) }
    end
    assert_equal earlier + ["NoSuchSceneA#update"], reported
  end

  test "a group with a live spelling binds that one and is not reported" do
    hit, reported = reporting do
      Hooks.variants(["NoSuchSceneA", "HookVariantsLiveScene"], :update, "commands") { |c| bind_around(c, :update) }
    end
    assert_equal [["HookVariantsLiveScene"], []], [hit, reported]
  end

  test "a group whose first spelling is the live one binds it" do
    hit = Hooks.variants(["HookVariantsFirstScene", "NoSuchSceneB"], :update) { |c| bind_around(c, :update) }
    assert_equal ["HookVariantsFirstScene"], hit
  end

  # A hook on the alias would miss the parent's instances.
  test "with an empty alias subclass listed first, the owner binds, and either one's instance runs the hook once" do
    seen = []
    hit = Hooks.variants(["HookVariantsAlias", "HookVariantsOwner"], :refresh, "spec_alias") do |c|
      Hooks.after_hook(c, :refresh, :optional => true) { |_s, _r, _a| seen.push(c) }
    end
    HookVariantsOwner.new.refresh
    HookVariantsAlias.new.refresh
    assert_equal [["HookVariantsOwner"], ["HookVariantsOwner", "HookVariantsOwner"]], [hit, seen]
  end

  test "a spelling that does not bind leaves a related spelling free to bind" do
    hit = Hooks.variants(["HookVariantsBareParent", "HookVariantsChild"], :draw) { |c| bind_around(c, :draw) }
    assert_equal ["HookVariantsChild"], hit
  end

  test "each registrar answers whether it bound" do
    got = [Hooks.around_hook("NoSuchClassAtAll", :whatever, :optional => true) { |_s, nxt, _a| nxt.call },
           Hooks.after_hook("HookVariantsBindTarget", :no_such_method_here, :optional => true) { |_s, _r, _a| nil },
           Hooks.before_hook("HookVariantsBindTarget", :refresh, :optional => true) { |_s, _a| nil },
           Hooks.before_hook("HookVariantsBindTarget", :refresh, :optional => true) { |_s, _a| nil }]
    assert_equal [false, false, true, true], got, "an absent class, an absent method, a method, a second hook on it"
  end

  test "a method hooked before still answers what it did" do
    Hooks.before_hook("HookVariantsAnswerTarget", :refresh, :optional => true) { |_s, _a| nil }
    assert_equal :done, HookVariantsAnswerTarget.new.refresh
  end

  private

  # Binds a pass-through around hook on cname#meth, answering whether it bound.
  def bind_around(cname, meth)
    Hooks.around_hook(cname, meth, :optional => true) { |_s, nxt, _a| nxt.call }
  end

  # The block's value and the groups it reported unbound, the report emptied for it and put back after.
  def reporting
    was = Hooks.unbound.dup
    Hooks.unbound.clear
    value = yield
    [value, Hooks.unbound.dup]
  ensure
    Hooks.unbound.replace(was)
  end
end
