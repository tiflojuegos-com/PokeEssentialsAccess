# Nacrene's museum (map 673): a wall of bookcases, events 9, 13, 14, 16, 17, 21 and 25, with no sprite but 14 and 25, drawn
# with a tile, each answering only when pressed facing up. Six say "No switch here"; event 25, at (15, 11), says "A switch!", sets switch 215 and
# turns the door at (15, 10) into the way to the gym. The door's change is said by the core.
PokeAccess::Game.define("fireash") do
  cases = [9, 13, 14, 16, 17, 21, 25]
  mechanic(:state, 673) do
    auto
    name 25, lambda { |_ev| PokeAccess::Puzzles.assist? ? :fa_bookcase_switch : :fa_bookcase },
         :when => lambda { |_ev| !$game_switches[215] }
    name cases - [25], :fa_bookcase, :when => lambda { |_ev| !$game_switches[215] && !PokeAccess::Puzzles.assist? }
    hide cases - [25], :assist => true
    arrival_hint :fa_bookcases_rule
    solved { $game_switches[215] }
  end
end
