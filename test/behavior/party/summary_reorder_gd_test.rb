# Reordering moves on the modern summary scene (PokemonSummary_Scene); the cases are in summary_reorder_cases.rb.
require File.expand_path("summary_reorder_cases", File.dirname(__FILE__))

class SummaryReorderGdTest < PokeAccessTest
  SummaryReorderCases.define(self, PokemonSummary_Scene, lambda { |id| GameData::Move.get(id).name })
end
