# The move-list cursor method differs by gen-6 fork: stock FightMenuDisplay has setIndex; both Infinite Fusion games
# inherit index= from a BattleMenuBase parent, with no setIndex. The reader is gated on the one the fork has.

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

# A hook on a child class binds a method it inherits (Infinite Fusion's index=) and leaves the parent unpatched.
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
