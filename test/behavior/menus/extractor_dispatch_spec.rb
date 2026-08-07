# Extractor dispatch: the MOST DERIVED matching class wins, regardless of registration order --
# mirroring Ruby's own method dispatch. First-match-by-registration would let a core extractor on a base
# window class capture every subclass forever, so a profile could never specialise one.
Suite.define("menus: the most derived extractor wins over registration order") do
  base = Class.new do
    def index; 0; end
  end
  Object.const_set(:ExtDispatchBase, base) unless Object.const_defined?(:ExtDispatchBase)
  child = Class.new(ExtDispatchBase)
  Object.const_set(:ExtDispatchChild, child) unless Object.const_defined?(:ExtDispatchChild)

  PokeAccess::Menus.def_extractor("ExtDispatchBase") { |_w, _i| "base" }
  PokeAccess::Menus.def_extractor("ExtDispatchChild") { |_w, _i| "child" }

  eq "a base instance uses the base extractor", PokeAccess::Menus.focused_text(ExtDispatchBase.new), "base"
  eq "a child instance uses the child extractor even though the base registered first",
     PokeAccess::Menus.focused_text(ExtDispatchChild.new), "child"

  grandchild = Class.new(ExtDispatchChild)
  Object.const_set(:ExtDispatchGrandchild, grandchild) unless Object.const_defined?(:ExtDispatchGrandchild)
  eq "an unregistered grandchild falls to its nearest registered ancestor",
     PokeAccess::Menus.focused_text(ExtDispatchGrandchild.new), "child"
end
