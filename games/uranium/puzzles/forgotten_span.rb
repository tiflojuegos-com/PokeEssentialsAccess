# The cracked ice of the Forgotten Span (maps 245 and 246): a tile holds the first step and breaks on the second, which
# throws the player back to where the ice began.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 245) do
    auto
    name(/\ACracked Ice\z/, :ura_pp_ice_name, :when => false)
    arrival_hint lambda { ($game_variables[131] || 0).to_i >= 12 ? :ura_pp_ice_rule : nil }, :once => true
  end

  mechanic(:state, 246) do
    auto
    name(/\ACracked Ice\z/, :ura_pp_ice_name, :when => false)
    arrival_hint :ura_pp_ice_rule, :once => true
    sent_back :ura_pp_ice_fell, :to => [17, 17, 65, 67], :events => /\ACracked Ice\z/
    sent_back :ura_pp_ice_fell, :to => [15, 15, 4, 6], :maps => 245
  end
end
