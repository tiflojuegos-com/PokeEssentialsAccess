# Castle Zygara (map 603): the blue floor switch (event 38) sets switch 1260, opening the barrier into the green one's
# room; the green switch (event 42) sets 1261, opening the other wing's barrier (map 422) and closing this one. The
# suspicious bookcase (events 20 and 21) is pushed by its Yes and opens the passage behind it (switch 1272).
module PokeAccess
  module RejuvCastleZygara
    # The assist's line, by how far the switches have gone.
    def self.hint
      return :rjg_cz_hint_done if $game_switches[1261]
      $game_switches[1260] ? :rjg_cz_hint_green : :rjg_cz_hint_blue
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  cz = PokeAccess::RejuvCastleZygara
  mechanic(:state, 603, :part => :switches) do
    auto
    name 38, lambda { |_ev| $game_switches[1260] ? :rjg_cz_blue_on : :rjg_cz_blue }
    name 42, lambda { |_ev| $game_switches[1261] ? :rjg_cz_green_on : :rjg_cz_green }
    name [20, 21], :rjg_cz_bookcase, :grouped => true, :assist => true, :when => lambda { |_ev| !$game_switches[1272] }
    active { PokeAccess::Puzzles.assist? }
    hint lambda { cz.hint }
  end
end
