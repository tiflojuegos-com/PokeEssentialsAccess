# Blacksteeple's notes, read in order along the story variable 232: Saki's riddle (the purple-covered book of map 443,
# then the green wall and the false wall of map 437) and the Prestige Room's note (map 443, event 69) and bookcase
# (event 9).
module PokeAccess
  module RejuvBlacksteeple
    # The story variable of the castle.
    def self.story
      $game_variables[232].to_i
    end

    # True while the story stands at value v and the puzzle assist is on.
    def self.step?(v)
      PokeAccess::Puzzles.assist? && story == v
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  bs = PokeAccess::RejuvBlacksteeple
  mechanic(:state, 443, :part => :riddle) do
    auto
    name 71, :rj_bs_purple_books, :when => lambda { |_ev| bs.story < 52 }
    phase lambda { bs.step?(48) }, :hint => :rj_bs_hint_book, :hidden => right_way(71)
    solved { bs.story >= 52 }
  end
  mechanic(:state, 437, :part => :riddle) do
    auto
    phase lambda { bs.step?(49) }, :hint => :rj_bs_hint_wall, :hidden => right_way(24)
    phase lambda { bs.step?(51) }, :hint => :rj_bs_hint_false_wall, :hidden => right_way(3, 4)
    solved { bs.story >= 52 }
  end
  mechanic(:state, 443, :part => :prestige) do
    auto
    name 69, :rj_bs_candelabra
    name 9, :rj_bs_bookcase, :when => false
    phase lambda { bs.step?(59) }, :hint => :rj_bs_hint_candelabra, :hidden => right_way(69)
    phase lambda { bs.step?(60) }, :hint => :rj_bs_hint_bookcase, :hidden => right_way(9)
    solved { bs.story >= 61 }
  end
end
