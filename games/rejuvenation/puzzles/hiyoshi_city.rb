# Hiyoshi City in Aevium's past (map 375), Nymiera's house: with variable 546 at 100, the bookcase at (47, 64) hides a
# switch (event 60, no graphic) that opens a staircase down (546 to 101, then 102); past it, the Timesplicer crystal
# takes the group back to the present.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 375, :part => :nymiera_bookcase) do
    auto
    name 60, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rj_nymiera_switch : :rj_nymiera_bookcase },
         :when => lambda { |_ev| $game_variables[546].to_i == 100 }
    hint :rj_nymiera_hint
    active { $game_variables[546].to_i == 100 }
    solved(nil, :quiet => true) { $game_variables[546].to_i >= 101 }
  end
end
