# The back of Route 1 (map 5): the Exploud 29 at (28,28), named "Trainer(4)", sees four tiles ahead. When it sees the
# player facing it, a level 50 wild battle starts; won or caught, it is gone (switch 93 off). Fled, it starts: the six
# Loudred (19, 41 to 45) wake, each fighting at a touch, and the Exploud moves to event 9 at (19,14) with switch 93 on.
PokeAccess::Game.define("rejuvenation") do
  watchers(5, :events => [29])
  mechanic(:state, 5, :part => :exploud) do
    auto
    name 29, :rj_exploud
    active { PokeAccess::Puzzles.assist? }
    hint lambda { $game_switches[93] ? :rj_exploud_awake_hint : :rj_exploud_hint }
  end
end
