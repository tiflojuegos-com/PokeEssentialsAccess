# Termitero Alfa (map 149): four termites (events 1, 2, 3 and 7, sight 1) walk up and down their columns across the room between
# the way in and the way down to map 151. One that has the player right in front of it sends them back to (44, 27), by the way
# in. They sound as they move, the rule is said on arriving and the move back as theirs, until the mound's story ends (switch 94).
PokeAccess::Game.define("armonia") do
  mechanic(:state, 149) do
    auto
    obstacle({ :events => [1, 2, 3, 7] }, :moving => true)
    sent_back :arm_termite_caught, :to => [44, 27], :events => [1, 2, 3, 7]
    arrival_hint :arm_termite_rule
    phase lambda { true }, :quiet => true, :hint => :arm_termite_hint
    solved { $game_switches[94] }
  end
end
