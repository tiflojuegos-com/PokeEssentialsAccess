# Mt. Tamaranch in Dream Route 13 (map 217): three passages (west event 2, east event 3, north event 4) that each carry
# the player to another side of the same room, and variable 31 follows the order they are taken in: west, west, west
# (variable at 1, 2 and 3 after them), north (4), east, east (5 and 6), north (7), west (8) and north again to leave. Any
# passage out of order puts the variable at 1.
module PokeAccess
  # The passage the sequence asks for next.
  module UraniumTamaranch
    # The label of the passage that follows the variable's value.
    def self.hint
      case $game_variables[31].to_i
      when 3, 6 then :ura_po_tam_hint_north
      when 8 then :ura_po_tam_hint_exit
      when 4, 5 then :ura_po_tam_hint_east
      else :ura_po_tam_hint_west
      end
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 217, :part => :sequence) do
    auto
    arrival_hint :ura_po_tam_rule, :once => true
    name 2, :ura_po_tam_west
    name 3, :ura_po_tam_east
    name 4, :ura_po_tam_north
    phase lambda { true }, :quiet => true, :hint => lambda { PokeAccess::UraniumTamaranch.hint }
  end
end
