# Puka Island (map 4), the call of Deoxys: with Rayquaza in the party, a tile with no graphic at (21, 19) says its ball
# moves, and the one at (44, 22) that it moves hard and turns switch 244 on, which brings Deoxys to (35, 23). Nothing
# shows either tile, so the second is listed with the puzzle assist alone.
PokeAccess::Game.define("herolegacy") do
  rayquaza = lambda { PokeAccess::Data.species_name(:RAYQUAZA).to_s }
  mechanic(:state, 4) do
    auto
    name 7, lambda { |_ev| PokeAccess::I18n.t(:hl_deoxys_spot, :name => rayquaza.call) },
         :assist => true, :when => lambda { |_ev| !$game_switches[244] }
  end
end
