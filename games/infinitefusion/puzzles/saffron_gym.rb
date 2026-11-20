# Saffron City Gym (map 152): 21 same-map teleport pads. The way from the door to the leader's room (Sabrina, beaten when
# switch 9 is on) crosses pads 60, 62, 16 and 46, in that order; the assist lists them as the right way.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 152) do
    auto
    phase lambda { !$game_switches[9] }, :quiet => true, :hint => :ifk_sg_hint, :hidden => right_way(60, 62, 16, 46)
  end
end
