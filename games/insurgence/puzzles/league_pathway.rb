# Pokemon League Pathway (map 771). The Elite Four rooms (maps 428 to 431) send the player back to its north end (20,3),
# above an arch (20,10 to 13) that leads down to the hall. With the four beaten (variable 142 at 4 or more) the Giratina
# statue (event 1, 20,17) slides right as the map loads and carries the floor switch (event 9) onto its old tile;
# stepping on it turns switch 635 on, which makes the arch's tile 20,12 (event 20) the one way to the Champion Room. The
# statue is on screen only from x 13 to 27, y 11 to 22, so its line waits for the player to come down the arch. No
# auto: the core would count the arch's change as three passages.
PokeAccess::Game.define("insurgence") do
  door_open = lambda { $game_switches[635] }
  armed = lambda { ($game_variables[142] || 0).to_i >= 4 && !door_open.call }
  mechanic(:state, 771) do
    in_view = at(13, 27, 11, 22)
    spot :at => [20, 17], :label => :ins_league_switch, :onto => true, :when => armed
    phase lambda { armed.call && in_view.call }, :title => :ins_league_statue_moved, :entry_title => true,
          :hint => :ins_league_switch_hint
    phase lambda { armed.call && PokeAccess::Puzzles.assist? }, :quiet => true, :hint => :ins_league_switch_hint
    solved(:ins_league_door_open) { door_open.call }
  end
end
