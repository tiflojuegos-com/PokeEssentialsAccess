# Miraijima's four seals (OQ8, hidden quest): a riddle at (39, 13) of map 153 names four companions, and four buttons with no
# graphic want them in order, each with its species in the party: Blastoise on map 159, Pikachu on 145, Venusaur on 161 and
# Charizard on 151. Var 119 counts the buttons in; a button pressed out of turn lets them all out again and sets it to 0,
# while one pressed without its species does nothing. With the four in (var 119 at 4) the way of map 253 to its inner cave
# opens and the riddle is done: its page never changes, so the count is the end.
PokeAccess::Game.define("keishou") do
  seals = { 159 => [33, 1], 145 => [19, 2], 161 => [49, 3], 151 => [27, 4] }
  all_in = lambda { $game_variables[119] >= 4 }
  seals.each do |map, (event, order)|
    mechanic(:state, map) do
      auto
      name event, lambda { PokeAccess::Puzzles.assist? ? "ks_o_seal_#{order}".to_sym : :ks_o_seal },
           :when => lambda { |_ev| !$game_self_switches[[map, event, "A"]] }
      count :ks_o_seals_in, :var => 119, :of => 4, :assist => true, :reset => :ks_o_seals_out
      hint :ks_o_seals_hint
      solved(nil, &all_in)
    end
  end
  mechanic(:state, 153) do
    auto
    name 48, :ks_o_seal_riddle, :when => lambda { |_ev| !all_in.call }
    hint :ks_o_seals_hint
    solved(nil, &all_in)
  end
end
