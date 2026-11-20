# The Rangers' first mission in Angelure Shoals (map 233, variable 133 at 1): ten Sponaree on watch (events 17 to 26)
# walk or turn and catch the player they see five tiles ahead, which sends the player back to the entrance (common event
# 40) and takes back the berries. The "Trainer(5)" ones see until something stands in the way, the "Counter(5)" ones
# (18, 24 and 26) over it.
module PokeAccess
  module UraniumShoals
    def self.sponaree; (17..26).to_a; end
    def self.over_obstacles; [18, 24, 26]; end

    def self.mission?
      $game_variables[133].to_i == 1 && !$game_switches[155]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 233) do
    auto
    name PokeAccess::UraniumShoals.sponaree,
         lambda { |ev| PokeAccess::UraniumShoals.over_obstacles.include?(ev.id) ? :ura_r3_sponaree_over : :ura_r3_sponaree }
    arrival_hint lambda { PokeAccess::UraniumShoals.mission? ? :ura_r3_sponaree_rule : nil }
    active { PokeAccess::UraniumShoals.mission? }
  end
end
