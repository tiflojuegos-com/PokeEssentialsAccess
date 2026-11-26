# Tanzan Mountain (map 273), Mew's errand: the green crystal drawn on the floor (event 6) reacts to a crystal plug in
# the bag and lights switch 544, which lets the rock at (12, 11) (event 7) break with Rock Smash. The game plays no
# sound.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 273, :part => :green_crystal) do
    auto
    name 6, :rbf_green_crystal
    name 7, lambda { |_ev| $game_switches[544] ? :rbf_cracked_rock : nil }
    watch :switch => 544, :say => :rbf_green_crystal_lit
  end
end
