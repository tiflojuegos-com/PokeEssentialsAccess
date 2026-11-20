# Dragon's Den (map 335): a parallel event moves the whirlpools (events 8 to 67) about the pool again and again;
# touching one spins the player and pushes them a tile up.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 335) do
    auto
    obstacle({ :events => (8..67).to_a }, :moving => true)
    arrival_hint :ifp_whirlpool_rule
    sent_back :ifp_whirlpool_push, :forced => true
  end
end
