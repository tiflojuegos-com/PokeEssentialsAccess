# Obsidia Slums (map 85): the fridge drawn at the top left (event 43, used facing up from (4, 8)) hides a switch that
# opens the way north (switch 1753); pressed before fighting Victoria (variable 56 at 3) it skips the fight. The core
# says what it opens.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 85, :part => :fridge) do
    auto
    name 43, :rbf_fridge, :when => lambda { |_ev| PokeAccess::Puzzles.assist? }
    hint :rbf_fridge_hint
    solved(nil, :quiet => true) { $game_switches[1753] }
  end
end
