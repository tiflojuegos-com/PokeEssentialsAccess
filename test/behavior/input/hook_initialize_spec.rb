# Regression: hooks must bind to private methods too. initialize is always private in Ruby, so a reader
# that hooks a custom scene's initialize (e.g. Awakening's EncounterListUI) was silently never wrapped while
# wrap only checked method_defined? (public methods). wrap now also accepts private_method_defined? and
# keeps the method private afterwards.
Suite.define("hooks: before/after bind to a private method (initialize)") do
  klass = Class.new do
    def initialize; @made = true; end
    def made?; @made; end
  end
  Object.const_set(:PaHookInitProbe, klass) unless Object.const_defined?(:PaHookInitProbe)
  fired = []
  PokeAccess::Hooks.after_hook("PaHookInitProbe", :initialize) { |_i, _r, _a| fired << :after }
  obj = PaHookInitProbe.new
  truthy "the original initialize still ran (object constructed)", obj.made?
  eq "the after-hook fired on a private initialize", [:after], fired
  # NOT initialize for this one: Ruby forces that private however it is defined, including through the
  # define_method wrap uses, so asserting it proves nothing about the mod. Re-privatisation is only really
  # tested on an ordinary private method.
  PaHookInitProbe.send(:define_method, :secret) { :kept }
  PaHookInitProbe.send(:private, :secret)
  PokeAccess::Hooks.after_hook("PaHookInitProbe", :secret) { |_i, _r, _a| }
  truthy "a wrapped private method stays private", PaHookInitProbe.private_method_defined?(:secret)
end
