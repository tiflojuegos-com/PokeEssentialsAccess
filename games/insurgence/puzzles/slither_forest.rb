# Slither Forest (map 765, reached by flight at 27,62): the Manaphy statue (event 37, at 26,47) stands in a pocket of 91 tiles
# (y 38 to 49) south of the boulder field. Heart Swap within seven tiles trades places with it and lands in the pocket, whose
# only way on, other than another Heart Swap back south, is pushing boulders; Delta Deino (event 2, at 30,20) and the items lie
# beyond, and the hint stops once Deino has been met (its self switch A).
PokeAccess::Game.define("insurgence") do
  deino_met = lambda { $game_self_switches[[765, 2, "A"]] }
  mechanic(:state, 765) do
    auto
    active { !deino_met.call }
    solved(nil, :quiet => true) { deino_met.call }
    hint :ins_u2_slither_hint
  end
end
