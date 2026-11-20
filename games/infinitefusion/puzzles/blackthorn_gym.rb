# Blackthorn Gym: the door at (4,12) of map 377 leads to map 426, where six rocks go into three holes at (7,9), (13,12) and
# (13,5); any rock in any hole fills it and sets switch 360, 361 or 362, which lays a bridge over a gap of map 377. Walking
# into a hole drops the player to 377, at the bridge once it is filled. Map 377's east part (holes at (42,9), (48,12) and
# (48,5), reached by pressing the bare tile at (15,24) twenty times) does the same with three rocks.
PokeAccess::Game.define("infinitefusion") do
  holes = {
    426 => { 360 => [7, 9], 361 => [13, 12], 362 => [13, 5] },
    377 => { 360 => [42, 9], 361 => [48, 12], 362 => [48, 5] }
  }

  mechanic(:state, [377, 426]) do
    auto
    count :if_jo_holes_filled, :switches => [360, 361, 362]
    arrival_hint(lambda { $game_map.map_id == 426 ? :if_jo_blackthorn_rule : nil }, :once => true)
    hint :if_jo_blackthorn_hint
    holes.each do |map, at|
      at.each do |switch, xy|
        spot :at => xy, :when => lambda { $game_map.map_id == map },
             :label => lambda { $game_switches[switch] ? :if_jo_hole_down : :if_jo_hole }
      end
    end
  end
end
