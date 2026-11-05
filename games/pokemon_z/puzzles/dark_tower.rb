# Torre Oscura, maps 262-264: the Hypno statues stand by switch (458, 459, 460, 461, 466; gone with 462 for one, 468
# for all), flipped with nothing said by sensors on the floor: 264's (42,28) sets 458 and clears 459, 263's (57,25)
# the reverse, 264's (63,24) sets 460 and clears 459 and 461, 264's (5,20) sets 461 and clears 460. 461 closes the
# central room of 262, where Lanto tells the jukebox's code (462 on meeting him); 460 the east door of 262's hall; 458
# the corridor to 264's south-east room, which from 264's south room the way north through (42,28) closes. Each lambda
# answers the next step from a map's parts in each state: Lanto,
# the jukebox (463), the north door (465 once its monster falls). 263's purple lever (455) lets the player leave by
# the south. 264's rule is told until Lanto is met; west of its sensor (5,19-20), its tile (3,14) keeps 460 on, unless
# 459 walls the room it lands in.
PokeAccess::Game.define("pokemon_z") do
  tower_262 = lambda do
    west_room = $game_switches[459] && $game_player.x <= 9 && $game_player.y <= 11
    if $game_switches[468] then nil
    elsif $game_player.x >= 42
      if !$game_switches[462] then $game_switches[461] ? :z_tower_e_tp : :z_tower_e_down
      elsif !$game_switches[463] then :z_tower_jukebox
      else :z_tower_north_door
      end
    elsif west_room then :z_tower_pocket
    elsif !$game_switches[462]
      if $game_switches[461] then :z_tower_w_tp
      elsif $game_player.x >= 30 then :z_tower_pocket
      else :z_tower_lanto
      end
    elsif !$game_switches[460] || $game_player.x >= 30 then :z_tower_w_east
    elsif $game_switches[459] then :z_tower_w_tp
    else :z_tower_w_down
    end
  end
  tower_263 = lambda do
    if $game_switches[468] then nil
    elsif $game_switches[458] && $game_player.x == 18 && $game_player.y <= 5 then :z_tower_pocket
    elsif $game_switches[458] && $game_player.y <= 10 && $game_player.x >= 44 && $game_player.x <= 50 then :z_tower_room_tp
    elsif $game_player.x >= 43 then :z_tower_rooms
    elsif $game_switches[462] then :z_tower_doors_up
    else :z_tower_door_nw
    end
  end
  tower_264 = lambda do
    se_room = $game_player.x >= 60 && ($game_player.y >= 25 || ($game_switches[458] && $game_player.y >= 23))
    on_sensor = $game_player.x == 63 && $game_player.y == 24
    west = $game_player.x <= 28
    south_room = $game_player.x <= 44 && ($game_player.y >= 29 || ($game_player.y >= 27 && $game_player.x <= 41))
    if $game_switches[468] then nil
    elsif $game_switches[459] && $game_player.x >= 18 && west then :z_tower_pocket
    elsif !$game_switches[462]
      if $game_switches[461]
        if se_room then :z_tower_sensor
        elsif west || $game_switches[458] || south_room then :z_tower_up
        else :z_tower_sensor_far
        end
      elsif se_room || on_sensor then :z_tower_se_back
      elsif !west then :z_tower_west_door
      else $game_player.x <= 4 && !$game_switches[459] ? :z_tower_west_tile : :z_tower_up
      end
    elsif se_room && $game_switches[458] then :z_tower_se_back
    elsif !west || $game_switches[459] then :z_tower_up
    else :z_tower_east_door
    end
  end
  [[262, tower_262, [:z_tower_e_tp, :z_tower_e_down, :z_tower_jukebox, :z_tower_north_door, :z_tower_pocket, :z_tower_w_tp,
                     :z_tower_lanto, :z_tower_w_east, :z_tower_w_down]],
   [263, tower_263, [:z_tower_pocket, :z_tower_room_tp, :z_tower_rooms, :z_tower_doors_up, :z_tower_door_nw]],
   [264, tower_264, [:z_tower_pocket, :z_tower_sensor, :z_tower_up, :z_tower_sensor_far, :z_tower_se_back,
                     :z_tower_west_door, :z_tower_west_tile, :z_tower_east_door]]].each do |map, step, keys|
    mechanic(:state, map) do
      if map == 263
        watch :switch => 455, :label => :z_tower_lever, :on => :z_tower_lever_on, :off => :z_tower_lever_off
        controls
      end
      arrival_hint lambda { $game_switches[462] || $game_switches[468] ? nil : :z_tower_rule } if map == 264
      obstacle(/\AestatuasHypno\z/, :label => :z_tower_statue)
      keys.each { |key| phase lambda { step.call == key }, :hint => key }
    end
  end

  # Torre Oscura, map 265: three rooms in normal colours (A), upside down (B) and in negative ones (C), whose doors warp
  # with nothing said. A: var 185 counts its lower left door (event 4), three in a row lead to B; its lower right door
  # sets it back to 0, and past 3 (a return the stairs of 266 did not reset) only that door helps. B: its north doors
  # (events 6 and 7) swap the player between them over vars 187 and 188, and pressing up against them always ends in C.
  # C has no counter: the stairs of its central room (event 11) go down to 266. Hibis beaten (470, set by her event in 266
  # once the fight is won; 468 only says the player asked her for time) ends the rule and the rooms' lines on the info key.
  mechanic(:state, 265) do
    arrival_hint :z_tower_doors_rule
    solved { $game_switches[470] }
    room_a = at(0, 30, 0, 24)
    phase lambda { room_a.call && $game_variables[185] >= 3 }, :quiet => true, :title => :z_tower_room_a,
          :hint => :z_tower_a_reset, :hidden => right_way(5)
    phase room_a, :title => :z_tower_room_a, :hint => :z_tower_a_hint, :hidden => right_way(4),
          :progress => { :var => 185, :of => 3, :label => :z_tower_count, :assist => true, :announce => true,
                         :hide_zero => true }
    phase at(36, 66, 0, 21), :title => :z_tower_room_b, :hint => :z_tower_b_hint, :hidden => right_way(6, 7)
    phase at(0, 30, 31, 51), :title => :z_tower_room_c, :hint => :z_tower_c_hint, :hidden => right_way(11)
  end
end
