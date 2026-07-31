# Which method carries the move-list cursor is not the same in every gen-6 fork, and the reader is gated on
# that rather than assuming one shape:
#
#   - Stock gen-6 (Opalo, Z, Armonia...) declares FightMenuDisplay standalone with setIndex.
#   - Both Infinite Fusion games give it a BattleMenuBase parent whose cursor setter is index=, with no
#     setIndex anywhere. The move list was therefore silent in battle there -- the command menu still read,
#     because CommandMenuDisplay#index= does exist, which is what made the gap look like a partial failure.
#
# What matters is that gating picks the right one per fork and that the stock games keep the method they
# already used, so nothing that works today changes.

Suite.define("battle: the move cursor is gated on the method the fork actually has") do
  stock = Class.new do
    def setIndex(v); @index = v; end
    def index=(v); @index = v; end
  end
  fork_base = Class.new do
    def index=(v); @index = v; end
  end
  forked = Class.new(fork_base)

  Object.const_set(:PaSpecStockFight, stock) unless Object.const_defined?(:PaSpecStockFight)
  Object.const_set(:PaSpecForkedFight, forked) unless Object.const_defined?(:PaSpecForkedFight)

  truthy "a stock display advertises setIndex", PokeAccess::Engine.has?("PaSpecStockFight#setIndex")
  falsy "the Infinite Fusion shape does not", PokeAccess::Engine.has?("PaSpecForkedFight#setIndex")
  truthy "but it does inherit index= from its base", PokeAccess::Engine.has?("PaSpecForkedFight#index=")
end

# The other half of why the fix works: in the Infinite Fusion shape index= is declared on the PARENT, so
# hooking the child has to reach an inherited method. Verified end to end -- if wrap only bound methods a
# class owns outright, the gate would pick index= and still bind nothing.
Suite.define("battle: a hook binds a method inherited from a parent class") do
  base = Class.new { def index=(v); @index = v; end }
  Object.const_set(:PaSpecInheritBase, base) unless Object.const_defined?(:PaSpecInheritBase)
  Object.const_set(:PaSpecInheritChild, Class.new(base)) unless Object.const_defined?(:PaSpecInheritChild)

  seen = []
  PokeAccess::Hooks.after_hook("PaSpecInheritChild", :index=) { |_i, _r, args| seen << args[0] }
  obj = PaSpecInheritChild.new
  obj.index = 2

  eq "the body ran with the value the child was given", seen, [2]
  eq "and the original still assigned it", obj.instance_variable_get(:@index), 2
  falsy "the parent itself is left unpatched", PaSpecInheritBase.new.respond_to?(:index__pa_orig_PaSpecInheritBase)
end
