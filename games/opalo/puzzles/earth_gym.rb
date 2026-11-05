# Opalo's gym of earth (map 38): five levers in a chain (switches 169 to 173) that lower the rocks on the way to the leader's
# door, and the Mudsdale (sprite 750) that patrol and send the player back to a checkpoint. The leader's medal (switch 130)
# ends it: no rule on arriving, nothing on the info key.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 38) do
    auto
    obstacle({ :tile => 1570 }, :label => :op_g2_rocks)
    obstacle(/\A750\z/, :moving => true, :label => :op_g2_mudsdale)
    count :op_g2_levers, :switches => 169..173
    sent_back :op_g2_mudsdale_back, :to => [9, 40], :events => 6..9
    sent_back :op_g2_mudsdale_back, :to => [23, 31], :events => 17..21
    sent_back :op_g2_mudsdale_back, :to => [32, 14], :events => 22..24
    arrival_hint :op_g2_rule
    solved { $game_switches[130] }
    hint :op_g2_hint
  end
end
