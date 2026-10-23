# Reordering moves on the gen-6 summary scene (PokemonSummaryScene); the cases are in summary_reorder_cases.rb.
require File.expand_path("summary_reorder_cases", File.dirname(__FILE__))

class SummaryReorderTest < PokeAccessTest
  SummaryReorderCases.define(self, PokemonSummaryScene, lambda { |id| PBMoves.getName(id) })
end
