# Stalemate (map 893), on Darkrai's errand with variable 697 from 18: the corridor with the false Luna never ends, as a
# parallel event takes the player from any row past 78 back 48 rows up the same column. Only turning back once 697
# reaches 20 and stepping on (95, 21), the middle of the corridor, sets 697 to 25 and lets the errand go on.
module PokeAccess
  module RebornStalemate
    # True while the corridor loops.
    def self.looping?
      v = $game_variables[697].to_i
      v >= 18 && v < 25
    end

    # True once turning back is the way on.
    def self.turning?
      v = $game_variables[697].to_i
      v >= 20 && v < 25
    end
  end
end

PokeAccess::Game.define("reborn") do
  corridor = PokeAccess::RebornStalemate
  mechanic(:state, 893) do
    auto
    sent_back lambda { PokeAccess::Puzzles.assist? ? :rbf_stalemate_loop : nil }, :from => [94, 96, 79, 89],
              :to => [94, 96, 31, 41]
    spot :at => [95, 21], :label => :rbf_stalemate_turn, :onto => true, :assist => true,
         :when => lambda { corridor.turning? }
    phase lambda { PokeAccess::Puzzles.assist? && corridor.turning? }, :quiet => true, :hint => :rbf_stalemate_hint
    active { corridor.looping? }
    solved(nil, :quiet => true) { $game_variables[697].to_i >= 25 }
  end
end
