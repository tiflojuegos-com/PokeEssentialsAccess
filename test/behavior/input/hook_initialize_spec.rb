# Hooks bind to private methods such as initialize, and a wrapped private method stays private (checked on an ordinary
# one, since Ruby keeps initialize private anyway).
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
  PaHookInitProbe.send(:define_method, :secret) { :kept }
  PaHookInitProbe.send(:private, :secret)
  PokeAccess::Hooks.after_hook("PaHookInitProbe", :secret) { |_i, _r, _a| }
  truthy "a wrapped private method stays private", PaHookInitProbe.private_method_defined?(:secret)
end
