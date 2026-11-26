# The crest of the Forsaken Laboratory (map 403): event 62, with no graphic, opens the stock Tile Puzzle on the "Panel"
# picture; solving it sets variable 431 to 5. The core reads the puzzle.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 403, :part => :crest_panel) do
    auto
    name 62, :rj_null_panel, :when => lambda { |_ev| $game_variables[431].to_i < 5 }
  end
end
