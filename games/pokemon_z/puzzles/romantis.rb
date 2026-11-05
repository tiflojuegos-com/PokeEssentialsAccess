# Bastión de Romantis: the purple symbol of map 277 (event 4, from switch 479 until 493 opens the leader's room) leads
# to map 276, seven rooms of tiles that warp with nothing said. With the assist alone, each room's way on is said on
# landing: five rooms in a chain to the leader's, and two out of the way. The leader beaten (switch 493, set by her event
# after the badge) ends the keep's rule and its rooms' lines on the info key.
PokeAccess::Game.define("pokemon_z") do
  mechanic(:state, 277) do
    phase lambda { $game_switches[479] && !$game_switches[493] }, :quiet => true, :hint => :z_romantis_start,
          :spots => [{ :event => 4, :label => :z_romantis_symbol }]
  end
  mechanic(:state, 276) do
    arrival_hint :z_romantis_rule
    solved { $game_switches[493] }
    [[at(2, 11, 37, 44), 3, :z_romantis_1], [at(39, 49, 21, 28), 17, :z_romantis_2],
     [at(39, 49, 37, 44), 20, :z_romantis_3], [at(2, 11, 20, 28), 6, :z_romantis_4],
     [at(39, 49, 5, 12), 13, :z_romantis_5], [at(2, 11, 5, 12), 9, :z_romantis_side_tm],
     [at(20, 30, 6, 12), 10, :z_romantis_side_west]].each do |zone, event, key|
      phase zone, :hint => key, :hidden => right_way(event)
    end
  end
end
