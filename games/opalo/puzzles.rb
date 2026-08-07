# Opalo gym (map 46, "Gimnasio Pokemon"): two three-tile machines and two levers, all of them silent about
# what they did. Everything below was read out of Data/Map046.rxdata rather than guessed.
#
# The machines sit at (5..7,9) and (36..38,8) and run the same script: "Activar la maquinaria?" -- if switch
# 174 is already on it sets 178 (Water2), otherwise 174 (Fire5). Each then sets its own guard switch (243
# left, 244 right), which swaps in an empty second page, so each machine works exactly ONCE, and no event
# anywhere turns 174, 178, 243 or 244 back off. The room therefore has three states and the player passes
# through them one way, which is why 178 is watched as well as 174.
#
# There are NO obstacles here. All sixteen "Humo" events on the map are through=true, and the tile-graphic
# events that appear with 174/178 (columns 23-25) use tiles whose tileset passage byte is 0x00, passable
# from every side. Obstacle matching in core is by sprite name only and never consults passability, so
# declaring them would put a wall on the open floor of a gym.
#
# No :solved either: the door to the leader at (24,8) transfers to map 103 from its first page with no
# switch condition, so nothing in this room gates it and there is no win state to announce.
PokeAccess::Game.define("opalo") do
  puzzle(46,
    :kind => :state,
    :watch => [
      { :switch => 174, :label => :op_machine,  :on => :op_on, :off => :op_off },
      { :switch => 178, :label => :op_machine2, :on => :op_on, :off => :op_off },
      { :switch => 175, :label => :op_lever1,   :on => :op_on, :off => :op_off },
      { :switch => 177, :label => :op_lever2,   :on => :op_on, :off => :op_off }
    ])
end
