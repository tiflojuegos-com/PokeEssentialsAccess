# Vitro's gym of Cianwood (Gimnasio Orquidea, map 47): a wheel (event 2) flips switch 95, which stops the waterfall (event 4) that
# falls on Anibal, who will not battle while it falls. The wheel says nothing of what it did. Switch 8 is the badge.
PokeAccess::Game.define("vitro") do
  mechanic(:state, 47) do
    name 2, :vitro_cianwood_wheel
    name 4, :vitro_cianwood_waterfall
    watch :switch => 95, :label => :vitro_cianwood_gate, :on => :vitro_cianwood_closed, :off => :vitro_cianwood_open
    solved { $game_switches[8] }
    arrival_hint :vitro_cianwood_rule
    hint :vitro_cianwood_hint
  end
end
