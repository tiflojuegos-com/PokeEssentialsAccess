# Pirámides Origen: the statues that speak to whoever carries the right Pokemon or item, event 17 of map 31 and event 9 of map 189,
# by a name in place of their graphic's file name. What they ask they say themselves, and failing costs nothing.
PokeAccess::Game.define("armonia") do
  [[31, 17], [189, 9]].each do |map, statue|
    mechanic(:state, map) do
      auto
      name statue, :arm_origen_statue
    end
  end
end
