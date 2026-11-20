# Amatree Town's gym (map 69): seven boulders pushed onto their own tile. Each boulder writes its tile into variables 113
# and 114 and, only when it stands exactly on its own, turns its switch on (a push past it turns it off); a row of torches
# changes with each. Switch 94 marks the leader's defeat.
module PokeAccess
  module UraniumAmatree
    # Each boulder's event, its switch and the tile it belongs on, in the order the game numbers them (Gym 5 Puzzle 1 to 7).
    def self.boulders
      [[9, 87, 17, 29], [1, 88, 11, 24], [26, 89, 6, 29], [69, 90, 12, 14], [2, 91, 24, 24], [111, 92, 24, 9], [123, 93, 6, 8]]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 69) do
    auto
    arrival_hint :ura_pz_amatree_rule
    solved(nil) { $game_switches[94] }
    count :ura_pz_boulders, :switches => PokeAccess::UraniumAmatree.boulders.map { |b| b[1] }, :of => 7
    PokeAccess::UraniumAmatree.boulders.each do |event, switch, x, y|
      phase lambda { !$game_switches[switch] }, :quiet => true, :hint => :ura_pz_boulder_hint,
            :track => { :event => event, :label => :ura_pz_boulder, :goal => [x, y, x, y],
                        :goal_label => :ura_pz_boulder_goal }
    end
  end
end
