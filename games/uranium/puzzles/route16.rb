# Route 16 (map 132): a field of ice where the player slides in the facing direction until something stops them.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 132) do
    auto
    arrival_hint :ura_po_r16_rule, :once => true
  end
end
