# Venesi City's gym (map 147): ice that slides the player until something stops them, and a fake leader, Iago (event 7), whose
# defeat drops the player to (42, 11), by the real leader Rosalind (event 24). The core already routes the ice.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 147) do
    auto
    arrival_hint :ura_pz_venesi_rule, :once => true
    solved(nil) { $game_switches[112] }
    spot :event => 24, :label => :ura_pz_venesi_leader, :assist => true
    sent_back :ura_pz_venesi_fall, :to => [42, 11], :events => [7]
  end
end
