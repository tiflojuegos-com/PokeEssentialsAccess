# Burole Town's gym (map 66): fifteen rocks smashed one at a time. Event 21 draws a number into variable 108 once, and the
# one rock whose own number matches holds the gem (switch 67) that the pillar in front of Davern asks for.
module PokeAccess
  module UraniumBurole
    # The number event 21 can draw that each rock holds the gem for, by the rock's event id.
    def self.gem_number
      { 5 => 1, 6 => 2, 7 => 3, 8 => 6, 9 => 5, 10 => 8, 11 => 7, 13 => 9, 14 => 10, 15 => 11, 16 => 12, 17 => 14, 18 => 13,
        19 => 0, 20 => 4 }
    end

    # Whether the rock still unbroken holds the gem the game has not yet given.
    def self.holds_gem?(event_id)
      !$game_switches[67] && $game_variables[108].to_i == gem_number[event_id] &&
        !$game_self_switches[[66, event_id, "A"]]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 66) do
    auto
    arrival_hint :ura_pz_burole_rule
    solved(nil) { $game_switches[62] }
    PokeAccess::UraniumBurole.gem_number.keys.each do |id|
      spot :event => id, :label => :ura_pz_gem_rock, :assist => true,
           :when => lambda { |*args| PokeAccess::UraniumBurole.holds_gem?(id) }
    end
  end
end
