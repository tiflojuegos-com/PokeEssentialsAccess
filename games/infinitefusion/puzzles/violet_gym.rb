# Violet Gym (map 363): the sand of the east platform is a drop. A parallel event sends a player on sand to column 6 of
# their row, with a falling animation, and elevators switch the soft wind (switch 357) that pushes the player two tiles
# south over and over. Routes keep off the sand, which is named as the drop it is. Beating Falkner sets switch 40.
PokeAccess::Game.define("infinitefusion") do
  sand = lambda { |x, y| $game_map.map_id == 363 && PokeAccess::World::Terrain.kind(x, y) == :sand }

  terrain_rule(:kinds => [:sand]) { |x, y, _d| sand.call(x, y) ? false : nil }
  PokeAccess::World::Terrain.label_rule { |x, y| sand.call(x, y) ? :if_jo_sand_drop : nil }

  mechanic(:state, 363) do
    auto
    watch :switch => 357, :label => :if_jo_wind, :on => :if_jo_wind_on, :off => :if_jo_wind_off
    arrival_hint :if_jo_violet_rule
    solved { $game_switches[40] }
    sent_back :if_jo_violet_fall, :from => [18, 26, 1, 28], :to => [6, 6, 0, 30]
  end
end
