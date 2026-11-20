# The Sunken Ship (map 249): invisible doors, events with no graphic that move the player to another room of the same map. The
# way to Krakanao crosses six rooms: the deck (entered at 9, 6), the hall of doors to the south, the south-west room, the
# rooms behind the dead coral that Coral Break clears (events 45, 47 and 49, all three needed) and the room of the monster.
# Each phase names the events that go on for the room the player stands in, found by a search over the tiles and the doors.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 249) do
    auto
    sent_back :ura_pp_ship_door, :events => [1, 2, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 41, 83, 84, 87, 88, 99]
    arrival_hint :ura_pp_ship_rule, :once => true
    unsolved = lambda { !$game_switches[159] }
    {
      :deck => [at(4, 20, 5, 13), [1, 2, 84, 87]],
      :dead_end => [at(8, 20, 16, 28), [9]],
      :hall => [at(8, 17, 39, 50), [10]],
      :south => [at(9, 28, 61, 66), [45, 47, 12]],
      :trap => [at(42, 52, 40, 50), [18, 19]],
      :middle => [at(22, 36, 9, 27), [49]],
      :east => [at(37, 46, 13, 25), [21, 99]]
    }.each do |room, (box, way)|
      phase lambda { unsolved.call && box.call }, :quiet => true, :hint => "ura_pp_ship_#{room}".to_sym, :hidden => right_way(*way)
    end
    solved { $game_switches[159] }
  end
end
