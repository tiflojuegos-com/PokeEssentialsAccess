# Fort Leviatán, the cells (map 126): the table of the lower right cell (event 2) moves up with an action and only a
# sound, switch 265, and its tile is then the secret way out; the lever of the lower left cell (event 14, switch 266)
# opens the central cell, as silent. Map 125: a parallel process (event 38) sends the player standing on (6,46) to map 106,
# with no event on that tile. The platform there is covered by a false wall, events 29 to 37 ("#EOT HIDE"), and event 30's
# tile shuts (6,46) until the Lens of Truth reaches it: the platform is listed while it does, and with the assist, the
# covered platform and that it takes the lens.
PokeAccess::Game.define("pokemon_z") do
  open = lambda { PokeAccess::World::Lens.reaches?($game_map.events[30]) }
  mechanic(:state, 125) do
    auto
    spot :at => [6, 46], :onto => true, :label => :z_fort_platform, :when => open
    spot :at => [6, 46], :onto => true, :assist => true, :when => lambda { !open.call },
         :label => lambda { [:z_fort_platform_lens, { :item => PokeAccess::World::Lens.item_name }] }
  end

  mechanic(:state, 126) do
    solved(nil, :quiet => true) { $game_switches[265] && $game_switches[266] }
    watch :switch => 265, :label => :z_fort_table, :on => :z_fort_moved, :off => :z_fort_still
    watch :switch => 266, :label => :z_fort_cell, :on => :z_fort_open, :off => :z_fort_closed
    spot :event => 2, :label => lambda { $game_switches[265] ? :z_fort_way_out : :z_fort_table }
    spot :event => 14, :label => :z_fort_lever
    hint :z_fort_hint
  end
end
