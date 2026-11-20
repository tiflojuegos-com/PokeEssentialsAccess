# Infernal Base, Diana's cell (map 432): the cell (57,27) and the nook with the button (event 34, switch 439 opens the
# cells) are walled off from the room below. The Manaphy statue (event 29, at 63,27) is inside the nook, so Heart Swap,
# which swaps places with the first statue within seven tiles on each axis, is the way in and, once the button is
# pressed, out again. The Manaphy scene (event 19, which ends by turning switch 435 on) teaches Heart Swap (variable 42,
# entry 5); switch 437 ends the cell.
PokeAccess::Game.define("insurgence") do
  swap_known = lambda { ($game_variables[42][5] rescue false) == true }
  cells_open = lambda { $game_switches[439] }
  done = lambda { $game_switches[437] }
  ready = lambda { swap_known.call && $game_switches[435] && !done.call }
  mechanic(:state, 432) do
    auto
    spot :event => 34, :label => :ins_inf_button, :assist => true, :onto => true, :when => lambda { !cells_open.call }
    phase lambda { ready.call && !cells_open.call }, :title => :ins_inf_rule, :hint => :ins_inf_hint
    phase lambda { ready.call && cells_open.call }, :title => :ins_inf_rule, :quiet => true, :hint => :ins_inf_hint_out
    solved(nil, :quiet => true) { done.call }
  end
end
