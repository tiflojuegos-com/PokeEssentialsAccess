# Jirukala Cavern (map 211): the interface 34 at (54,35), with no graphic, asks four digits into variable 28 and opens
# with 9867 (variable 313 to 4). The page compares the entry with that one value, so the core says it with the assist.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 211, :part => :interface) do
    auto
    name 34, :rj_jirukala_interface, :when => lambda { |_ev| $game_variables[313].to_i < 4 }
  end
end
