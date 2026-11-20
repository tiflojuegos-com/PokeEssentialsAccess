# The ice floors: the Seafoam Islands' three lower floors (maps 133, 134 and 135; 130 and 136 have no ice) and the
# Glacial Cave (map 198, beside its Guardian Bird altar). The player slides on until something stops them, and the
# routes already plan the slides; this says the floor's rule on the first arrival.
PokeAccess::Game.define("anil") do
  mechanic(:state, [133, 134, 135]) do
    auto
    arrival_hint :anil_ice_rule, :once => true
  end

  mechanic(:state, 198, :part => :ice) do
    auto
    arrival_hint :anil_ice_rule, :once => true
  end
end
