# Opalo's heist of the Golden Bug casino: the garage door (event 12 of map 342) wants the generator's power (switch 621),
# whose lever (event 38 of map 341) stands behind a door of map 341 (events 28 to 37) that the lever of map 342 (event 11,
# switch 620) opens; a third lever (event 45 of map 341, switch 675) opens the door of events 39 to 44. With the assist, the
# info key tells the way until the garage is open (var 174 at 6), from the floor the player stands on.
PokeAccess::Game.define("opalo") do
  told = lambda { PokeAccess::Puzzles.assist? && $game_variables[174].to_i < 6 }

  mechanic(:state, 341) do
    auto
    obstacle({ :events => (28..37).to_a + (39..44).to_a }, :label => :loc_sign_locked)
    active { told.call }
    hint :op_casino_hint_lever_floor
  end

  mechanic(:state, 342) do
    auto
    active { told.call }
    hint :op_casino_hint_garage_floor
  end
end
