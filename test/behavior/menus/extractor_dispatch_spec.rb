# Extractor dispatch: the most derived registered class wins whatever the registration order, so a profile can
# specialise a core extractor.
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
