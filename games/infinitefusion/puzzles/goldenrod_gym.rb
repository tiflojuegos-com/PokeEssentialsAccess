# Goldenrod Gym (map 524): three counting rounds. Pressing a "count" tile switches on 405, 406 or 407, which draws the
# Pokemon as events named pk1 or pk2; the round's automatic page jumps one of them and switches it off again, so they stay
# on screen for that one jump and are never listed. A wrong answer only starts a battle and the gate opens either way; the
# numeric answers are fixed in the pages, so the core says them with the assist. Beating Whitney sets switch 38.
PokeAccess::Game.define("infinitefusion") do
  beaten = lambda { $game_switches[38] }

  mechanic(:state, 524) do
    auto
    arrival_hint :if_jo_whitney_rule
    hint :if_jo_whitney_hint
    solved(&beaten)
    active { !beaten.call }
  end
end
