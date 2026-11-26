# Mossy Town's Hamstar Chasing (episode 3, maps 8 to 12): with switch 185 on, seven Hamstar to find before Hannah (map
# 11) ends the episode; variable 52 counts them. Five are drawn; two answer at places with no graphic: the shore (event
# 44, x 43, y 13 to 16), which asks for the Pokemon that lifts the swimming one out, and the wall under the roof (event
# 41, x 26, y 19 to 21, from the sixth on), which asks for one that flies up, both checked with pbChoosePokemon.
module PokeAccess
  module SlldHamstar
    # True while the chase runs: started and not all seven found.
    def self.chasing?
      $game_switches[185] && $game_variables[52] < 7
    end

    # The answer to a choice of Pokemon, by the species' name.
    def self.choose(species)
      [:puzzle_answer, { :a => PokeAccess::Data.species_name(species).to_s }]
    end
  end
end

PokeAccess::Game.define("slld_anime") do
  ham = PokeAccess::SlldHamstar
  mechanic(:state, 8) do
    auto
    name 44, :slld_hamstar_shore, :when => lambda { |_ev| ham.chasing? }
    name 41, :slld_hamstar_wall, :when => lambda { |_ev| ham.chasing? && $game_variables[52] >= 6 }
    on_reach 44, { :text => /another idea/ }, lambda { |_ev| ham.choose(:MOONKY) }, :assist => true
    on_reach 41, { :text => /help with that/ }, lambda { |_ev| ham.choose(:BUDCHEEP) }, :assist => true
    count :slld_hamstars, :var => 52, :of => 7, :hide_zero => true
    active { ham.chasing? }
    solved(nil, :quiet => true) { $game_variables[52] >= 7 }
    hint :slld_hamstar_hint
  end
  [9, 10, 12].each do |map|
    mechanic(:state, map) do
      auto
      count :slld_hamstars, :var => 52, :of => 7, :hide_zero => true
      active { ham.chasing? }
      solved(nil, :quiet => true) { $game_variables[52] >= 7 }
    end
  end
end
