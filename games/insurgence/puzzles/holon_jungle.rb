# Holon Jungle (map 454): either of the two boulders (events 65 and 67), pushed onto the tile at 39,31, turns switch 529 on
# and draws the door of the north wall (39 to 41, 22 to 24). Both can be pushed there from the Settlement Alfa entrance.
PokeAccess::Game.define("insurgence") do
  open_door = lambda { $game_switches[529] }
  mechanic(:state, 454) do
    auto
    spot :at => [39, 31], :label => :ins_u2_jungle_plate, :assist => true, :when => lambda { !open_door.call }
    active { !open_door.call }
    solved(nil, :quiet => true) { open_door.call }
    hint :ins_u2_jungle_hint
  end
end
