# The hunt for Corin-Rouge (variable 155), after the Police Station: the suspects of Sunset Circle (map 522, event 145),
# Malchous Forest Park (533, 52) and the Coral Gym's ward (536, 31) add one each when beaten, 9 to 12. Their clues point
# to the Coral Gym's flower bed (613, event 4, used facing up), where Carmen sets 13; the Sunset Circle one is real.
module PokeAccess
  module RebornCorin
    SUSPECTS = { 522 => 145, 533 => 52, 536 => 31 }

    # The hunt's step.
    def self.step
      $game_variables[155].to_i
    end

    # A suspect's name while the hunt asks for it, or nil to leave its own.
    def self.label(map)
      return :rbf_corin_suspect if step >= 9 && step <= 11
      return :rbf_corin_real if step == 13 && map == 522 && PokeAccess::Puzzles.assist?
      nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  corin = PokeAccess::RebornCorin
  corin::SUSPECTS.each do |map, id|
    mechanic(:state, map, :part => :corin) do
      auto
      name id, lambda { |_ev| corin.label(map) }, :when => lambda { |_ev| !corin.label(map).nil? }
      phase lambda { PokeAccess::Puzzles.assist? && corin.step == 12 }, :quiet => true, :hint => :rbf_corin_riddle_hint
      phase lambda { PokeAccess::Puzzles.assist? && corin.step == 13 }, :quiet => true, :hint => :rbf_corin_real_hint
      active { corin.step == 12 || corin.step == 13 }
    end
  end
  mechanic(:state, 613, :part => :corin) do
    auto
    hide 4, :when => lambda { |_ev| !PokeAccess::Puzzles.assist? }
    name 4, :rbf_corin_flowers, :assist => true, :when => lambda { |_ev| corin.step == 12 }
    phase lambda { PokeAccess::Puzzles.assist? && corin.step == 12 }, :quiet => true, :hint => :rbf_corin_flowers_hint
    active { corin.step == 12 }
  end
end
