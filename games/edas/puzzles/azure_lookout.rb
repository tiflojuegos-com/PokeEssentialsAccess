# Edas' Cima Azur (map 41): two touch tiles on the cliff edge (events 1 and 2) show a picture of the fields of Pueblo Dominus and
# turn switch 82 on, which the policeman of the fields in map 22 takes as the report he asked for. They have no graphic, so
# they are named for the lists.
PokeAccess::Game.define("edas") do
  mechanic(:state, 41) do
    auto
    name [1, 2], :edas_lookout
  end
end
