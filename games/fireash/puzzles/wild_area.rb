# Wild Area (map 222): the two rocks by the Kubfu's keeper (events 11 and 12, no sprite) evolve a Kubfu in the party to one
# form of Urshifu the moment they are touched, with no question, so the walks keep off them. Galar's Wild Area (map 397) has
# the rune rock likewise (event 10, two tiles by two), which evolves a Galarian Yamask that has been hurt enough.
PokeAccess::Game.define("fireash") do
  mechanic(:state, 222) do
    auto
    name 11, :fa_o_rock_single
    name 12, :fa_o_rock_rapid
    avoid [11, 12]
  end
  mechanic(:state, 397) do
    auto
    name 10, :fa_o_rock_yamask
    avoid [10]
  end
end
