# Mosswater Industrial (map 71): two keypads with no sprite on drawn consoles, the elevator lock (event 183, code 3179,
# variable 634 to 21) and the secondary security (event 201, code 4862, to 27). Monitors drawn mosswaterkeyboard show
# one digit of a code each (events 186 to 188, 200, 206, 228 and 232), which stays drawn beside the monitor once read.
module PokeAccess
  module RebornMosswater
    CLUES = [186, 187, 228, 188, 200, 232, 206]

    # The factory's story step, variable 634.
    def self.step; $game_variables[634].to_i; end

    # With the assist, the code the keypad ahead asks for.
    def self.hint
      step < 21 ? :rba_mw_hint_lift : :rba_mw_hint_security
    end
  end
end

PokeAccess::Game.define("reborn") do
  moss = PokeAccess::RebornMosswater
  mechanic(:state, 71) do
    auto
    name 183, :rba_mw_lift_keypad
    name 201, :rba_mw_security_keypad
    name moss::CLUES, :rba_mw_clue_monitor, :assist => true
    hint lambda { moss.hint }
    active { moss.step < 27 }
    solved { moss.step >= 27 }
  end
end
