# Blaine's gym (Cinnabar Island, map 131): five rooms of three doors with no sprite. A door asks a riddle with a menu and
# takes the player to the next room, where a helper fights them; the last room's doors lead to Blaine instead, with no helper
# and no burn. V64 counts the rooms crossed. The riddle is drawn from the door's own bank by V61, and its right option is the
# one that does not add to V62: a wrong one costs the extra prize and, before a helper, burns up to three Pokemon.
PokeAccess::Game.define("anil") do
  doors = { 1 => [14, 16, 17], 2 => [21, 32, 33], 3 => [48, 49, 50], 4 => [51, 52, 53], 5 => [54, 55, 56] }
  last = doors.length
  mechanic(:state, 131) do
    auto
    doors.each { |room, ids| name ids, [:anil_riddle_door, { :n => room }] }
    right_choice doors.values.flatten, :avoids => { :var => 62 }
    sent_back :anil_riddle_passed, :events => (1...last).map { |room| doors[room] }.flatten
    sent_back :anil_riddle_leader, :events => doors[last]
    count :anil_riddle_rooms, :var => 64, :of => last
    solved(nil) { $game_variables[64].to_i >= last }
    arrival_hint :anil_riddle_rule
  end
end
