# Ilex Forest's clearing of sleeping Pokemon (map 266): on a Tuesday night (switch 1022) entering it facing up with the
# flute not yet played (switch 1008) sets switch 1020, takes the running away and puts a wait between steps of 36 seconds of the game's clock, which runs 60 times
# faster (under a second); running, or stepping before the wait is over (event 31), sets switch 1021 and the sleepers
# (events 32 to 39) flee.
PokeAccess::Game.define("infinitefusion") do
  sleepers = (32..39).to_a

  mechanic(:state, 266) do
    auto
    name sleepers, :ifq_ilex_sleeper
    watch :switch => 1020, :say => :ifq_ilex_rule
    watch :switch => 1021, :say => :ifq_ilex_spooked
    active { $game_switches[1020] }
    hint :ifq_ilex_hint
  end
end
