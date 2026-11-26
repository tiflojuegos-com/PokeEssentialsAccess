# School of Nightmares (map 94), Platinum route: the two masked men (events 25 and 26) let the group on, variable 684 to
# 4, only for a password typed in a text entry; its hint is on a classroom's board. With the puzzle assist the core says
# the answer as the entry opens, as the page compares it with a fixed word.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 94, :part => :masked_men) do
    auto
    name [25, 26], :rj_school_masked_man, :when => lambda { |_ev| $game_switches[1324] }
    hint :rj_school_password_hint
    active { $game_switches[1324] && $game_variables[684].to_i < 4 }
    solved(nil, :quiet => true) { $game_variables[684].to_i >= 4 }
  end
end
