# Vitro's Sinjoh Ruins (map 154): three circles drawn on the floor, walked onto, each a strip with no sprite: Dialga's (event
# 6), Palkia's (event 11) and Giratina's (event 12). Each asks to confirm only with Arceus first in the party, sets variable 53
# to 1, 2 or 3 and variable 45 to 7, and starts the scene. There is no wrong one: they are named until the choice is made.
PokeAccess::Game.define("vitro") do
  mechanic(:state, 154) do
    auto
    unchosen = lambda { |_ev| $game_variables[45] < 7 }
    name 6, :vitro_sinjoh_dialga, :when => unchosen
    name 11, :vitro_sinjoh_palkia, :when => unchosen
    name 12, :vitro_sinjoh_giratina, :when => unchosen
  end
end
