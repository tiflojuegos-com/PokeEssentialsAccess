# Goldune's gym, two floors: map 85 above, map 86 below. Quicksand drops the player, and the boulders pushed into it, to the
# floor below. Above, the entrance boulder (event 21) falls through the sand beside it (switch 561) and comes down as event 5,
# whose plate opens door 1 (switch 568); its stairs lead up to two boulders (events 22 and 23) whose plates open door 2
# (switch 569, variable 153); its sand leads down to the stairs up to three boulders (events 3 to 5), which fall through the
# sand at 22,21 (switches 562 to 564) and come down as events 12, 8 and 20, whose three plates open door 3 (switch 570,
# variable 154) to Dustin. Any of the three takes any plate, and each counts once, by the self switch A of the parallel
# event that watches that rock on all three plates (events 24, 21 and 23): the first rock not yet counted is guided to the
# first plate nothing stands on, nearest the rocks' fall first. The third rock's watcher opens the door at 3 and counts it
# once more the next frame, so the count stops at 3. The three above go in from the lowest; the last one's pushes are spelt out, as the assisted plan runs out
# of budget on it. Leaving the gym resets it all; switch 7 is the badge.
PokeAccess::Game.define("solarlight") do
  badge = lambda { $game_switches[7] }
  door = lambda { |n| [:solar_goldune_door, { :n => n }] }
  fallen = lambda { $game_switches[562] && $game_switches[563] && $game_switches[564] }
  off_plate = lambda do |id, x, y|
    ev = $game_map.events[id]
    ev && !(ev.x == x && ev.y == y)
  end
  lower_plates = [[14, 26], [11, 33], [5, 30]]
  lower_rocks = [[20, 24], [12, 21], [8, 23]]
  counted = lambda { |check| $game_self_switches && $game_self_switches[[86, check, "A"]] ? true : false }
  next_placing = lambda do
    first = lower_rocks.find { |_id, check| !counted.call(check) }
    taken = lower_rocks.map { |id, _check| (ev = $game_map.events[id]) && [ev.x, ev.y] }
    plate = lower_plates.find { |xy| !taken.include?(xy) }
    first && plate ? [first[0], plate] : nil
  end
  rock = { :label => :solar_goldune_rock, :goal_label => :solar_goldune_plate }
  hole = { :label => :solar_goldune_rock, :goal_label => :solar_goldune_quicksand }

  mechanic(:state, 85) do
    name(/\AQuicksand/, :solar_goldune_quicksand, :grouped => true)
    name 27, door.call(2)
    spot :at => [39, 18], :label => :solar_goldune_plate, :onto => true
    spot :at => [43, 23], :label => :solar_goldune_plate, :onto => true
    watch :switch => 561, :label => :solar_goldune_entry_rock, :on => :solar_goldune_fell, :off => :solar_goldune_above
    watch :switch => 569, :label => door.call(2), :on => :solar_goldune_open, :off => :solar_goldune_shut
    count :solar_goldune_on_plates, :var => 153, :of => 2, :reset => false
    count :solar_goldune_rocks_fell, :switches => [562, 563, 564], :reset => false
    phase lambda { !$game_switches[561] }, :quiet => true, :hint => :solar_goldune_h_entry,
          :track => hole.dup.merge!(:event => 21, :goal => [37, 34, 37, 36])
    phase lambda { !$game_switches[568] }, :quiet => true, :hint => :solar_goldune_h_door1_above
    phase lambda { !$game_switches[569] && off_plate.call(23, 39, 18) }, :quiet => true, :hint => :solar_goldune_h_door2,
          :track => rock.dup.merge!(:event => 23, :goal => [39, 18, 39, 18])
    phase lambda { !$game_switches[569] && off_plate.call(22, 43, 23) }, :quiet => true, :hint => :solar_goldune_h_door2,
          :track => rock.dup.merge!(:event => 22, :goal => [43, 23, 43, 23])
    [[564, 5, :solar_goldune_h_three], [563, 4, :solar_goldune_h_three], [562, 3, :solar_goldune_h_three_last]].each do |sw, id, hint|
      phase lambda { !$game_switches[sw] }, :quiet => true, :hint => hint,
            :track => hole.dup.merge!(:event => id, :goal => [22, 21, 22, 21])
    end
    phase lambda { !$game_switches[570] }, :quiet => true, :hint => :solar_goldune_h_fall
    solved { badge.call }
    arrival_hint :solar_goldune_rule_above, :once => true
  end

  mechanic(:state, 86) do
    name 16, door.call(1)
    name 22, door.call(3)
    [[26, 33], [5, 30], [11, 33], [14, 26]].each { |xy| spot :at => xy, :label => :solar_goldune_plate, :onto => true }
    watch :switch => 568, :label => door.call(1), :on => :solar_goldune_open, :off => :solar_goldune_shut
    watch :switch => 570, :label => door.call(3), :on => :solar_goldune_open, :off => :solar_goldune_shut
    count :solar_goldune_on_plates, :value => lambda { [$game_variables[154].to_i, 3].min }, :of => 3, :reset => false
    phase lambda { !$game_switches[561] }, :quiet => true, :hint => :solar_goldune_h_start_below
    phase lambda { !$game_switches[568] }, :quiet => true, :hint => :solar_goldune_h_door1,
          :track => rock.dup.merge!(:event => 5, :goal => [26, 33, 26, 33])
    phase lambda { !$game_switches[569] }, :quiet => true, :hint => :solar_goldune_h_door2_below
    phase lambda { !fallen.call }, :quiet => true, :hint => :solar_goldune_h_three_below
    lower_rocks.each do |id, _check|
      lower_plates.each do |x, y|
        phase lambda { !$game_switches[570] && next_placing.call == [id, [x, y]] }, :quiet => true,
              :hint => :solar_goldune_h_plates, :track => rock.dup.merge!(:event => id, :goal => [x, y, x, y])
      end
    end
    phase lambda { !$game_switches[570] }, :quiet => true, :hint => :solar_goldune_h_plates
    phase lambda { true }, :quiet => true, :hint => :solar_goldune_h_dustin
    solved { badge.call }
    arrival_hint :solar_goldune_rule_below, :once => true
  end
end
