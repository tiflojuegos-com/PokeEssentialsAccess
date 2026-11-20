# The routes ride the arrow floor of Sede Nytia N.3 (map 200): a step onto an arrow ends where its move, chains taken, leaves
# the player (puzzles/nytia_arrows.rb).
PokeAccess::Game.define("armonia") do
  terrain_rule(:tiles => lambda { |x, y| !PokeAccess::ArmoniaArrows.at(x, y).nil? }) do |x, y, _d|
    PokeAccess::ArmoniaArrows.landing(x, y)
  end
end
