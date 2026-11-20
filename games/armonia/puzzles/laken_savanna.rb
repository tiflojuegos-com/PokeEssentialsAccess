# Sabana Lakén (map 69): nine Hippopotas (events 1 to 3 and 5 to 10, sight 1 to 4) walk their rounds between the way in and the
# scene at the far end (event 11), which sets switch 91 and opens the way on to map 70 (events 23 to 25). One that sees the
# player sends them through Ciudad Wiel (map 111) back to (19, 17). They sound as they move, the rule is said once a session and
# the move back as theirs. Event 4 only fights.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 69) do
    auto
    obstacle({ :events => [1, 2, 3, 5, 6, 7, 8, 9, 10] }, :moving => true)
    sent_back :arm_laken_caught, :to => [19, 17], :maps => [111]
    arrival_hint :arm_laken_rule, :once => true
    phase lambda { !$game_switches[91] }, :quiet => true, :hint => :arm_laken_hint
    solved { $game_switches[91] }
  end
end
