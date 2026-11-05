# Opalo's gym of ghosts (map 110): three levers (switches 218, 216 and 217, in the order they can be reached) that turn
# cracks into floor on the way to the leader's door.
PokeAccess::Game.define("opalo") do
  mechanic(:state, 110) do
    auto
    obstacle(/grietas/, :label => :op_g5_cracks)
    count :op_g5_levers, :switches => 216..218
    hint :op_g5_hint
  end
end
