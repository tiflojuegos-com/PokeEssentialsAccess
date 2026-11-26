# The school trip to the Mossy Monument (map 793): variable 370 counts the children's clues and four lets the class
# leave (EV38). Alice (EV5) asks for a word with its mark (passCheck "Achoo!"); Kalvin (EV6) asks what the player wants
# to know: the statues add to 370, Henry (self switch D) opens the monument.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 793, :part => :trip) do
    auto
    right_choice 6, :takes => lambda { $game_self_switches[[793, 6, "B"]] ? { :self => "D" } : { :var => 370 } }
  end
end

# Inside (map 794) four Unown stones (EV3 to EV6, no graphic) do nothing until Alice has told of her Rage Candy Bar
# (switch 365, her EV18 outside). A bar draws the Unown out to fight (self switch A); with none left the clue counts
# alone (self switch B).
module PokeAccess
  module AshenMossyInterior
    MAP = 794
    STONES = [3, 4, 5, 6]
    ALICE_TOLD = 365

    # Whether a stone has given its clue.
    def self.done?
      STONES.any? { |ev| $game_self_switches[[MAP, ev, "A"]] || $game_self_switches[[MAP, ev, "B"]] } ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  inside = PokeAccess::AshenMossyInterior
  mechanic(:state, inside::MAP, :part => :stones) do
    auto
    name inside::STONES, :afi_unown_stone, :grouped => true
    right_choice inside::STONES, :takes => { :var => 370 }
    phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[inside::ALICE_TOLD] && !inside.done? }, :quiet => true,
          :hint => :afi_mossy_alice_first
    phase lambda { PokeAccess::Puzzles.assist? && $game_switches[inside::ALICE_TOLD] && !inside.done? }, :quiet => true,
          :hint => :afi_mossy_stone, :hidden => right_way(inside::STONES[0])
    solved(nil, :quiet => true) { inside.done? }
  end
end
