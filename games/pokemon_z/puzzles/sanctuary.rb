# Santuario Prosperidad (map 119): 3x3 floor runes, each toggling a switch, to form X, Y and Z in turn (var 95
# is the stage; switches 190 and 193 mark Y and Z, 194 the solve). The solve's autorun puts every rune out 80 frames
# later, var 95 still at its stage until the transfer, so the puzzle is over once 194 is on.
PokeAccess::Game.define("pokemon_z") do
  sw = [172, 173, 174, 175, 184, 185, 186, 187, 188]
  x_pat = [true, false, true, false, true, false, true, false, true]
  y_pat = [true, false, true, false, true, false, false, true, false]
  z_pat = [true, true, true, false, true, false, true, true, true]
  mechanic(:grid, 119) do
    cells 3, [[13, 11], [15, 11], [17, 11],
              [13, 13], [15, 13], [17, 13],
              [13, 15], [15, 15], [17, 15]]
    lit { |i| $game_switches[sw[i]] }
    active { $game_variables[95] >= 1 && $game_variables[95] < 4 && !$game_switches[194] }
    solved { $game_switches[194] || $game_variables[95] >= 4 }
    target do
      v = $game_variables[95]
      if v < 1 || v >= 4
        nil
      elsif $game_switches[193]
        { :name => "Z", :pattern => z_pat }
      elsif $game_switches[190]
        { :name => "Y", :pattern => y_pat }
      else
        { :name => "X", :pattern => x_pat }
      end
    end
  end
end
