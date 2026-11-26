# Morove Cavern's mural (map 690, EV11, Case Seventeen): a tile puzzle, pbTilePuzzle(4, "Stakataka"), read by the core's
# Tile Puzzle reader. The picture is only named until solved, which sets self switch B and gives the Mural Clue.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 690, :part => :afd_mural) do
    auto
    name 11, :afd_mural, :when => lambda { |_ev| !$game_self_switches[[690, 11, "B"]] }
    solved(nil, :quiet => true) { $game_self_switches[[690, 11, "B"]] }
  end
end
