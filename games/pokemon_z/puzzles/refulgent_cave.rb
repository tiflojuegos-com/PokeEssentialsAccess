# Cueva Refulgente (maps 51 and 78): a crystal gives way, three tiles, only to a walk against it in the direction its
# touch page checks (133-137 turn on, the page empties; Ruta 7 and Novarte turn them off again). The rule is told on
# arrival while one can move; the hint goes by the nearest still to move.
PokeAccess::Game.define("pokemon_z") do
  [[51, [[27, 133, 11, 24, :z_crystal_down], [29, 134, 21, 29, :z_crystal_left], [31, 135, 33, 67, :z_crystal_right]]],
   [78, [[45, 136, 40, 20, :z_crystal_down], [52, 137, 39, 64, :z_crystal_right]]]].each do |map, crystals|
    still = lambda { crystals.reject { |row| $game_switches[row[1]] } }
    mechanic(:state, map) do
      arrival_hint lambda { still.call.empty? ? nil : :z_crystal_rule }
      phase lambda { !still.call.empty? }, :quiet => true,
            :hidden => { :events => crystals.map { |row| row[0] }, :label => :z_crystal },
            :hint => lambda {
              near = still.call.min_by { |row| (row[2] - $game_player.x).abs + (row[3] - $game_player.y).abs }
              near ? near[4] : nil
            }
    end
  end
end
