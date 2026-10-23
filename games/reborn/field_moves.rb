# Reborn's golden tools stand in for a Pokemon that knows a field move, each with that move's disc in the bag too, the
# move's badge still asked (HiddenMoves.rb).
PokeAccess::Game.define("reborn") do
  field_move_tool(:CUT, [:GOLDENAXE, :HM01])
  field_move_tool(:ROCKSMASH, [:GOLDENHAMMER, :TM94])
  field_move_tool(:STRENGTH, [:GOLDENGAUNTLET, :HM04])
  field_move_tool(:SURF, [:GOLDENSURFBOARD, :HM03])
  field_move_tool(:WATERFALL, [:GOLDENJETPACK, :HM05])
  field_move_tool(:DIVE, [:GOLDENSCUBAGEAR, :HM06])
end
