# The gym of Amberino Town (maps 252 and 253): the door to Dhara opens once the three Flygon raising the sandstorm are
# beaten (variable 117). Nine hidden quicksands of the upper room drop the player into the sand room below; three of
# them, where the floor sounds of Flygon (terrain 36), land by a Flygon. The teleporters below and the Cacturne send the
# player back to the upper room's entrance (16, 42).
module PokeAccess
  module RealideaAmberino
    UPPER = 252
    LOWER = 253
    BEATEN = 117
    FLYGON_SANDS = [3, 5, 6]
    ENTRANCE = [16, 42]
  end
end

PokeAccess::Game.define("realidea") do
  gym = PokeAccess::RealideaAmberino
  mechanic(:state, gym::UPPER) do
    auto
    count :rea_amberino_flygons, :var => gym::BEATEN, :of => 3, :announce => false
    name gym::FLYGON_SANDS, :rea_amberino_flygon_sand, :assist => true
    sent_back :rea_amberino_back, :maps => [gym::LOWER], :to => gym::ENTRANCE
    solved(nil, :quiet => true) { $game_variables[gym::BEATEN] >= 3 }
    hint :rea_amberino_hint
  end
  mechanic(:state, gym::LOWER) do
    auto
    count :rea_amberino_flygons, :var => gym::BEATEN, :of => 3, :announce => false
    solved(nil, :quiet => true) { $game_variables[gym::BEATEN] >= 3 }
  end
end
