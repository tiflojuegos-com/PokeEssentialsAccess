# Hooks.override: the DECLARED replacement primitive (F-L11-002). It must substitute a mod module's
# singleton method (the Reminiscencia case) or a game class's instance method, hand the body the
# original as a callable (wrap instead of substitute), register every installation in overrides (the
# diag's visibility), and stack: a second override receives the first as its original.
Suite.define("hooks: override replaces module and instance methods, visibly and stackably") do
  mod = Module.new do
    def self.detail(x); "core:#{x}"; end
  end
  Object.const_set(:OverrideSpecReader, mod) unless Object.const_defined?(:OverrideSpecReader)

  before_count = PokeAccess::Hooks.overrides.length
  PokeAccess::Hooks.override(OverrideSpecReader, :detail, :tag => "spec") do |_m, original, args|
    "game:#{args[0]}+#{original.call}"
  end
  eq "the module singleton is replaced and can wrap the original",
     OverrideSpecReader.detail(5), "game:5+core:5"
  eq "the installation is registered for the diag", PokeAccess::Hooks.overrides.length, before_count + 1
  truthy "the listing names target, method and tag",
         PokeAccess::Hooks.overrides.last.include?("OverrideSpecReader.detail") &&
         PokeAccess::Hooks.overrides.last.include?("spec")

  PokeAccess::Hooks.override(OverrideSpecReader, :detail) do |_m, original, _args|
    "outer[#{original.call}]"
  end
  eq "a second override receives the first as its original",
     OverrideSpecReader.detail(5), "outer[game:5+core:5]"

  klass = Class.new { def read; :engine; end }
  Object.const_set(:OverrideSpecScene, klass) unless Object.const_defined?(:OverrideSpecScene)
  PokeAccess::Hooks.override("OverrideSpecScene", :read) { |_inst, _original, _args| :replaced }
  eq "an instance method of a (game) class is replaced too", OverrideSpecScene.new.read, :replaced

  n = PokeAccess::Hooks.overrides.length
  PokeAccess::Hooks.override("OverrideNoSuchClass_pa", :x, :optional => true) { |_i, _o, _a| }
  eq "an optional absent target installs nothing", PokeAccess::Hooks.overrides.length, n

  named = Class.new { def name; "inner"; end }
  Object.const_set(:OverrideSpecNamed, named) unless Object.const_defined?(:OverrideSpecNamed)
  PokeAccess::Hooks.override("OverrideSpecNamed", :name) { |_i, original, _a| "seen:#{original.call}" }
  eq "an instance method shadowed by Module's singleton (:name) is still replaced as instance",
     OverrideSpecNamed.new.name, "seen:inner"
  eq "the class-level name Module provides stays untouched", OverrideSpecNamed.name, "OverrideSpecNamed"

  n = PokeAccess::Hooks.overrides.length
  m = PokeAccess::Hooks.missing.length
  PokeAccess::Hooks.override(OverrideSpecReader, :no_such_meth_pa, :optional => true) { |_i, _o, _a| }
  eq "an optional ABSENT METHOD on a present target installs nothing", PokeAccess::Hooks.overrides.length, n
  eq "and stays out of missing", PokeAccess::Hooks.missing.length, m
  PokeAccess::Hooks.override(OverrideSpecReader, :no_such_meth_pa) { |_i, _o, _a| }
  eq "a non-optional absent method is recorded as missing", PokeAccess::Hooks.missing.length, m + 1
end
