# Fort Leviatán, the cells (map 126): the table of the lower right cell (event 2) moves up with an action and only a
# sound, switch 265, and its tile is then the secret way out; the lever of the lower left cell (event 14, switch 266)
# opens the central cell, as silent.
PokeAccess::Game.define("pokemon_z") do
  mechanic(:state, 126) do
    solved(nil, :quiet => true) { $game_switches[265] && $game_switches[266] }
    watch :switch => 265, :label => :z_fort_table, :on => :z_fort_moved, :off => :z_fort_still
    watch :switch => 266, :label => :z_fort_cell, :on => :z_fort_open, :off => :z_fort_closed
    spot :event => 2, :label => lambda { $game_switches[265] ? :z_fort_way_out : :z_fort_table }
    spot :event => 14, :label => :z_fort_lever
    hint :z_fort_hint
  end
end
