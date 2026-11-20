# Hekate Town (map 245): six teleport orbs (events 1 to 6, "Particle effect - aura") join three clearings in pairs: the
# northwest one (Murk Forest, the Pokemon Center), the southwest one (Fiery Caverns) and the east one (Route 12).
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 245) do
    auto
    name 1..6, :ins_hekate_orb
    sent_back :ins_hekate_sent, :events => 1..6
    active { true }
    hint :ins_hekate_hint
    arrival_hint :ins_hekate_rule, :once => true
  end
end
