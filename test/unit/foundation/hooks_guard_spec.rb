
# The reentrancy guard records every outer>inner pair it silences in Hooks.suppressed, for the diagnostic.
Suite.define("hooks: the guard records what it silences, so a mute screen leaves evidence") do
  klass = Class.new do
    define_method(:outer_drive) { inner_read }
    define_method(:inner_read) { :read }
  end
  Object.const_set(:GuardEvidence, klass) unless Object.const_defined?(:GuardEvidence)

  PokeAccess::Hooks.after_hook("GuardEvidence", :inner_read) { |_s, _r, _a| PokeAccess.speak("leido", true) }
  PokeAccess::Hooks.after_hook("GuardEvidence", :outer_drive) { |_s, _r, _a| nil }

  before = PokeAccess::Hooks.suppressed.length
  SpeakCapture.clear
  GuardEvidence.new.outer_drive

  eq "the guarded outer did silence the reader it drives", SpeakCapture.log.length, 0
  truthy "and the engine wrote down that it did",
         PokeAccess::Hooks.suppressed.length > before
  truthy "naming both ends of the pair",
         PokeAccess::Hooks.suppressed.any? { |p| p.include?("outer_drive") && p.include?("inner_read") }
end
