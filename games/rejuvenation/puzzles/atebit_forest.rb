# Atebit Town (map 293), the Hidden Library 3 quest (variable 265): the Funky Forest's sixteen graphic-less flower tiles
# send the player back to the entrance (30, 21). It is crossed at 265 = 17 to reach Alice and at 18 to reach the cave,
# where at 19 the wall's tile puzzle (event 48) opens the Tile Puzzle.
module PokeAccess
  module RejuvAtebit
    MAP = 293
    TRAPS = [27, 28, 29, 30, 31, 32, 33, 38, 39, 40, 41, 63, 69, 70, 71, 72]

    # The assisted hint of the forest, by the quest's step.
    def self.forest_hint
      case $game_variables[265].to_i
      when 17 then :rj_atebit_hint_alice
      when 18 then :rj_atebit_hint_cave
      end
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  atebit = PokeAccess::RejuvAtebit
  mechanic(:state, atebit::MAP, :part => :funky_forest) do
    auto
    name atebit::TRAPS, :rj_atebit_flower
    sent_back :rj_atebit_flower_back, :to => [30, 21], :events => atebit::TRAPS
    avoid atebit::TRAPS, :assist => true
    not_control atebit::TRAPS
    hint lambda { atebit.forest_hint }
    active { [17, 18].include?($game_variables[265].to_i) }
  end

  mechanic(:state, atebit::MAP, :part => :kabuto) do
    auto
    name 48, :rj_atebit_tile_puzzle, :when => lambda { |_ev| $game_variables[265].to_i == 19 }
  end
end
