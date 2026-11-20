# Second gym, Ciudad Óleo (map 69): dark rooms in a grid of five by five, joined by corridors whose touch events, with no
# graphic, carry the player to the next room when walked into toward it; four at the ends of corridors that look closed
# (events 17, 18, 32 and 33) go 21 tiles through the wall. The lift to the leader (event 3) sets 94. Each room's way on
# to the lift was walked over the map's events from the entrance. A carried player is in no room: the tunnels cross
# rooms on the way, whose hint would be wrong there.
PokeAccess::Game.define("pokemon_z") do
  cols = [[2, 8], [17, 23], [32, 38], [47, 53], [62, 68]]
  rows = [[7, 11], [19, 24], [33, 37], [46, 50], [59, 63]]
  steps = { :z_gym2_up => [4, 9, 11], :z_gym2_down => [2, 12, 21, 22, 23, 30],
            :z_gym2_left => [38, 39, 40, 43, 44, 45, 64, 66, 68], :z_gym2_right => [47, 51, 52, 58],
            :z_gym2_tunnel => [17, 18], :z_gym2_lift => [3] }
  key_of = {}
  steps.each { |key, ids| ids.each { |id| key_of[id] = key } }
  rooms = [[1, 0, 30], [2, 0, 45], [3, 0, 68], [4, 0, 44], [0, 1, 3], [1, 1, 2], [2, 1, 58], [3, 1, 12], [4, 1, 43],
           [0, 2, 11], [1, 2, 38], [2, 2, 18], [3, 2, 39], [4, 2, 66], [0, 3, 21], [1, 3, 22], [2, 3, 23], [3, 3, 40],
           [4, 3, 9], [0, 4, 47], [1, 4, 51], [2, 4, 52], [3, 4, 17], [4, 4, 64]]
  zones = [[at(30, 40, 71, 86), 4]] + rooms.map { |c, r, id| [at(cols[c][0], cols[c][1], rows[r][0], rows[r][1]), id] }
  mechanic(:state, 69) do
    auto
    arrival_hint :z_gym2_rule
    solved(nil, :quiet => true) { $game_switches[94] }
    phase lambda { ($game_player.move_route_forcing rescue false) ? true : false }, :quiet => true
    zones.each do |zone, id|
      phase lambda { !$game_switches[94] && zone.call }, :hint => key_of[id], :hidden => right_way(id)
    end
  end
end
