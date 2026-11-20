# Void Gauntlet, Pokemon Mansion (map 470): from the Void Gauntlet entrance the way to Naragex Forest is shut by six gates
# (events Gate_1A to Gate_1F). The secret switch (event 30, at 9,7) toggles switch 686, the gates' state, and sits in a
# chamber with no way in on foot; Heart Swap, which swaps places with the statue (event 3, at 13,10) from up to seven
# tiles on each axis, lands in it, and another Heart Swap from the chamber returns to where the statue was left.
PokeAccess::Game.define("insurgence") do
  gates_open = lambda { $game_switches[686] }
  mechanic(:state, 470) do
    auto
    name 30, :ins_u2_mansion_switch
    name(/\AGate_1/, :ins_u2_mansion_gate, :grouped => true)
    phase lambda { !gates_open.call }, :quiet => true, :hint => :ins_u2_mansion_hint
    phase lambda { gates_open.call }, :quiet => true, :hint => :ins_u2_mansion_open_hint
  end
end
