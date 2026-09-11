# Hooks.variants: registering the same hook across the spellings a class takes across games, and saying so
# when not one of them bound.
#
# The failure it exists to catch leaves no trace of any other kind. An :optional hook whose class is absent
# is skipped on purpose, because cross-game variance is normal and the alternative would fill the missing
# list with noise. But a hook written against ONE spelling when the games use another is not variance, it is
# a bug, and it presents exactly like a screen that has nothing to say: no exception, no missing entry, no
# failing test. The item-storage title spent its whole life like that in eight of the fourteen games.
Suite.define("hooks: a hook group that binds nowhere is reported, one that binds anywhere is not") do
  h = PokeAccess::Hooks
  before = h.unbound.dup
  begin
    bound = h.variants(["NoSuchSceneA", "NoSuchSceneB"], :pbStartScene) do |cname|
      h.around_hook(cname, :pbStartScene, :optional => true) { |_s, nxt, _a| nxt.call }
    end
    eq "no spelling bound", bound, []
    truthy "so the group is named in the report, by its first spelling",
           h.unbound.include?("NoSuchSceneA#pbStartScene")
    eq "and named once however often it is registered",
       (h.variants(["NoSuchSceneA", "NoSuchSceneB"], :pbStartScene) { |c| h.around_hook(c, :pbStartScene, :optional => true) { |_s, n, _a| n.call } };
        h.unbound.select { |u| u == "NoSuchSceneA#pbStartScene" }.length), 1

    Object.const_set(:SpecVariantTarget, Class.new { def update(*a); :updated; end }) unless defined?(SpecVariantTarget)
    hit = h.variants(["NoSuchSceneA", "SpecVariantTarget"], :update, "commands") do |cname|
      h.around_hook(cname, :update, :optional => true) { |_s, nxt, _a| nxt.call }
    end
    eq "the spelling this game has is the one that bound", hit, ["SpecVariantTarget"]
    falsy "and a group with a live spelling is never reported", h.unbound.include?("commands#update")
  ensure
    h.unbound.replace(before)
  end
end

# The BES-T compatibility layers alias one spelling to the other with an EMPTY subclass, and the game
# instantiates whichever side it wrote first. A hook bound on the empty alias never runs for the parent's
# instances, so the class that owns the method must be the one that binds, whatever order the group lists:
# Awakening's hall of fame was mute because its alias came first in the list.
Suite.define("hooks: a group with an empty alias subclass binds the class that owns the method") do
  h = PokeAccess::Hooks
  Object.const_set(:SpecVarOwner, Class.new { def refresh; :owner; end }) unless defined?(SpecVarOwner)
  Object.const_set(:SpecVarAlias, Class.new(SpecVarOwner)) unless defined?(SpecVarAlias)
  seen = []
  hit = h.variants(["SpecVarAlias", "SpecVarOwner"], :refresh, "spec_alias") do |cname|
    h.after_hook(cname, :refresh, :optional => true) { |_s, _r, _a| seen.push(cname) }
  end
  eq "the owner is the spelling that bound, though the alias was listed first", hit, ["SpecVarOwner"]
  SpecVarOwner.new.refresh
  eq "so an instance of the class the game builds runs the hook", seen, ["SpecVarOwner"]
  seen.clear
  SpecVarAlias.new.refresh
  eq "and the alias, inheriting it, runs it exactly once", seen, ["SpecVarOwner"]
end

# The registrars answer whether they bound, which is what variants counts.
Suite.define("hooks: the registrars say whether they bound") do
  h = PokeAccess::Hooks
  # Bound on a class of this spec's own, so no live middleware is left on a window the other suites use.
  Object.const_set(:SpecBindTarget, Class.new { def refresh; :done; end }) unless defined?(SpecBindTarget)
  falsy "an absent class does not bind", h.around_hook("NoSuchClassAtAll", :whatever, :optional => true) { |_s, n, _a| n.call }
  falsy "nor an absent method on a class that exists",
        h.after_hook("SpecBindTarget", :no_such_method_here, :optional => true) { |_s, _r, _a| nil }
  truthy "a method that exists binds", h.before_hook("SpecBindTarget", :refresh, :optional => true) { |_s, _a| nil }
  truthy "and so does a second hook on the same method", h.before_hook("SpecBindTarget", :refresh, :optional => true) { |_s, _a| nil }
  eq "and the hooked method still answers what it did", SpecBindTarget.new.refresh, :done
end
