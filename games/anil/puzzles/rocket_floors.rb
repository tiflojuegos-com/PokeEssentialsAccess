# The carrying floors of the Rocket Hideout (maps 83 and 84) and of the Rocket Warehouse off Route 27 (map 214): touch
# tiles with no sprite that carry the player several tiles in a line. The routes already follow them; this says the
# floor's rule on the first arrival.
PokeAccess::Game.define("anil") do
  mechanic(:state, [83, 84, 214]) do
    auto
    arrival_hint :anil_carry_rule, :once => true
  end
end
