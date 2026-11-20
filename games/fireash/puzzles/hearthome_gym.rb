# Hearthome's gym (map 611): five doors in a row, left to right events 3, 9, 10, 11 and 12; only the second leads to Fantina
# and the rest to a trainer's room, each with a pad back (13 to 17). Her badge fight (switch 158) ends it.
PokeAccess::Game.define("fireash") do
  doors = { 3 => :fa_door_1, 9 => :fa_door_2, 10 => :fa_door_3, 11 => :fa_door_4, 12 => :fa_door_5 }
  mechanic(:state, 611) do
    auto
    name doors.keys, lambda { |ev| PokeAccess::Puzzles.assist? && ev.id == 9 ? :fa_door_2_right : doors[ev.id] }
    name 13..17, PokeAccess::FireAshPads.namer((13..17).to_a, :fa_pad, :fa_pad_back)
    sent_back :fa_door_sent, :events => doors.keys
    arrival_hint :fa_doors_rule
    solved { $game_switches[158] }
  end
end
