# Route 20 of Kalos (map 865): Wulfric's second fight needs Serena, who stands at (14, 50) from his first fight on (switch
# 270) until she is beaten (switch 271). Her place is already listed as a person; the assist says why to go.
PokeAccess::Game.define("fireash") do
  mechanic(:state, 865) do
    auto
    active { $game_switches[270] && !$game_switches[271] }
    hint :fa_route20_hint
    solved { $game_switches[271] }
  end
end
