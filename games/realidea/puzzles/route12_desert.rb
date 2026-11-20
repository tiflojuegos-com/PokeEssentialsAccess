# The desert of Route 12 (map 139): seven quicksands, each ringed by a different number of rocks (one to seven), throw the
# player elsewhere in the desert. Variable 120 counts the ones taken in the order of their rocks and a wrong one sets it
# to 0; the seventh with the count at 6 leads to the oasis. Lilliana tells the order. Another order (variable 175: three,
# four, one and five rocks) leads to a secret place. The first arrival at the oasis (switch 465) ends it.
module PokeAccess
  module RealideaDesert
    MAP = 139
    ORDER = 120
    OASIS_REACHED = 465
    # The rocks around each quicksand, by event.
    ROCKS = { 46 => 1, 47 => 2, 48 => 3, 49 => 4, 50 => 5, 51 => 6, 52 => 7 }

    # The name of a quicksand: how many rocks ring it.
    def self.sand(ev)
      [:rea_desert_sand, { :n => ROCKS[ev.id] }]
    end

    # What the puzzle assist says: the quicksand to take next.
    def self.hint
      [:rea_desert_hint, { :n => [$game_variables[ORDER].to_i, 6].min + 1 }]
    end
  end
end

PokeAccess::Game.define("realidea") do
  desert = PokeAccess::RealideaDesert
  mechanic(:state, desert::MAP) do
    auto
    name desert::ROCKS.keys, lambda { |ev| desert.sand(ev) }
    sent_back :rea_desert_thrown, :events => desert::ROCKS.keys
    active { PokeAccess::Puzzles.assist? && !$game_switches[desert::OASIS_REACHED] }
    solved(nil, :quiet => true) { $game_switches[desert::OASIS_REACHED] }
    hint lambda { desert.hint }
  end
end
