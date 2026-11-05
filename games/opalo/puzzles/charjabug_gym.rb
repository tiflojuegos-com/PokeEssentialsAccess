# Opalo's gym of Charjabug (map 121): the four Charjabug drawn differently from their groups (events 1, 15, 20 and 33, switches
# 284, 285, 282 and 283) power the generators and add to var 83, event 15 two and the others one; with 4 the barriers go.
# The leader's medal (switch 255) ends it: no rule on arriving, nothing on the info key.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 121) do
    auto
    name [1, 15, 20, 33], :op_g6_special
    obstacle(/rayosBarrera/, :label => :op_g6_barrier)
    count :op_g6_caught, :switches => 282..285
    arrival_hint :op_g6_rule
    solved { $game_switches[255] }
    hint :op_g6_hint
  end
end
