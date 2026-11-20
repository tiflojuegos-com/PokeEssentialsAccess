# Sky Pillar's floors (maps 634, 639, 640 and 641, each above the one the common event 36 drops to): the cracked tiles are
# events drawn as BW154 that a step on makes the player fall to the floor below, near the same place; the walks keep off them while
# there is another way, and on these four floors there is none, so they cross some.
PokeAccess::Game.define("infinitefusion") do
  [634, 639, 640, 641].each do |map|
    mechanic(:state, map) do
      auto
      obstacle(/BW154/, :moving => true)
      avoid(/BW154/)
      arrival_hint :ifq_sky_rule
    end
  end
end
