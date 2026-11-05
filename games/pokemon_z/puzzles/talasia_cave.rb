# Cueva Talasia (map 433): nine rooms of four doors with no graphic, three across and three down, each 26 by 24 tiles.
# The great rocks a room's tiles draw tell its door, as on a clock: 3 east, 6 south, 9 west, 12 north. A wrong door lands
# at the room's entrance, in the sixth at the fifth's; the eighth's right door leads to Mew (event 4). Mew met (its self
# switch A, set once the fight is over) ends the rule and the rooms' lines on the info key: the tile of its room sends the
# player back to the first room, which has the exit.
PokeAccess::Game.define("pokemon_z") do
  talasia_room = lambda { |place| [place[0] / 26, place[1] / 24] }
  mew_met = lambda { $game_self_switches[[433, 4, "A"]] }
  PokeAccess::Locator.teleport_cause(:z_talasia_wrong) do |from, to|
    wrong = to[2] == 433 && (talasia_room.call(from) == talasia_room.call(to) ||
                             (talasia_room.call(from) == [1, 2] && to == [37, 41, 433]))
    wrong ? PokeAccess::I18n.t(:z_talasia_wrong) : nil
  end
  # A wrong door can land on or beside the tile stepped on, too near for the teleport reading to tell it from a step.
  before("Scene_Map", :transfer_player, :optional => true) do |_scene, _args|
    temp = $game_temp
    next unless $game_map.map_id == 433 && temp.player_new_map_id == 433
    near = ($game_player.x - temp.player_new_x).abs + ($game_player.y - temp.player_new_y).abs <= 1
    PokeAccess.speak(PokeAccess::I18n.t(:z_talasia_wrong), false) if near
  end
  mechanic(:state, 433) do
    arrival_hint :z_talasia_rule
    solved { mew_met.call }
    [[0, 0, 3, 2, :z_talasia_e], [0, 1, 6, 10, :z_talasia_s], [0, 2, 6, 14, :z_talasia_s], [1, 0, 12, 15, :z_talasia_n],
     [1, 1, 3, 22, :z_talasia_e], [1, 2, 3, 23, :z_talasia_e], [2, 0, 6, 27, :z_talasia_s],
     [2, 1, 9, 31, :z_talasia_w]].each do |column, row, rocks, door, key|
      room = at(column * 26, column * 26 + 25, row * 24, row * 24 + 23)
      phase lambda { room.call && !mew_met.call },
            :title => [:z_talasia_rocks, { :n => rocks }], :entry_title => true, :hint => key,
            :hidden => right_way(door)
    end
    mew_room = at(52, 77, 48, 71)
    phase lambda { mew_room.call && !mew_met.call }, :hint => :z_talasia_mew,
          :hidden => right_way(4)
  end
end
