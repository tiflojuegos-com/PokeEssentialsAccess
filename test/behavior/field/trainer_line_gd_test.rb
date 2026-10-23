# The trainer line with the GameData-era player ($player); the cases live in trainer_line_cases.rb.
require File.expand_path("trainer_line_cases", File.dirname(__FILE__))

class TrainerLineGdTest < PokeAccessTest
  TrainerLineCases.define(self)
end
