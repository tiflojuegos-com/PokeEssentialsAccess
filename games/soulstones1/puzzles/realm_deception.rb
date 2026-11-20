# Realm of Deception (map 280): invisible barriers shove the player back until the branches are walked in one order,
# each ending in a scene that raises variable 149: Alexis (events 28 and 29) to 1, Leo (31 and 32) to 2 and Selene (37 and
# 39) to 3, which lets the player on to Dahlia (event 14). The game says each barrier itself; the assist points at the
# next scene.
module PokeAccess
  module SoulstonesDeception
    NEXT = [28, 31, 37, 14]

    # The event the assist points at now.
    def self.next_event
      NEXT[[$game_variables[149].to_i, NEXT.length - 1].min]
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  deception = PokeAccess::SoulstonesDeception

  mechanic(:state, 280) do
    auto
    deception::NEXT.each do |id|
      spot(:event => id, :label => :puzzle_right_way, :assist => true, :when => lambda { deception.next_event == id })
    end
    hint :ss1_deception_hint
    active { PokeAccess::Puzzles.assist? && $game_variables[149].to_i < 3 }
    solved(nil, :quiet => true) { $game_variables[149].to_i >= 3 }
  end
end
