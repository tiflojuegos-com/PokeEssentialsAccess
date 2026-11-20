# Cracked floors that give way: Sky Pillar's later copy (maps 576 and 578, over 575 and 577) and Mirage Tower (maps 810
# and 811, over 809 and 810). Each tile holds once if crossed by bike with a direction key held, gives way otherwise or
# on a second step, and drops the player to the floor below; arriving mends every tile. The upper Granite Cave (map
# 144) has cracked ground that holds only while riding a bike, and drops a walker to map 145.
PokeAccess::Game.define("emerald") do
  mechanic(:state, [576, 578, 810, 811]) do
    auto
    arrival_hint :em_crumble_rule, :once => true
    hint :em_crumble_hint
  end

  mechanic(:state, 144) do
    auto
    arrival_hint :em_bike_floor_rule, :once => true
    hint :em_bike_floor_hint
  end
end
