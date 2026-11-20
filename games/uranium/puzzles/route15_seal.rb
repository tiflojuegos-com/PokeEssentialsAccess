# The seal of Route 15's seafloor (map 220): two seals painted on the floor (events 10 and 22, with no graphic of their
# own) ask for five symbols in a row. One sequence, the one Kaito's note gives, lights switch 146 and takes away the
# bubbles to the left (event 1), which send the player back to the seal (36, 12) and close the way on; another lights 147
# and takes away those to the right (event 3), before a few items.
module PokeAccess
  module UraniumSeal
    # What the right sequence lights, read each time a menu of the seal opens: switch 146, the way on, while it is off;
    # then 147; nothing once both are lit.
    def self.takes
      return { :switch => 146 } unless $game_switches[146]
      $game_switches[147] ? nil : { :switch => 147 }
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 220) do
    auto
    name [10, 22], :ura_rp_seal
    name [1, 3], :ura_rp_bubbles
    watch :switch => 146, :say => :ura_rp_bubbles_left_gone
    watch :switch => 147, :say => :ura_rp_bubbles_right_gone
    sent_back :ura_rp_bubbles_back, :to => [36, 12], :events => [1, 3]
    arrival_hint :ura_rp_seal_rule
    right_choice [10, 22], :takes => lambda { PokeAccess::UraniumSeal.takes }
    hint :ura_rp_seal_hint
    solved(nil) { $game_switches[146] }
  end
end
