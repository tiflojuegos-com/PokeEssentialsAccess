# Reminiscencia's PC box is eight slots wide: the profile's column count is the game's NUMROWS, its horizontal
# cursor stride (the game's names are swapped), and the shared width stands without that constant.
require File.expand_path("../../../games/reminiscencia/pc_grid", File.dirname(__FILE__))

Suite.define("reminiscencia pc: a row holds what the game's own cursor stride says") do
  party = PokeAccess::Party
  eq "without the game's constant the shared width stands", party.box_columns, 6
  begin
    Object.const_set(:NUMROWS, 8)
    eq "with it, a row holds eight", party.box_columns, 8
  ensure
    Object.send(:remove_const, :NUMROWS) if Object.const_defined?(:NUMROWS)
  end
  eq "and it is back to the shared width once the game is gone", party.box_columns, 6
end
