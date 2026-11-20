# Single controls of side stories: the generator switch of New Mauville (map 263, event 13, switch 204), the trash can
# of Mauville's Game Corner that hides a red button once the Ranger's errand has begun (map 182, event 43, var 176 at 1),
# and the Regi door of the Sealed Chamber (map 475), which Dig opens with Wailord first in the party and Relicanth last
# (the game's script 400_Sealed Chamber Regis, switch 1075); the braille on its walls says so.
module PokeAccess
  module EmStorySwitches
    # Whether the party stands as the Sealed Chamber's Dig asks: Wailord first and Relicanth last.
    def self.party_ready?
      return false unless $player.respond_to?(:party)
      party = $player.party || []
      party.length >= 2 && party[0].species == :WAILORD && party[-1].species == :RELICANTH
    end

    # The assist's line in the Sealed Chamber, by whether the party is ready.
    def self.sealed_hint
      party_ready? ? :em_sealed_ready : :em_sealed_hint
    end
  end
end

PokeAccess::Game.define("emerald") do
  story = PokeAccess::EmStorySwitches
  mechanic(:state, 263) do
    auto
    name 13, :em_generator_switch, :when => lambda { |_ev| !$game_switches[204] }
    solved(nil, :quiet => true) { $game_switches[204] }
  end

  mechanic(:state, 182) do
    auto
    name 43, :em_corner_can, :assist => true, :when => lambda { |_ev| $game_variables[176].to_i == 1 }
  end

  mechanic(:state, 475) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => lambda { story.sealed_hint }
    solved(nil, :quiet => true) { $game_switches[1075] }
  end
end
