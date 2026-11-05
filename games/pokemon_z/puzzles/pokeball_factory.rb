# Fábrica de Pokéball (maps 235 and 236): three levers (switches 484, 485, 488) turn a pushing tile each with nothing
# said: 235's (12,20), which then lets the player past on the way to the stairs (3,25), 236's (24,7), on the way to its
# stairs (21,7), and 235's (9,9), on the way to the door (10,4). The way on is by the guide's order, from each part of
# map 235: its north-west only leaves by the lift tile (event 34), the east reaches the second lever, the stairs (36,18)
# serve the east part around (36,23), and the north part holds the third lever and the door. Switch 491, set by the scene
# past that door, ends it: what is left on these floors is reached without the levers.
PokeAccess::Game.define("pokemon_z") do
  factory_open = lambda { !$game_switches[491] }
  factory_nw = lambda { me = $game_player; (me.x <= 5 || (me.x <= 11 && me.y >= 12)) && me.y <= 19 }
  factory_east = lambda { me = $game_player; (me.x >= 21 && me.y <= 29) || (me.x >= 23 && me.y <= 34) }
  factory_stairs = lambda do
    me = $game_player
    me.y >= 19 && (me.x >= 36 || (me.y >= 23 && me.x >= 31) || (me.y == 27 && me.x >= 29))
  end
  factory_north = lambda do
    me = $game_player
    (me.x >= 14 && me.x <= 28 && me.y <= 20) || (me.x >= 7 && me.x <= 32 && me.y <= 11)
  end
  mechanic(:state, 235) do
    watch :switch => 484, :label => :z_factory_lever_nw, :on => :z_factory_lever_nw_on, :off => :z_factory_lever_off
    watch :switch => 485, :label => :z_factory_lever_mid, :on => :z_factory_lever_mid_on, :off => :z_factory_lever_off
    watch :switch => 488, :label => :z_factory_lever_ne, :on => :z_factory_lever_ne_on, :off => :z_factory_lever_off
    controls
    [[lambda { !$game_switches[484] }, 12, :z_factory_go_nw],
     [factory_nw, 34, :z_factory_lift],
     [lambda { !$game_switches[485] && factory_east.call }, 20, :z_factory_go_mid],
     [lambda { !$game_switches[485] }, 6, :z_factory_up_sw],
     [factory_stairs, 7, :z_factory_up_e],
     [lambda { !$game_switches[488] && factory_north.call }, 33, :z_factory_go_ne],
     [factory_north, 9, :z_factory_door],
     [lambda { true }, 6, :z_factory_up_sw]].each do |live, event, key|
      phase lambda { factory_open.call && live.call }, :hint => key, :hidden => right_way(event)
    end
  end
  mechanic(:state, 236) do
    phase lambda { factory_open.call && !$game_switches[485] }, :hint => :z_factory_down_e, :hidden => right_way(6)
    phase factory_open, :hint => :z_factory_down_n, :hidden => right_way(7)
  end
end
