# Alpha Temple (maps 531 to 535): the doors (events named door, no graphic) either carry the player to another door of the same
# map, which is what is named here, or to the next room, which keeps the exit or entrance name the core gives it. In the
# keyboard room (map 536) the stone keyboard (event 1, at 13,19) asks a word, "birth", and switch 498 opens the doors of the north wall.
PokeAccess::Game.define("insurgence") do
  [[531, [2, 3, 4, 5, 8, 9, 10, 11]], [532, [2, 3, 4, 5]], [534, [6, 7]], [535, [2, 3, 4, 5]]].each do |map, doors|
    mechanic(:state, map) do
      auto
      name doors, :ins_u1_temple_door
      sent_back :ins_u1_temple_door_sent, :events => doors
    end
  end
  mechanic(:state, 536) do
    auto
    name 1, :ins_u1_stone_keyboard
    answer 1, "birth"
    active { !$game_switches[498] }
    solved(nil, :quiet => true) { $game_switches[498] }
  end
end
