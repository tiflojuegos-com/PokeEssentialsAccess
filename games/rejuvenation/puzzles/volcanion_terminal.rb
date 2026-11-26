# Volcanion's terminal in the V.G.C.R. (map 153): the monitor 30, used facing up while variable 214 is 9, offers SHUT
# DOWN, TRANSFER and FEED. SHUT DOWN asks an executive id (XE089321, in the machine notes 71); TRANSFER sends it to
# Carotos Mountain (214 to 10). The page compares the text in a script: the core does not answer it.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 153, :part => :volcanion) do
    auto
    name 30, :rj_volcanion_terminal, :when => lambda { |_ev| $game_variables[214].to_i == 9 }
    name 71, :rj_volcanion_notes
    on_use 30, lambda { |_ev| $game_variables[214].to_i == 9 ? :rj_volcanion_id : nil }, :assist => true
  end
end
