# Route 12 (map 127), the maze man's hidden item: four balls look alike until the prize is won (switch 128). The one at
# (17, 43) holds the TM; the other three are a Voltorb, an Electrode and a Foongus.
PokeAccess::Game.define("herolegacy") do
  open = lambda { |label| lambda { |_ev| $game_switches[128] ? nil : label } }
  mechanic(:state, 127) do
    auto
    name 25, open.call(:hl_maze_real), :assist => true
    name [59, 61, 62], open.call(:hl_maze_decoy), :assist => true
  end
end
