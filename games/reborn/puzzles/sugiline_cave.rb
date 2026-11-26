# The Sugiline Cave (map 654): the stairs down are a sand slide (tiles 45 to 54 at y 30 push the player back) until both
# buttons under the Arceus statues are pressed, 56 at (17,29) for switch 886 and 57 at (32,29) for 887. Below, the sand
# pits of the B1F maps (656 to 659) drop the player at the cave's mouth, map 651 at (34,44).
module PokeAccess
  module RebornSugilineCave
    BUTTONS = { 56 => 886, 57 => 887 }
    PITS = [656, 657, 658, 659]

    # True once both buttons are pressed and the stairs stand.
    def self.stairs?
      BUTTONS.values.all? { |sw| $game_switches[sw] }
    end
  end
end

PokeAccess::Game.define("reborn") do
  cave = PokeAccess::RebornSugilineCave
  mechanic(:state, 654, :part => :stairs) do
    auto
    name cave::BUTTONS.keys, :rbe_sc_button, :when => lambda { |ev| !$game_switches[cave::BUTTONS[ev.id]] }
    arrival_hint lambda { PokeAccess::Puzzles.assist? ? :rbe_sc_hint : nil }
    solved(nil, :quiet => true) { cave.stairs? }
  end

  mechanic(:state, 651, :part => :pits) do
    auto
    sent_back :rbe_sc_fell, :to => [34, 44], :maps => cave::PITS
  end
end
