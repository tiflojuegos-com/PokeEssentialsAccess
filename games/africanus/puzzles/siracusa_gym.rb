# Siracusa's gym (map 214): six invisible smelting points give one ingot a press (variables 56 gold, 57 silver, 58
# copper). The Bronzor of event 2 opens the east door (switch 211) with 1 copper, 1 silver and no gold, the one of event 1
# the west door (switch 212) with 2 gold, 1 copper and no silver. A wrong key empties the ingots and burns a random
# Pokemon; a right one keeps them. Events 12 and 13 throw them away, and so does event 22 at (30, 17), the one way
# north past the east door. Both doors open ends it: no rule on arriving, nothing on the info key.
PokeAccess::Game.define("africanus") do
  metals = [{ :var => 56, :label => :af_ingot_gold }, { :var => 57, :label => :af_ingot_silver },
            { :var => 58, :label => :af_ingot_copper }]
  mechanic(:state, 214) do
    auto
    name [8, 14], :af_forge_gold
    name [15, 16], :af_forge_silver
    name [17, 18], :af_forge_copper
    name [12, 13], :af_forge_dump
    name 2, :af_bronzor_east
    name 1, :af_bronzor_west
    on_use 22, lambda { [56, 57, 58].any? { |v| $game_variables[v].to_i > 0 } ? :af_forge_empties : "" }
    arrival_hint :af_forge_rule
    solved { $game_switches[211] && $game_switches[212] }
    phase(lambda { !$game_switches[211] }, :title => :af_forge_east, :hint => :af_forge_east_hint, :values => metals)
    phase(lambda { $game_switches[211] && !$game_switches[212] }, :title => :af_forge_west,
          :hint => :af_forge_west_hint, :values => metals)
  end
end
