# Racine's gym (maps 167 and 168). In the nursery (map 167) the trampoline (event 1) steps away from the player who walks into
# it; a parallel event sets switch 96 once it stands on (18, 17), and then event 4 at (14, 9) throws the player over the wall,
# the one way on. Its moves are followed and, with the assist, how far it is from its place. In the gym above (map 168) the bug
# Pokemon that bump the player throw them back down, which is said as theirs.
PokeAccess::Game.define("armonia") do
  mechanic(:state, 167) do
    auto
    name 1, :arm_racine_trampoline
    name 4, :arm_racine_jump, :when => lambda { |_ev| $game_switches[96] }
    phase lambda { !$game_switches[96] }, :quiet => true, :hint => :arm_racine_trampoline_hint,
          :track => { :event => 1, :label => :arm_racine_trampoline, :goal => [18, 17, 18, 17],
                      :goal_label => :arm_racine_trampoline_goal }
    solved { $game_switches[96] }
  end

  mechanic(:state, 168) do
    auto
    sent_back :arm_racine_knocked, :events => [56, 57, 58, 59, 60, 62, 65]
  end
end
