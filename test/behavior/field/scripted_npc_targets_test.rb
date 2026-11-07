# Shared classification cases under this engine harness.
require File.expand_path("scripted_npc_targets_cases", File.dirname(__FILE__))

class ScriptedNpcTargetsTest < PokeAccessTest
  ScriptedNpcTargetCases.define(self)
end
