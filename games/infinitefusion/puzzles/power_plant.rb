# Power Plant (map 198): the two silent terminals (events 90 and 96) charge the gate (events 92 to 94) with the five cell
# batteries lying around, 4 points each out of the 20 the gate wants (variable 129); switch 297 is the open gate.
PokeAccess::Game.define("infinitefusion") do
  needed = 20
  per_battery = 4
  open = lambda { $game_switches[297] }
  missing = lambda { (needed - $game_variables[129] + per_battery - 1) / per_battery }

  mechanic(:state, 198) do
    auto
    name [90, 96], :ifo_pp_terminal
    name [92, 93, 94], :ifo_pp_gate, :grouped => true, :when => lambda { |_ev| !open.call }
    count :ifo_pp_batteries, :var => 130, :of => 5, :assist => true
    hint lambda { open.call ? nil : (missing.call <= 0 ? :ifo_pp_open : [:ifo_pp_hint, { :n => missing.call }]) }
    active { PokeAccess::Puzzles.assist? && !open.call }
  end
end
